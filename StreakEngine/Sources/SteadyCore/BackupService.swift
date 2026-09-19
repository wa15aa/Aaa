import Foundation
import CoreData
import CryptoKit
import Security

/// iCloud 加密备份（MVP_SPEC §3.5/§4）：
/// 单个 AES-GCM 加密 JSON 写 iCloud Drive/Steady/backup.json，每日首次启动增量覆盖。
/// 密钥派生自设备 Keychain（首次生成 256-bit 随机密钥，AfterFirstUnlock）。
public final class BackupService {
    public static let schemaVersion: Int16 = 1

    // MARK: DTO（备份格式，独立于 CoreData 实体，schema 演进可控）

    public struct HabitDTO: Codable, Equatable {
        public var id: UUID; public var name: String; public var icon: String
        public var colorHex: String; public var frequencyKind: String
        public var timesPerWeek: Int16
        public var reminderHour: Int16?; public var reminderMinute: Int16?
        public var reminder2Hour: Int16?; public var reminder2Minute: Int16?
        public var reminder3Hour: Int16?; public var reminder3Minute: Int16?
        public var createdAt: Date; public var createdDay: String
        public var sortOrder: Int16; public var archivedAt: Date?
    }

    public struct CheckinDTO: Codable, Equatable {
        public var habitId: UUID; public var day: String
        public var ts: Date; public var backfill: Bool; public var tzOffsetMinutes: Int32
    }

    public struct Payload: Codable {
        public var schemaVersion: Int16
        public var habits: [HabitDTO]
        public var checkins: [CheckinDTO]
    }

    public enum BackupError: Error {
        case unsupportedSchema(Int16)
        case corrupt
    }

    // MARK: 导出 / 导入（纯逻辑，可测）

    public static func export(context: NSManagedObjectContext) throws -> Data {
        let habits = (try? context.fetch(NSFetchRequest<HabitEntity>(entityName: "Habit"))) ?? []
        let checkins = (try? context.fetch(NSFetchRequest<CheckinEntity>(entityName: "Checkin"))) ?? []
        let payload = Payload(
            schemaVersion: schemaVersion,
            habits: habits.map {
                HabitDTO(id: $0.id, name: $0.name, icon: $0.icon, colorHex: $0.colorHex,
                         frequencyKind: $0.frequencyKind, timesPerWeek: $0.timesPerWeek,
                         reminderHour: $0.reminderHour >= 0 ? $0.reminderHour : nil,
                         reminderMinute: $0.reminderHour >= 0 ? $0.reminderMinute : nil,
                         reminder2Hour: $0.reminder2Hour >= 0 ? $0.reminder2Hour : nil,
                         reminder2Minute: $0.reminder2Hour >= 0 ? $0.reminder2Minute : nil,
                         reminder3Hour: $0.reminder3Hour >= 0 ? $0.reminder3Hour : nil,
                         reminder3Minute: $0.reminder3Hour >= 0 ? $0.reminder3Minute : nil,
                         createdAt: $0.createdAt, createdDay: $0.createdDay,
                         sortOrder: $0.sortOrder, archivedAt: $0.archivedAt)
            },
            checkins: checkins.map {
                CheckinDTO(habitId: $0.habitId, day: $0.day, ts: $0.ts,
                           backfill: $0.backfill, tzOffsetMinutes: $0.tzOffsetMinutes)
            })
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(payload)
    }

    /// 恢复：缺失的习惯/打卡插入，已存在的跳过（幂等，可重复执行）。
    /// - Returns: (新增习惯数, 新增打卡数)
    @discardableResult
    public static func restore(context: NSManagedObjectContext, from data: Data) throws -> (Int, Int) {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let payload = try? dec.decode(Payload.self, from: data) else { throw BackupError.corrupt }
        guard payload.schemaVersion <= schemaVersion else { throw BackupError.unsupportedSchema(payload.schemaVersion) }

        var addedHabits = 0, addedCheckins = 0
        for dto in payload.habits {
            let req = NSFetchRequest<HabitEntity>(entityName: "Habit")
            req.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
            req.fetchLimit = 1
            if ((try? context.count(for: req)) ?? 0) > 0 { continue }
            let h = HabitEntity(entity: NSEntityDescription.entity(forEntityName: "Habit", in: context)!, insertInto: context)
            h.id = dto.id; h.name = dto.name; h.icon = dto.icon; h.colorHex = dto.colorHex
            h.frequencyKind = dto.frequencyKind; h.timesPerWeek = dto.timesPerWeek
            h.reminderHour = dto.reminderHour ?? -1; h.reminderMinute = dto.reminderMinute ?? -1
            h.reminder2Hour = dto.reminder2Hour ?? -1; h.reminder2Minute = dto.reminder2Minute ?? -1
            h.reminder3Hour = dto.reminder3Hour ?? -1; h.reminder3Minute = dto.reminder3Minute ?? -1
            h.createdAt = dto.createdAt; h.createdDay = dto.createdDay
            h.sortOrder = dto.sortOrder; h.archivedAt = dto.archivedAt
            addedHabits += 1
        }
        for dto in payload.checkins {
            let req = NSFetchRequest<CheckinEntity>(entityName: "Checkin")
            req.predicate = NSPredicate(format: "habitId == %@ AND day == %@", dto.habitId as CVarArg, dto.day)
            req.fetchLimit = 1
            if ((try? context.count(for: req)) ?? 0) > 0 { continue }
            let c = CheckinEntity(entity: NSEntityDescription.entity(forEntityName: "Checkin", in: context)!, insertInto: context)
            c.id = UUID(); c.habitId = dto.habitId; c.day = dto.day; c.ts = dto.ts
            c.backfill = dto.backfill; c.tzOffsetMinutes = dto.tzOffsetMinutes
            addedCheckins += 1
        }
        if context.hasChanges { try context.save() }
        return (addedHabits, addedCheckins)
    }

    // MARK: 加解密

    public static func encrypt(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw BackupError.corrupt }
        return combined
    }

    public static func decrypt(_ ciphertext: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key)
    }

    /// 设备密钥：Keychain 读取，不存在则生成 256-bit 随机密钥存入。
    /// 进程内缓存：CLI/无 entitlements 环境下 SecItemAdd 可能失败，缓存保证进程内加解密一致。
    private static var cachedKey: SymmetricKey?
    /// 测试钩子：CLI harness 下 securityd 可能挂死（mach_msg 无响应），测试直接注入密钥绕过 Keychain。
    public static var keyOverrideForTesting: SymmetricKey?
    public static func loadOrCreateKey() -> SymmetricKey {
        if let k = keyOverrideForTesting { return k }
        if let k = cachedKey { return k }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "sh.steadyhabit",
            kSecAttrAccount as String: "backup-key",
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data, data.count == 32 {
            let k = SymmetricKey(data: data)
            cachedKey = k
            return k
        }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        let data = Data(bytes)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "sh.steadyhabit",
            kSecAttrAccount as String: "backup-key",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: data,
        ]
        SecItemAdd(add as CFDictionary, nil)
        let k = SymmetricKey(data: data)
        cachedKey = k
        return k
    }

    // MARK: 落盘（iCloud Drive，无 ubiquity 容器时降级本地 Application Support）

    public static func backupFileURL() -> URL {
        let fm = FileManager.default
        if let ubiquity = fm.url(forUbiquityContainerIdentifier: nil) {
            return ubiquity.appendingPathComponent("Documents/Steady/backup.json")
        }
        let base = (fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    ?? fm.temporaryDirectory)
        return base.appendingPathComponent("Steady/backup.json")
    }

    /// 每日首次启动调用：今天已备份则跳过，否则导出+加密+覆盖写，并更新 BackupMeta。
    @discardableResult
    public static func performDailyBackup(context: NSManagedObjectContext,
                                          today: String = HabitRepository.todayKey()) -> Bool {
        let meta = fetchOrCreateMeta(context: context)
        if let last = meta.lastBackupAt,
           HabitRepository.localDayFormatter.string(from: last) == today {
            return false
        }
        do {
            let plain = try export(context: context)
            let cipher = try encrypt(plain, key: loadOrCreateKey())
            let url = backupFileURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try cipher.write(to: url, options: .atomic)
            meta.lastBackupAt = HabitRepository.localDayFormatter.date(from: today) ?? Date()
            meta.schemaVersion = schemaVersion
            if context.hasChanges { try context.save() }
            return true
        } catch {
            return false
        }
    }

    /// 删除重装后一键恢复（DoD #3）：读备份文件 → 解密 → 幂等导入。
    @discardableResult
    public static func restoreFromBackupFile(context: NSManagedObjectContext) -> Bool {
        do {
            let cipher = try Data(contentsOf: backupFileURL())
            let plain = try decrypt(cipher, key: loadOrCreateKey())
            _ = try restore(context: context, from: plain)
            return true
        } catch {
            return false
        }
    }

    private static func fetchOrCreateMeta(context: NSManagedObjectContext) -> BackupMetaEntity {
        let req = NSFetchRequest<BackupMetaEntity>(entityName: "BackupMeta")
        req.fetchLimit = 1
        if let m = try? context.fetch(req).first { return m }
        let m = BackupMetaEntity(entity: NSEntityDescription.entity(forEntityName: "BackupMeta", in: context)!, insertInto: context)
        m.schemaVersion = schemaVersion
        return m
    }
}

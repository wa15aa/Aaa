import CoreData

/// CoreData 栈。数据模型用代码构建（等价 MVP_SPEC §4），避免 .xcdatamodeld 资源依赖。
/// 约束：(habitId, day) 唯一；Checkin 只增不改；删除习惯=软删（archivedAt）。
public final class PersistenceController {
    public static let shared = PersistenceController()

    /// 测试用内存栈
    public static func inMemory() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    public let container: NSPersistentContainer

    public init(inMemory: Bool = false) {
        let model = PersistenceController.makeModel()
        container = NSPersistentContainer(name: "Steady", managedObjectModel: model)
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData 加载失败: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    public static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // MARK: Habit
        let habit = NSEntityDescription()
        habit.name = "Habit"
        habit.managedObjectClassName = "HabitEntity"
        let habitAttrs: [(String, NSAttributeType, Bool)] = [
            ("id", .UUIDAttributeType, false),
            ("name", .stringAttributeType, false),
            ("icon", .stringAttributeType, false),
            ("colorHex", .stringAttributeType, false),
            ("frequencyKind", .stringAttributeType, false),   // "daily" | "weekly"
            ("habitType", .stringAttributeType, false),       // "build" | "quit"（轻量迁移靠默认值）
            ("timesPerWeek", .integer16AttributeType, false), // weekly 时 1...6
            ("reminderHour", .integer16AttributeType, true),
            ("reminderMinute", .integer16AttributeType, true),
            ("reminder2Hour", .integer16AttributeType, true),   // W6 功能批②：每习惯多提醒（≤3）
            ("reminder2Minute", .integer16AttributeType, true),
            ("reminder3Hour", .integer16AttributeType, true),
            ("reminder3Minute", .integer16AttributeType, true),
            ("createdAt", .dateAttributeType, false),
            ("createdDay", .stringAttributeType, false),      // yyyy-MM-dd 本地
            ("sortOrder", .integer16AttributeType, false),
            ("archivedAt", .dateAttributeType, true),
        ]
        habit.properties = habitAttrs.map { makeAttr($0.0, $0.1, optional: $0.2) }
        // 存量数据迁移：habitType 默认 "build"（新增属性带默认值 → 轻量迁移安全）
        (habit.properties.first { $0.name == "habitType" } as? NSAttributeDescription)?.defaultValue = "build"
        // 新增多提醒字段默认 -1（未设）；optional Int16 缺失值读出为 0 会误判成 0:00 提醒
        for n in ["reminder2Hour", "reminder2Minute", "reminder3Hour", "reminder3Minute"] {
            (habit.properties.first { $0.name == n } as? NSAttributeDescription)?.defaultValue = -1
        }

        // MARK: Checkin
        let checkin = NSEntityDescription()
        checkin.name = "Checkin"
        checkin.managedObjectClassName = "CheckinEntity"
        let checkinAttrs: [(String, NSAttributeType, Bool)] = [
            ("id", .UUIDAttributeType, false),
            ("habitId", .UUIDAttributeType, false),
            ("day", .stringAttributeType, false), // yyyy-MM-dd 本地时区
            ("ts", .dateAttributeType, false),
            ("backfill", .booleanAttributeType, false),
            ("tzOffsetMinutes", .integer32AttributeType, false),
        ]
        checkin.properties = checkinAttrs.map { makeAttr($0.0, $0.1, optional: $0.2) }
        // (habitId, day) 唯一约束
        let habitIdAttr = checkin.properties.first { $0.name == "habitId" } as! NSAttributeDescription
        let dayAttr = checkin.properties.first { $0.name == "day" } as! NSAttributeDescription
        checkin.uniquenessConstraints = [[habitIdAttr, dayAttr]]

        // MARK: StreakSegment
        let segment = NSEntityDescription()
        segment.name = "StreakSegment"
        segment.managedObjectClassName = "StreakSegmentEntity"
        let segAttrs: [(String, NSAttributeType, Bool)] = [
            ("habitId", .UUIDAttributeType, false),
            ("startDay", .stringAttributeType, false),
            ("endDay", .stringAttributeType, false),
            ("length", .integer32AttributeType, false),
        ]
        segment.properties = segAttrs.map { makeAttr($0.0, $0.1, optional: $0.2) }

        // MARK: BackupMeta
        let backup = NSEntityDescription()
        backup.name = "BackupMeta"
        backup.managedObjectClassName = "BackupMetaEntity"
        backup.properties = [
            makeAttr("lastBackupAt", .dateAttributeType, optional: true),
            makeAttr("schemaVersion", .integer16AttributeType, optional: false),
        ]

        model.entities = [habit, checkin, segment, backup]
        return model
    }

    private static func makeAttr(_ name: String, _ type: NSAttributeType, optional: Bool) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        return a
    }
}

// MARK: - Entities

@objc(HabitEntity)
public final class HabitEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var icon: String
    @NSManaged public var colorHex: String
    @NSManaged public var frequencyKind: String
    @NSManaged public var habitType: String
    @NSManaged public var timesPerWeek: Int16
    @NSManaged public var reminderHour: Int16
    @NSManaged public var reminderMinute: Int16
    @NSManaged public var reminder2Hour: Int16
    @NSManaged public var reminder2Minute: Int16
    @NSManaged public var reminder3Hour: Int16
    @NSManaged public var reminder3Minute: Int16
    @NSManaged public var createdAt: Date
    @NSManaged public var createdDay: String
    @NSManaged public var sortOrder: Int16
    @NSManaged public var archivedAt: Date?
}

@objc(CheckinEntity)
public final class CheckinEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var habitId: UUID
    @NSManaged public var day: String
    @NSManaged public var ts: Date
    @NSManaged public var backfill: Bool
    @NSManaged public var tzOffsetMinutes: Int32
}

@objc(StreakSegmentEntity)
public final class StreakSegmentEntity: NSManagedObject {
    @NSManaged public var habitId: UUID
    @NSManaged public var startDay: String
    @NSManaged public var endDay: String
    @NSManaged public var length: Int32
}

@objc(BackupMetaEntity)
public final class BackupMetaEntity: NSManagedObject {
    @NSManaged public var lastBackupAt: Date?
    @NSManaged public var schemaVersion: Int16
}

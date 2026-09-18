import Foundation
import CryptoKit
import SteadyCore

// BackupService 断言测试（本机 XCTest 卡死，用可执行断言替代）
var passed = 0, failed = 0
func check(_ cond: Bool, _ name: String) {
    if cond { passed += 1 } else { failed += 1; print("FAIL: \(name)") }
}

let key = SymmetricKey(size: .bits256)

// 1. 空库导出/恢复不炸
let pc1 = PersistenceController.inMemory()
let ctx1 = pc1.container.viewContext
let emptyData = try! BackupService.export(context: ctx1)
let r0 = try! BackupService.restore(context: ctx1, from: emptyData)
check(r0 == (0, 0), "empty export/restore")

// 2. 建数据：2 习惯（daily + weekly）+ 若干打卡
let repo = HabitRepository(context: ctx1)
let h1 = repo.createHabit(name: "冥想", icon: "star.fill", colorHex: "4F8CFF", frequency: .daily)
let h2 = repo.createHabit(name: "跑步", icon: "figure.run", colorHex: "FF6B6B", frequency: .timesPerWeek(3))
_ = repo.checkin(habitId: h1.id, day: "2026-09-16")
_ = repo.checkin(habitId: h1.id, day: "2026-09-17")
_ = repo.checkin(habitId: h2.id, day: "2026-09-15")
let streakBefore = repo.streakState(for: h1).current

// 3. 导出 → 加密 → 解密 → 恢复进全新库，零丢失
let data = try! BackupService.export(context: ctx1)
let cipher = try! BackupService.encrypt(data, key: key)
check(cipher != data, "ciphertext differs from plaintext")
let plain = try! BackupService.decrypt(cipher, key: key)
check(plain == data, "decrypt roundtrip")

let pc2 = PersistenceController.inMemory()
let ctx2 = pc2.container.viewContext
let r1 = try! BackupService.restore(context: ctx2, from: plain)
check(r1.0 == 2, "restored 2 habits (got \(r1.0))")
check(r1.1 == 3, "restored 3 checkins (got \(r1.1))")

// 4. 恢复后 streak 一致（历史零丢失的实质验证）
let repo2 = HabitRepository(context: ctx2)
let habits2 = repo2.activeHabits()
check(habits2.count == 2, "activeHabits after restore")
let h1r = habits2.first { $0.id == h1.id }!
check(repo2.streakState(for: h1r).current == streakBefore, "streak preserved across restore")
check(h1r.name == "冥想" && h1r.createdDay == h1.createdDay, "habit fields preserved")
let h2r = habits2.first { $0.id == h2.id }!
check(h2r.frequencyKind == "weekly" && h2r.timesPerWeek == 3, "weekly frequency preserved")

// 5. 恢复幂等：重复恢复不增数据
let r2 = try! BackupService.restore(context: ctx2, from: plain)
check(r2 == (0, 0), "restore idempotent")

// 6. 错密钥解密必须失败
let wrongKey = SymmetricKey(size: .bits256)
check((try? BackupService.decrypt(cipher, key: wrongKey)) == nil, "wrong key rejected")

// 7. 篡改密文必须失败
var tampered = cipher
tampered[tampered.count - 1] ^= 0xFF
check((try? BackupService.decrypt(tampered, key: key)) == nil, "tampered ciphertext rejected")

// 8. 每日备份：同一天第二次调用跳过
let pc3 = PersistenceController.inMemory()
let ctx3 = pc3.container.viewContext
let repo3 = HabitRepository(context: ctx3)
_ = repo3.createHabit(name: "阅读", icon: "book.fill", colorHex: "4F8CFF", frequency: .daily)
// 用固定 key 路径不可测 performDailyBackup 的 Keychain 部分，但"同日跳过"逻辑可测
let first = BackupService.performDailyBackup(context: ctx3, today: "2026-09-18")
check(first == true, "first daily backup runs")
let second = BackupService.performDailyBackup(context: ctx3, today: "2026-09-18")
check(second == false, "same-day backup skipped")
let nextDay = BackupService.performDailyBackup(context: ctx3, today: "2026-09-19")
check(nextDay == true, "next-day backup runs")

// 9. 从备份文件恢复（模拟删除重装）
let pc4 = PersistenceController.inMemory()
let ctx4 = pc4.container.viewContext
check(BackupService.restoreFromBackupFile(context: ctx4) == true, "restore from backup file")
check(HabitRepository(context: ctx4).activeHabits().count == 1, "file restore recovered habit")

print("\(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)

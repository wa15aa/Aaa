import Foundation
import SteadyCore
import StreakEngine

// RepositoryTests 的等价断言版（本机 XCTest 不可用，见 streakcheck 注释）。
// 验收：模型约束（habitId+day 幂等、软删数据保留、补签仅昨天）。

var passed = 0, failed = 0
func check(_ cond: Bool, _ name: String, _ detail: String = "") {
    if cond { passed += 1; print("PASS \(name)") }
    else { failed += 1; print("FAIL \(name) \(detail)") }
}

let persistence = PersistenceController.inMemory()
let repo = HabitRepository(context: persistence.container.viewContext)

// 1. 创建 daily 习惯默认值
let h1 = repo.createHabit(name: "读书", icon: "book.fill", colorHex: "4F8CFF", frequency: .daily)
check(h1.name == "读书" && h1.frequencyKind == "daily" && repo.activeHabits().count == 1, "01_createDaily")

// 2. weekly 次数钳制到 6
let h2 = repo.createHabit(name: "健身", icon: "figure.run", colorHex: "22CC88", frequency: .timesPerWeek(9))
check(h2.frequencyKind == "weekly" && h2.timesPerWeek == 6, "02_weeklyClamp")

// 3. 同日重复打卡幂等（唯一约束）
check(repo.checkin(habitId: h1.id), "03a_firstCheckin")
check(repo.checkin(habitId: h1.id), "03b_secondCheckin")
check(repo.allCheckins(habitId: h1.id).count == 1, "03c_idempotent")

// 4. 补签：远古日期拒绝
let today = HabitRepository.todayKey()
check(repo.checkin(habitId: h1.id, day: today), "04a_todayCheckin")
check(!repo.checkin(habitId: h1.id, day: "2020-01-01", backfill: true), "04b_ancientBackfillRejected")

// 5. 软删保留数据
repo.checkin(habitId: h2.id)
repo.archive(h2)
check(repo.activeHabits().count == 1, "05a_archivedHidden")
check(repo.allCheckins(habitId: h2.id).count == 1, "05b_dataKept")

// 6. streak 桥接
let s = repo.streakState(for: h1)
check(s.current == 1 && s.todayState == .done, "06_streakBridge", "\(s)")

// 7. quit 型：创建默认 daily（传 weekly 也被钳回 daily）、默认 "build" 不影响旧习惯
let q1 = repo.createHabit(name: "戒烟", icon: "nosign", colorHex: "FF5555", frequency: .timesPerWeek(3), type: .quit)
check(q1.habitType == "quit" && q1.frequencyKind == "daily", "07_quitForcesDaily", "\(q1.habitType)/\(q1.frequencyKind)")
check(h1.habitType == "build", "07b_defaultBuild")

// 8. quit 零破戒：streakState 路由到 quitDaily，创建当天 current=1
let sq = repo.streakState(for: q1)
check(sq.current == 1 && sq.todayState == .done, "08_quitNoSlip_counts", "\(sq)")

// 9. quit 标破戒（checkin 即 slip）：今天破戒 → 暗格不清零
check(repo.checkin(habitId: q1.id, day: today), "09a_markSlip")
let sq2 = repo.streakState(for: q1)
check(sq2.current == 0 && sq2.todayState == .dimmed && sq2.segments.isEmpty, "09b_slipToday_dimmed", "\(sq2)")

// 10. 撤销破戒标记：removeCheckin 恢复
check(repo.removeCheckin(habitId: q1.id, day: today), "10a_removeSlip")
let sq3 = repo.streakState(for: q1)
check(sq3.current == 1 && sq3.todayState == .done, "10b_slipUndone", "\(sq3)")
check(!repo.removeCheckin(habitId: q1.id, day: today), "10c_removeNonexistent")

print("\n===== \(passed) passed, \(failed) failed =====")
if failed > 0 { exit(1) }

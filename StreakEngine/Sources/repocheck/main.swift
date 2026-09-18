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

print("\n===== \(passed) passed, \(failed) failed =====")
if failed > 0 { exit(1) }

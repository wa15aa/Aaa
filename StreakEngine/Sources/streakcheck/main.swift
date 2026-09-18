import Foundation
import StreakEngine

// 本机 XCTest 运行器挂起（Xcode 14.2/macOS 12 环境问题），
// 用可执行目标跑同一批断言验证引擎。断言逻辑与 Tests/ 中的 XCTest 用例一一对应。

var passed = 0
var failed = 0

func check(_ cond: Bool, _ name: String, _ detail: String = "") {
    if cond { passed += 1; print("PASS \(name)") }
    else { failed += 1; print("FAIL \(name) \(detail)") }
}

func c(_ days: [String]) -> [CheckinInput] { days.map { CheckinInput(day: DayKey($0)) } }
func backfill(_ day: String) -> CheckinInput { CheckinInput(day: DayKey(day), backfill: true) }

// 1
var s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-03"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-03"))
check(s.current == 3 && s.best == 3 && s.segments.isEmpty && s.todayState == .done, "01_consecutiveDays", "\(s)")

// 2
s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-04"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-04"))
check(s.current == 3 && s.segments.isEmpty, "02_missOneDay_keepsStreak", "\(s)")

// 3
s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-05"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-05"))
check(s.current == 1 && s.best == 2 && s.segments.count == 1 && s.segments[0].length == 2 && s.segments[0].endDay == DayKey("2026-01-02"), "03_missTwoDays_resets", "\(s)")

// 4
s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-03","2026-01-08"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-08"))
check(s.current == 1 && s.best == 3, "04_bestPreservedAcrossReset", "\(s)")

// 5
s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-03"))
check(s.current == 2 && s.todayState == .dimmed && s.segments.isEmpty, "05_todayFirstMiss_isDimmed", "\(s)")

// 6
s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-04"))
check(s.current == 0 && s.segments.count == 1 && s.todayState == .missed, "06_todaySecondMiss_seals", "\(s)")

// 7
s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-03"]) + [backfill("2026-01-02")], createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-03"))
check(s.current == 3, "07_backfillYesterday", "\(s)")

// 8-10
check(StreakEngine.canBackfill(day: DayKey("2026-01-02"), today: DayKey("2026-01-03")), "08_canBackfillYesterday")
check(!StreakEngine.canBackfill(day: DayKey("2026-01-01"), today: DayKey("2026-01-03")), "09_cannotBackfillOlder")
check(!StreakEngine.canBackfill(day: DayKey("2026-01-03"), today: DayKey("2026-01-03")), "10_cannotBackfillToday")

// 11
s = StreakEngine.daily(checkins: c(["2026-01-30","2026-01-31","2026-02-01"]), createdDay: DayKey("2026-01-30"), today: DayKey("2026-02-01"))
check(s.current == 3, "11_acrossMonths", "\(s)")

// 12
s = StreakEngine.daily(checkins: c(["2024-02-28","2024-02-29","2024-03-01"]), createdDay: DayKey("2024-02-28"), today: DayKey("2024-03-01"))
check(s.current == 3, "12_leapDay", "\(s)")

// 13
s = StreakEngine.daily(checkins: c(["2026-03-07","2026-03-08","2026-03-09"]), createdDay: DayKey("2026-03-07"), today: DayKey("2026-03-09"))
check(s.current == 3, "13_dstWeek", "\(s)")

// 14
s = StreakEngine.daily(checkins: [], createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-01"))
check(s.current == 0 && s.todayState == .dimmed, "14_createdTodayNoCheckin", "\(s)")

// 15
s = StreakEngine.daily(checkins: c(["2025-12-31","2026-01-01"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-01"))
check(s.current == 1, "15_checkinBeforeCreationIgnored", "\(s)")

// 16
s = StreakEngine.weekly(checkins: c(["2026-01-05","2026-01-07","2026-01-09"]), targetPerWeek: 3, createdDay: DayKey("2026-01-05"), today: DayKey("2026-01-09"))
check(s.current == 1 && s.todayState == .done, "16_weeklyMet", "\(s)")

// 17
s = StreakEngine.weekly(checkins: c(["2025-12-29","2025-12-31","2026-01-02","2026-01-05"]), targetPerWeek: 3, createdDay: DayKey("2025-12-29"), today: DayKey("2026-01-07"))
check(s.current == 1 && s.todayState == .dimmed, "17_weeklyCurrentWeekGrace", "\(s)")

// 18
s = StreakEngine.weekly(checkins: c(["2025-12-01","2025-12-03","2025-12-05","2025-12-08","2025-12-15"]), targetPerWeek: 3, createdDay: DayKey("2025-12-01"), today: DayKey("2025-12-25"))
check(s.current == 0 && s.segments.count == 1 && s.best == 1, "18_weeklyTwoMissedWeeks", "\(s)")

// 19
let done: Set<DayKey> = [DayKey("2026-01-01"), DayKey("2026-01-03")]
check(StreakEngine.dayState(day: DayKey("2026-01-02"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")) == .dimmed, "19a_dimmed")
check(StreakEngine.dayState(day: DayKey("2026-01-07"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")) == .missed, "19b_missed")
check(StreakEngine.dayState(day: DayKey("2026-01-11"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")) == .future, "19c_future")
check(StreakEngine.dayState(day: DayKey("2025-12-31"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")) == .beforeStart, "19d_beforeStart")

// 20
s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-06","2026-01-07","2026-01-08","2026-01-09"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-09"))
check(s.current == 4 && s.best == 4 && s.segments.count == 1 && s.segments[0].length == 2, "20_secondSegmentBeatsBest", "\(s)")

print("\n===== \(passed) passed, \(failed) failed =====")
if failed > 0 { exit(1) }

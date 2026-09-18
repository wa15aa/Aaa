import XCTest
@testable import StreakEngine

final class StreakEngineTests: XCTestCase {

    private func c(_ days: [String]) -> [CheckinInput] { days.map { CheckinInput(day: DayKey($0)) } }
    private func backfill(_ day: String) -> CheckinInput { CheckinInput(day: DayKey(day), backfill: true) }

    // 1. 连续 3 天打卡 → current=3
    func test01_consecutiveDays() {
        let s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-03"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-03"))
        XCTAssertEqual(s.current, 3)
        XCTAssertEqual(s.best, 3)
        XCTAssertTrue(s.segments.isEmpty)
        XCTAssertEqual(s.todayState, .done)
    }

    // 2. 断签 1 天不清零，streak 继续
    func test02_missOneDay_keepsStreak() {
        let s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-04"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-04"))
        XCTAssertEqual(s.current, 3) // 1,2,4 三天都算
        XCTAssertTrue(s.segments.isEmpty)
    }

    // 3. 连续断签 2 天 → 段封存，current 从断后重新算
    func test03_missTwoDays_resets() {
        let s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-05"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-05"))
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.best, 2)
        XCTAssertEqual(s.segments.count, 1)
        XCTAssertEqual(s.segments[0].length, 2)
        XCTAssertEqual(s.segments[0].endDay, DayKey("2026-01-02"))
    }

    // 4. best 是历史段，重置后不归零
    func test04_bestPreservedAcrossReset() {
        let s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02","2026-01-03","2026-01-08"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-08"))
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.best, 3)
    }

    // 5. 今天断签第 1 天 → 暗格，current 保留
    func test05_todayFirstMiss_isDimmed() {
        let s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-03"))
        XCTAssertEqual(s.current, 2)
        XCTAssertEqual(s.todayState, .dimmed)
        XCTAssertTrue(s.segments.isEmpty)
    }

    // 6. 今天已是断签第 2 天 → 段封存
    func test06_todaySecondMiss_seals() {
        let s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-02"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-04"))
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.segments.count, 1)
        XCTAssertEqual(s.todayState, .missed)
    }

    // 7. 补签昨天 → streak 连续
    func test07_backfillYesterday() {
        let s = StreakEngine.daily(checkins: c(["2026-01-01","2026-01-03"]) + [backfill("2026-01-02")], createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-03"))
        XCTAssertEqual(s.current, 3)
    }

    // 8. canBackfill：昨天 ✓
    func test08_canBackfillYesterday() {
        XCTAssertTrue(StreakEngine.canBackfill(day: DayKey("2026-01-02"), today: DayKey("2026-01-03")))
    }

    // 9. canBackfill：前天 ✗
    func test09_cannotBackfillOlder() {
        XCTAssertFalse(StreakEngine.canBackfill(day: DayKey("2026-01-01"), today: DayKey("2026-01-03")))
    }

    // 10. canBackfill：今天 ✗（今天直接打卡不是补签）
    func test10_cannotBackfillToday() {
        XCTAssertFalse(StreakEngine.canBackfill(day: DayKey("2026-01-03"), today: DayKey("2026-01-03")))
    }

    // 11. 跨月断签计算正确
    func test11_acrossMonths() {
        let s = StreakEngine.daily(checkins: c(["2026-01-30","2026-01-31","2026-02-01"]), createdDay: DayKey("2026-01-30"), today: DayKey("2026-02-01"))
        XCTAssertEqual(s.current, 3)
    }

    // 12. 跨闰日（2026 非闰年，用 2024 验证 2/29）
    func test12_leapDay() {
        let s = StreakEngine.daily(checkins: c(["2024-02-28","2024-02-29","2024-03-01"]), createdDay: DayKey("2024-02-28"), today: DayKey("2024-03-01"))
        XCTAssertEqual(s.current, 3)
    }

    // 13. 夏令时切换周（美区 2026-03-08 DST 开始）日期推演不漂移
    func test13_dstWeek() {
        let s = StreakEngine.daily(checkins: c(["2026-03-07","2026-03-08","2026-03-09"]), createdDay: DayKey("2026-03-07"), today: DayKey("2026-03-09"))
        XCTAssertEqual(s.current, 3)
    }

    // 14. 创建当天未打卡 → dimmed，current 0
    func test14_createdTodayNoCheckin() {
        let s = StreakEngine.daily(checkins: [], createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-01"))
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.todayState, .dimmed)
    }

    // 15. 打卡早于创建日（脏数据）不影响：从创建日开始算
    func test15_checkinBeforeCreationIgnored() {
        let s = StreakEngine.daily(checkins: c(["2025-12-31","2026-01-01"]), createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-01"))
        XCTAssertEqual(s.current, 1)
    }

    // 16. 周频率 3 次/周：达标周 streak=1
    func test16_weeklyMet() {
        let s = StreakEngine.weekly(checkins: c(["2026-01-05","2026-01-07","2026-01-09"]), targetPerWeek: 3, createdDay: DayKey("2026-01-05"), today: DayKey("2026-01-09"))
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.todayState, .done)
    }

    // 17. 周频率：当周未结束未达标 → 不打断
    func test17_weeklyCurrentWeekGrace() {
        // 上周达标 3 次，本周（今天周三）只打了 1 次
        let s = StreakEngine.weekly(checkins: c(["2025-12-29","2025-12-31","2026-01-02","2026-01-05"]), targetPerWeek: 3, createdDay: DayKey("2025-12-29"), today: DayKey("2026-01-07"))
        XCTAssertEqual(s.current, 1) // 上周那 1 周
        XCTAssertEqual(s.todayState, .dimmed)
    }

    // 18. 周频率：连续 2 周未达标 → 封存
    func test18_weeklyTwoMissedWeeks() {
        // 第 1 周达标，第 2、3 周各只 1 次，今天在第 4 周
        let s = StreakEngine.weekly(
            checkins: c(["2025-12-01","2025-12-03","2025-12-05","2025-12-08","2025-12-15"]),
            targetPerWeek: 3, createdDay: DayKey("2025-12-01"), today: DayKey("2025-12-25"))
        XCTAssertEqual(s.current, 0)
        XCTAssertEqual(s.segments.count, 1)
        XCTAssertEqual(s.best, 1)
    }

    // 19. dayState 热力图：断签 1 天且邻居有打卡 → dimmed；孤立断签 → missed；未来 → future
    func test19_dayStateGrid() {
        let done: Set<DayKey> = [DayKey("2026-01-01"), DayKey("2026-01-03")]
        XCTAssertEqual(StreakEngine.dayState(day: DayKey("2026-01-02"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")), .dimmed)
        XCTAssertEqual(StreakEngine.dayState(day: DayKey("2026-01-07"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")), .missed)
        XCTAssertEqual(StreakEngine.dayState(day: DayKey("2026-01-11"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")), .future)
        XCTAssertEqual(StreakEngine.dayState(day: DayKey("2025-12-31"), checkins: done, createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-10")), .beforeStart)
    }

    // 20. 长 streak 跨段累计 best（两段，第二段更长）
    func test20_secondSegmentBeatsBest() {
        let s = StreakEngine.daily(
            checkins: c(["2026-01-01","2026-01-02","2026-01-06","2026-01-07","2026-01-08","2026-01-09"]),
            createdDay: DayKey("2026-01-01"), today: DayKey("2026-01-09"))
        XCTAssertEqual(s.current, 4)
        XCTAssertEqual(s.best, 4)
        XCTAssertEqual(s.segments.count, 1)
        XCTAssertEqual(s.segments[0].length, 2)
    }
}

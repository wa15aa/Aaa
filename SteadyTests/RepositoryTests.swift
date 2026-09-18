import XCTest
import SteadyCore
import StreakEngine
import CoreData

/// 模型约束验收（任务 1 DoD）：
/// (habitId, day) 唯一、Checkin 只增不改（幂等打卡）、删除习惯=软删数据保留。
final class RepositoryTests: XCTestCase {

    private var persistence: PersistenceController!
    private var repo: HabitRepository!

    override func setUp() {
        persistence = PersistenceController.inMemory()
        repo = HabitRepository(context: persistence.container.viewContext)
    }

    func testCreateHabit_defaults() {
        let h = repo.createHabit(name: "读书", icon: "book.fill", colorHex: "4F8CFF", frequency: .daily)
        XCTAssertEqual(h.name, "读书")
        XCTAssertEqual(h.frequencyKind, "daily")
        XCTAssertEqual(repo.activeHabits().count, 1)
    }

    func testWeeklyHabit_clampsRange() {
        let h = repo.createHabit(name: "健身", icon: "figure.run", colorHex: "22CC88", frequency: .timesPerWeek(9))
        XCTAssertEqual(h.frequencyKind, "weekly")
        XCTAssertEqual(h.timesPerWeek, 6)
    }

    func testCheckin_idempotentSameDay() {
        let h = repo.createHabit(name: "冥想", icon: "star.fill", colorHex: "FFAA00", frequency: .daily)
        XCTAssertTrue(repo.checkin(habitId: h.id))
        XCTAssertTrue(repo.checkin(habitId: h.id)) // 重复打卡幂等
        XCTAssertEqual(repo.allCheckins(habitId: h.id).count, 1)
    }

    func testBackfill_onlyYesterday() {
        let h = repo.createHabit(name: "跑步", icon: "figure.run", colorHex: "FF4444", frequency: .daily)
        // 构造"前天"不能补签（除非今天恰好是月初等边界，用相对日期稳妥起见不测绝对日）
        let today = HabitRepository.todayKey()
        XCTAssertTrue(repo.checkin(habitId: h.id, day: today))
        XCTAssertFalse(repo.checkin(habitId: h.id, day: "2020-01-01", backfill: true))
    }

    func testArchive_keepsData() {
        let h = repo.createHabit(name: "喝水", icon: "drop.fill", colorHex: "00AAFF", frequency: .daily)
        repo.checkin(habitId: h.id)
        repo.archive(h)
        XCTAssertEqual(repo.activeHabits().count, 0)
        XCTAssertEqual(repo.allCheckins(habitId: h.id).count, 1) // 数据保留
    }

    func testStreakStateBridge_daily() {
        let h = repo.createHabit(name: "写作", icon: "book.fill", colorHex: "AA66FF", frequency: .daily)
        repo.checkin(habitId: h.id)
        let s = repo.streakState(for: h)
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.todayState, .done)
    }
}

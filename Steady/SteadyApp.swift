import SwiftUI
import SteadyCore
import CoreData

@main
struct SteadyApp: App {
    let persistence = PersistenceController.shared

    init() {
        // 每日首次启动：iCloud 加密增量备份（MVP_SPEC §3.5）
        // 注意：不在启动时请求通知权限（DoD#5），权限在用户自设第一条提醒时才弹
        let container = persistence.container
        DispatchQueue.global(qos: .utility).async {
            BackupService.performDailyBackup(context: container.newBackgroundContext())
        }
        #if DEBUG
        // DEBUG 下空库自动注入演示数据（截图/联调用）；Release 永不包含
        Self.seedDemoData(context: persistence.container.viewContext)
        #endif
    }

    #if DEBUG
    static func seedDemoData(context: NSManagedObjectContext) {
        let repo = HabitRepository(context: context)
        guard repo.activeHabits().isEmpty else { return }
        let today = DayKey(HabitRepository.todayKey())
        let created = StreakEngine.addDays(today, -21).raw
        let specs: [(String, String, String, Frequency, [Int])] = [
            ("冥想 10 分钟", "brain.head.profile", "4F8CFF", .daily, Array(0...13).filter { $0 != 5 }),
            ("跑步", "figure.run", "FF6B6B", .timesPerWeek(3), [0, 1, 3, 7, 8, 10, 14, 15]),
            ("读书 20 页", "book.fill", "34C759", .daily, Array(0...20).filter { $0 != 9 }),
        ]
        for (name, icon, color, freq, doneDays) in specs {
            let h = repo.createHabit(name: name, icon: icon, colorHex: color, frequency: freq)
            h.createdDay = created
            for off in doneDays {
                _ = repo.checkin(habitId: h.id, day: StreakEngine.addDays(today, -off).raw)
            }
        }
        try? context.save()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

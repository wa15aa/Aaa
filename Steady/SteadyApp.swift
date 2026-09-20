import SwiftUI
import SteadyCore
import CoreData

@main
struct SteadyApp: App {
    let persistence = PersistenceController.shared

    init() {
        #if DEBUG
        // 冷启动打点起点（DoD#1 度量）：Swift 全局变量惰性初始化不可靠，init 即写起点
        UserDefaults.standard.set(CFAbsoluteTimeGetCurrent(), forKey: "steady.launchStartTs")
        #endif
        // 每日首次启动：iCloud 加密增量备份（MVP_SPEC §3.5）
        // 注意：不在启动时请求通知权限（DoD#5），权限在用户自设第一条提醒时才弹
        let container = persistence.container
        // 修复 2026-09-19 真 crash：newBackgroundContext 是 privateQueue 并发模型，
        // 直接在 GCD 线程访问违反 CoreData 线程约束 → _PFObjectIDFastHash64 空指针 SIGSEGV。
        // 必须包 context.perform（E2E 17_relaunch_with_data 防回归）
        let bg = container.newBackgroundContext()
        bg.perform {
            BackupService.performDailyBackup(context: bg)
        }
        #if DEBUG
        // E2E 钩子：-noSeed 跳过演示数据（Maestro 确定性）；-e2ePro 直接置 Pro（测 quit/详情页）
        if ProcessInfo.processInfo.arguments.contains("-e2ePro") {
            UserDefaults.standard.set(true, forKey: "steady.isPro")
        }
        // DEBUG 下空库自动注入演示数据（截图/联调用）；Release 永不包含
        if !ProcessInfo.processInfo.arguments.contains("-noSeed") {
            Self.seedDemoData(context: persistence.container.viewContext)
        }
        // E2E 钩子：-e2eSeedQuit 注入带历史的 quit 习惯（4 天前创建、2 天前破戒一次），
        // 用于 19_quit_slip_streak_survives 验证"破戒 1 天 streak 不清零"核心叙事
        if ProcessInfo.processInfo.arguments.contains("-e2eSeedQuit") {
            let repo = HabitRepository(context: persistence.container.viewContext)
            if !repo.activeHabits().contains(where: { $0.name == "No sugar" }) {
                let today = DayKey(HabitRepository.todayKey())
                let q = repo.createHabit(name: "No sugar", icon: "bandage.fill",
                                         colorHex: "FF9F0A", frequency: .daily, type: .quit)
                q.createdDay = StreakEngine.addDays(today, -4).raw
                _ = repo.checkin(habitId: q.id, day: StreakEngine.addDays(today, -2).raw)
            }
        }
        #endif
    }

    #if DEBUG
    static func seedDemoData(context: NSManagedObjectContext) {
        let repo = HabitRepository(context: context)
        guard repo.activeHabits().isEmpty else { return }
        let today = DayKey(HabitRepository.todayKey())
        let created = StreakEngine.addDays(today, -21).raw
        let specs: [(String, String, String, Frequency, [Int])] = [
            // 冥想今天故意不打卡（截图像真实使用中的 2/3 状态）
            ("Meditate 10 min", "brain.head.profile", "4F8CFF", .daily, Array(1...13).filter { $0 != 5 }),
            ("Run", "figure.run", "FF6B6B", .timesPerWeek(3), [0, 1, 3, 7, 8, 10, 14, 15]),
            ("Read 20 pages", "book.fill", "34C759", .daily, Array(0...20).filter { $0 != 9 }),
        ]
        for (name, icon, color, freq, doneDays) in specs {
            let h = repo.createHabit(name: name, icon: icon, colorHex: color, frequency: freq)
            h.createdDay = created
            for off in doneDays {
                _ = repo.checkin(habitId: h.id, day: StreakEngine.addDays(today, -off).raw)
            }
        }
        // screenshotMode=quit：追加一个 quit 型种子（"No sugar"，两天前破戒一次）截 quit 行引导
        if UserDefaults.standard.string(forKey: "screenshotMode") == "quit" {
            let q = repo.createHabit(name: "No sugar", icon: "bandage.fill", colorHex: "FF9F0A",
                                     frequency: .daily, type: .quit)
            q.createdDay = created
            _ = repo.checkin(habitId: q.id, day: StreakEngine.addDays(today, -2).raw)
        }
        try? context.save()
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                // onboarding 移进 ContentView（@AppStorage 驱动，见 ContentView.swift）
        }
    }
}

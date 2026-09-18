import SwiftUI
import SteadyCore

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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

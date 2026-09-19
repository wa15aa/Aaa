import WidgetKit
import SwiftUI
import SteadyCore
import CoreData

/// W7 ③ Widget 小尺寸只读先行：systemSmall，今日清单（最多 3 个习惯 + 是否已勾），
/// 不可交互（点击打开主 app）。数据经 App Group 共享 CoreData store 读取。
struct SteadyEntry: TimelineEntry {
    let date: Date
    let rows: [Row]
    let doneCount: Int
    let totalCount: Int

    struct Row: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let colorHex: String
        let done: Bool   // quit 型：今天有破戒记录= true 显示为橙色点
        let isQuit: Bool
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SteadyEntry { sample() }
    func getSnapshot(in context: Context, completion: @escaping (SteadyEntry) -> Void) {
        completion(load())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SteadyEntry>) -> Void) {
        let entry = load()
        // 30 分钟刷新 + 主 app 写入时 WidgetCenter.reloadAllTimelines（后续接）
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func sample() -> SteadyEntry {
        SteadyEntry(date: Date(), rows: [
            .init(id: UUID(), name: "Meditate", icon: "brain.head.profile", colorHex: "4F8CFF", done: true, isQuit: false),
            .init(id: UUID(), name: "Run", icon: "figure.run", colorHex: "FF6B6B", done: false, isQuit: false),
        ], doneCount: 1, totalCount: 2)
    }

    private func load() -> SteadyEntry {
        let pc = PersistenceController()
        let ctx = pc.container.viewContext
        let repo = HabitRepository(context: ctx)
        let habits = repo.activeHabits()
        let today = HabitRepository.todayKey()
        var rows: [SteadyEntry.Row] = []
        var done = 0, total = 0
        for h in habits.prefix(3) {
            let marked = repo.fetchCheckin(habitId: h.id, day: today) != nil
            let isQuit = h.habitType == "quit"
            rows.append(.init(id: h.id, name: h.name, icon: h.icon, colorHex: h.colorHex,
                              done: marked, isQuit: isQuit))
            if !isQuit { total += 1; if marked { done += 1 } }
        }
        return SteadyEntry(date: Date(), rows: rows, doneCount: done, totalCount: total)
    }
}

struct SteadyWidgetView: View {
    let entry: SteadyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Steady").font(.caption).bold()
                Spacer()
                Text("\(entry.doneCount)/\(entry.totalCount)")
                    .font(.caption2).foregroundColor(.secondary)
            }
            if entry.rows.isEmpty {
                Text("No habits yet").font(.caption2).foregroundColor(.secondary)
            }
            ForEach(entry.rows) { r in
                HStack(spacing: 6) {
                    Image(systemName: r.icon)
                        .font(.caption2)
                        .foregroundColor(Color(hex: r.colorHex))
                    Text(r.name).font(.caption2).lineLimit(1)
                    Spacer()
                    Image(systemName: r.isQuit
                          ? (r.done ? "bandage.fill" : "checkmark.circle.fill")
                          : (r.done ? "checkmark.circle.fill" : "circle"))
                        .font(.caption2)
                        .foregroundColor(r.isQuit && r.done ? .orange
                                         : (r.done ? Color(hex: r.colorHex) : Color(.systemGray3)))
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
    }
}

@main
struct SteadyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SteadyWidget", provider: Provider()) { entry in
            SteadyWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("Today's habits at a glance.")
        .supportedFamilies([.systemSmall]) // 只读小尺寸先行；中尺寸/可交互 v1.1
    }
}

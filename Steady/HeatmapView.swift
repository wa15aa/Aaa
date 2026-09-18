import SwiftUI
import SteadyCore
import StreakEngine

/// GitHub 式当年热力图：行=周一到周日，列=周（MVP_SPEC §1）。
/// 状态色：done=习惯色，dimmed=暗格（断签1天 streak 仍活），missed=灰，future/beforeStart=近透明。
struct HeatmapView: View {
    let habit: HabitEntity
    let checkins: Set<DayKey>
    let createdDay: DayKey
    let today: DayKey

    var onTapDay: ((DayKey, DayState) -> Void)? = nil

    private let cell: CGFloat = 12
    private let gap: CGFloat = 3

    /// 当年 1 月 1 日所在周的周一 → 今天
    private var weeks: [[DayKey]] {
        let yearStart = DayKey(String(today.raw.prefix(4)) + "-01-01")
        var first = StreakEngine.weekStart(yearStart)
        var result: [[DayKey]] = []
        while first <= today {
            var week: [DayKey] = []
            for i in 0..<7 { week.append(StreakEngine.addDays(first, i)) }
            result.append(week)
            first = StreakEngine.addDays(first, 7)
        }
        return result
    }

    private var accent: Color { Color(hex: habit.colorHex) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Canvas { ctx, size in
                for (w, week) in weeks.enumerated() {
                    for (d, day) in week.enumerated() {
                        let state = StreakEngine.dayState(day: day, checkins: checkins, createdDay: createdDay, today: today)
                        let rect = CGRect(x: CGFloat(w) * (cell + gap), y: CGFloat(d) * (cell + gap), width: cell, height: cell)
                        let path = Path(roundedRect: rect, cornerRadius: 2.5)
                        ctx.fill(path, with: .color(color(for: state)))
                    }
                }
            }
            .frame(width: CGFloat(weeks.count) * (cell + gap), height: 7 * (cell + gap))
        }
        // Canvas 内不便于逐格手势，叠加一层透明热区
        .overlay(heatmapTapOverlay)
    }

    private var heatmapTapOverlay: some View {
        GeometryReader { geo in
            Color.clear.contentShape(Rectangle())
                .onTapGesture { loc in
                    let w = Int(loc.x / (cell + gap))
                    let d = Int(loc.y / (cell + gap))
                    guard weeks.indices.contains(w), weeks[w].indices.contains(d) else { return }
                    let day = weeks[w][d]
                    let state = StreakEngine.dayState(day: day, checkins: checkins, createdDay: createdDay, today: today)
                    onTapDay?(day, state)
                }
        }
    }

    private func color(for state: DayState) -> Color {
        switch state {
        case .done: return accent
        case .dimmed: return accent.opacity(0.25)
        case .missed: return Color.gray.opacity(0.3)
        case .future, .beforeStart: return Color.gray.opacity(0.08)
        }
    }
}

/// 习惯详情：热力图 + 统计 + 点格子看详情
struct HabitDetailView: View {
    let habit: HabitEntity
    let repo: HabitRepository

    @State private var selected: (DayKey, DayState)? = nil

    private var state: StreakState { repo.streakState(for: habit) }
    private var checkinSet: Set<DayKey> { Set(repo.allCheckins(habitId: habit.id).map { DayKey($0.day) }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: habit.icon).foregroundColor(Color(hex: habit.colorHex))
                Text(habit.name).font(.title2)
            }
            HStack(spacing: 24) {
                stat("当前", "\(state.current)")
                stat("最佳", "\(state.best)")
                stat("历史段", "\(state.segments.count)")
            }
            HeatmapView(habit: habit,
                        checkins: checkinSet,
                        createdDay: DayKey(habit.createdDay),
                        today: DayKey(HabitRepository.todayKey())) { day, st in
                selected = (day, st)
            }
            if let (day, st) = selected {
                Text("\(day.raw)：\(label(for: st))")
                    .font(.callout).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ name: String, _ value: String) -> some View {
        VStack { Text(value).font(.headline); Text(name).font(.caption).foregroundColor(.secondary) }
    }

    private func label(for state: DayState) -> String {
        switch state {
        case .done: return "已完成"
        case .dimmed: return "断签 1 天（streak 仍保留）"
        case .missed: return "未打卡"
        case .future: return "未来"
        case .beforeStart: return "习惯创建前"
        }
    }
}

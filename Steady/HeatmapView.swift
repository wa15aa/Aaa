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
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
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
                    // 手势直接挂 Canvas：坐标即内容坐标，天然不受滚动偏移影响
                    .contentShape(Rectangle())
                    .onTapGesture { loc in
                        let w = Int(loc.x / (cell + gap))
                        let d = Int(loc.y / (cell + gap))
                        guard weeks.indices.contains(w), weeks[w].indices.contains(d) else { return }
                        let day = weeks[w][d]
                        let state = StreakEngine.dayState(day: day, checkins: checkins, createdDay: createdDay, today: today)
                        onTapDay?(day, state)
                    }
                    Color.clear.frame(width: 1).id("heatmapEnd")
                }
            }
            // 默认滚到最新一周（否则当年视图停留在 1 月，近期打卡看不见）
            .onAppear { proxy.scrollTo("heatmapEnd", anchor: .trailing) }
        }
        .frame(height: 7 * (cell + gap))
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

    /// 完成率（MVP_SPEC §3.7）：daily = 打卡天数/创建以来天数；weekly = 达标周数/创建以来周数
    private var completionRate: Int {
        let created = DayKey(habit.createdDay)
        let today = DayKey(HabitRepository.todayKey())
        // 统一用引擎的整数日期算法算天数
        func daysBetween(_ a: DayKey, _ b: DayKey) -> Int {
            var n = 0, d = a
            while d < b { d = StreakEngine.addDays(d, 1); n += 1 }
            return n
        }
        if habit.frequencyKind == "weekly" {
            let totalWeeks = max(1, daysBetween(StreakEngine.weekStart(created), StreakEngine.weekStart(today)) / 7 + 1)
            var met = 0
            var w = StreakEngine.weekStart(created)
            while w <= today {
                let weekDays = (0..<7).map { StreakEngine.addDays(w, $0) }
                if weekDays.filter({ checkinSet.contains($0) }).count >= Int(habit.timesPerWeek) { met += 1 }
                w = StreakEngine.addDays(w, 7)
            }
            return met * 100 / totalWeeks
        }
        let totalDays = max(1, daysBetween(created, today) + 1)
        let done = checkinSet.filter { $0 >= created && $0 <= today }.count
        return done * 100 / totalDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: habit.icon).foregroundColor(Color(hex: habit.colorHex))
                Text(habit.name).font(.title2)
            }
            HStack(spacing: 24) {
                stat("Current", "\(state.current)")
                stat("Best", "\(state.best)")
                stat("Journeys", "\(state.segments.count)")
                stat("Rate", "\(completionRate)%")
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
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ name: String, _ value: String) -> some View {
        VStack { Text(value).font(.headline); Text(name).font(.caption).foregroundColor(.secondary) }
    }

    private func label(for state: DayState) -> String {
        switch state {
        case .done: return "Done"
        case .dimmed: return "Missed 1 day — streak survived"
        case .missed: return "Missed"
        case .future: return "Upcoming"
        case .beforeStart: return "Before habit created"
        }
    }
}

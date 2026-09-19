import SwiftUI
import Charts
import SteadyCore
import StreakEngine

/// GitHub 式当年热力图：行=周一到周日，列=周（MVP_SPEC §1）。
/// 状态色：done=习惯色，dimmed=暗格（断签/破戒1天 streak 仍活），missed=灰，future/beforeStart=近透明。
struct HeatmapView: View {
    let habit: HabitEntity
    let checkins: Set<DayKey> // quit 型时此集合 = 破戒天
    let createdDay: DayKey
    let today: DayKey

    var onTapDay: ((DayKey, DayState) -> Void)? = nil

    private let cell: CGFloat = 12
    private let gap: CGFloat = 3
    private var isQuit: Bool { habit.habitType == "quit" }

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

    private func state(for day: DayKey) -> DayState {
        if isQuit {
            return StreakEngine.quitDayState(day: day, slips: checkins, createdDay: createdDay, today: today)
        }
        return StreakEngine.dayState(day: day, checkins: checkins, createdDay: createdDay, today: today)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Canvas { ctx, size in
                        for (w, week) in weeks.enumerated() {
                            for (d, day) in week.enumerated() {
                                let rect = CGRect(x: CGFloat(w) * (cell + gap), y: CGFloat(d) * (cell + gap), width: cell, height: cell)
                                let path = Path(roundedRect: rect, cornerRadius: 2.5)
                                ctx.fill(path, with: .color(color(for: state(for: day))))
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
                        onTapDay?(day, state(for: day))
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

/// 习惯详情（W6 打磨，基准 habitkit-app-teardown 04 页）：
/// 头部徽章+名 → 今日主动作（build=打卡 / quit=标破戒）→ 统计行 → 热力图 → 点格子看详情
struct HabitDetailView: View {
    let habit: HabitEntity
    let repo: HabitRepository

    @State private var selected: (DayKey, DayState)? = nil
    @State private var tick = 0 // 打卡/标破戒后触发重算

    private var isQuit: Bool { habit.habitType == "quit" }
    private var state: StreakState { _ = tick; return repo.streakState(for: habit) }
    private var checkinSet: Set<DayKey> { _ = tick; return Set(repo.allCheckins(habitId: habit.id).map { DayKey($0.day) }) }
    private var today: String { HabitRepository.todayKey() }
    private var todayMarked: Bool { checkinSet.contains(DayKey(today)) }
    private var accent: Color { Color(hex: habit.colorHex) }

    /// 完成率（MVP_SPEC §3.7）：daily = 打卡天数/创建以来天数；quit = 无破戒天/创建以来天数；weekly = 达标周数/创建以来周数
    private var completionRate: Int {
        let created = DayKey(habit.createdDay)
        let todayKey = DayKey(today)
        func daysBetween(_ a: DayKey, _ b: DayKey) -> Int {
            var n = 0, d = a
            while d < b { d = StreakEngine.addDays(d, 1); n += 1 }
            return n
        }
        if habit.frequencyKind == "weekly" {
            let totalWeeks = max(1, daysBetween(StreakEngine.weekStart(created), StreakEngine.weekStart(todayKey)) / 7 + 1)
            var met = 0
            var w = StreakEngine.weekStart(created)
            while w <= todayKey {
                let weekDays = (0..<7).map { StreakEngine.addDays(w, $0) }
                if weekDays.filter({ checkinSet.contains($0) }).count >= Int(habit.timesPerWeek) { met += 1 }
                w = StreakEngine.addDays(w, 7)
            }
            return met * 100 / totalWeeks
        }
        let totalDays = max(1, daysBetween(created, todayKey) + 1)
        if isQuit {
            let slips = checkinSet.filter { $0 >= created && $0 <= todayKey }.count
            return max(0, (totalDays - slips)) * 100 / totalDays
        }
        let done = checkinSet.filter { $0 >= created && $0 <= todayKey }.count
        return done * 100 / totalDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: habit.icon)
                    .font(.title3)
                    .foregroundColor(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.15))
                    .cornerRadius(10)
                Text(habit.name).font(.title2).bold()
                if isQuit {
                    Text("QUIT")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(accent.opacity(0.15))
                        .foregroundColor(accent)
                        .cornerRadius(4)
                }
            }
            todayAction
            HStack(spacing: 24) {
                stat("Current", "\(state.current)")
                stat("Best", "\(state.best)")
                stat("Journeys", "\(state.segments.count)")
                stat("Rate", "\(completionRate)%")
            }
            HeatmapView(habit: habit,
                        checkins: checkinSet,
                        createdDay: DayKey(habit.createdDay),
                        today: DayKey(today)) { day, st in
                selected = (day, st)
            }
            if let (day, st) = selected {
                Text("\(day.raw)：\(label(for: st))")
                    .font(.callout).foregroundColor(.secondary)
            }
            chartSection
            Spacer()
        }
        .padding()
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 今日主动作：详情页是补卡/标破戒的自然入口（HabitKit 04 页大红 ✓ 的位置）
    @ViewBuilder
    private var todayAction: some View {
        if isQuit {
            if todayMarked {
                HStack {
                    Label("Slip marked — one slip doesn't break you", systemImage: "bandage.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Undo") {
                        repo.removeCheckin(habitId: habit.id, day: today)
                        tick += 1
                    }
                    .font(.subheadline)
                }
            } else {
                Button {
                    repo.checkin(habitId: habit.id, day: today)
                    tick += 1
                } label: {
                    Text("I slipped today")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        } else {
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                if repo.checkin(habitId: habit.id, day: today) {
                    generator.impactOccurred()
                }
                tick += 1
            } label: {
                Label(todayMarked ? "Done for today" : "Check in for today",
                      systemImage: todayMarked ? "checkmark.circle.fill" : "circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(todayMarked ? accent.opacity(0.2) : accent)
                    .foregroundColor(todayMarked ? accent : .white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(todayMarked)
        }
    }

    // MARK: W6 功能批③ 统计图表化（Swift Charts，对齐 HabitKit 05 页）

    /// 周维度完成率：最近 8 周，每周达标天数（daily/quit=完成天数，weekly=当周打卡数）
    private var weeklyBuckets: [(label: String, value: Int)] {
        let todayKey = DayKey(today)
        let thisWeek = StreakEngine.weekStart(todayKey)
        return (0..<8).reversed().map { back in
            let ws = StreakEngine.addDays(thisWeek, -7 * back)
            let days = (0..<7).map { StreakEngine.addDays(ws, $0) }.filter { $0 <= todayKey }
            if isQuit {
                let slips = days.filter { checkinSet.contains($0) }.count
                return ("W\(back == 0 ? " now" : "-\(back)")", max(0, days.count - slips))
            }
            let done = days.filter { checkinSet.contains($0) }.count
            return ("W\(back == 0 ? " now" : "-\(back)")", done)
        }
    }

    /// 月维度完成率（%）：最近 6 个月
    private var monthlyBuckets: [(label: String, value: Int)] {
        let todayKey = DayKey(today)
        let created = DayKey(habit.createdDay)
        let ym = { (d: DayKey) -> String in String(d.raw.prefix(7)) }
        var months: [String] = []
        var cursor = DayKey(ym(created) + "-01")
        while cursor <= todayKey {
            months.append(ym(cursor))
            cursor = StreakEngine.addDays(cursor, 32)
            cursor = DayKey(ym(cursor) + "-01")
        }
        return months.suffix(6).map { m in
            let days = checkinSet.filter { $0.raw.hasPrefix(m) }
            // 月内总天数近似：该月打卡/破戒计数 ÷ 当月已过天数
            let firstOfMonth = DayKey(m + "-01")
            var last = StreakEngine.addDays(firstOfMonth, 32)
            last = DayKey(ym(last) + "-01")
            var total = 0; var d = firstOfMonth
            let end = min(last, StreakEngine.addDays(todayKey, 1))
            while d < end { if d >= created { total += 1 }; d = StreakEngine.addDays(d, 1) }
            guard total > 0 else { return (String(m.suffix(2)), 0) }
            let pct = isQuit ? max(0, (total - days.count)) * 100 / total : days.count * 100 / total
            return (String(m.suffix(2)), pct)
        }
    }

    @State private var chartRange = 0 // 0=周 1=月

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $chartRange) {
                Text("Weeks").tag(0)
                Text("Months").tag(1)
            }
            .pickerStyle(.segmented)
            if chartRange == 0 {
                Chart(weeklyBuckets, id: \.label) { b in
                    BarMark(x: .value("Week", b.label), y: .value(isQuit ? "Clean" : "Done", b.value))
                        .foregroundStyle(accent)
                }
                .frame(height: 140)
            } else {
                Chart(monthlyBuckets, id: \.label) { b in
                    BarMark(x: .value("Month", b.label), y: .value("Rate %", b.value))
                        .foregroundStyle(accent)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 140)
            }
        }
    }

    private func stat(_ name: String, _ value: String) -> some View {
        VStack { Text(value).font(.headline); Text(name).font(.caption).foregroundColor(.secondary) }
    }

    private func label(for state: DayState) -> String {
        if isQuit {
            switch state {
            case .done: return "Clean day"
            case .dimmed: return "Slip day — streak survived"
            case .missed: return "Slip run — journey reset"
            case .future: return "Upcoming"
            case .beforeStart: return "Before habit created"
            }
        }
        switch state {
        case .done: return "Done"
        case .dimmed: return "Missed 1 day — streak survived"
        case .missed: return "Missed"
        case .future: return "Upcoming"
        case .beforeStart: return "Before habit created"
        }
    }
}

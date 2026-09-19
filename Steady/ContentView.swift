import SwiftUI
import SteadyCore
import StreakEngine

/// 首屏：今天清单 + 打卡 ≤1 次点击（MVP_SPEC §1）。
struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var habits: [HabitEntity] = []
    @State private var streaks: [UUID: Int] = [:]
    @State private var checkedToday: Set<UUID> = []
    @State private var weeklyProgress: [UUID: Int] = [:]
    @State private var segmentCounts: [UUID: Int] = [:]
    @State private var last7: [UUID: [DayState]] = [:]
    @State private var showAdd = false
    @State private var autoShowDetail = false
    @State private var autoShowPaywall = false
    @State private var showStatsPaywall = false

    private var repo: HabitRepository { HabitRepository(context: context) }

    var body: some View {
        NavigationView {
            Group {
                if habits.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(habits, id: \.id) { habit in
                                habitRow(habit)
                            }
                        } header: {
                            Text("\(checkedToday.count) of \(habits.count) done today")
                                .textCase(nil)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    // DEBUG 截图管线：screenshotMode=detail 时自动进第一个习惯的详情页
                    .background(
                        NavigationLink(isActive: $autoShowDetail) {
                            if let first = habits.first {
                                HabitDetailView(habit: first, repo: repo)
                            }
                        } label: { EmptyView() }.hidden()
                    )
                }
            }
            .navigationTitle("Today")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd, onDismiss: reload) {
                AddHabitView().environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $autoShowPaywall) {
                PaywallView(onUnlocked: { autoShowPaywall = false })
            }
            .sheet(isPresented: $showStatsPaywall) {
                PaywallView(onUnlocked: { showStatsPaywall = false },
                            requestedFeature: "Detailed stats & full history")
            }
            .onAppear(perform: reload)
        }
    }

    /// 空态：新用户引导（MVP_SPEC §1 首屏 ≤1 点击创建）
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            Text("No habits yet")
                .font(.title2).bold()
            Text("Start with one tiny action.\nMissing one day is fine — never miss two.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Create your first habit") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding()
    }

    @MainActor
    private func habitRow(_ habit: HabitEntity) -> some View {
        HStack {
            // replan-v2 §4.2：统计页功能点触发 paywall——免费用户点行进 paywall（requestedFeature 置顶），Pro 直达详情
            if StoreKitManager.shared.isPro {
                NavigationLink {
                    HabitDetailView(habit: habit, repo: repo)
                } label: {
                    rowLabel(habit)
                }
            } else {
                Button { showStatsPaywall = true } label: { rowLabel(habit) }
                    .buttonStyle(.plain)
            }
            Spacer()
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                if repo.checkin(habitId: habit.id) {
                    generator.impactOccurred()
                }
                reload()
            } label: {
                Image(systemName: checkedToday.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundColor(checkedToday.contains(habit.id) ? Color(hex: habit.colorHex) : Color(.systemGray3))
            }
            .buttonStyle(.plain)
            .disabled(checkedToday.contains(habit.id))
        }
    }

    private func rowLabel(_ habit: HabitEntity) -> some View {
        HStack {
            Image(systemName: habit.icon)
                .font(.body)
                .foregroundColor(Color(hex: habit.colorHex))
                .frame(width: 36, height: 36)
                .background(Color(hex: habit.colorHex).opacity(0.15))
                .cornerRadius(10)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(subtitle(for: habit))
                    .font(.caption)
                    .foregroundColor(.secondary)
                weekDots(for: habit)
            }
        }
    }

    /// daily → "X-day streak"；weekly → "This week x/N · w-week streak"；streak 归零且有历史段 → "Journey N"（反罪恶感，MVP_SPEC §2）
    private func subtitle(for habit: HabitEntity) -> String {
        let streak = streaks[habit.id] ?? 0
        let segments = segmentCounts[habit.id] ?? 0
        if streak == 0 && segments > 0 {
            return "Journey \(segments + 1) · best streak still on record"
        }
        if habit.frequencyKind == "weekly" {
            let done = weeklyProgress[habit.id] ?? 0
            return "This week \(done)/\(habit.timesPerWeek) · \(streak)-week streak"
        }
        return "\(streak)-day streak"
    }

    /// 最近 7 天小点：done=习惯色实点，dimmed=半透明（断签不死可视化），其余灰（MVP_SPEC §2 反罪恶感要可感知）
    private func weekDots(for habit: HabitEntity) -> some View {
        HStack(spacing: 4) {
            let states = last7[habit.id] ?? []
            ForEach(Array(states.enumerated()), id: \.offset) { _, st in
                Circle()
                    .fill(dotColor(st, hex: habit.colorHex))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 2)
    }

    private func dotColor(_ st: DayState, hex: String) -> Color {
        switch st {
        case .done: return Color(hex: hex)
        case .dimmed: return Color(hex: hex).opacity(0.35)
        default: return Color(.systemGray4)
        }
    }

    private func reload() {
        habits = repo.activeHabits()
        let today = DayKey(HabitRepository.todayKey())
        let weekStart = StreakEngine.weekStart(today)
        streaks = [:]
        checkedToday = []
        weeklyProgress = [:]
        for h in habits {
            let state = repo.streakState(for: h)
            streaks[h.id] = state.current
            segmentCounts[h.id] = state.segments.count
            let checkins = repo.allCheckins(habitId: h.id)
            if checkins.contains(where: { $0.day == today.raw }) {
                checkedToday.insert(h.id)
            }
            if h.frequencyKind == "weekly" {
                weeklyProgress[h.id] = checkins.filter { $0.day >= weekStart.raw && $0.day <= today.raw }.count
            }
            let cset = Set(checkins.map { DayKey($0.day) })
            last7[h.id] = (0..<7).reversed().map { back in
                let day = StreakEngine.addDays(today, -back)
                return StreakEngine.dayState(day: day, checkins: cset,
                                             createdDay: DayKey(h.createdDay), today: today)
            }
        }
        #if DEBUG
        // 截图管线：defaults write sh.steadyhabit.Steady screenshotMode detail|paywall
        switch UserDefaults.standard.string(forKey: "screenshotMode") {
        case "detail" where !habits.isEmpty:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { autoShowDetail = true }
        case "paywall":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { autoShowPaywall = true }
        case "add":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showAdd = true }
        default:
            break
        }
        #endif
    }
}

struct AddHabitView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isWeekly = false
    @State private var timesPerWeek = 3
    @State private var reminderTimes: [Date] = []
    private let defaultReminderTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var showPaywall = false
    @State private var habitType: HabitType = .build
    @State private var showQuitPaywall = false
    @State private var icon = "star.fill"
    @State private var colorHex = "4F8CFF"

    // W6 功能批①：40 SF Symbols 图标 + 21 色色板（对齐 HabitKit 选择器容量）
    private let icons = ["star.fill", "heart.fill", "flame.fill", "book.fill", "figure.run", "drop.fill",
                         "leaf.fill", "moon.fill", "sun.max.fill", "pencil", "paintbrush.fill", "music.note",
                         "dumbbell.fill", "bicycle", "fork.knife", "cup.and.saucer.fill", "bed.double.fill", "brain.head.profile",
                         "text.book.closed.fill", "laptopcomputer", "camera.fill", "gamecontroller.fill", "cart.fill", "phone.fill",
                         "figure.walk", "figure.yoga", "sportscourt.fill", "trophy.fill",
                         "pills.fill", "stethoscope", "bandage.fill", "waterbottle.fill",
                         "graduationcap.fill", "globe", "airplane", "car.fill",
                         "house.fill", "briefcase.fill", "gift.fill", "pawprint.fill"]
    private let colors = ["4F8CFF", "FF6B6B", "34C759", "FF9500", "AF52DE", "00C7BE", "FFD60A", "FF375F",
                          "5E5CE6", "64D2FF", "30D158", "FF9F0A", "BF5AF2", "6AC4DC", "FF6482", "AC8E68",
                          "2E7D5B", "0A5CFF", "D70015", "8E8E93", "1C1C1E"]

    private func save() {
        let repo = HabitRepository(context: context)
        let habit = repo.createHabit(
            name: name, icon: icon, colorHex: colorHex,
            frequency: isWeekly ? .timesPerWeek(timesPerWeek) : .daily,
            type: habitType)
        if !reminderTimes.isEmpty {
            NotificationManager.requestAuthorization()
            // 先落库（备份会带走），再调度本地通知
            let times: [(hour: Int, minute: Int)] = reminderTimes.map {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: $0)
                return (comps.hour ?? 9, comps.minute ?? 0)
            }
            repo.setReminders(habit: habit, times: times)
            NotificationManager.scheduleReminders(habitId: habit.id, name: habit.name, times: times)
        }
        dismiss()
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("Habit name", text: $name)
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(icons, id: \.self) { name in
                            Image(systemName: name)
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(icon == name ? Color(hex: colorHex).opacity(0.25) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture { icon = name }
                        }
                    }
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
                if habitType == .build {
                    Toggle("Weekly goal", isOn: $isWeekly)
                    if isWeekly {
                        Stepper("\(timesPerWeek) times per week", value: $timesPerWeek, in: 1...6)
                    }
                }
                Section("Type") {
                    // replan-v2 §4.1：Quit 为 Pro 功能（paywall 功能点触发之一），免费用户选 Quit → paywall
                    Picker("Habit type", selection: $habitType) {
                        Text("Build — do it every day").tag(HabitType.build)
                        Text("Quit — slip days don't break you").tag(HabitType.quit)
                    }
                    .onChange(of: habitType) { newValue in
                        if newValue == .quit && !StoreKitManager.shared.isPro {
                            habitType = .build
                            showQuitPaywall = true
                        }
                    }
                    if habitType == .quit {
                        Text("Only mark days you slipped. One slip never breaks your streak.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Section("Reminders") {
                    // W6 功能批②：每习惯多提醒，上限 3 条（对齐 HabitKit）
                    ForEach(Array(reminderTimes.indices), id: \.self) { i in
                        HStack {
                            DatePicker("Reminder \(i + 1)", selection: $reminderTimes[i],
                                       displayedComponents: .hourAndMinute)
                            Button(role: .destructive) { reminderTimes.remove(at: i) } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if reminderTimes.count < 3 {
                        Button {
                            reminderTimes.append(defaultReminderTime)
                        } label: {
                            Label("Add reminder", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // DoD#4：第 4 个习惯触发 paywall（免费版 3 个）
                        let repo = HabitRepository(context: context)
                        if !StoreKitManager.shared.isPro && repo.activeHabits().count >= 3 {
                            showPaywall = true
                        } else {
                            save()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onUnlocked: save)
            }
            .sheet(isPresented: $showQuitPaywall) {
                PaywallView(onUnlocked: { habitType = .quit },
                            requestedFeature: "Quit habits — slip days don't break you")
            }
        }
    }
}

extension Color {
    init(hex: String) {
        var v = hex
        if v.hasPrefix("#") { v.removeFirst() }
        let n = UInt64(v, radix: 16) ?? 0x4F8CFF
        self.init(red: Double((n >> 16) & 0xFF) / 255,
                  green: Double((n >> 8) & 0xFF) / 255,
                  blue: Double(n & 0xFF) / 255)
    }
}

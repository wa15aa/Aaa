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
    @State private var showSettings = false
    // W7 视图批①：主页 3 视图（list 清单 / week 周表矩阵 / compact 紧凑），胶囊切换器
    @AppStorage("steady.homeViewMode") private var viewMode = 0
    // W7④ 面板自定义：streak 数字 / 周小点 显示开关（设置页 Dashboard 段）
    @AppStorage("steady.showStreaks") private var showStreaks = true
    @AppStorage("steady.showWeekDots") private var showWeekDots = true
    @AppStorage("steady.showOverview") private var showOverview = true
    // W7 onboarding 移到此处由 @AppStorage 驱动：UserDefaults 写入自动触发重渲染，
    // 修复 SteadyApp 里裸 Binding 读 defaults 不响应（Get started 关不掉 / Replay 不弹）
    @AppStorage("steady.onboarded") private var onboarded = false

    private var repo: HabitRepository { HabitRepository(context: context) }

    var body: some View {
        NavigationView {
            Group {
                if habits.isEmpty {
                    emptyState
                } else if viewMode == 1 {
                    weekMatrixView
                } else {
                    List {
                        Section {
                            ForEach(habits, id: \.id) { habit in
                                if viewMode == 2 { compactRow(habit) } else { habitRow(habit) }
                            }
                            .onMove { from, to in
                                // W7 设置批：拖拽排序持久化到 sortOrder
                                var copy = habits
                                copy.move(fromOffsets: from, toOffset: to)
                                repo.reorder(copy)
                                habits = copy
                            }
                            .onDelete { idx in
                                // 滑动删除=归档（软删，Checkin 保留；Settings→Archived 可恢复/彻底删除）
                                for i in idx {
                                    NotificationManager.cancelReminder(habitId: habits[i].id)
                                    repo.archive(habits[i])
                                }
                                reload()
                            }
                        } header: {
                            // quit 型默认"已守住"，不计入待完成数；破戒标记也不是 done
                            // Overview 开关（设置页 Dashboard 段）可整体关掉这行
                            if showOverview {
                                let buildHabits = habits.filter { $0.habitType != "quit" }
                                let buildDone = buildHabits.filter { checkedToday.contains($0.id) }.count
                                Text("\(buildDone) of \(buildHabits.count) done today")
                                    .textCase(nil)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
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
            .overlay(alignment: .bottom) {
                if !habits.isEmpty { viewSwitcher }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        EditButton()
                        Button { showAdd = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Add habit")
                    }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: reload) {
                SettingsView().environment(\.managedObjectContext, context)
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
            // 首启动一页式 onboarding；截图管线非 none 时压住（"none" 归一化为不压）
            .fullScreenCover(isPresented: Binding(
                get: {
                    let sm = UserDefaults.standard.string(forKey: "screenshotMode")
                    return !onboarded && (sm == nil || sm == "none")
                },
                set: { if !$0 { onboarded = true } }
            )) {
                OnboardingView()
            }
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
            if habit.habitType == "quit" {
                // Quit 型默认今天已守住：不显示打卡钮，只给"标破戒"钮（再点一次=误标撤销）
                let slipped = checkedToday.contains(habit.id)
                Button {
                    if slipped { _ = repo.removeCheckin(habitId: habit.id, day: HabitRepository.todayKey()) }
                    else { _ = repo.checkin(habitId: habit.id) }
                    reload()
                } label: {
                    Image(systemName: slipped ? "bandage.fill" : "bandage")
                        .font(.system(size: 22))
                        .foregroundColor(slipped ? .orange : Color(.systemGray3))
                }
                .buttonStyle(.plain)
                .accessibilityLabel((slipped ? "Undo slip " : "Mark slip ") + habit.name)
            } else {
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
                .accessibilityLabel((checkedToday.contains(habit.id) ? "Checked in " : "Check in ") + habit.name)
            }
        }
    }

    /// 紧凑行（视图 2）：只有 icon+名+streak+打卡钮，无副标题无小点
    @MainActor
    private func compactRow(_ habit: HabitEntity) -> some View {
        HStack {
            Image(systemName: habit.icon)
                .foregroundColor(Color(hex: habit.colorHex))
            Text(habit.name).font(.subheadline)
            if showStreaks {
                Text("\(streaks[habit.id] ?? 0)d")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if habit.habitType == "quit" {
                let slipped = checkedToday.contains(habit.id)
                Button {
                    if slipped { _ = repo.removeCheckin(habitId: habit.id, day: HabitRepository.todayKey()) }
                    else { _ = repo.checkin(habitId: habit.id) }
                    reload()
                } label: {
                    Image(systemName: slipped ? "bandage.fill" : "bandage")
                        .foregroundColor(slipped ? .orange : Color(.systemGray3))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    if repo.checkin(habitId: habit.id) { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                    reload()
                } label: {
                    Image(systemName: checkedToday.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(checkedToday.contains(habit.id) ? Color(hex: habit.colorHex) : Color(.systemGray3))
                }
                .buttonStyle(.plain)
                .disabled(checkedToday.contains(habit.id))
                .accessibilityLabel((checkedToday.contains(habit.id) ? "Checked in " : "Check in ") + habit.name)
            }
        }
    }

    /// 周表矩阵（视图 1）：行=习惯，列=本周 7 天，点格子补卡/撤销（quit 型=标破戒）
    @MainActor
    private var weekMatrixView: some View {
        let today = DayKey(HabitRepository.todayKey())
        let ws = StreakEngine.weekStart(today)
        let days = (0..<7).map { StreakEngine.addDays(ws, $0) }
        let letters = ["M","T","W","T","F","S","S"]
        return List {
            // 列头
            HStack(spacing: 6) {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    Text(letters[i])
                        .font(.caption2).bold()
                        .foregroundColor(d == today ? .accentColor : .secondary)
                        .frame(width: 28)
                }
            }
            ForEach(habits, id: \.id) { h in
                HStack(spacing: 6) {
                    Label(h.name, systemImage: h.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundColor(Color(hex: h.colorHex))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(days, id: \.raw) { d in
                        weekCell(habit: h, day: d, today: today)
                    }
                }
            }
        }
    }

    @MainActor
    private func weekCell(habit: HabitEntity, day: DayKey, today: DayKey) -> some View {
        let set = Set(repo.allCheckins(habitId: habit.id).map { DayKey($0.day) })
        let marked = set.contains(day)
        let future = day > today
        return Button {
            guard !future else { return }
            if marked { _ = repo.removeCheckin(habitId: habit.id, day: day.raw) }
            else { _ = repo.checkin(habitId: habit.id, day: day.raw) }
            reload()
        } label: {
            Image(systemName: marked ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundColor(marked ? Color(hex: habit.colorHex)
                                 : future ? Color(.systemGray5) : Color(.systemGray3))
                .frame(width: 28)
        }
        .buttonStyle(.plain)
        .disabled(future)
    }

    /// 底部胶囊切换器（W7 视图批①，参考 HabitKit 02 页）
    private var viewSwitcher: some View {
        HStack(spacing: 0) {
            ForEach([(0, "list.bullet", "List"), (1, "calendar.day.timeline.leading", "Week"), (2, "rectangle.compress.vertical", "Compact")], id: \.0) { mode, icon, name in
                Button { withAnimation(.easeInOut(duration: 0.15)) { viewMode = mode } } label: {
                    Label(name, systemImage: icon)
                        .font(.caption).bold()
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(viewMode == mode ? Color.accentColor : Color.clear)
                        .foregroundColor(viewMode == mode ? .white : .secondary)
                        .cornerRadius(16)
                }
            }
        }
        .padding(4)
        .background(.regularMaterial)
        .cornerRadius(20)
        .shadow(radius: 4)
        .padding(.bottom, 8)
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
                if showStreaks {
                    Text(subtitle(for: habit))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if showWeekDots { weekDots(for: habit) }
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
        // quit 型：streak = 连续守住天数，措辞点明语义
        if habit.habitType == "quit" {
            return streak > 0 ? "\(streak)-day clean streak" : "Clean today counts — only mark slips"
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
        case "settings":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showSettings = true }
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
                                .accessibilityIdentifier("icon_\(name)")
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
                                .accessibilityIdentifier("color_\(hex)")
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

// Color(hex:) 已上移到 SteadyCore/ColorHex.swift（widget 扩展共用）

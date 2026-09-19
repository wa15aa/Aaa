import SwiftUI
import SteadyCore

/// 首屏：今天清单 + 打卡 ≤1 次点击（MVP_SPEC §1）。
struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var habits: [HabitEntity] = []
    @State private var streaks: [UUID: Int] = [:]
    @State private var checkedToday: Set<UUID> = []
    @State private var weeklyProgress: [UUID: Int] = [:]
    @State private var segmentCounts: [UUID: Int] = [:]
    @State private var showAdd = false
    @State private var autoShowDetail = false
    @State private var autoShowPaywall = false

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
                            Text("今天已完成 \(checkedToday.count)/\(habits.count)")
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
            .navigationTitle("今天")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd, onDismiss: reload) {
                AddHabitView().environment(\.managedObjectContext, context)
            }
            .sheet(isPresented: $autoShowPaywall) {
                PaywallView(onUnlocked: { autoShowPaywall = false })
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
            Text("还没有习惯")
                .font(.title2).bold()
            Text("从一个最小行动开始，\n断一天没关系，别断两天。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("创建第一个习惯") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding()
    }

    private func habitRow(_ habit: HabitEntity) -> some View {
        HStack {
            NavigationLink {
                HabitDetailView(habit: habit, repo: repo)
            } label: {
                HStack {
                    Image(systemName: habit.icon)
                        .foregroundColor(Color(hex: habit.colorHex))
                    VStack(alignment: .leading) {
                        Text(habit.name)
                        Text(subtitle(for: habit))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
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
                    .font(.title2)
                    .foregroundColor(checkedToday.contains(habit.id) ? Color(hex: habit.colorHex) : Color(.systemGray3))
            }
            .buttonStyle(.plain)
            .disabled(checkedToday.contains(habit.id))
        }
    }

    /// daily → "连续 X 天"；weekly → "本周 x/N · 连续 w 周"；streak 归零且有历史段 → "第 N 段旅程"（反罪恶感，MVP_SPEC §2）
    private func subtitle(for habit: HabitEntity) -> String {
        let streak = streaks[habit.id] ?? 0
        let segments = segmentCounts[habit.id] ?? 0
        if streak == 0 && segments > 0 {
            return "第 \(segments + 1) 段旅程 · 历史最佳仍在"
        }
        if habit.frequencyKind == "weekly" {
            let done = weeklyProgress[habit.id] ?? 0
            return "本周 \(done)/\(habit.timesPerWeek) · 连续 \(streak) 周"
        }
        return "连续 \(streak) 天"
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
        }
        #if DEBUG
        // 截图管线：defaults write sh.steadyhabit.Steady screenshotMode detail|paywall
        switch UserDefaults.standard.string(forKey: "screenshotMode") {
        case "detail" where !habits.isEmpty:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { autoShowDetail = true }
        case "paywall":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { autoShowPaywall = true }
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
    @State private var hasReminder = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var showPaywall = false
    @State private var icon = "star.fill"
    @State private var colorHex = "4F8CFF"

    // MVP_SPEC §4：icon enum 32 个的可用子集（SF Symbols，v1 先 24 个常用）
    private let icons = ["star.fill", "heart.fill", "flame.fill", "book.fill", "figure.run", "drop.fill",
                         "leaf.fill", "moon.fill", "sun.max.fill", "pencil", "paintbrush.fill", "music.note",
                         "dumbbell.fill", "bicycle", "fork.knife", "cup.and.saucer.fill", "bed.double.fill", "brain.head.profile",
                         "text.book.closed.fill", "laptopcomputer", "camera.fill", "gamecontroller.fill", "cart.fill", "phone.fill"]
    private let colors = ["4F8CFF", "FF6B6B", "34C759", "FF9500", "AF52DE", "00C7BE", "FFD60A", "FF375F"]

    private func save() {
        let repo = HabitRepository(context: context)
        let habit = repo.createHabit(
            name: name, icon: icon, colorHex: colorHex,
            frequency: isWeekly ? .timesPerWeek(timesPerWeek) : .daily)
        if hasReminder {
            NotificationManager.requestAuthorization()
            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            // 先落库（备份会带走），再调度本地通知
            repo.setReminder(habit: habit, hour: comps.hour, minute: comps.minute)
            NotificationManager.scheduleReminder(habitId: habit.id, name: habit.name,
                                                 hour: comps.hour, minute: comps.minute)
        }
        dismiss()
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("习惯名字", text: $name)
                Section("图标") {
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
                Section("颜色") {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
                Toggle("每周 N 次", isOn: $isWeekly)
                if isWeekly {
                    Stepper("每周 \(timesPerWeek) 次", value: $timesPerWeek, in: 1...6)
                }
                Toggle("每日提醒", isOn: $hasReminder)
                if hasReminder {
                    DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("新习惯")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onUnlocked: save)
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

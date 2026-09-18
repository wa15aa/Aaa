import SwiftUI
import SteadyCore

/// 首屏：今天清单 + 打卡 ≤1 次点击（MVP_SPEC §1）。
struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var habits: [HabitEntity] = []
    @State private var streaks: [UUID: Int] = [:]
    @State private var checkedToday: Set<UUID> = []
    @State private var showAdd = false

    private var repo: HabitRepository { HabitRepository(context: context) }

    var body: some View {
        NavigationView {
            List {
                ForEach(habits, id: \.id) { habit in
                    HStack {
                        NavigationLink {
                            HabitDetailView(habit: habit, repo: repo)
                        } label: {
                            HStack {
                                Image(systemName: habit.icon)
                                    .foregroundColor(Color(hex: habit.colorHex))
                                VStack(alignment: .leading) {
                                    Text(habit.name)
                                    Text("连续 \(streaks[habit.id] ?? 0) 天")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Button {
                            repo.checkin(habitId: habit.id)
                            reload()
                        } label: {
                            Image(systemName: checkedToday.contains(habit.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .disabled(checkedToday.contains(habit.id))
                    }
                }
            }
            .navigationTitle("今天")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd, onDismiss: reload) {
                AddHabitView().environment(\.managedObjectContext, context)
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        habits = repo.activeHabits()
        let today = HabitRepository.todayKey()
        streaks = [:]
        checkedToday = []
        for h in habits {
            streaks[h.id] = repo.streakState(for: h).current
            if repo.fetchCheckin(habitId: h.id, day: today) != nil {
                checkedToday.insert(h.id)
            }
        }
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

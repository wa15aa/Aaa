import CoreData
@_exported import StreakEngine

/// 习惯仓库：CRUD + 打卡。UI 只跟它说话，不直接碰 CoreData。
public final class HabitRepository {
    public let context: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.context = context
    }

    public static var localDayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f // 不锁时区：本地"天"语义
    }

    public static func todayKey(now: Date = Date()) -> String {
        localDayFormatter.string(from: now)
    }

    // MARK: CRUD

    @discardableResult
    public func createHabit(name: String, icon: String, colorHex: String,
                     frequency: Frequency, sortOrder: Int16 = 0) -> HabitEntity {
        // 用 context 所属 model 解析实体（同进程多 container 时 +entity 全局查找会二义）
        let h = HabitEntity(entity: NSEntityDescription.entity(forEntityName: "Habit", in: context)!, insertInto: context)
        h.id = UUID()
        h.name = String(name.prefix(30))
        h.icon = icon
        h.colorHex = colorHex
        switch frequency {
        case .daily:
            h.frequencyKind = "daily"; h.timesPerWeek = 0
        case .timesPerWeek(let n):
            h.frequencyKind = "weekly"; h.timesPerWeek = Int16(min(max(n, 1), 6))
        }
        h.createdAt = Date()
        h.createdDay = Self.todayKey()
        h.sortOrder = sortOrder
        // -1 = 未设提醒（0:00 是合法提醒时间，不能用 0 当哨兵）
        h.reminderHour = -1; h.reminderMinute = -1
        save()
        return h
    }

    /// 设置/清除每日提醒时间。hour 传 nil 表示清除。
    public func setReminder(habit: HabitEntity, hour: Int?, minute: Int?) {
        if let hour = hour, let minute = minute, (0...23).contains(hour), (0...59).contains(minute) {
            habit.reminderHour = Int16(hour); habit.reminderMinute = Int16(minute)
        } else {
            habit.reminderHour = -1; habit.reminderMinute = -1
        }
        save()
    }

    /// 软删：数据保留
    public func archive(_ habit: HabitEntity) {
        habit.archivedAt = Date()
        save()
    }

    public func activeHabits() -> [HabitEntity] {
        let req = NSFetchRequest<HabitEntity>(entityName: "Habit")
        req.predicate = NSPredicate(format: "archivedAt == nil")
        req.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    // MARK: 打卡

    /// 打卡（默认今天）。重复打卡同一天 = 幂等（唯一约束冲突时保留已有记录）。
    @discardableResult
    public func checkin(habitId: UUID, day: String? = nil, backfill: Bool = false) -> Bool {
        let dayKey = day ?? Self.todayKey()
        if let _ = fetchCheckin(habitId: habitId, day: dayKey) { return true } // 幂等
        if backfill && !StreakEngine.canBackfill(day: DayKey(dayKey), today: DayKey(Self.todayKey())) {
            return false // 只允许补昨天
        }
        let c = CheckinEntity(entity: NSEntityDescription.entity(forEntityName: "Checkin", in: context)!, insertInto: context)
        c.id = UUID()
        c.habitId = habitId
        c.day = dayKey
        c.ts = Date()
        c.backfill = backfill
        c.tzOffsetMinutes = Int32(TimeZone.current.secondsFromGMT() / 60)
        save()
        return true
    }

    public func fetchCheckin(habitId: UUID, day: String) -> CheckinEntity? {
        let req = NSFetchRequest<CheckinEntity>(entityName: "Checkin")
        req.predicate = NSPredicate(format: "habitId == %@ AND day == %@", habitId as CVarArg, day)
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }

    public func allCheckins(habitId: UUID) -> [CheckinEntity] {
        let req = NSFetchRequest<CheckinEntity>(entityName: "Checkin")
        req.predicate = NSPredicate(format: "habitId == %@", habitId as CVarArg)
        req.sortDescriptors = [NSSortDescriptor(key: "day", ascending: true)]
        return (try? context.fetch(req)) ?? []
    }

    // MARK: streak 计算（桥接 StreakEngine）

    public func streakState(for habit: HabitEntity) -> StreakState {
        let inputs = allCheckins(habitId: habit.id).map {
            CheckinInput(day: DayKey($0.day), backfill: $0.backfill)
        }
        let today = DayKey(Self.todayKey())
        let created = DayKey(habit.createdDay)
        if habit.frequencyKind == "weekly" {
            return StreakEngine.weekly(checkins: inputs, targetPerWeek: Int(habit.timesPerWeek),
                                       createdDay: created, today: today)
        }
        return StreakEngine.daily(checkins: inputs, createdDay: created, today: today)
    }

    private func save() {
        if context.hasChanges { try? context.save() }
    }
}

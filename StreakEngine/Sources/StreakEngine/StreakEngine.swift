import Foundation

// MARK: - 输入模型（纯值类型，与持久层解耦）

/// 打卡记录的日期键，"yyyy-MM-dd"，始终按本地"天"语义解释。
public struct DayKey: Hashable, Comparable, Codable {
    public let raw: String // yyyy-MM-dd
    public init(_ raw: String) { self.raw = raw }
    public static func < (a: DayKey, b: DayKey) -> Bool { a.raw < b.raw }
}

public enum Frequency: Codable, Equatable {
    case daily
    case timesPerWeek(Int) // 1...6
}

/// 习惯类型（replan-v2 §4.1，2026-09-19 用户批准）：
/// - build：每天主动打卡，完成集 = 打卡天
/// - quit：戒断型，默认完成，只标破戒天，完成集 = 非破戒天；streak 计连续无破戒天
public enum HabitType: String, Codable, Equatable {
    case build
    case quit
}

public struct CheckinInput: Equatable {
    public let day: DayKey
    public let backfill: Bool
    public init(day: DayKey, backfill: Bool = false) {
        self.day = day
        self.backfill = backfill
    }
}

// MARK: - 输出模型

/// 某一天在热力图上的状态。
public enum DayState: Equatable {
    case done          // 完成（含补签）
    case dimmed        // 断签 1 天（streak 未清零的"暗格"）
    case missed        // 断签（计入连续断签）
    case future        // 未来
    case beforeStart   // 习惯创建之前
}

public struct StreakSegmentValue: Equatable, Codable {
    public let startDay: DayKey
    public let endDay: DayKey
    public let length: Int // 段内完成天数（weekly：段内达标周数）
    public init(startDay: DayKey, endDay: DayKey, length: Int) {
        self.startDay = startDay
        self.endDay = endDay
        self.length = length
    }
}

public struct StreakState: Equatable {
    public var current: Int            // 当前连续段（daily：有效完成天数；weekly：连续达标周数）
    public var best: Int               // 历史最佳
    public var segments: [StreakSegmentValue] // 已封存的历史段
    public var todayState: DayState
    public init(current: Int, best: Int, segments: [StreakSegmentValue], todayState: DayState) {
        self.current = current
        self.best = best
        self.segments = segments
        self.todayState = todayState
    }
}

// MARK: - 引擎

/// 弹性 streak 引擎。规则见 MVP_SPEC §2：
/// - never-miss-twice：断签 1 天不清零（暗格），连续断签 2 天才重置 current
/// - 补签：只允许补"昨天"；引擎对非法补签不特殊惩罚（输入层已过滤）
/// - 周频率：按周（周一起算）达成次数 ≥ N 计 streak（单位=周），当周未结束不打断
/// - 日期全部用 civil-date 整数算法（Howard Hinnant），零 DateFormatter/ICU 依赖，
///   天然免疫时区/夏令时在序列推演中的干扰
public enum StreakEngine {

    // MARK: civil date 整数算法

    /// "yyyy-MM-dd" → 自 1970-01-01 的天数
    static func daysFromCivil(_ day: DayKey) -> Int {
        let p = day.raw.split(separator: "-")
        guard p.count == 3, let y0 = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]) else {
            return 0
        }
        let y = m <= 2 ? y0 - 1 : y0
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400                                   // [0, 399]
        let mp = (m + 9) % 12                                     // [0, 11]
        let doy = (153 * mp + 2) / 5 + d - 1                      // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy           // [0, 146096]
        return era * 146097 + doe - 719468
    }

    /// 自 1970-01-01 的天数 → "yyyy-MM-dd"
    static func civilFromDays(_ z0: Int) -> DayKey {
        let z = z0 + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097                                // [0, 146096]
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)         // [0, 365]
        let mp = (5 * doy + 2) / 153                              // [0, 11]
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp + (mp < 10 ? 3 : -9)
        let yr = m <= 2 ? y + 1 : y
        return DayKey(String(format: "%04d-%02d-%02d", yr, m, d))
    }

    /// day + n 天
    public static func addDays(_ day: DayKey, _ n: Int) -> DayKey {
        civilFromDays(daysFromCivil(day) + n)
    }

    /// b - a 的天数差
    static func daysBetween(_ a: DayKey, _ b: DayKey) -> Int {
        daysFromCivil(b) - daysFromCivil(a)
    }

    /// 0=Sunday ... 6=Saturday（1970-01-01 是周四）
    public static func weekday(_ day: DayKey) -> Int {
        let z = daysFromCivil(day)
        return ((z + 4) % 7 + 7) % 7
    }

    /// 所在周（周一起算）的周一
    public static func weekStart(_ day: DayKey) -> DayKey {
        let offset = (weekday(day) + 6) % 7 // 距离周一的天数
        return addDays(day, -offset)
    }

    // MARK: daily

    /// 计算 daily 习惯的 streak 状态。
    /// - Parameters:
    ///   - checkins: 全部打卡（含补签），调用方保证 (habitId, day) 唯一
    ///   - createdDay: 习惯创建日
    ///   - today: 本地"今天"
    public static func daily(checkins: [CheckinInput], createdDay: DayKey, today: DayKey) -> StreakState {
        let doneDays = Set(checkins.map { $0.day })
        var segments: [StreakSegmentValue] = []
        var best = 0
        var runLength = 0       // 当前未封存段的完成天数
        var runStart: DayKey? = nil
        var lastDone: DayKey? = nil
        var consecutiveMisses = 0 // 自上次打卡以来的连续断签天数（0 或 1 时 streak 存活）

        func sealSegment(end: DayKey) {
            guard let s = runStart, runLength > 0 else { return }
            segments.append(StreakSegmentValue(startDay: s, endDay: end, length: runLength))
            best = max(best, runLength)
            runLength = 0
            runStart = nil
        }

        var day = createdDay
        while day <= today {
            if doneDays.contains(day) {
                if runStart == nil { runStart = day }
                runLength += 1
                consecutiveMisses = 0
                lastDone = day
            } else {
                consecutiveMisses += 1
                if consecutiveMisses >= 2 {
                    sealSegment(end: lastDone ?? day)
                }
            }
            day = addDays(day, 1)
        }

        let current = runLength
        best = max(best, runLength)

        let todayState: DayState
        if doneDays.contains(today) {
            todayState = .done
        } else if consecutiveMisses == 1 && runStart != nil {
            todayState = .dimmed // 断签第 1 天，streak 仍活
        } else if today == createdDay && runStart == nil {
            todayState = .dimmed // 创建当天还没打卡
        } else {
            todayState = .missed
        }

        return StreakState(current: current, best: best, segments: segments, todayState: todayState)
    }

    // MARK: quit（戒断型，daily-only）

    /// 计算 quit 型习惯的 streak 状态。语义与 daily 对称（never-slip-twice）：
    /// 默认每天都是完成天；破戒 1 天 = 暗格（streak 不清零）；连续破戒 2 天才封存段。
    /// current 单位 = 当前段内无破戒天数（与 daily 的"段内完成天数"对称）。
    public static func quitDaily(slips: [CheckinInput], createdDay: DayKey, today: DayKey) -> StreakState {
        let slipDays = Set(slips.map { $0.day })
        var done: [CheckinInput] = []
        var day = createdDay
        while day <= today {
            if !slipDays.contains(day) { done.append(CheckinInput(day: day)) }
            day = addDays(day, 1)
        }
        return daily(checkins: done, createdDay: createdDay, today: today)
    }

    /// 热力图单格状态（quit 型）：非破戒天 = done；孤立破戒天 = dimmed（streak 跨过）；
    /// 与另一破戒天相邻的破戒天 = missed（该段已断）。
    public static func quitDayState(day: DayKey, slips: Set<DayKey>, createdDay: DayKey, today: DayKey) -> DayState {
        if day > today { return .future }
        if day < createdDay { return .beforeStart }
        if !slips.contains(day) { return .done }
        if !slips.contains(addDays(day, -1)) || !slips.contains(addDays(day, 1)) {
            return .dimmed
        }
        return .missed
    }

    // MARK: weekly

    /// 计算 timesPerWeek(N) 习惯的 streak 状态（单位：连续达标周数）。
    /// 周按周一起算（与热力图列对齐）。
    public static func weekly(checkins: [CheckinInput], targetPerWeek: Int, createdDay: DayKey, today: DayKey) -> StreakState {
        // 按周聚合完成次数
        var counts: [DayKey: Int] = [:]
        for ci in checkins {
            let ws = weekStart(ci.day)
            counts[ws, default: 0] += 1
        }

        let createdWeek = weekStart(createdDay)
        let todayWeek = weekStart(today)
        let thisWeekDone = counts[todayWeek, default: 0]

        var segments: [StreakSegmentValue] = []
        var best = 0
        var runWeeks = 0
        var runStartWeek: DayKey? = nil
        var lastMetWeek: DayKey? = nil
        var consecutiveMissedWeeks = 0

        func sealSegment() {
            guard let s = runStartWeek, runWeeks > 0, let e = lastMetWeek else { return }
            segments.append(StreakSegmentValue(startDay: s, endDay: e, length: runWeeks))
            best = max(best, runWeeks)
            runWeeks = 0
            runStartWeek = nil
        }

        var week = createdWeek
        while week <= todayWeek {
            let isCurrentWeek = (week == todayWeek)
            let met = counts[week, default: 0] >= targetPerWeek
            if met {
                if runStartWeek == nil { runStartWeek = week }
                runWeeks += 1
                lastMetWeek = week
                consecutiveMissedWeeks = 0
            } else if isCurrentWeek {
                // 当周未结束：未达标不打断（给完整一周时间）
            } else {
                consecutiveMissedWeeks += 1
                if consecutiveMissedWeeks >= 2 {
                    sealSegment()
                }
                // 断 1 周：streak 存活（等价 daily 的暗格）
            }
            week = addDays(week, 7)
        }

        let current = runWeeks
        best = max(best, runWeeks)

        let todayState: DayState = thisWeekDone >= targetPerWeek ? .done : .dimmed
        return StreakState(current: current, best: best, segments: segments, todayState: todayState)
    }

    // MARK: 单日热力图状态

    /// 热力图单格状态（daily 习惯）。
    public static func dayState(day: DayKey, checkins: Set<DayKey>, createdDay: DayKey, today: DayKey) -> DayState {
        if day > today { return .future }
        if day < createdDay { return .beforeStart }
        if checkins.contains(day) { return .done }
        // 断签 1 天暗格：该天前后 streak 未断（即昨天或今天有打卡）
        if checkins.contains(addDays(day, -1)) || checkins.contains(addDays(day, 1)) {
            return .dimmed
        }
        return .missed
    }

    // MARK: 补签合法性

    /// 只允许补签昨天（含），不允许更早。
    public static func canBackfill(day: DayKey, today: DayKey) -> Bool {
        daysBetween(day, today) == 1
    }
}

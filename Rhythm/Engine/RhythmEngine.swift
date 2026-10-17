import Foundation
import SwiftUI

enum RhythmEngine {
    static func buildSnapshot(
        today: DailyRhythmSample,
        week: [DailyRhythmSample],
        now: Date = .now,
        isMockData: Bool
    ) -> RhythmSnapshot {
        let normalizedWeek = normalizedWeekEndingToday(from: week, today: today, now: now)
        let scores = score(today: today, week: normalizedWeek, now: now)
        let phase = phase(for: today, scores: scores, now: now)
        let nextBatch = nextBatchDate(after: now)
        let insights = insights(for: normalizedWeek, today: today)

        return RhythmSnapshot(
            generatedAt: now,
            today: today,
            week: normalizedWeek,
            scores: scores,
            phase: phase,
            nextBreakMinutes: nextBreakMinutes(for: phase, scores: scores),
            nextBatchDate: nextBatch,
            heldNotificationCount: heldNotificationCount(from: today, phase: phase),
            passThroughNotificationCount: phase == .reset ? 1 : 2,
            workingInsights: insights.working,
            pullInsights: insights.pull,
            isMockData: isMockData
        )
    }

    static func score(today: DailyRhythmSample, week: [DailyRhythmSample], now: Date = .now) -> RhythmScores {
        let daylight = clampScore((today.daylightMinutes / 20.0) * 100.0)
        let movement = clampScore((today.exerciseMinutes / 30.0) * 70.0 + (today.steps / 8_000.0) * 30.0)
        let sleep = sleepScore(today.sleepMinutes)
        let hrv = hrvScore(today: today, week: week)
        let recovery = clampScore(Double(hrv) * 0.52 + Double(sleep) * 0.34 + min(today.mindfulMinutes / 10.0, 1.0) * 14.0)
        let appFriction = clampScore(100.0 - max(0, Double(today.pickups - 18)) * 2.4 - max(0, today.appBudgetUsedMinutes - 45) * 1.1)
        let rhythmicity = clampScore(
            Double(daylight) * 0.20
            + Double(hrv) * 0.20
            + Double(movement) * 0.17
            + Double(sleep) * 0.22
            + Double(recovery) * 0.13
            + Double(appFriction) * 0.08
        )

        return RhythmScores(
            rhythmicity: rhythmicity,
            daylight: daylight,
            hrv: hrv,
            movement: movement,
            sleep: sleep,
            recovery: recovery,
            appFriction: appFriction
        )
    }

    static func phase(for today: DailyRhythmSample, scores: RhythmScores, now: Date = .now) -> AutonomicPhase {
        let hour = Calendar.current.component(.hour, from: now)

        if hour < 10, today.daylightMinutes < 8 {
            return .morningAnchor
        }

        if hour >= 20 {
            return .downshift
        }

        if scores.hrv < 45 || today.pickups >= 12 && today.appBudgetUsedMinutes > 25 {
            return .reset
        }

        if hour >= 22 || scores.sleep < 45 {
            return .recovery
        }

        return .focus
    }

    static func scoreForWeekChart(_ sample: DailyRhythmSample, week: [DailyRhythmSample]) -> Double {
        let scores = score(today: sample, week: week)
        return Double(scores.rhythmicity) / 100.0
    }

    static func applying(
        interventions: [RhythmInterventionLog],
        to sample: DailyRhythmSample,
        calendar: Calendar = .current
    ) -> DailyRhythmSample {
        let relevant = interventions.filter { intervention in
            calendar.isDate(intervention.startedAt, inSameDayAs: sample.date)
        }

        return relevant.reduce(sample) { partial, intervention in
            applying(intervention: intervention, to: partial)
        }
    }

    private static func applying(
        intervention: RhythmInterventionLog,
        to sample: DailyRhythmSample
    ) -> DailyRhythmSample {
        var updated = sample
        let minutes = max(intervention.durationMinutes, 0)

        switch intervention.kind {
        case .outdoorWalk:
            updated.daylightMinutes += min(minutes, 45)
            updated.exerciseMinutes += minutes
            updated.steps += minutes * 105
            updated.distanceMeters += minutes * 82
        case .breathingReset:
            updated.mindfulMinutes += max(minutes, 1.5)
            updated.pickups = max(0, updated.pickups - 3)
            updated.appBudgetUsedMinutes = max(0, updated.appBudgetUsedMinutes - 4)
            if let hrv = updated.hrvMS {
                updated.hrvMS = hrv + min(6, minutes * 1.5)
            }
        case .appGate:
            updated.pickups = max(0, updated.pickups - 1)
            updated.appBudgetUsedMinutes = max(0, updated.appBudgetUsedMinutes - min(minutes * 0.4, 8))
        case .downshiftRoutine:
            updated.mindfulMinutes += 2
            updated.appBudgetUsedMinutes = max(0, updated.appBudgetUsedMinutes - 6)
        }

        return updated
    }

    private static func hrvScore(today: DailyRhythmSample, week: [DailyRhythmSample]) -> Int {
        guard let hrv = today.hrvMS else {
            return 50
        }

        let baselineValues = week.compactMap(\.hrvMS)
        let baseline = baselineValues.isEmpty ? hrv : baselineValues.reduce(0, +) / Double(baselineValues.count)
        let absolute = min(hrv / 70.0, 1.0) * 72.0
        let relative = ((hrv - baseline) / max(baseline, 1.0)) * 42.0 + 28.0
        return clampScore(absolute + relative)
    }

    private static func sleepScore(_ minutes: Double) -> Int {
        let target = 450.0
        let diff = abs(minutes - target)
        return clampScore(100.0 - diff / 2.6)
    }

    private static func normalizedWeekEndingToday(from week: [DailyRhythmSample], today: DailyRhythmSample, now: Date) -> [DailyRhythmSample] {
        var values = week.sorted { $0.date < $1.date }
        if values.isEmpty {
            values = MockRhythmData.week
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        values.removeAll { calendar.isDate($0.date, inSameDayAs: todayStart) }
        values.append(today)
        return Array(values.suffix(7))
    }

    private static func nextBreakMinutes(for phase: AutonomicPhase, scores: RhythmScores) -> Int {
        switch phase {
        case .reset:
            0
        case .morningAnchor:
            5
        case .focus:
            scores.recovery > 70 ? 18 : 12
        case .downshift:
            30
        case .recovery:
            45
        }
    }

    private static func nextBatchDate(after now: Date) -> Date {
        let calendar = Calendar.current
        let batchHours = [9, 12, 17, 20]
        for hour in batchHours {
            if let candidate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now), candidate > now {
                return candidate
            }
        }

        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: now) ?? now) ?? now.addingTimeInterval(3_600)
    }

    private static func heldNotificationCount(from today: DailyRhythmSample, phase: AutonomicPhase) -> Int {
        let base = max(8, Int(today.appBudgetUsedMinutes * 0.7))
        return phase == .downshift ? base + 12 : base
    }

    private static func insights(
        for week: [DailyRhythmSample],
        today: DailyRhythmSample
    ) -> (working: [RhythmInsight], pull: [RhythmInsight]) {
        let daylightDays = week.filter { $0.daylightMinutes >= 15 }.count
        let mindfulDays = week.filter { $0.mindfulMinutes >= 3 }.count
        let avgHRV = average(week.compactMap(\.hrvMS))
        let lowSleepDays = week.filter { $0.sleepMinutes < 390 }.count
        let highPickupDays = week.filter { $0.pickups > 35 }.count

        let working = [
            RhythmInsight(
                title: "Morning light",
                body: "Morning light \(daylightDays) of 7 days - daylight score \(score(today: today, week: week).daylight)",
                tint: RhythmColor.bio
            ),
            RhythmInsight(
                title: "Recovery practice",
                body: "Breathing or mindful resets logged \(mindfulDays) of 7 days - average HRV \(Int(avgHRV.rounded())) ms",
                tint: RhythmColor.bio
            )
        ]

        let pull = [
            RhythmInsight(
                title: "Sleep pressure",
                body: lowSleepDays == 0 ? "Sleep stayed inside the target band this week" : "\(lowSleepDays) nights landed below 6h 30m of sleep",
                tint: RhythmColor.warn
            ),
            RhythmInsight(
                title: "Pickup cadence",
                body: highPickupDays == 0 ? "Pickup cadence stayed below the spiral threshold" : "\(highPickupDays) days crossed the pickup threshold",
                tint: RhythmColor.warn
            )
        ]

        return (working, pull)
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func clampScore(_ value: Double) -> Int {
        Int(min(max(value.rounded(), 0), 100))
    }
}

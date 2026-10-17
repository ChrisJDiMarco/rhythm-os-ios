import SwiftUI

enum RhythmScreen: Int, CaseIterable, Identifiable {
    case morning
    case dashboard
    case breathe
    case gate
    case notifications
    case evening
    case weekly

    var id: Int { rawValue }

    var number: String {
        String(format: "%02d", rawValue + 1)
    }

    var title: String {
        switch self {
        case .morning:
            "Morning Light"
        case .dashboard:
            "Rhythm Dashboard"
        case .breathe:
            "HRV Reset"
        case .gate:
            "App Gate"
        case .notifications:
            "Notification Batch"
        case .evening:
            "Evening Downshift"
        case .weekly:
            "Weekly Report"
        }
    }

    var tabTitle: String {
        switch self {
        case .morning:
            "Light"
        case .dashboard:
            "Today"
        case .breathe:
            "Reset"
        case .gate:
            "Apps"
        case .notifications:
            "Alerts"
        case .evening:
            "Night"
        case .weekly:
            "Week"
        }
    }

    var tabSymbol: String {
        switch self {
        case .morning:
            "sun.max.fill"
        case .dashboard:
            "circle.hexagongrid.fill"
        case .breathe:
            "wind"
        case .gate:
            "shield.fill"
        case .notifications:
            "bell.badge.fill"
        case .evening:
            "moon.stars.fill"
        case .weekly:
            "chart.bar.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .morning:
            "Anchor circadian rhythm before feeds."
        case .dashboard:
            "A live read of your current autonomic phase."
        case .breathe:
            "Interrupt sympathetic spikes in 90 seconds."
        case .gate:
            "Pause before dopamine loops start."
        case .notifications:
            "Real people pass. Algorithms wait."
        case .evening:
            "Biological sunset prepares recovery."
        case .weekly:
            "Rhythmicity, not raw screen time."
        }
    }
}

struct VitalMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let unit: String
    let delta: String
    let trend: Trend

    enum Trend {
        case good
        case warning
    }
}

struct GateOption: Identifiable {
    let intent: GateIntentKind
    var id: GateIntentKind { intent }
    let title: String
    let meta: String
    let tint: Color
    let symbol: String
}

enum GateIntentKind: String, CaseIterable, Codable, Identifiable, Equatable {
    case message
    case learn
    case decompress
    case avoiding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .message:
            "Message someone"
        case .learn:
            "Learn something"
        case .decompress:
            "Decompress"
        case .avoiding:
            "I'm avoiding something"
        }
    }

    var meta: String {
        switch self {
        case .message:
            "5 min - DMs only"
        case .learn:
            "10 min - saved + educational only"
        case .decompress:
            "10 min - check-in halfway"
        case .avoiding:
            "Suggest a different reset"
        }
    }

    var durationMinutes: Int {
        switch self {
        case .message:
            5
        case .learn, .decompress:
            10
        case .avoiding:
            2
        }
    }

    var tint: Color {
        switch self {
        case .message:
            RhythmColor.bio
        case .learn:
            RhythmColor.evening
        case .decompress:
            RhythmColor.morning
        case .avoiding:
            RhythmColor.danger
        }
    }

    var symbol: String {
        switch self {
        case .message:
            "bubble.left.and.bubble.right.fill"
        case .learn:
            "book.closed.fill"
        case .decompress:
            "leaf.fill"
        case .avoiding:
            "arrow.uturn.backward.circle.fill"
        }
    }

    var appliesShield: Bool {
        self != .message
    }
}

struct GateSession: Codable, Equatable {
    var intent: GateIntentKind
    var startedAt: Date
    var endsAt: Date

    func isActive(at date: Date = .now) -> Bool {
        date < endsAt
    }
}

enum RhythmInterventionKind: String, Codable, Equatable {
    case outdoorWalk
    case breathingReset
    case appGate
    case downshiftRoutine
}

struct RhythmInterventionLog: Identifiable, Codable, Equatable {
    var id: UUID
    var kind: RhythmInterventionKind
    var startedAt: Date
    var endedAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        kind: RhythmInterventionKind,
        startedAt: Date,
        endedAt: Date,
        note: String
    ) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
    }

    var durationMinutes: Double {
        max(endedAt.timeIntervalSince(startedAt) / 60.0, 0)
    }
}

struct NotificationItem: Identifiable {
    let id = UUID()
    let sender: String
    let preview: String
    let status: String
    let isPassThrough: Bool
}

struct RoutineItem: Identifiable {
    let id = UUID()
    let label: String
    let time: String?
    var isDone: Bool
}

enum HealthPermissionStatus: Equatable {
    case unavailable
    case notRequested
    case requesting
    case authorized
    case denied
    case failed(String)

    var label: String {
        switch self {
        case .unavailable:
            "Health unavailable"
        case .notRequested:
            "Connect Apple Health"
        case .requesting:
            "Requesting Health access"
        case .authorized:
            "Apple Health connected"
        case .denied:
            "Health access limited"
        case .failed:
            "Health connection issue"
        }
    }

    var isUsable: Bool {
        if case .authorized = self { true } else { false }
    }
}

enum AppGatePermissionStatus: Equatable {
    case unavailable
    case notRequested
    case requesting
    case authorized
    case denied
    case failed(String)

    var label: String {
        switch self {
        case .unavailable:
            "App gate unavailable"
        case .notRequested:
            "Set up App Gate"
        case .requesting:
            "Requesting Screen Time"
        case .authorized:
            "App Gate active"
        case .denied:
            "Screen Time denied"
        case .failed:
            "App Gate fallback"
        }
    }
}

enum AutonomicPhase: String, Equatable {
    case morningAnchor = "Morning anchor"
    case focus = "Focus phase"
    case reset = "Reset needed"
    case downshift = "Downshift"
    case recovery = "Recovery"

    var detail: String {
        switch self {
        case .morningAnchor:
            "Get outside before high-stimulus apps."
        case .focus:
            "Sympathetic activation is in range."
        case .reset:
            "A 90-second reset will settle the loop."
        case .downshift:
            "Reduce light, alerts, and novelty."
        case .recovery:
            "Protect sleep pressure and recovery."
        }
    }
}

struct DailyRhythmSample: Identifiable, Equatable {
    let id = UUID()
    var date: Date
    var hrvMS: Double?
    var restingHeartRate: Double?
    var averageHeartRate: Double?
    var steps: Double
    var distanceMeters: Double
    var exerciseMinutes: Double
    var daylightMinutes: Double
    var mindfulMinutes: Double
    var sleepMinutes: Double
    var pickups: Int
    var appBudgetUsedMinutes: Double

    static func empty(date: Date = .now) -> DailyRhythmSample {
        DailyRhythmSample(
            date: date,
            hrvMS: nil,
            restingHeartRate: nil,
            averageHeartRate: nil,
            steps: 0,
            distanceMeters: 0,
            exerciseMinutes: 0,
            daylightMinutes: 0,
            mindfulMinutes: 0,
            sleepMinutes: 0,
            pickups: 0,
            appBudgetUsedMinutes: 0
        )
    }
}

struct RhythmScores: Equatable {
    var rhythmicity: Int
    var daylight: Int
    var hrv: Int
    var movement: Int
    var sleep: Int
    var recovery: Int
    var appFriction: Int
}

struct RhythmInsight: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var body: String
    var tint: Color
}

struct RhythmSnapshot: Equatable {
    var generatedAt: Date
    var today: DailyRhythmSample
    var week: [DailyRhythmSample]
    var scores: RhythmScores
    var phase: AutonomicPhase
    var nextBreakMinutes: Int
    var nextBatchDate: Date
    var heldNotificationCount: Int
    var passThroughNotificationCount: Int
    var workingInsights: [RhythmInsight]
    var pullInsights: [RhythmInsight]
    var isMockData: Bool

    static let mock = RhythmSnapshot(
        generatedAt: .now,
        today: DailyRhythmSample(
            date: .now,
            hrvMS: 62,
            restingHeartRate: 58,
            averageHeartRate: 73,
            steps: 4_850,
            distanceMeters: 3_420,
            exerciseMinutes: 18,
            daylightMinutes: 24,
            mindfulMinutes: 7,
            sleepMinutes: 438,
            pickups: 14,
            appBudgetUsedMinutes: 23
        ),
        week: MockRhythmData.week,
        scores: RhythmScores(rhythmicity: 78, daylight: 88, hrv: 76, movement: 61, sleep: 72, recovery: 74, appFriction: 84),
        phase: .focus,
        nextBreakMinutes: 18,
        nextBatchDate: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now) ?? .now.addingTimeInterval(1_800),
        heldNotificationCount: 24,
        passThroughNotificationCount: 2,
        workingInsights: [
            RhythmInsight(title: "Morning light", body: "Morning light 6 of 7 days - sleep onset moved earlier by 22 min", tint: RhythmColor.bio),
            RhythmInsight(title: "HRV baseline", body: "HRV baseline up 4 ms - breathing breaks taken on schedule", tint: RhythmColor.bio)
        ],
        pullInsights: [
            RhythmInsight(title: "Late screens", body: "Late-night screen use Wed + Thu pushed sleep past midnight", tint: RhythmColor.warn),
            RhythmInsight(title: "Missed resets", body: "Skipped two breathing breaks Tuesday during a client call", tint: RhythmColor.warn)
        ],
        isMockData: true
    )
}

enum MockRhythmData {
    static var week: [DailyRhythmSample] {
        let calendar = Calendar.current
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: .now)) else {
                return nil
            }

            let daylight = [11, 19, 15, 8, 22, 27, 24][offset]
            let sleep = [390, 428, 412, 365, 452, 471, 438][offset]
            let hrv = [52, 58, 55, 47, 60, 64, 62][offset]
            let steps = [4_200, 5_800, 5_100, 3_200, 7_800, 9_400, 4_850][offset]
            let mindful = [2, 8, 5, 0, 7, 10, 7][offset]
            let pickups = [36, 24, 29, 42, 18, 13, 14][offset]

            return DailyRhythmSample(
                date: date,
                hrvMS: Double(hrv),
                restingHeartRate: Double([62, 60, 61, 66, 59, 57, 58][offset]),
                averageHeartRate: Double([76, 72, 74, 80, 71, 70, 73][offset]),
                steps: Double(steps),
                distanceMeters: Double(steps) * 0.72,
                exerciseMinutes: Double([12, 22, 18, 8, 34, 38, 18][offset]),
                daylightMinutes: Double(daylight),
                mindfulMinutes: Double(mindful),
                sleepMinutes: Double(sleep),
                pickups: pickups,
                appBudgetUsedMinutes: Double([54, 41, 48, 61, 31, 26, 23][offset])
            )
        }
    }
}

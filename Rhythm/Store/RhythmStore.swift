import Combine
import Foundation
import SwiftUI
import UIKit

enum RhythmRefreshReason: Equatable {
    case launch
    case foreground
    case manual
    case authorization
    case mockModeChanged
    case intervention
    case healthBackground(String)

    var label: String {
        switch self {
        case .launch:
            "Launch sync"
        case .foreground:
            "Open sync"
        case .manual:
            "Manual sync"
        case .authorization:
            "Health sync"
        case .mockModeChanged:
            "Mode sync"
        case .intervention:
            "Intervention sync"
        case let .healthBackground(identifier):
            identifier
                .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
                .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
        }
    }
}

@MainActor
final class RhythmStore: ObservableObject {
    @Published private(set) var snapshot = RhythmSnapshot.mock
    @Published private(set) var healthStatus: HealthPermissionStatus = .notRequested
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshCompletedAt: Date?
    @Published private(set) var lastHealthObserverPingAt: Date?
    @Published private(set) var lastRefreshReason: RhythmRefreshReason = .launch
    @Published private(set) var backgroundDeliveryStatus = "Health observers idle"
    @Published var useMockData: Bool {
        didSet {
            UserDefaults.standard.set(useMockData, forKey: Keys.useMockData)
            startHealthObserversIfPossible()
            Task { await refresh(reason: .mockModeChanged) }
        }
    }
    @Published var routineItems: [RoutineItem] {
        didSet { persistRoutine() }
    }
    @Published private(set) var notificationAuthorizationGranted = false
    @Published private(set) var activeOutdoorStart: Date?
    @Published private(set) var activeBreathingStart: Date?
    @Published private(set) var activeGateSession: GateSession?
    @Published private(set) var interventionLog: [RhythmInterventionLog]
    @Published private(set) var lastError: String?

    let appShield = AppShieldService()

    private let healthKit = HealthKitService()
    private let notifications = NotificationScheduler()

    private enum Keys {
        static let useMockData = "rhythm.useMockData"
        static let routine = "rhythm.routineItems"
        static let hasBootstrapped = "rhythm.hasBootstrapped"
        static let activeOutdoorStart = "rhythm.activeOutdoorStart"
        static let activeBreathingStart = "rhythm.activeBreathingStart"
        static let activeGateSession = "rhythm.activeGateSession"
        static let interventionLog = "rhythm.interventionLog"
        static let rhythmCache = "rhythm.rhythmCache"
        static let lastRefreshCompletedAt = "rhythm.lastRefreshCompletedAt"
        static let lastHealthObserverPingAt = "rhythm.lastHealthObserverPingAt"
    }

    init() {
        let storedMockPreference = UserDefaults.standard.object(forKey: Keys.useMockData) as? Bool
        useMockData = storedMockPreference ?? !healthKit.isAvailable
        routineItems = Self.loadRoutine()
        interventionLog = Self.loadInterventionLog()
        if let cached = Self.loadRhythmCache() {
            snapshot = RhythmEngine.buildSnapshot(
                today: cached.today.sample,
                week: cached.week.map(\.sample),
                isMockData: cached.isMockData
            )
        }
        activeOutdoorStart = UserDefaults.standard.object(forKey: Keys.activeOutdoorStart) as? Date
        activeBreathingStart = UserDefaults.standard.object(forKey: Keys.activeBreathingStart) as? Date
        activeGateSession = Self.loadGateSession()
        lastRefreshCompletedAt = UserDefaults.standard.object(forKey: Keys.lastRefreshCompletedAt) as? Date
        lastHealthObserverPingAt = UserDefaults.standard.object(forKey: Keys.lastHealthObserverPingAt) as? Date
        healthStatus = healthKit.authorizationStatus
        pruneExpiredGateSession()
    }

    var rhythmConfidence: Double {
        let sourceWeight = snapshot.isMockData ? 0.56 : 1.0
        let ageSeconds = lastRefreshCompletedAt.map { Date().timeIntervalSince($0) } ?? 3_600
        let freshness = max(0.18, min(1.0, 1.0 - ageSeconds / 900.0))
        let completeness = dataCompleteness
        return min(1.0, max(0.18, sourceWeight * (0.45 + freshness * 0.32 + completeness * 0.23)))
    }

    var freshnessLabel: String {
        if isRefreshing {
            return "Syncing now"
        }

        guard let lastRefreshCompletedAt else {
            return "Awaiting first sync"
        }

        let seconds = max(0, Int(Date().timeIntervalSince(lastRefreshCompletedAt)))
        switch seconds {
        case 0..<20:
            return "Synced just now"
        case 20..<60:
            return "Synced \(seconds)s ago"
        case 60..<3_600:
            return "Synced \(seconds / 60)m ago"
        default:
            return "Synced \(seconds / 3_600)h ago"
        }
    }

    func bootstrap() async {
        pruneExpiredGateSession()

        guard !UserDefaults.standard.bool(forKey: Keys.hasBootstrapped) else {
            notificationAuthorizationGranted = await notifications.authorizationGranted()
            startHealthObserversIfPossible()
            await refresh(reason: .launch)
            return
        }

        UserDefaults.standard.set(true, forKey: Keys.hasBootstrapped)
        notificationAuthorizationGranted = await notifications.authorizationGranted()
        if notificationAuthorizationGranted {
            await notifications.scheduleMorningAnchor()
            await notifications.scheduleDownshift()
        }
        startHealthObserversIfPossible()
        await refresh(reason: .launch)
    }

    func appDidBecomeActive() async {
        pruneExpiredGateSession()
        healthStatus = healthKit.authorizationStatus
        startHealthObserversIfPossible()

        if shouldRefreshOnForeground {
            await refresh(reason: .foreground)
        } else {
            reconcileCurrentSnapshot(reason: .foreground)
        }
    }

    func requestHealthAuthorization() async {
        healthStatus = .requesting
        do {
            healthStatus = try await healthKit.requestAuthorization()
            startHealthObserversIfPossible()
            useMockData = !healthStatus.isUsable
            await refresh(reason: .authorization)
        } catch {
            healthStatus = .failed(error.localizedDescription)
            lastError = error.localizedDescription
            useMockData = true
        }
    }

    func requestNotificationAuthorization() async {
        notificationAuthorizationGranted = await notifications.requestAuthorization()
        if notificationAuthorizationGranted {
            await notifications.scheduleMorningAnchor()
            await notifications.scheduleDownshift()
        }
    }

    func scheduleNextNotificationBatch() async {
        if !notificationAuthorizationGranted {
            await requestNotificationAuthorization()
        }

        guard notificationAuthorizationGranted else { return }
        await notifications.scheduleBatchDelivery(
            at: snapshot.nextBatchDate,
            heldCount: snapshot.heldNotificationCount
        )
        successHaptic()
    }

    func refresh(reason: RhythmRefreshReason = .manual) async {
        guard !isRefreshing else { return }

        lastRefreshReason = reason
        isRefreshing = true
        defer { isRefreshing = false }

        appShield.refreshStatus()
        healthStatus = healthKit.authorizationStatus
        pruneExpiredGateSession()

        guard !useMockData, healthKit.isAvailable, healthStatus.isUsable else {
            commitSnapshot(
                RhythmEngine.buildSnapshot(
                today: RhythmEngine.applying(interventions: interventionLog, to: RhythmSnapshot.mock.today),
                week: MockRhythmData.week.map { RhythmEngine.applying(interventions: interventionLog, to: $0) },
                isMockData: true
                ),
                reason: reason
            )
            return
        }

        do {
            async let today = healthKit.fetchToday()
            async let week = healthKit.fetchWeek()
            let liveToday = try await today
            let liveWeek = try await week
            let nextSnapshot = RhythmEngine.buildSnapshot(
                today: RhythmEngine.applying(interventions: interventionLog, to: liveToday),
                week: liveWeek.map { RhythmEngine.applying(interventions: interventionLog, to: $0) },
                isMockData: false
            )
            lastError = nil
            commitSnapshot(nextSnapshot, reason: reason)
        } catch {
            lastError = error.localizedDescription
            commitSnapshot(
                RhythmEngine.buildSnapshot(
                today: RhythmEngine.applying(interventions: interventionLog, to: RhythmSnapshot.mock.today),
                week: MockRhythmData.week.map { RhythmEngine.applying(interventions: interventionLog, to: $0) },
                isMockData: true
                ),
                reason: reason
            )
        }
    }

    func startOutdoorSession() {
        activeOutdoorStart = .now
        UserDefaults.standard.set(activeOutdoorStart, forKey: Keys.activeOutdoorStart)
        lightHaptic()
    }

    func finishOutdoorSession() async {
        guard let start = activeOutdoorStart else { return }
        let end = max(Date(), start.addingTimeInterval(60))
        activeOutdoorStart = nil
        UserDefaults.standard.removeObject(forKey: Keys.activeOutdoorStart)
        appendIntervention(.outdoorWalk, startedAt: start, endedAt: end, note: "Morning light walk")

        guard healthStatus.isUsable, !useMockData else {
            await refresh(reason: .intervention)
            return
        }

        do {
            try await healthKit.saveOutdoorWalkSession(start: start, end: end)
            successHaptic()
            await refresh(reason: .intervention)
        } catch {
            lastError = error.localizedDescription
            warningHaptic()
        }
    }

    func startBreathingReset() {
        activeBreathingStart = .now
        UserDefaults.standard.set(activeBreathingStart, forKey: Keys.activeBreathingStart)
        lightHaptic()
        Task { await notifications.scheduleBreathingReminder() }
    }

    func completeBreathingReset() async {
        guard let start = activeBreathingStart else { return }
        let end = max(Date(), start.addingTimeInterval(90))
        activeBreathingStart = nil
        UserDefaults.standard.removeObject(forKey: Keys.activeBreathingStart)
        appendIntervention(.breathingReset, startedAt: start, endedAt: end, note: "90-second HRV reset")

        guard healthStatus.isUsable, !useMockData else {
            successHaptic()
            await refresh(reason: .intervention)
            return
        }

        do {
            try await healthKit.saveMindfulSession(start: start, end: end)
            successHaptic()
            await refresh(reason: .intervention)
        } catch {
            lastError = error.localizedDescription
            warningHaptic()
        }
    }

    func toggleRoutine(_ itemID: RoutineItem.ID) {
        guard let index = routineItems.firstIndex(where: { $0.id == itemID }) else { return }
        routineItems[index].isDone.toggle()
        if routineItems[index].isDone {
            appendIntervention(.downshiftRoutine, startedAt: .now, endedAt: Date().addingTimeInterval(60), note: routineItems[index].label)
        }
        lightHaptic()
    }

    func resetRoutine() {
        routineItems = Self.defaultRoutine
    }

    func activateGateIntent(_ intent: GateIntentKind) {
        let start = Date()
        let end = start.addingTimeInterval(TimeInterval(intent.durationMinutes * 60))
        activeGateSession = GateSession(intent: intent, startedAt: start, endsAt: end)
        persistGateSession()
        appendIntervention(.appGate, startedAt: start, endedAt: end, note: intent.title)

        if intent.appliesShield {
            applyAppGateShield()
        } else {
            lightHaptic()
        }

        Task {
            await notifications.scheduleGateCheckIn(intent: intent)
            await refresh(reason: .intervention)
        }
    }

    func clearGateSession() {
        activeGateSession = nil
        UserDefaults.standard.removeObject(forKey: Keys.activeGateSession)
        notifications.cancelGateCheckIn()
        lightHaptic()
        Task { await refresh(reason: .intervention) }
    }

    func applyAppGateShield() {
        appShield.applyShield()
        lightHaptic()
    }

    func clearAppGateShield() {
        appShield.clearShield()
        lightHaptic()
    }

    func refreshMockScenario(_ phase: AutonomicPhase) {
        var today = RhythmSnapshot.mock.today
        switch phase {
        case .morningAnchor:
            today.daylightMinutes = 2
            today.pickups = 6
        case .focus:
            today.daylightMinutes = 24
            today.hrvMS = 62
            today.pickups = 14
        case .reset:
            today.hrvMS = 34
            today.pickups = 31
            today.appBudgetUsedMinutes = 48
        case .downshift:
            today.daylightMinutes = 19
            today.mindfulMinutes = 6
        case .recovery:
            today.sleepMinutes = 320
            today.hrvMS = 42
        }

        snapshot = RhythmEngine.buildSnapshot(today: today, week: MockRhythmData.week, isMockData: true)
    }

    private func startHealthObserversIfPossible() {
        guard healthStatus.isUsable, !useMockData else {
            healthKit.stopObservers()
            backgroundDeliveryStatus = healthStatus.isUsable ? "Health observers paused" : healthStatus.label
            return
        }

        healthKit.startObservers { [weak self] identifier in
            Task { @MainActor in
                self?.lastHealthObserverPingAt = .now
                if let lastHealthObserverPingAt = self?.lastHealthObserverPingAt {
                    UserDefaults.standard.set(lastHealthObserverPingAt, forKey: Keys.lastHealthObserverPingAt)
                }
                await self?.refresh(reason: .healthBackground(identifier))
            }
        } onDeliveryRegistration: { [weak self] identifier, success, message in
            Task { @MainActor in
                if success {
                    self?.backgroundDeliveryStatus = "Listening for \(Self.shortHealthIdentifier(identifier))"
                } else {
                    self?.backgroundDeliveryStatus = message ?? "Health background delivery unavailable"
                }
            }
        }
    }

    private var shouldRefreshOnForeground: Bool {
        guard !isRefreshing else { return false }

        if let lastHealthObserverPingAt,
           let lastRefreshCompletedAt,
           lastHealthObserverPingAt > lastRefreshCompletedAt {
            return true
        }

        guard let lastRefreshCompletedAt else { return true }

        if !Calendar.current.isDate(lastRefreshCompletedAt, inSameDayAs: Date()) {
            return true
        }

        let staleAfter: TimeInterval = snapshot.isMockData ? 45 : 90
        return Date().timeIntervalSince(lastRefreshCompletedAt) > staleAfter
    }

    private var dataCompleteness: Double {
        let signals = [
            snapshot.today.hrvMS != nil,
            snapshot.today.restingHeartRate != nil || snapshot.today.averageHeartRate != nil,
            snapshot.today.sleepMinutes > 0,
            snapshot.today.daylightMinutes > 0,
            snapshot.today.steps > 0,
            snapshot.today.mindfulMinutes > 0
        ]
        let present = signals.filter { $0 }.count
        return Double(present) / Double(signals.count)
    }

    private func reconcileCurrentSnapshot(reason: RhythmRefreshReason) {
        let nextSnapshot = RhythmEngine.buildSnapshot(
            today: snapshot.today,
            week: snapshot.week,
            isMockData: snapshot.isMockData
        )
        commitSnapshot(nextSnapshot, reason: reason, updatesLastRefreshDate: false)
    }

    private func commitSnapshot(
        _ nextSnapshot: RhythmSnapshot,
        reason: RhythmRefreshReason,
        updatesLastRefreshDate: Bool = true
    ) {
        snapshot = nextSnapshot
        lastRefreshReason = reason
        if updatesLastRefreshDate {
            lastRefreshCompletedAt = nextSnapshot.generatedAt
            UserDefaults.standard.set(lastRefreshCompletedAt, forKey: Keys.lastRefreshCompletedAt)
        }
        persistRhythmCache(nextSnapshot)
    }

    private func persistRhythmCache(_ snapshot: RhythmSnapshot) {
        let cache = PersistedRhythmCache(snapshot: snapshot)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: Keys.rhythmCache)
    }

    private static func loadRhythmCache() -> PersistedRhythmCache? {
        guard let data = UserDefaults.standard.data(forKey: Keys.rhythmCache) else {
            return nil
        }

        return try? JSONDecoder().decode(PersistedRhythmCache.self, from: data)
    }

    private static func shortHealthIdentifier(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKCategoryTypeIdentifier", with: "")
            .replacingOccurrences(of: "HKWorkoutTypeIdentifier", with: "Workout")
    }

    private func appendIntervention(
        _ kind: RhythmInterventionKind,
        startedAt: Date,
        endedAt: Date,
        note: String
    ) {
        let entry = RhythmInterventionLog(
            kind: kind,
            startedAt: startedAt,
            endedAt: endedAt,
            note: note
        )
        interventionLog.append(entry)
        pruneInterventionLog()
        persistInterventionLog()
    }

    private func pruneInterventionLog() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        interventionLog = Array(interventionLog.filter { $0.endedAt >= cutoff }.suffix(80))
    }

    private func persistInterventionLog() {
        guard let data = try? JSONEncoder().encode(interventionLog) else { return }
        UserDefaults.standard.set(data, forKey: Keys.interventionLog)
    }

    private static func loadInterventionLog() -> [RhythmInterventionLog] {
        guard let data = UserDefaults.standard.data(forKey: Keys.interventionLog),
              let decoded = try? JSONDecoder().decode([RhythmInterventionLog].self, from: data) else {
            return []
        }

        return decoded
    }

    private func persistGateSession() {
        guard let activeGateSession,
              let data = try? JSONEncoder().encode(activeGateSession) else {
            UserDefaults.standard.removeObject(forKey: Keys.activeGateSession)
            return
        }

        UserDefaults.standard.set(data, forKey: Keys.activeGateSession)
    }

    private static func loadGateSession() -> GateSession? {
        guard let data = UserDefaults.standard.data(forKey: Keys.activeGateSession) else {
            return nil
        }

        return try? JSONDecoder().decode(GateSession.self, from: data)
    }

    private func pruneExpiredGateSession() {
        guard let session = activeGateSession, !session.isActive() else { return }
        activeGateSession = nil
        UserDefaults.standard.removeObject(forKey: Keys.activeGateSession)
        notifications.cancelGateCheckIn()
    }

    private func persistRoutine() {
        let codableItems = routineItems.map { PersistedRoutineItem(item: $0) }
        guard let data = try? JSONEncoder().encode(codableItems) else { return }
        UserDefaults.standard.set(data, forKey: Keys.routine)
    }

    private static func loadRoutine() -> [RoutineItem] {
        guard let data = UserDefaults.standard.data(forKey: Keys.routine),
              let decoded = try? JSONDecoder().decode([PersistedRoutineItem].self, from: data) else {
            return defaultRoutine
        }

        return decoded.map { RoutineItem(label: $0.label, time: $0.time, isDone: $0.isDone) }
    }

    private static let defaultRoutine = [
        RoutineItem(label: "Dim lights - home set to warm 2200K", time: nil, isDone: true),
        RoutineItem(label: "Stretch - 5 min", time: nil, isDone: true),
        RoutineItem(label: "Warm shower", time: "9:30", isDone: false),
        RoutineItem(label: "Read - 20 min", time: "10:00", isDone: false),
        RoutineItem(label: "Lights out", time: "11:00", isDone: false)
    ]

    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func successHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func warningHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

private struct PersistedRoutineItem: Codable {
    var label: String
    var time: String?
    var isDone: Bool

    init(item: RoutineItem) {
        label = item.label
        time = item.time
        isDone = item.isDone
    }
}

private struct PersistedRhythmCache: Codable {
    var generatedAt: Date
    var today: PersistedDailyRhythmSample
    var week: [PersistedDailyRhythmSample]
    var isMockData: Bool

    init(snapshot: RhythmSnapshot) {
        generatedAt = snapshot.generatedAt
        today = PersistedDailyRhythmSample(sample: snapshot.today)
        week = snapshot.week.map(PersistedDailyRhythmSample.init(sample:))
        isMockData = snapshot.isMockData
    }
}

private struct PersistedDailyRhythmSample: Codable {
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

    init(sample: DailyRhythmSample) {
        date = sample.date
        hrvMS = sample.hrvMS
        restingHeartRate = sample.restingHeartRate
        averageHeartRate = sample.averageHeartRate
        steps = sample.steps
        distanceMeters = sample.distanceMeters
        exerciseMinutes = sample.exerciseMinutes
        daylightMinutes = sample.daylightMinutes
        mindfulMinutes = sample.mindfulMinutes
        sleepMinutes = sample.sleepMinutes
        pickups = sample.pickups
        appBudgetUsedMinutes = sample.appBudgetUsedMinutes
    }

    var sample: DailyRhythmSample {
        DailyRhythmSample(
            date: date,
            hrvMS: hrvMS,
            restingHeartRate: restingHeartRate,
            averageHeartRate: averageHeartRate,
            steps: steps,
            distanceMeters: distanceMeters,
            exerciseMinutes: exerciseMinutes,
            daylightMinutes: daylightMinutes,
            mindfulMinutes: mindfulMinutes,
            sleepMinutes: sleepMinutes,
            pickups: pickups,
            appBudgetUsedMinutes: appBudgetUsedMinutes
        )
    }
}

import Foundation
import HealthKit

enum HealthKitServiceError: LocalizedError {
    case healthDataUnavailable
    case missingType(String)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            "Apple Health data is not available on this device."
        case let .missingType(type):
            "HealthKit type unavailable: \(type)"
        }
    }
}

final class HealthKitService {
    private let store = HKHealthStore()
    private let calendar = Calendar.current
    private var observerQueries: [HKObserverQuery] = []

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var authorizationStatus: HealthPermissionStatus {
        guard isAvailable else { return .unavailable }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return .failed("Mindful session type unavailable")
        }

        switch store.authorizationStatus(for: mindfulType) {
        case .notDetermined:
            return .notRequested
        case .sharingAuthorized:
            return .authorized
        case .sharingDenied:
            return .denied
        @unknown default:
            return .failed("Unknown HealthKit authorization state")
        }
    }

    func requestAuthorization() async throws -> HealthPermissionStatus {
        guard isAvailable else { throw HealthKitServiceError.healthDataUnavailable }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: shareTypes(), read: readTypes()) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return authorizationStatus
    }

    func fetchToday() async throws -> DailyRhythmSample {
        let start = calendar.startOfDay(for: .now)
        let end = Date()
        return try await fetchSample(from: start, to: end)
    }

    func fetchWeek() async throws -> [DailyRhythmSample] {
        let todayStart = calendar.startOfDay(for: .now)
        var samples: [DailyRhythmSample] = []

        for offset in 0..<7 {
            let start = calendar.date(byAdding: .day, value: offset - 6, to: todayStart) ?? todayStart
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
            samples.append(try await fetchSample(from: start, to: min(end, Date())))
        }

        return samples
    }

    func startObservers(onChange: @escaping @Sendable () -> Void) {
        guard isAvailable, observerQueries.isEmpty else { return }

        let sampleTypes = readTypes().compactMap { $0 as? HKSampleType }
        for sampleType in sampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                if error == nil {
                    onChange()
                }
                completionHandler()
            }

            store.execute(query)
            store.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { _, _ in }
            observerQueries.append(query)
        }
    }

    func stopObservers() {
        observerQueries.forEach { store.stop($0) }
        observerQueries.removeAll()
    }

    func saveMindfulSession(start: Date, end: Date) async throws {
        guard isAvailable else { throw HealthKitServiceError.healthDataUnavailable }
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            throw HealthKitServiceError.missingType("mindfulSession")
        }

        let sample = HKCategorySample(
            type: mindfulType,
            value: 0,
            start: start,
            end: end,
            metadata: [
                HKMetadataKeyWasUserEntered: true,
                "RhythmOSIntervention": "BreathingReset"
            ]
        )

        try await save(sample)
    }

    func saveOutdoorWalkSession(start: Date, end: Date) async throws {
        guard isAvailable else { throw HealthKitServiceError.healthDataUnavailable }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: nil)
        try await builder.beginCollection(at: start)
        try await builder.addMetadata([
            HKMetadataKeyWasUserEntered: true,
            "RhythmOSIntervention": "MorningLightAnchor"
        ])
        try await builder.endCollection(at: end)
        _ = try await finishWorkout(builder)
    }

    private func fetchSample(from start: Date, to end: Date) async throws -> DailyRhythmSample {
        async let hrv = averageQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), from: start, to: end)
        async let restingHR = averageQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: end)
        async let averageHR = averageQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: end)
        async let steps = sumQuantity(.stepCount, unit: .count(), from: start, to: end)
        async let distance = sumQuantity(.distanceWalkingRunning, unit: .meter(), from: start, to: end)
        async let exercise = sumQuantity(.appleExerciseTime, unit: .minute(), from: start, to: end)
        async let daylight = sumQuantity(.timeInDaylight, unit: .minute(), from: start, to: end)
        async let mindful = categoryDuration(.mindfulSession, acceptedValues: nil, from: start, to: end)
        async let sleep = categoryDuration(.sleepAnalysis, acceptedValues: asleepValues, from: start, to: end)

        let hrvValue = try await hrv
        let restingHRValue = try await restingHR
        let averageHRValue = try await averageHR
        let stepsValue = try await steps
        let distanceValue = try await distance
        let exerciseValue = try await exercise
        let daylightValue = try await daylight
        let mindfulValue = try await mindful
        let sleepValue = try await sleep

        return DailyRhythmSample(
            date: start,
            hrvMS: hrvValue,
            restingHeartRate: restingHRValue,
            averageHeartRate: averageHRValue,
            steps: stepsValue,
            distanceMeters: distanceValue,
            exerciseMinutes: exerciseValue,
            daylightMinutes: daylightValue,
            mindfulMinutes: mindfulValue,
            sleepMinutes: sleepValue,
            pickups: estimatedPickups(from: stepsValue, mindful: mindfulValue, date: start),
            appBudgetUsedMinutes: estimatedAppBudget(from: mindfulValue, date: start)
        )
    }

    private var asleepValues: Set<Int> {
        Set([
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])
    }

    private func readTypes() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()

        [
            HKQuantityTypeIdentifier.heartRateVariabilitySDNN,
            .restingHeartRate,
            .heartRate,
            .stepCount,
            .distanceWalkingRunning,
            .appleExerciseTime,
            .timeInDaylight
        ].compactMap { HKObjectType.quantityType(forIdentifier: $0) }
            .forEach { types.insert($0) }

        [
            HKCategoryTypeIdentifier.sleepAnalysis,
            .mindfulSession
        ].compactMap { HKObjectType.categoryType(forIdentifier: $0) }
            .forEach { types.insert($0) }

        types.insert(HKObjectType.workoutType())
        return types
    }

    private func shareTypes() -> Set<HKSampleType> {
        var types = Set<HKSampleType>()

        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }

        types.insert(HKObjectType.workoutType())
        return types
    }

    private func sumQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingType(identifier.rawValue)
        }

        let statistics = try await statistics(for: type, options: .cumulativeSum, from: start, to: end)
        return statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func averageQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingType(identifier.rawValue)
        }

        let statistics = try await statistics(for: type, options: .discreteAverage, from: start, to: end)
        return statistics.averageQuantity()?.doubleValue(for: unit)
    }

    private func statistics(
        for type: HKQuantityType,
        options: HKStatisticsOptions,
        from start: Date,
        to end: Date
    ) async throws -> HKStatistics {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let statistics {
                    continuation.resume(returning: statistics)
                } else {
                    continuation.resume(throwing: HealthKitServiceError.missingType(type.identifier))
                }
            }

            store.execute(query)
        }
    }

    private func categoryDuration(
        _ identifier: HKCategoryTypeIdentifier,
        acceptedValues: Set<Int>?,
        from start: Date,
        to end: Date
    ) async throws -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: identifier) else {
            throw HealthKitServiceError.missingType(identifier.rawValue)
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }

            store.execute(query)
        }

        let filtered = samples.filter { sample in
            if let acceptedValues {
                acceptedValues.contains(sample.value)
            } else {
                true
            }
        }

        let seconds = filtered.reduce(0.0) { partial, sample in
            partial + sample.endDate.timeIntervalSince(sample.startDate)
        }

        return seconds / 60.0
    }

    private func save(_ sample: HKSample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func finishWorkout(_ builder: HKWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: HealthKitServiceError.missingType("finishedWorkout"))
                }
            }
        }
    }

    private func estimatedPickups(from steps: Double, mindful: Double, date: Date) -> Int {
        // iOS does not expose raw pickup count through public APIs. This keeps
        // the engine functional until Screen Time reports are authorized.
        let hour = calendar.component(.hour, from: date)
        let activityOffset = max(0, 28 - Int(steps / 500))
        let mindfulOffset = mindful >= 5 ? -4 : 2
        return max(8, min(48, 18 + activityOffset + mindfulOffset + hour % 5))
    }

    private func estimatedAppBudget(from mindful: Double, date: Date) -> Double {
        let daySeed = Double(calendar.component(.weekday, from: date))
        return max(18, 54 - mindful * 1.8 + daySeed)
    }
}

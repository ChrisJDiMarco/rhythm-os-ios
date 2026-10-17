import XCTest
@testable import Rhythm

final class RhythmEngineTests: XCTestCase {
    func testFocusPhaseForBalancedDay() {
        let sample = DailyRhythmSample(
            date: date(hour: 11),
            hrvMS: 64,
            restingHeartRate: 58,
            averageHeartRate: 72,
            steps: 5_200,
            distanceMeters: 3_600,
            exerciseMinutes: 22,
            daylightMinutes: 24,
            mindfulMinutes: 6,
            sleepMinutes: 440,
            pickups: 14,
            appBudgetUsedMinutes: 22
        )

        let snapshot = RhythmEngine.buildSnapshot(
            today: sample,
            week: MockRhythmData.week,
            now: date(hour: 11),
            isMockData: true
        )

        XCTAssertEqual(snapshot.phase, .focus)
        XCTAssertGreaterThanOrEqual(snapshot.scores.rhythmicity, 70)
    }

    func testResetPhaseForLowHRVAndHighPickupCadence() {
        var sample = RhythmSnapshot.mock.today
        sample.hrvMS = 32
        sample.pickups = 34
        sample.appBudgetUsedMinutes = 54

        let snapshot = RhythmEngine.buildSnapshot(
            today: sample,
            week: MockRhythmData.week,
            now: date(hour: 15),
            isMockData: true
        )

        XCTAssertEqual(snapshot.phase, .reset)
        XCTAssertEqual(snapshot.nextBreakMinutes, 0)
    }

    func testMorningAnchorWinsBeforeTenWhenDaylightIsLow() {
        var sample = RhythmSnapshot.mock.today
        sample.daylightMinutes = 1
        sample.hrvMS = 58
        sample.pickups = 4
        sample.appBudgetUsedMinutes = 2

        let snapshot = RhythmEngine.buildSnapshot(
            today: sample,
            week: MockRhythmData.week,
            now: date(hour: 7),
            isMockData: true
        )

        XCTAssertEqual(snapshot.phase, .morningAnchor)
        XCTAssertLessThan(snapshot.scores.daylight, 20)
    }

    func testScoresRemainBounded() {
        let extreme = DailyRhythmSample(
            date: date(hour: 12),
            hrvMS: 200,
            restingHeartRate: 40,
            averageHeartRate: 55,
            steps: 60_000,
            distanceMeters: 42_000,
            exerciseMinutes: 480,
            daylightMinutes: 300,
            mindfulMinutes: 120,
            sleepMinutes: 900,
            pickups: 0,
            appBudgetUsedMinutes: 0
        )

        let scores = RhythmEngine.score(today: extreme, week: [extreme], now: date(hour: 12))
        XCTAssertTrue((0...100).contains(scores.rhythmicity))
        XCTAssertTrue((0...100).contains(scores.daylight))
        XCTAssertTrue((0...100).contains(scores.hrv))
        XCTAssertTrue((0...100).contains(scores.movement))
        XCTAssertTrue((0...100).contains(scores.sleep))
        XCTAssertTrue((0...100).contains(scores.recovery))
        XCTAssertTrue((0...100).contains(scores.appFriction))
    }

    func testLocalInterventionsUpdateSample() {
        let start = date(hour: 7)
        var sample = DailyRhythmSample.empty(date: start)
        sample.hrvMS = 48
        sample.pickups = 18
        sample.appBudgetUsedMinutes = 32

        let interventions = [
            RhythmInterventionLog(
                kind: .outdoorWalk,
                startedAt: start,
                endedAt: start.addingTimeInterval(10 * 60),
                note: "Walk"
            ),
            RhythmInterventionLog(
                kind: .breathingReset,
                startedAt: start.addingTimeInterval(60 * 60),
                endedAt: start.addingTimeInterval(60 * 60 + 90),
                note: "Reset"
            )
        ]

        let updated = RhythmEngine.applying(interventions: interventions, to: sample)

        XCTAssertEqual(Int(updated.daylightMinutes.rounded()), 10)
        XCTAssertEqual(Int(updated.exerciseMinutes.rounded()), 10)
        XCTAssertGreaterThan(updated.mindfulMinutes, 1)
        XCTAssertLessThan(updated.pickups, sample.pickups)
        XCTAssertGreaterThan(updated.hrvMS ?? 0, sample.hrvMS ?? 0)
    }

    func testNextBatchRollsToTomorrowAfterLastBatch() {
        let now = date(hour: 21, minute: 30)
        let snapshot = RhythmEngine.buildSnapshot(
            today: RhythmSnapshot.mock.today,
            week: MockRhythmData.week,
            now: now,
            isMockData: true
        )

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDate(snapshot.nextBatchDate, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now))
        XCTAssertEqual(calendar.component(.hour, from: snapshot.nextBatchDate), 9)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

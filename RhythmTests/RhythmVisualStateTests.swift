import XCTest
@testable import Rhythm

final class RhythmVisualStateTests: XCTestCase {
    func testFocusStateIsCoherentAndCalm() {
        let state = RhythmVisualState(
            snapshot: snapshot(phase: .focus, scores: highScores, pickups: 8),
            confidence: 0.95,
            isRefreshing: false
        )

        XCTAssertGreaterThan(state.coherence, 0.75)
        XCTAssertLessThan(state.entropy, 0.35)
        XCTAssertLessThan(state.turbulence, 0.40)
        XCTAssertGreaterThan(state.density, 0.75)
    }

    func testResetStateIsVisiblyAgitated() {
        let state = RhythmVisualState(
            snapshot: snapshot(phase: .reset, scores: lowScores, pickups: 38),
            confidence: 0.72,
            isRefreshing: false
        )

        XCTAssertLessThan(state.coherence, 0.55)
        XCTAssertGreaterThan(state.entropy, 0.70)
        XCTAssertGreaterThan(state.turbulence, 0.90)
        XCTAssertGreaterThan(state.pulseRate, 1.40)
    }

    func testMorningDownshiftAndRecoveryUseDistinctMotionProfiles() {
        let morning = RhythmVisualState(
            snapshot: snapshot(phase: .morningAnchor, scores: mixedScores, pickups: 10),
            confidence: 0.82,
            isRefreshing: false
        )
        let downshift = RhythmVisualState(
            snapshot: snapshot(phase: .downshift, scores: mixedScores, pickups: 10),
            confidence: 0.82,
            isRefreshing: false
        )
        let recovery = RhythmVisualState(
            snapshot: snapshot(phase: .recovery, scores: mixedScores, pickups: 10),
            confidence: 0.82,
            isRefreshing: false
        )

        XCTAssertGreaterThan(morning.pulseRate, downshift.pulseRate)
        XCTAssertGreaterThan(morning.density, recovery.density)
        XCTAssertLessThan(recovery.pulseRate, morning.pulseRate)
        XCTAssertNotEqual(morning.primary, downshift.primary)
        XCTAssertNotEqual(downshift.primary, recovery.primary)
    }

    func testLowConfidenceDegradesVisualCoherence() {
        let highConfidence = RhythmVisualState(
            snapshot: snapshot(phase: .focus, scores: highScores, pickups: 8, isMockData: false),
            confidence: 0.95,
            isRefreshing: false
        )
        let lowConfidence = RhythmVisualState(
            snapshot: snapshot(phase: .focus, scores: highScores, pickups: 8, isMockData: true),
            confidence: 0.24,
            isRefreshing: false
        )

        XCTAssertLessThan(lowConfidence.coherence, highConfidence.coherence)
        XCTAssertGreaterThan(lowConfidence.entropy, highConfidence.entropy)
        XCTAssertLessThan(lowConfidence.glow, highConfidence.glow)
    }

    func testRefreshingAddsPulseAndDensity() {
        let idle = RhythmVisualState(
            snapshot: snapshot(phase: .focus, scores: mixedScores, pickups: 12),
            confidence: 0.74,
            isRefreshing: false
        )
        let refreshing = RhythmVisualState(
            snapshot: snapshot(phase: .focus, scores: mixedScores, pickups: 12),
            confidence: 0.74,
            isRefreshing: true
        )

        XCTAssertGreaterThan(refreshing.pulseRate, idle.pulseRate)
        XCTAssertGreaterThan(refreshing.density, idle.density)
        XCTAssertGreaterThan(refreshing.magneticResponse, idle.magneticResponse)
    }

    private var highScores: RhythmScores {
        RhythmScores(rhythmicity: 92, daylight: 88, hrv: 90, movement: 86, sleep: 91, recovery: 89, appFriction: 94)
    }

    private var mixedScores: RhythmScores {
        RhythmScores(rhythmicity: 68, daylight: 54, hrv: 62, movement: 58, sleep: 67, recovery: 64, appFriction: 70)
    }

    private var lowScores: RhythmScores {
        RhythmScores(rhythmicity: 28, daylight: 24, hrv: 22, movement: 35, sleep: 32, recovery: 26, appFriction: 18)
    }

    private func snapshot(
        phase: AutonomicPhase,
        scores: RhythmScores,
        pickups: Int,
        isMockData: Bool = false
    ) -> RhythmSnapshot {
        var snapshot = RhythmSnapshot.mock
        snapshot.phase = phase
        snapshot.scores = scores
        snapshot.today.pickups = pickups
        snapshot.isMockData = isMockData
        return snapshot
    }
}

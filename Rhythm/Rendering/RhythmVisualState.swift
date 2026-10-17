import Foundation
import simd

struct RhythmVisualState: Equatable {
    var phase: AutonomicPhase
    var coherence: Float
    var entropy: Float
    var turbulence: Float
    var pulseRate: Float
    var density: Float
    var glow: Float
    var magneticResponse: Float
    var primary: SIMD3<Float>
    var secondary: SIMD3<Float>
    var accent: SIMD3<Float>
    var shadow: SIMD3<Float>
    var isRefreshing: Bool

    init(
        snapshot: RhythmSnapshot,
        confidence: Double,
        isRefreshing: Bool
    ) {
        let normalizedConfidence = Self.clamp(Float(confidence), 0.0, 1.0)
        let sourceConfidence = snapshot.isMockData ? normalizedConfidence * 0.72 : normalizedConfidence
        let rhythm = Self.score(snapshot.scores.rhythmicity)
        let recovery = Self.score(snapshot.scores.recovery)
        let daylight = Self.score(snapshot.scores.daylight)
        let hrv = Self.score(snapshot.scores.hrv)
        let sleep = Self.score(snapshot.scores.sleep)
        let movement = Self.score(snapshot.scores.movement)
        let friction = Self.score(snapshot.scores.appFriction)
        let pickupPressure = Self.clamp(Float(snapshot.today.pickups - 12) / 32.0, 0.0, 1.0)
        let lowSignal = 1.0 - sourceConfidence

        self.phase = snapshot.phase
        self.isRefreshing = isRefreshing

        let phaseCoherencePenalty: Float
        let turbulenceBase: Float
        let pulseBase: Float
        let densityBase: Float
        let glowBase: Float

        switch snapshot.phase {
        case .morningAnchor:
            phaseCoherencePenalty = 0.06
            turbulenceBase = 0.36
            pulseBase = 0.82
            densityBase = 0.68
            glowBase = 0.70 + daylight * 0.18
            primary = SIMD3<Float>(1.00, 0.64, 0.27)
            secondary = SIMD3<Float>(0.98, 0.85, 0.45)
            accent = SIMD3<Float>(0.00, 0.96, 0.83)
            shadow = SIMD3<Float>(0.08, 0.09, 0.18)
        case .focus:
            phaseCoherencePenalty = 0.00
            turbulenceBase = 0.18
            pulseBase = 0.64
            densityBase = 0.74
            glowBase = 0.66
            primary = SIMD3<Float>(0.00, 0.96, 0.83)
            secondary = SIMD3<Float>(0.32, 0.72, 1.00)
            accent = SIMD3<Float>(0.72, 0.57, 1.00)
            shadow = SIMD3<Float>(0.01, 0.04, 0.09)
        case .reset:
            phaseCoherencePenalty = 0.28
            turbulenceBase = 0.74
            pulseBase = 1.34
            densityBase = 0.88
            glowBase = 0.84
            primary = SIMD3<Float>(1.00, 0.30, 0.38)
            secondary = SIMD3<Float>(1.00, 0.78, 0.28)
            accent = SIMD3<Float>(0.00, 0.96, 0.83)
            shadow = SIMD3<Float>(0.13, 0.03, 0.06)
        case .downshift:
            phaseCoherencePenalty = 0.05
            turbulenceBase = 0.24
            pulseBase = 0.42
            densityBase = 0.58
            glowBase = 0.58
            primary = SIMD3<Float>(0.72, 0.57, 1.00)
            secondary = SIMD3<Float>(0.39, 0.20, 0.85)
            accent = SIMD3<Float>(1.00, 0.64, 0.27)
            shadow = SIMD3<Float>(0.04, 0.02, 0.09)
        case .recovery:
            phaseCoherencePenalty = 0.10
            turbulenceBase = 0.20
            pulseBase = 0.36
            densityBase = 0.52
            glowBase = 0.54
            primary = SIMD3<Float>(0.56, 0.72, 1.00)
            secondary = SIMD3<Float>(0.72, 0.57, 1.00)
            accent = SIMD3<Float>(0.00, 0.96, 0.83)
            shadow = SIMD3<Float>(0.03, 0.05, 0.12)
        }

        let biologicalStrength = rhythm * 0.28 + recovery * 0.20 + hrv * 0.19 + sleep * 0.17 + friction * 0.10 + movement * 0.06
        coherence = Self.clamp(0.18 + biologicalStrength * 0.58 + sourceConfidence * 0.34 - phaseCoherencePenalty, 0.10, 1.0)
        entropy = Self.clamp(1.05 - coherence + pickupPressure * 0.26 + lowSignal * 0.24 + (snapshot.phase == .reset ? 0.20 : 0.0), 0.04, 1.0)
        turbulence = Self.clamp(turbulenceBase + entropy * 0.36 + pickupPressure * 0.20 + (isRefreshing ? 0.08 : 0.0), 0.05, 1.0)
        pulseRate = Self.clamp(pulseBase + entropy * 0.28 + (isRefreshing ? 0.22 : 0.0), 0.25, 1.7)
        density = Self.clamp(densityBase + rhythm * 0.20 - lowSignal * 0.20 + (isRefreshing ? 0.06 : 0.0), 0.34, 1.0)
        glow = Self.clamp(glowBase + coherence * 0.22 + recovery * 0.12 - lowSignal * 0.18, 0.28, 1.0)
        magneticResponse = Self.clamp(0.35 + coherence * 0.32 + entropy * 0.24 + (isRefreshing ? 0.06 : 0.0), 0.24, 0.96)
    }

    private static func score(_ value: Int) -> Float {
        clamp(Float(value) / 100.0, 0.0, 1.0)
    }

    private static func clamp(_ value: Float, _ minimum: Float, _ maximum: Float) -> Float {
        min(max(value, minimum), maximum)
    }
}

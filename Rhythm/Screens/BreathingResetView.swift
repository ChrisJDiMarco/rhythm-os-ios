import SwiftUI

struct BreathingResetView: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        ScreenChrome(screen: .breathe, variant: .breathe, spacing: 18) {
            HStack {
                Spacer()
                StatusBadge(text: store.snapshot.phase == .reset ? "Sympathetic spike detected" : "Reset available", color: store.snapshot.phase == .reset ? RhythmColor.danger : RhythmColor.bio)
                Spacer()
            }

            VStack(alignment: .center, spacing: 8) {
                Text(store.snapshot.phase == .reset ? "Your body looks activated." : "Keep the reset loop close.")
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink)
                    .multilineTextAlignment(.center)

                Text(triggerCopy)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity)

            BreathOrbView()
                .frame(height: 260)
                .frame(maxWidth: .infinity)

            BreathingControl()

            GlassCard(radius: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("HRV trace")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(1.1)
                            .textCase(.uppercase)
                            .foregroundStyle(RhythmColor.ink3)

                        Spacer()

                        Text("38 ms - climbing")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(RhythmColor.bio)
                    }

                    HRVTrace()
                        .stroke(RhythmColor.bio.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(height: 42)
                        .shadow(color: RhythmColor.bio.opacity(0.35), radius: 8)

                    HStack(spacing: 10) {
                        BreathingProgress()
                    }
                }
            }
        }
    }

    private var triggerCopy: String {
        let today = store.snapshot.today
        let hrv = today.hrvMS.map { "\(Int($0.rounded())) ms HRV" } ?? "HRV unavailable"
        return "\(today.pickups) estimated pickups today - \(hrv) - 90 seconds will settle the loop."
    }
}

private struct BreathOrbView: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        TimelineView(.animation) { context in
            let cycleBase = store.activeBreathingStart.map { context.date.timeIntervalSince($0) } ?? context.date.timeIntervalSinceReferenceDate
            let cycle = cycleBase.truncatingRemainder(dividingBy: 10)
            let phase = breathPhase(for: cycle)

            ZStack {
                Circle()
                    .stroke(RhythmColor.bio.opacity(0.08), lineWidth: 1)
                    .frame(width: 214, height: 214)
                    .scaleEffect(phase.outerScale)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [RhythmColor.bio.opacity(0.88), RhythmColor.bio.opacity(0.18), RhythmColor.bio.opacity(0.04)],
                            center: UnitPoint(x: 0.36, y: 0.32),
                            startRadius: 8,
                            endRadius: 92
                        )
                    )
                    .frame(width: 166, height: 166)
                    .scaleEffect(phase.scale)
                    .shadow(color: RhythmColor.bio.opacity(0.34), radius: 44)
                    .shadow(color: RhythmColor.bio.opacity(0.20), radius: 92)

                Text(phase.label)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(RhythmColor.ink)
                    .contentTransition(.numericText())
            }
            .animation(.easeInOut(duration: 0.35), value: phase.label)
        }
    }

    private func breathPhase(for cycle: TimeInterval) -> BreathPhase {
        if cycle < 4 {
            let progress = cycle / 4
            return BreathPhase(label: "Inhale", scale: 0.78 + progress * 0.22, outerScale: 0.92 + progress * 0.10)
        }

        if cycle < 6 {
            return BreathPhase(label: "Hold", scale: 1, outerScale: 1.04)
        }

        let progress = (cycle - 6) / 4
        return BreathPhase(label: "Exhale", scale: 1 - progress * 0.22, outerScale: 1.04 - progress * 0.10)
    }
}

private struct BreathingControl: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            if let start = store.activeBreathingStart {
                let elapsed = min(context.date.timeIntervalSince(start), 90)
                Button {
                    Task { await store.completeBreathingReset() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: elapsed >= 90 ? "checkmark.circle.fill" : "stopwatch.fill")
                        Text(elapsed >= 90 ? "Complete reset" : "Running - \(time(elapsed))")
                            .monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color(hex: 0x061310))
                    .background(RhythmColor.bio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    store.startBreathingReset()
                } label: {
                    Label("Start 90-second reset", systemImage: "wind")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color(hex: 0x061310))
                        .background(RhythmColor.bio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func time(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return "\(value / 60):\(String(format: "%02d", value % 60)) / 1:30"
    }
}

private struct BreathingProgress: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = store.activeBreathingStart.map { context.date.timeIntervalSince($0) } ?? 42
            let capped = min(max(elapsed, 0), 90)

            HStack(spacing: 10) {
                ProgressView(value: capped, total: 90)
                    .progressViewStyle(.linear)
                    .tint(RhythmColor.bio)
                    .frame(height: 6)

                Text("\(format(capped)) / 1:30")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(RhythmColor.ink2)
            }
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }
}

private struct BreathPhase: Equatable {
    let label: String
    let scale: Double
    let outerScale: Double
}

private struct HRVTrace: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: 0.00, y: 0.62),
            CGPoint(x: 0.06, y: 0.22),
            CGPoint(x: 0.12, y: 0.62),
            CGPoint(x: 0.19, y: 0.54),
            CGPoint(x: 0.25, y: 0.30),
            CGPoint(x: 0.31, y: 0.68),
            CGPoint(x: 0.38, y: 0.44),
            CGPoint(x: 0.44, y: 0.74),
            CGPoint(x: 0.50, y: 0.24),
            CGPoint(x: 0.56, y: 0.57),
            CGPoint(x: 0.63, y: 0.18),
            CGPoint(x: 0.69, y: 0.46),
            CGPoint(x: 0.75, y: 0.12),
            CGPoint(x: 0.81, y: 0.38),
            CGPoint(x: 0.88, y: 0.09),
            CGPoint(x: 0.94, y: 0.32),
            CGPoint(x: 1.00, y: 0.08)
        ]

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: point(first, in: rect))

        for point in points.dropFirst() {
            path.addLine(to: self.point(point, in: rect))
        }

        return path
    }

    private func point(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }
}

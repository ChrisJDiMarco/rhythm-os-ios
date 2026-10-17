import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: RhythmStore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        let snapshot = store.snapshot

        ScreenChrome(screen: .dashboard, variant: .dashboard, spacing: 18) {
            HStack {
                Text(snapshot.today.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(RhythmColor.ink3)

                Spacer()

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [RhythmColor.bio, RhythmColor.evening],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: snapshot.isMockData ? "waveform.path.ecg" : "heart.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x071014).opacity(0.72))
                    )
            }

            HealthConnectionCard()

            CircadianRing(snapshot: snapshot)
                .frame(height: 268)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(metrics(from: snapshot)) { metric in
                    MetricTile(metric: metric)
                }
            }
        }
    }

    private func metrics(from snapshot: RhythmSnapshot) -> [VitalMetric] {
        [
            VitalMetric(
                label: "HRV",
                value: snapshot.today.hrvMS.map { "\(Int($0.rounded()))" } ?? "--",
                unit: "ms",
                delta: "\(snapshot.scores.hrv)/100 readiness",
                trend: snapshot.scores.hrv >= 55 ? .good : .warning
            ),
            VitalMetric(
                label: "Sun today",
                value: "\(Int(snapshot.today.daylightMinutes.rounded()))",
                unit: "min",
                delta: snapshot.scores.daylight >= 80 ? "goal hit" : "needs light",
                trend: snapshot.scores.daylight >= 70 ? .good : .warning
            ),
            VitalMetric(
                label: "Movement",
                value: "\(Int(snapshot.today.exerciseMinutes.rounded()))",
                unit: "min",
                delta: "\(Int(snapshot.today.steps.rounded())) steps",
                trend: snapshot.scores.movement >= 65 ? .good : .warning
            ),
            VitalMetric(
                label: "Pickups",
                value: "\(snapshot.today.pickups)",
                unit: "",
                delta: "\(Int(snapshot.today.appBudgetUsedMinutes.rounded())) min used",
                trend: snapshot.scores.appFriction >= 70 ? .good : .warning
            )
        ]
    }
}

private struct CircadianRing: View {
    let snapshot: RhythmSnapshot
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.05), style: StrokeStyle(lineWidth: 26, lineCap: .round))
                .frame(width: 236, height: 236)

            Circle()
                .trim(from: 0.0, to: 0.995)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hex: 0x0B1530),
                            Color(hex: 0x1A2B66),
                            RhythmColor.morning,
                            Color(hex: 0xFFF2C5),
                            RhythmColor.bio,
                            Color(hex: 0x5FBCFF),
                            RhythmColor.evening,
                            Color(hex: 0x4A2E80),
                            Color(hex: 0x0B1530)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 26, lineCap: .round)
                )
                .frame(width: 236, height: 236)
                .rotationEffect(.degrees(rotation))
                .shadow(color: RhythmColor.bio.opacity(0.18), radius: 22)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [RhythmColor.bgElevated, Color(hex: 0x05070F)],
                        center: .top,
                        startRadius: 16,
                        endRadius: 120
                    )
                )
                .frame(width: 172, height: 172)
                .overlay(Circle().stroke(.white.opacity(0.07), lineWidth: 1))

            VStack(spacing: 5) {
                Text("Now - \(snapshot.phase == .reset ? "Activated" : "Regulated")")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(RhythmColor.bio)

                Text(snapshot.phase.rawValue)
                    .font(.system(size: 27, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink)
                    .minimumScaleFactor(0.86)

                Text(snapshot.nextBreakMinutes == 0 ? snapshot.phase.detail : "\(snapshot.phase.detail) Next break in \(snapshot.nextBreakMinutes) min.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .foregroundStyle(RhythmColor.ink3)
                    .frame(width: 126)
            }

            RingMarker(angle: 168)
                .frame(width: 236, height: 236)
        }
        .onAppear {
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

private struct HealthConnectionCard: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        SolidCard(radius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: store.snapshot.isMockData ? "heart.text.square" : "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.healthStatus.isUsable ? RhythmColor.bio : RhythmColor.warn)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.healthStatus.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(RhythmColor.ink)

                        Text(store.snapshot.isMockData ? "Simulator/mock mode is active. Connect Health on device for live biometrics." : "Live Apple Health data is driving the rhythm engine.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .lineSpacing(2)
                            .foregroundStyle(RhythmColor.ink3)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await store.requestHealthAuthorization() }
                    } label: {
                        Label("Health", systemImage: "heart.circle.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RhythmColor.bio.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .foregroundStyle(RhythmColor.bio)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Label(store.isRefreshing ? "Syncing" : "Sync", systemImage: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .foregroundStyle(RhythmColor.ink2)
                    }
                    .buttonStyle(.plain)

                    Toggle(isOn: $store.useMockData) {
                        Text("Mock")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .labelsHidden()
                    .tint(RhythmColor.bio)
                }
            }
        }
    }
}

private struct RingMarker: View {
    let angle: Double

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2
            let radians = (angle - 90) * Double.pi / 180
            let x = proxy.size.width / 2 + CGFloat(cos(radians)) * radius
            let y = proxy.size.height / 2 + CGFloat(sin(radians)) * radius

            Circle()
                .fill(.white)
                .frame(width: 15, height: 15)
                .shadow(color: RhythmColor.bio.opacity(0.85), radius: 10)
                .overlay(Circle().stroke(RhythmColor.bgDeep, lineWidth: 4))
                .position(x: x, y: y)
        }
    }
}

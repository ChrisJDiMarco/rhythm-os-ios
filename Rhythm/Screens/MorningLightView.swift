import SwiftUI

struct MorningLightView: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        let daylight = store.snapshot.today.daylightMinutes
        let progress = min(daylight / 20.0, 1.0)

        ScreenChrome(screen: .morning, variant: .morning, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).hour().minute()))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.70))

                Text("Good morning, Chris.")
                    .font(.system(size: 35, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            SunriseScene()
                .frame(height: 228)
                .padding(.top, 4)

            GlassCard(radius: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(daylight >= 15 ? "Morning anchor is in place." : "Step outside before the feeds.")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(RhythmColor.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(daylight >= 15 ? "Apple Health shows enough daylight to stabilize tonight's sleep window. Keep the first feed delay intact." : "Your circadian system is asking for sunlight, not screens. Five to ten minutes of outdoor light anchors your sleep window tonight.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .lineSpacing(3)
                            .foregroundStyle(.white.opacity(0.70))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.08))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [RhythmColor.morning, RhythmColor.morningDeep],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: proxy.size.width * progress)
                                    .shadow(color: RhythmColor.morning.opacity(0.8), radius: 10)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text("Morning light")
                            Spacer()
                            Text("\(Int(daylight.rounded())) / 20 min")
                                .monospacedDigit()
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    }

                    OutdoorSessionControl()
                }
            }
        }
    }
}

private struct OutdoorSessionControl: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let start = store.activeOutdoorStart {
                Button {
                    Task { await store.finishOutdoorSession() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Finish walk - \(elapsed(from: start, now: context.date))")
                            .monospacedDigit()
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(Color(hex: 0x15131F))
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    store.startOutdoorSession()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start outdoor walk")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(Color(hex: 0x15131F))
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func elapsed(from start: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(start))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}

private struct SunriseScene: View {
    @State private var lifted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )

            ForEach(0..<5) { index in
                Capsule()
                    .fill(.white.opacity(0.10 - Double(index) * 0.013))
                    .frame(height: 1)
                    .offset(y: CGFloat(-40 - index * 26))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.98), RhythmColor.morning.opacity(0.95), RhythmColor.morningDeep.opacity(0.62), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 104
                    )
                )
                .frame(width: 218, height: 218)
                .offset(y: lifted ? 48 : 64)
                .blur(radius: 1.5)
                .animation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: lifted)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onAppear { lifted = true }
    }
}

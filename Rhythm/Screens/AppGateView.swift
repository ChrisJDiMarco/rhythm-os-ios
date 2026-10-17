import SwiftUI
import FamilyControls

struct AppGateView: View {
    @EnvironmentObject private var store: RhythmStore
    @State private var isPickerPresented = false

    private let options = GateIntentKind.allCases.map {
        GateOption(intent: $0, title: $0.title, meta: $0.meta, tint: $0.tint, symbol: $0.symbol)
    }

    var body: some View {
        ScreenChrome(screen: .gate, variant: .gate, spacing: 20) {
            HStack(spacing: 12) {
                AppGlyph()
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Opening")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(RhythmColor.ink3)

                    Text("TikTok")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(RhythmColor.ink)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What are you here to do?")
                    .font(.system(size: 31, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text("A two-second pause recruits prefrontal control before the dopamine loop starts.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .lineSpacing(3)
                    .foregroundStyle(RhythmColor.ink3)
            }

            AppGateControlCard(isPickerPresented: $isPickerPresented)

            ActiveGateSessionCard()

            VStack(spacing: 10) {
                ForEach(options) { option in
                    GateOptionRow(option: option) {
                        store.activateGateIntent(option.intent)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack {
                Spacer()
                Text("Today - 23 min of 45 min budget used")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
                Spacer()
            }
            .padding(.top, 4)
        }
        .familyActivityPicker(
            headerText: "Choose apps Rhythm OS should shield during focus or downshift.",
            footerText: "Selections stay on device and are controlled by Apple's Screen Time APIs.",
            isPresented: $isPickerPresented,
            selection: Binding(
                get: { store.appShield.selection },
                set: { store.appShield.selection = $0 }
            )
        )
    }
}

private struct ActiveGateSessionCard: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        if let session = store.activeGateSession {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(session.endsAt.timeIntervalSince(context.date), 0)

                GlassCard(radius: 18, strokeOpacity: 0.16) {
                    HStack(spacing: 12) {
                        Image(systemName: session.intent.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .foregroundStyle(session.intent.tint)
                            .background(session.intent.tint.opacity(0.14), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.intent.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(RhythmColor.ink)

                            Text("Gate active - \(format(remaining)) remaining")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(RhythmColor.ink3)
                        }

                        Spacer()

                        Button {
                            store.clearGateSession()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .frame(width: 30, height: 30)
                                .background(.white.opacity(0.08), in: Circle())
                                .foregroundStyle(RhythmColor.ink2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func format(_ seconds: TimeInterval) -> String {
        let value = Int(seconds)
        return "\(value / 60):\(String(format: "%02d", value % 60))"
    }
}

private struct AppGateControlCard: View {
    @EnvironmentObject private var store: RhythmStore
    @Binding var isPickerPresented: Bool

    var body: some View {
        SolidCard(radius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: store.appShield.isShieldingActive ? "shield.fill" : "shield")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.appShield.isShieldingActive ? RhythmColor.bio : RhythmColor.warn)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.appShield.status.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(RhythmColor.ink)

                        Text("\(store.appShield.selectedItemCount) apps/categories selected. Shielding requires Screen Time authorization and Apple entitlement approval on device.")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .lineSpacing(2)
                            .foregroundStyle(RhythmColor.ink3)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    SmallGateButton(title: "Authorize", symbol: "person.badge.shield.checkmark") {
                        Task { await store.appShield.requestAuthorization() }
                    }

                    SmallGateButton(title: "Choose", symbol: "square.grid.2x2") {
                        isPickerPresented = true
                    }

                    SmallGateButton(title: store.appShield.isShieldingActive ? "Clear" : "Shield", symbol: store.appShield.isShieldingActive ? "xmark.shield" : "shield.lefthalf.filled") {
                        if store.appShield.isShieldingActive {
                            store.clearAppGateShield()
                        } else {
                            store.applyAppGateShield()
                        }
                    }
                }
            }
        }
    }
}

private struct SmallGateButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(RhythmColor.ink2)
        }
        .buttonStyle(.plain)
    }
}

private struct AppGlyph: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.black)
            .overlay(
                ZStack {
                    Circle()
                        .fill(RhythmColor.bio)
                        .frame(width: 34, height: 34)
                        .offset(x: -9, y: -8)
                        .blur(radius: 10)

                    Circle()
                        .fill(Color(hex: 0xFF2D6D))
                        .frame(width: 34, height: 34)
                        .offset(x: 10, y: 11)
                        .blur(radius: 10)

                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            )
    }
}

private struct GateOptionRow: View {
    let option: GateOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(option.tint.opacity(0.16))
                    Image(systemName: option.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(option.tint)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(RhythmColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.84)

                    Text(option.meta)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(RhythmColor.ink3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RhythmColor.ink3)
            }
            .padding(14)
            .background(RhythmColor.bgCard.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

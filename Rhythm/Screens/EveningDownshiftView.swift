import SwiftUI

struct EveningDownshiftView: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        ScreenChrome(screen: .evening, variant: .evening, spacing: 16) {
            StatusBadge(text: "Biological sunset active", color: RhythmColor.evening)

            HStack(spacing: 16) {
                MoonGlyph()
                    .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Downshift mode")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundStyle(RhythmColor.ink)

                    Text("Bedtime in 1h 46m - 11:00 PM")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RhythmColor.ink3)
                        .lineLimit(2)
                }
            }

            SolidCard(radius: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Tonight's wind-down")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(1.0)
                            .textCase(.uppercase)
                            .foregroundStyle(RhythmColor.ink2)

                        Spacer()

                        Button("Reset") {
                            store.resetRoutine()
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(RhythmColor.evening)
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 0) {
                        ForEach(store.routineItems) { item in
                            RoutineRow(item: item) {
                                store.toggleRoutine(item.id)
                            }
                        }
                    }
                }
            }

            HiddenAppsCard()

            SolidCard(radius: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tomorrow's first task")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1.0)
                        .textCase(.uppercase)
                        .foregroundStyle(RhythmColor.ink3)

                    Text("Draft Andrey SOW - 9:00 AM")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(RhythmColor.ink)
                }
            }
        }
    }
}

private struct MoonGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xF6E7FF), Color(hex: 0xC8A8F0), Color(hex: 0x6E4AA0)],
                        center: UnitPoint(x: 0.32, y: 0.30),
                        startRadius: 3,
                        endRadius: 42
                    )
                )
                .shadow(color: RhythmColor.evening.opacity(0.34), radius: 22)

            Circle()
                .fill(Color(hex: 0x2A1F3A).opacity(0.48))
                .frame(width: 18, height: 18)
                .offset(x: 10, y: -12)

            Circle()
                .fill(Color(hex: 0x2A1F3A).opacity(0.34))
                .frame(width: 11, height: 11)
                .offset(x: -12, y: 14)
        }
    }
}

private struct RoutineRow: View {
    let item: RoutineItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(item.isDone ? RhythmColor.evening : .clear)
                        .overlay(
                            Circle()
                                .stroke(item.isDone ? RhythmColor.evening : RhythmColor.ink4, lineWidth: 1.5)
                        )

                    if item.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 21, height: 21)

                Text(item.label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(item.isDone ? RhythmColor.ink3 : RhythmColor.ink)
                    .strikethrough(item.isDone, color: RhythmColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                if let time = item.time {
                    Text(time)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RhythmColor.ink3)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

private struct HiddenAppsCard: View {
    @EnvironmentObject private var store: RhythmStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.appShield.isShieldingActive ? "Hidden until morning" : "Ready to hide")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(RhythmColor.ink3)

                Spacer()

                Button {
                    if store.appShield.isShieldingActive {
                        store.clearAppGateShield()
                    } else {
                        store.applyAppGateShield()
                    }
                } label: {
                    Text(store.appShield.isShieldingActive ? "Clear" : "Shield")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(RhythmColor.evening)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                HiddenAppIcon(kind: .tiktok)
                HiddenAppIcon(kind: .instagram)
                HiddenAppIcon(kind: .x)

                Text("\(store.appShield.selectedItemCount) selected")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
                    .padding(.leading, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
                .foregroundStyle(.white.opacity(0.14))
        )
    }
}

private enum HiddenAppKind {
    case tiktok
    case instagram
    case x
}

private struct HiddenAppIcon: View {
    let kind: HiddenAppKind

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(fill)
            .frame(width: 32, height: 32)
            .opacity(0.56)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
            )
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .tiktok:
            AnyShapeStyle(LinearGradient(colors: [RhythmColor.bio, Color(hex: 0xFF2D6D)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .instagram:
            AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF58529), Color(hex: 0xDD2A7B), Color(hex: 0x515BD4)], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .x:
            AnyShapeStyle(Color.black)
        }
    }

    private var symbol: String {
        switch kind {
        case .tiktok:
            "music.note"
        case .instagram:
            "camera.fill"
        case .x:
            "xmark"
        }
    }
}

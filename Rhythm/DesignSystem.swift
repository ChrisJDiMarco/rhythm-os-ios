import SwiftUI

enum RhythmColor {
    static let bgDeep = Color(hex: 0x050710)
    static let bgStage = Color(hex: 0x0A0D18)
    static let bgElevated = Color(hex: 0x11151F)
    static let bgCard = Color(hex: 0x161A26)
    static let ink = Color(hex: 0xF3F5FA)
    static let ink2 = Color(hex: 0xB6BCCE)
    static let ink3 = Color(hex: 0x6E7589)
    static let ink4 = Color(hex: 0x444A5A)
    static let bio = Color(hex: 0x00F5D4)
    static let bioDim = Color(hex: 0x038676)
    static let pulse = Color(hex: 0x38E8C2)
    static let morning = Color(hex: 0xFFB366)
    static let morningDeep = Color(hex: 0xFF7E3A)
    static let evening = Color(hex: 0xB891FF)
    static let eveningDeep = Color(hex: 0x7C3AED)
    static let danger = Color(hex: 0xFF5A6B)
    static let warn = Color(hex: 0xFFCE4A)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

enum RhythmBackgroundVariant {
    case morning
    case dashboard
    case breathe
    case gate
    case notifications
    case evening
    case weekly
}

struct RhythmBackground: View {
    let variant: RhythmBackgroundVariant

    var body: some View {
        ZStack {
            baseGradient

            switch variant {
            case .morning:
                atmosphericCircle(RhythmColor.morning, size: 340, x: 0.56, y: 0.94, opacity: 0.42, blur: 34)
                atmosphericCircle(RhythmColor.eveningDeep, size: 260, x: 0.18, y: 0.18, opacity: 0.16, blur: 48)
            case .dashboard:
                atmosphericCircle(RhythmColor.bio, size: 300, x: 0.5, y: 0.28, opacity: 0.12, blur: 42)
                atmosphericCircle(RhythmColor.evening, size: 240, x: 0.86, y: 0.82, opacity: 0.10, blur: 60)
            case .breathe:
                atmosphericCircle(RhythmColor.bio, size: 340, x: 0.5, y: 0.5, opacity: 0.18, blur: 54)
                atmosphericCircle(RhythmColor.eveningDeep, size: 280, x: 0.5, y: 0.95, opacity: 0.22, blur: 62)
            case .gate:
                atmosphericCircle(RhythmColor.danger, size: 280, x: 0.5, y: 0.05, opacity: 0.16, blur: 54)
                atmosphericCircle(RhythmColor.bio, size: 200, x: 0.88, y: 0.72, opacity: 0.08, blur: 56)
            case .notifications:
                atmosphericCircle(RhythmColor.bio, size: 220, x: 0.18, y: 0.16, opacity: 0.08, blur: 56)
                atmosphericCircle(RhythmColor.evening, size: 260, x: 0.92, y: 0.9, opacity: 0.10, blur: 64)
            case .evening:
                atmosphericCircle(RhythmColor.evening, size: 330, x: 0.5, y: 0.16, opacity: 0.18, blur: 54)
                atmosphericCircle(RhythmColor.morning, size: 260, x: 0.54, y: 0.98, opacity: 0.10, blur: 56)
            case .weekly:
                atmosphericCircle(RhythmColor.bio, size: 280, x: 0.48, y: 0.05, opacity: 0.13, blur: 58)
                atmosphericCircle(RhythmColor.evening, size: 230, x: 0.1, y: 0.86, opacity: 0.08, blur: 62)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var baseGradient: some View {
        switch variant {
        case .morning:
            LinearGradient(
                colors: [Color(hex: 0x0A0D18), Color(hex: 0x1A1525), Color(hex: 0x5A2F3F), Color(hex: 0xC46B3E)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .evening:
            LinearGradient(
                colors: [Color(hex: 0x0A0814), Color(hex: 0x1A1325), Color(hex: 0x2A1F3A)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .gate:
            LinearGradient(
                colors: [RhythmColor.bgStage, Color(hex: 0x0E0E18)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .notifications:
            LinearGradient(
                colors: [Color(hex: 0x060810), Color(hex: 0x0A0E1A)],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            LinearGradient(
                colors: [Color(hex: 0x05070F), RhythmColor.bgStage],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func atmosphericCircle(
        _ color: Color,
        size: CGFloat,
        x: CGFloat,
        y: CGFloat,
        opacity: Double,
        blur: CGFloat
    ) -> some View {
        GeometryReader { proxy in
            Circle()
                .fill(color.opacity(opacity))
                .frame(width: size, height: size)
                .blur(radius: blur)
                .position(x: proxy.size.width * x, y: proxy.size.height * y)
        }
    }
}

struct ScreenChrome<Content: View>: View {
    let screen: RhythmScreen
    let variant: RhythmBackgroundVariant
    var spacing: CGFloat = 18
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RhythmBackground(variant: variant)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: spacing) {
                        ScreenHeader(screen: screen)
                        content()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: max(proxy.size.height - 106, 0), alignment: .top)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 104)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }
}

struct ScreenHeader: View {
    let screen: RhythmScreen

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(screen.number)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(RhythmColor.bio)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 3) {
                Text(screen.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(RhythmColor.ink)
                    .tracking(1.2)
                    .textCase(.uppercase)

                Text(screen.subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
    }
}

struct GlassCard<Content: View>: View {
    var radius: CGFloat = 22
    var strokeOpacity: Double = 0.10
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.62), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(strokeOpacity), lineWidth: 1)
        )
    }
}

struct SolidCard<Content: View>: View {
    var radius: CGFloat = 18
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(14)
        .background(RhythmColor.bgCard.opacity(0.92), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.75), radius: 8)
            }

            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.1)
                .textCase(.uppercase)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(color.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.30), lineWidth: 1))
    }
}

struct MetricTile: View {
    let metric: VitalMetric

    var body: some View {
        SolidCard(radius: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(RhythmColor.ink3)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(metric.value)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(RhythmColor.ink)
                        .minimumScaleFactor(0.78)
                        .lineLimit(1)

                    if !metric.unit.isEmpty {
                        Text(metric.unit)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(RhythmColor.ink3)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: metric.trend == .good ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(metric.delta)
                        .lineLimit(1)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(metric.trend == .good ? RhythmColor.bio : RhythmColor.warn)
            }
        }
    }
}

struct PrimaryCapsuleButton: View {
    let title: String
    let symbol: String
    var tint: Color = .white

    var body: some View {
        Button {
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(tint == .white ? Color(hex: 0x15131F) : .white)
            .background(tint.opacity(tint == .white ? 0.92 : 0.96), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct SectionKicker: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(RhythmColor.ink2)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(RhythmColor.ink3)
            }
        }
        .padding(.horizontal, 2)
    }
}

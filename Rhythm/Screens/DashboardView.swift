import SwiftUI
import simd

struct DashboardView: View {
    @EnvironmentObject private var store: RhythmStore

    let openScreen: (RhythmScreen) -> Void

    @State private var touchOrigin: CGPoint?
    @State private var touchPoint: CGPoint?
    @State private var selectedCommand: BioCommand?
    @State private var lastHapticCommand: BioCommand?
    @State private var touchCleanupTask: Task<Void, Never>?

    private let commands = BioCommand.all

    var body: some View {
        let visualState = RhythmVisualState(
            snapshot: store.snapshot,
            confidence: store.rhythmConfidence,
            isRefreshing: store.isRefreshing
        )

        GeometryReader { proxy in
            ZStack {
                BiofieldMetalView(
                    visualState: visualState,
                    touchOrigin: touchOrigin,
                    touchPoint: touchPoint,
                    commandTint: selectedCommand?.fieldTint
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(Color(hex: 0x03060D))
                .ignoresSafeArea()
                .allowsHitTesting(false)

                if let touchOrigin {
                    BioCommandHalo(
                        commands: commands,
                        origin: touchOrigin,
                        touchPoint: touchPoint ?? touchOrigin,
                        selectedCommand: selectedCommand
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
            .background(Color(hex: 0x03060D))
            .contentShape(Rectangle())
            .gesture(commandGesture(in: proxy.size))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Rhythm biofield")
            .accessibilityHint("Press and drag to choose a rhythm command.")
            .onDisappear {
                clearTouchState(animated: false)
            }
        }
        .ignoresSafeArea()
    }

    private func commandGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if touchOrigin == nil {
                    touchOrigin = clamped(value.startLocation, in: size)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }

                let point = clamped(value.location, in: size)
                touchPoint = point
                selectedCommand = nearestCommand(from: touchOrigin ?? value.startLocation, to: point)
                scheduleTouchCleanup()

                if let selectedCommand, selectedCommand != lastHapticCommand {
                    UISelectionFeedbackGenerator().selectionChanged()
                    lastHapticCommand = selectedCommand
                }
            }
            .onEnded { _ in
                if let selectedCommand {
                    activate(selectedCommand)
                }

                clearTouchState(animated: true)
            }
    }

    private func nearestCommand(from origin: CGPoint, to point: CGPoint) -> BioCommand? {
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let distance = sqrt(dx * dx + dy * dy)
        guard distance > 44 else { return nil }

        let angle = atan2(dy, dx)
        return commands.min { first, second in
            angularDistance(angle, first.angle) < angularDistance(angle, second.angle)
        }
    }

    private func angularDistance(_ lhs: Double, _ rhs: Double) -> Double {
        let difference = abs(lhs - rhs)
        return min(difference, Double.pi * 2 - difference)
    }

    private func activate(_ command: BioCommand) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        switch command.kind {
        case .focus:
            Task { await store.refresh() }
            openScreen(.dashboard)
        case .light:
            if store.activeOutdoorStart == nil {
                store.startOutdoorSession()
            }
            openScreen(.morning)
        case .reset:
            if store.activeBreathingStart == nil {
                store.startBreathingReset()
            }
            openScreen(.breathe)
        case .apps:
            openScreen(.gate)
        case .alerts:
            openScreen(.notifications)
        case .night:
            openScreen(.evening)
        case .week:
            openScreen(.weekly)
        }
    }

    private func scheduleTouchCleanup() {
        touchCleanupTask?.cancel()
        touchCleanupTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard !Task.isCancelled, touchOrigin != nil else { return }
            clearTouchState(animated: true)
        }
    }

    private func clearTouchState(animated: Bool) {
        touchCleanupTask?.cancel()
        touchCleanupTask = nil

        let reset = {
            touchOrigin = nil
            touchPoint = nil
            selectedCommand = nil
            lastHapticCommand = nil
        }

        if animated {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                reset()
            }
        } else {
            reset()
        }
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 132), size.width - 132),
            y: min(max(point.y, 184), size.height - 238)
        )
    }
}

private struct BioCommandHalo: View {
    let commands: [BioCommand]
    let origin: CGPoint
    let touchPoint: CGPoint
    let selectedCommand: BioCommand?

    var body: some View {
        ZStack {
            BioCommandLens(origin: origin, tint: selectedCommand?.tint ?? RhythmColor.bio)

            FingerWake(
                origin: origin,
                touchPoint: touchPoint,
                tint: selectedCommand?.tint ?? RhythmColor.bio
            )

            ForEach(commands) { command in
                BioCommandNode(
                    command: command,
                    isSelected: selectedCommand == command
                )
                .position(position(for: command))
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: selectedCommand)
    }

    private func position(for command: BioCommand) -> CGPoint {
        let radius: CGFloat = selectedCommand == command ? 110 : 98
        return CGPoint(
            x: origin.x + cos(command.angle) * radius,
            y: origin.y + sin(command.angle) * radius
        )
    }
}

private struct BioCommandLens: View {
    let origin: CGPoint
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.98),
                            .white.opacity(0.98),
                            .white.opacity(0.88),
                            .white.opacity(0.42),
                            .white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 194
                    )
                )
                .frame(width: 388, height: 388)
                .blur(radius: 3.5)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(0.24),
                            tint.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 16,
                        endRadius: 156
                    )
                )
                .frame(width: 312, height: 312)
                .blendMode(.multiply)

            Circle()
                .stroke(Color(hex: 0x11151F).opacity(0.08), lineWidth: 1)
                .frame(width: 232, height: 232)
                .blur(radius: 0.4)
        }
        .position(origin)
        .allowsHitTesting(false)
    }
}

private struct FingerWake: View {
    let origin: CGPoint
    let touchPoint: CGPoint
    let tint: Color

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: origin)
                path.addLine(to: touchPoint)
            }
            .stroke(Color(hex: 0x11151F).opacity(0.20), style: StrokeStyle(lineWidth: 2, lineCap: .round))

            Circle()
                .fill(tint.opacity(0.86))
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.86), lineWidth: 1.2)
                )
                .shadow(color: tint.opacity(0.52), radius: 18)
                .position(touchPoint)

            Circle()
                .stroke(Color(hex: 0x11151F).opacity(0.15), lineWidth: 1.2)
                .frame(width: 54, height: 54)
                .position(origin)
        }
    }
}

private struct BioCommandNode: View {
    let command: BioCommand
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? command.tint.opacity(0.96) : Color.white.opacity(0.86))
                .frame(width: isSelected ? 60 : 50, height: isSelected ? 60 : 50)
                .shadow(
                    color: isSelected ? command.tint.opacity(0.42) : Color(hex: 0x11151F).opacity(0.14),
                    radius: isSelected ? 22 : 12,
                    y: isSelected ? 8 : 5
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? .white.opacity(0.74) : Color(hex: 0x11151F).opacity(0.12), lineWidth: 1)
                )

            Image(systemName: command.symbol)
                .font(.system(size: isSelected ? 22 : 18, weight: .semibold))
                .foregroundStyle(Color(hex: 0x07101D))
        }
        .frame(width: 68, height: 68)
        .scaleEffect(isSelected ? 1.08 : 1)
        .accessibilityLabel(command.label)
    }
}

private enum BioCommandKind {
    case focus
    case light
    case reset
    case apps
    case alerts
    case night
    case week
}

private struct BioCommand: Identifiable, Equatable {
    let kind: BioCommandKind
    let label: String
    let symbol: String
    let angle: Double
    let tint: Color
    let fieldTint: SIMD3<Float>

    var id: BioCommandKind { kind }

    static func == (lhs: BioCommand, rhs: BioCommand) -> Bool {
        lhs.kind == rhs.kind
    }

    static let all = [
        BioCommand(
            kind: .focus,
            label: "Focus",
            symbol: "scope",
            angle: -.pi / 2,
            tint: RhythmColor.bio,
            fieldTint: SIMD3<Float>(0.00, 0.96, 0.83)
        ),
        BioCommand(
            kind: .light,
            label: "Light",
            symbol: "sun.max.fill",
            angle: -.pi / 4,
            tint: RhythmColor.morning,
            fieldTint: SIMD3<Float>(1.00, 0.64, 0.27)
        ),
        BioCommand(
            kind: .apps,
            label: "Apps",
            symbol: "shield.fill",
            angle: 0,
            tint: RhythmColor.evening,
            fieldTint: SIMD3<Float>(0.72, 0.57, 1.00)
        ),
        BioCommand(
            kind: .alerts,
            label: "Alerts",
            symbol: "bell.badge.fill",
            angle: .pi / 4,
            tint: Color(hex: 0x5FBCFF),
            fieldTint: SIMD3<Float>(0.37, 0.74, 1.00)
        ),
        BioCommand(
            kind: .night,
            label: "Night",
            symbol: "moon.stars.fill",
            angle: .pi / 2,
            tint: RhythmColor.evening,
            fieldTint: SIMD3<Float>(0.72, 0.57, 1.00)
        ),
        BioCommand(
            kind: .week,
            label: "Week",
            symbol: "chart.bar.fill",
            angle: .pi * 3 / 4,
            tint: RhythmColor.warn,
            fieldTint: SIMD3<Float>(1.00, 0.78, 0.28)
        ),
        BioCommand(
            kind: .reset,
            label: "Reset",
            symbol: "wind",
            angle: .pi,
            tint: RhythmColor.bio,
            fieldTint: SIMD3<Float>(0.00, 0.96, 0.83)
        )
    ]
}

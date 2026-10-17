import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: RhythmStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = RhythmScreen.dashboard.rawValue

    var body: some View {
        ZStack {
            selectedScreen
                .id(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RhythmColor.bgDeep)
        .animation(.easeInOut(duration: 0.18), value: selection)
        .ignoresSafeArea(.keyboard)
        .task {
            await store.bootstrap()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await store.appDidBecomeActive() }
        }
        .safeAreaInset(edge: .bottom) {
            if selection != RhythmScreen.dashboard.rawValue {
                RhythmTabBar(selection: $selection)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var selectedScreen: some View {
        switch RhythmScreen(rawValue: selection) ?? .dashboard {
        case .morning:
            MorningLightView()
        case .dashboard:
            DashboardView { screen in
                selection = screen.rawValue
            }
        case .breathe:
            BreathingResetView()
        case .gate:
            AppGateView()
        case .notifications:
            NotificationBatchView()
        case .evening:
            EveningDownshiftView()
        case .weekly:
            WeeklyReportView()
        }
    }
}

private struct RhythmTabBar: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RhythmScreen.allCases) { screen in
                RhythmTabButton(
                    screen: screen,
                    isSelected: screen.rawValue == selection
                ) {
                    selection = screen.rawValue
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
    }
}

private struct RhythmTabButton: View {
    let screen: RhythmScreen
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? RhythmColor.bio : Color.white.opacity(0.001))
                        .shadow(color: isSelected ? RhythmColor.bio.opacity(0.34) : .clear, radius: 12)

                    Image(systemName: screen.tabSymbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? Color(hex: 0x03120F) : RhythmColor.ink3)
                }
                .frame(height: 34)

                Text(screen.tabTitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(isSelected ? RhythmColor.ink : RhythmColor.ink3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(screen.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    ContentView()
        .environmentObject(RhythmStore())
}

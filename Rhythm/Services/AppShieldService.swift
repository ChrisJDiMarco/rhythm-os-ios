import Foundation
import Combine
import FamilyControls
import ManagedSettings

@MainActor
final class AppShieldService: ObservableObject {
    @Published var selection: FamilyActivitySelection {
        didSet { saveSelection() }
    }
    @Published private(set) var status: AppGatePermissionStatus
    @Published private(set) var isShieldingActive = false

    private let store = ManagedSettingsStore()
    private let defaultsKey = "rhythm.familyActivitySelection"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        } else {
            selection = FamilyActivitySelection()
        }

        status = Self.status(from: AuthorizationCenter.shared.authorizationStatus)
    }

    var selectedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    func requestAuthorization() async {
        status = .requesting

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            status = Self.status(from: AuthorizationCenter.shared.authorizationStatus)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func refreshStatus() {
        status = Self.status(from: AuthorizationCenter.shared.authorizationStatus)
    }

    func applyShield() {
        guard case .authorized = status else {
            isShieldingActive = false
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        isShieldingActive = selectedItemCount > 0
    }

    func clearShield() {
        store.clearAllSettings()
        isShieldingActive = false
    }

    private func saveSelection() {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func status(from authorizationStatus: AuthorizationStatus) -> AppGatePermissionStatus {
        switch authorizationStatus {
        case .notDetermined:
            .notRequested
        case .denied:
            .denied
        case .approved:
            .authorized
        @unknown default:
            .failed("Unknown Screen Time authorization state")
        }
    }
}

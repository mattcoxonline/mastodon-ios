// Copyright © 2026 Mastodon gGmbH. All rights reserved.

import SwiftUI
import MastodonSDK
import MastodonCore
import MastodonLocalization
import MastodonAsset
import MastodonUI

enum SettingsDestinationType {
    case generalSettings
    case notificationsSettings
    case notificationsReceiveFromPicker
    case privacyAndSafety
    case serverDetails
    case aboutMastodon
    case languageSelection
}

enum SettingsRowAction {
    case pushDestination(SettingsDestinationType)
    case openUrl(URL?)
    case makeDonation
}

@MainActor
class SettingsModels {
    private var _notificationSettings: NotificationSettingsViewModel?
    
    func notificationSettings(authBox: MastodonAuthenticationBox) -> NotificationSettingsViewModel {
        if let _notificationSettings {
            return _notificationSettings
        } else {
            let newModel = NotificationSettingsViewModel(authBox: authBox)
            _notificationSettings = newModel
            return newModel
        }
    }
}

struct SettingsNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var generalSettingsViewModel = GeneralSettingsViewModel()
    @State private var viewModels = SettingsModels()
    @State private var navigator: MastodonNavigationRouter
    @State private var authBox: MastodonAuthenticationBox
    
    init(authenticationBox: MastodonAuthenticationBox) {
        self.authBox = authenticationBox
        navigator = MastodonNavigationRouter(authenticationBox: authenticationBox)
    }
    
    var body: some View {
        @Bindable var navigator = navigator
        NavigationStack(path: $navigator.navigationPath) {
            let domain = authBox.domain
            SettingsRootView(domain: domain)
                .navigationTitle(L10n.Scene.Settings.Overview.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.Common.Controls.Actions.done) {
                            dismiss()
                        }
                    }
                }
                .navigationDestination(for: MastodonNavigationDestination.self) { destination in
                    switch destination {
                    case .settings(let settingsType):
                        switch settingsType {
                        case .aboutMastodon:
                            AboutMastodonView(authBox: authBox)
                                .navigationTitle(L10n.Scene.Settings.AboutMastodon.title)
                        case .generalSettings:
                            GeneralSettingsView()
                                .environment(generalSettingsViewModel)
                        case .languageSelection:
                            LanguagePicker(selectedLanguage: generalSettingsViewModel.defaultPostLanguage, onSelect: { selected in
                                generalSettingsViewModel.defaultPostLanguage = selected
                                navigator.pop()
                            })
                            .environment(generalSettingsViewModel)
                            .navigationTitle(L10n.Scene.Settings.General.Language.defaultPostLanguage)
                        case .notificationsSettings:
                            if let authBox = AuthenticationObserver.shared.currentActiveUser {
                                NotificationSettingsView()
                                    .environment(viewModels.notificationSettings(authBox: authBox))
                            }
                        case .notificationsReceiveFromPicker:
                            if let authBox = AuthenticationObserver.shared.currentActiveUser {
                                NotificationReceiveFromPicker()
                                    .environment(viewModels.notificationSettings(authBox: authBox))
                                    .navigationTitle(L10n.Scene.Settings.Notifications.Policy.title)
                            }
                        case .privacyAndSafety:
                            PrivacySafetyView(viewModel: PrivacySafetyViewModel(authenticationBox: authBox))
                                .environment(PostInteractionSettingsViewModel(account: authBox.cachedAccount, initialSettings: .accountDefaults, contentIncludesQuote: false))
                                .navigationTitle(L10n.Scene.Settings.PrivacySafety.title)
                        case .serverDetails:
                            ServerDetailsView()
                        }
                    default:
                        navigator.destinationView(destination, sceneCoordinator: nil)
                    }
                }
        }
        .modifier(NavigatorPresentations(navigator: navigator))
        .environment(navigator)
    }
}

struct SettingsRootView: View {
    @Environment(MastodonNavigationRouter.self) var navigator
    @Environment(\.openURL) private var openURL
    let domain: String
    
    var settingsGroups: [SettingsGroup] {
        let all: [SettingsGroup] = [ .basic, .server, .donations ].filter { group in
            switch group {
            case .basic, .server: return true
            case .donations: return Mastodon.Entity.DonationCampaign.isEligibleForDonationsSettingsSection(domain: domain)
            }
        }
        return all
    }
    
    var body: some View {
        Form {
            ForEach(settingsGroups) { group in
                Section {
                    ForEach(group.rows(domain: domain)) { row in
                        settingsRow(row)
                            .onTapGesture {
                                switch row.rowAction {
                                case .pushDestination(let destination):
                                    navigator.push(.settings(destination))
                                case .openUrl(let url):
                                    guard let url else { break }
                                    openURL(url)
                                case .makeDonation:
                                    let presentingNavigator = MastodonTabViewRouter.current.navigationRouterForCurrentTab()
                                    presentingNavigator.dismissCurrentModal()
                                    presentingNavigator.presentSheet(.makeDonation, afterDeconflictionDelay: true)
                                }
                            }
                    }
                }
            }
        }
    }
    
    @ViewBuilder func settingsRow(_ setting: SettingsRow) -> some View {
        HStack(alignment: .top) {
            setting.icon
                .foregroundStyle(setting.iconTint)
            
            VStack(alignment: .leading) {
                Text(setting.title)
                    .foregroundStyle(setting.textColor)
                
                if let secondaryTitle = setting.secondaryTitle {
                    Text(secondaryTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let navigation = setting.navigation {
                Spacer()
                Image(systemName: navigation == .inApp ? "chevron.right" : "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
    }
}

enum SettingsGroup: String, Identifiable {
    case basic
    case server
    case donations

    func rows(domain: String) -> [SettingsRow] {
        switch self {
        case .basic:
            [.general, .notifications, .privacySafety]
        case .server:
            [.serverDetails(domain: domain), .aboutMastodon, .donateToOsloTown]
        case .donations:
            [.makeDonation, .manageDonations]
        }
    }

    var id: String { rawValue }
}

enum SettingsRow: Hashable, Identifiable {
    case general
    case notifications
    case privacySafety
    case serverDetails(domain: String)
    case aboutMastodon
    case makeDonation
    case manageDonations
    case donateToOsloTown

    var id: Self { self }

    var title: String {
        switch self {
        case .general:
            return L10n.Scene.Settings.Overview.general
        case .notifications:
            return L10n.Scene.Settings.Overview.notifications
        case .privacySafety:
            return L10n.Scene.Settings.Overview.privacySafety
        case .serverDetails(_):
            return L10n.Scene.Settings.Overview.aboutOsloTown
        case .makeDonation:
            return L10n.Scene.Settings.Overview.supportMastodon
        case .manageDonations:
            return L10n.Scene.Settings.Donation.manage
        case .aboutMastodon:
            return L10n.Scene.Settings.Overview.aboutMastodon
        case .donateToOsloTown:
            return L10n.Scene.Settings.AboutMastodon.contributeToMastodon
        }
    }

    var secondaryTitle: String? {
        switch self {
        case .general, .notifications, .privacySafety, .makeDonation, .manageDonations, .aboutMastodon, .donateToOsloTown, .serverDetails(_):
            return nil
        }
    }
    
    enum NavigationType {
        case inApp
        case external
    }

    var navigation: NavigationType? {
        switch self {
        case .general, .notifications, .privacySafety, .serverDetails(_), .aboutMastodon:
            return .inApp
        case .manageDonations, .donateToOsloTown:
            return .external
        case .makeDonation:
            return nil
        }
    }

    var icon: Image {
        switch self {
        case .general:
            return Image(systemName: "gear")
        case .notifications:
            return Image(systemName: "bell.badge")
        case .privacySafety:
            return Image(systemName: "lock.fill")
        case .serverDetails(_), .aboutMastodon:
            return Image(systemName: "info.circle.fill")
        case .makeDonation, .donateToOsloTown:
            return Image(systemName: "heart.fill")
        case .manageDonations:
            return Image(systemName: "gear")
        }
    }

    var iconTint: Color {
        switch self {
        case .general:
            return .gray
        case .notifications:
            return .red
        case .privacySafety:
            return .blue
        case .serverDetails(_):
            return Asset.Colors.accent.swiftUIColor
        case .makeDonation, .manageDonations, .donateToOsloTown, .aboutMastodon:
            return Asset.Colors.accent.swiftUIColor
        }

    }

    var textColor: Color {
        switch self {
        case .general, .notifications, .privacySafety, .makeDonation, .manageDonations, .aboutMastodon, .serverDetails(_), .donateToOsloTown:
            return .primary
        }

    }
}

extension SettingsRow {
    var rowAction: SettingsRowAction {
        switch self {
        case .general:
            return .pushDestination(.generalSettings)
        case .notifications:
            return .pushDestination(.notificationsSettings)
        case .privacySafety:
            return .pushDestination(.privacyAndSafety)
        case .serverDetails:
            return .pushDestination(.serverDetails)
        case .aboutMastodon:
            return .pushDestination(.aboutMastodon)
        case .makeDonation:
            return .makeDonation
        case .manageDonations:
            return .openUrl(URL(string: "https://sponsor.joinmastodon.org/donate/manage"))
        case .donateToOsloTown:
            return .openUrl(URL(string: "https://patreon.com/oslotown"))
        }
    }
}

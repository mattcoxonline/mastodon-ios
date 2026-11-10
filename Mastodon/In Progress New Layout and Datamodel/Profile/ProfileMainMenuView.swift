// Copyright © 2026 Mastodon gGmbH. All rights reserved.
import SwiftUI
import MastodonAsset
import MastodonCore
import MastodonExtension
import MastodonLocalization
import MastodonUI

struct ProfileMainMenuView: View {
    @Environment(MastodonNavigationRouter.self) private var navigator
    @Environment(ProfileViewModel.self) private var myProfileViewModel: ProfileViewModel?
    @Environment(AuthenticationObserver.self) private var authenticationObserver
    
    @State private var bioText: String?
    
    var body: some View {
        GeometryReader { geo in
            let fullWidth = min(maxFeedContentWidth, geo.size.width)
            ScrollView {
                LazyVStack(alignment: .leading) {
                    profileCard
                    quickAccessGrid
                    Divider()
                    accountSection
                    alternateAccountButtons
                    pendingRegistrationButtons
                    addAccountButton
                    Divider()
                    logOutActiveUserButton
                }
                .padding(Spacing.l)
                .frame(width: fullWidth, alignment: .center)
                .frame(width: geo.size.width, alignment: .center)
            }
            .padding(.leading, geo.safeAreaInsets.leading)
            .padding(.trailing, geo.safeAreaInsets.trailing)
            .ignoresSafeArea(.container, edges: .horizontal)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigator.presentSheet(.settings, afterDeconflictionDelay: false)
                    } label: {
                        Image(phosphor: .gear)
                    }
                    .accessibilityLabel(L10n.Common.Controls.Actions.settings)
                }
            }
            .task(id: authenticationObserver.currentActiveUser?.globallyUniqueUserIdentifier) {
                guard let authBox = authenticationObserver.currentActiveUser else { return }
                await checkForCollections(authBox)
            }
        }
    }
    
    // MARK: Profile header (Option A: identity-first)
    @ViewBuilder private var profileCard: some View {
        if let currentActiveUser = authenticationObserver.currentActiveUser, let myProfileViewModel {
            let account = currentActiveUser.cachedAccount
            VStack(alignment: .leading, spacing: Spacing.s) {
                if let headerString = account?.header, !headerString.isEmpty,
                   let headerURL = URL(string: headerString), !headerString.hasSuffix("/") {
                    AsyncImage(url: headerURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.l))
                }
                
                HStack(alignment: .top, spacing: Spacing.s) {
                    AvatarView(style: .circular, size: .extraLarge, avatarSource: .url(account?.avatarURL))
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(account?.displayNameWithFallback ?? currentActiveUser.authentication.username)
                            .font(.title3)
                            .fontWeight(.bold)
                            .lineLimit(2)
                        Text("@\(account?.acctWithDomain ?? currentActiveUser.authentication.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                
                if let bioText, !bioText.isEmpty {
                    Text(bioText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                
                HStack(spacing: Spacing.xs) {
                    statChip(count: account?.statusesCount ?? 0, label: L10n.Scene.Profile.Dashboard.myPosts) {
                        navigator.push(.myProfile(myProfileViewModel))
                    }
                    if let account {
                        statChip(count: account.followersCount, label: L10n.Scene.Profile.Dashboard.myFollowers) {
                            navigator.push(.timeline(.followers(ofUserId: account.id)))
                        }
                        statChip(count: account.followingCount, label: L10n.Scene.Profile.Dashboard.myFollowing) {
                            navigator.push(.timeline(.accountsFollowed(byUserId: account.id)))
                        }
                    }
                }
                
                Button {
                    navigator.push(.myProfile(myProfileViewModel))
                } label: {
                    Text(L10nLookup.Scene.Profile.MainMenu.viewProfile)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(Spacing.s)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: Radius.l)
            )
            .task(id: account?.note) {
                guard let note = account?.note, !note.isEmpty else {
                    bioText = nil
                    return
                }
                bioText = await Task.detached(priority: .userInitiated) {
                    Self.plainTextFromHTML(note)
                }.value
            }
        }
    }
    
    private func statChip(count: Int, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.lockup) {
                Text(count.asAbbreviatedCountString())
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(capitalized(label))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
    }
    
    private func capitalized(_ string: String) -> String {
        guard let first = string.first else { return string }
        return String(first).uppercased() + string.dropFirst()
    }
    
    nonisolated private static func plainTextFromHTML(_ html: String) -> String? {
        guard let data = html.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else { return nil }
        return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: Quick access tiles
    @ViewBuilder private var quickAccessGrid: some View {
        if let currentUser = authenticationObserver.currentActiveUser, let account = currentUser.cachedAccount {
            let columns = [
                GridItem(.flexible(), spacing: Spacing.xs, alignment: .topLeading),
                GridItem(.flexible(), spacing: Spacing.xs, alignment: .topLeading)
            ]
            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                quickTile(.myFavorites, image: Image(phosphor: .heart))
                quickTile(.myBookmarks, image: Image(phosphor: .bookmarkSimple))
                quickTile(.followers(ofUserId: account.id), image: Image(phosphor: .usersThree), subtitle: account.followersCount.asAbbreviatedCountString())
                quickTile(.accountsFollowed(byUserId: account.id), image: Image(phosphor: .usersFour), subtitle: account.followingCount.asAbbreviatedCountString())
                if shouldShowCollectionsRow(userGUID: currentUser.globallyUniqueUserIdentifier) {
                    quickTile(.collections(curatedByUserID: currentUser.userID), image: Image(phosphor: .circlesFour))
                }
            }
        }
    }
    
    private func quickTile(_ timelineType: MastodonTimelineType, image: Image, subtitle: String? = nil) -> some View {
        Button {
            navigator.push(.timeline(timelineType))
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                image
                    .font(.system(size: iconFontSize))
                    .foregroundStyle(Asset.Colors.accent.swiftUIColor)
                Text(timelineType.navigationTitle ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.s)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: Radius.l)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: Account maintenance
    @ViewBuilder private var accountSection: some View {
        if let myProfileViewModel {
            navigationRow(L10nLookup.Scene.EditProfile.title, icon: .image(Image(phosphor: .user)), navigatingTo: .editProfile(profileViewModel: myProfileViewModel))
        }
        if let account = authenticationObserver.currentActiveUser?.cachedAccount {
            timelineRow(.myBlockedAccounts, image: Image(phosphor: .prohibit))
        }
    }
    
    // MARK: Collections
    @State private var hasCollections: [ String : Bool ] = [:]
    private var collectionsAreAvailable: Bool {
        authenticationObserver.currentActiveUser?.authentication.instanceConfiguration?.isAvailable(.collections) == true
    }
    private func shouldShowCollectionsRow(userGUID: String) -> Bool {
        collectionsAreAvailable && (UserDefaults.standard.allowCreateCollections || hasCollections[userGUID] == true)
    }
    private func checkForCollections(_ authBox: MastodonAuthenticationBox) async {
        guard collectionsAreAvailable, let response = try? await APIService.shared.collections(accountID: authBox.userID, authenticationBox: authBox) else { return }
        hasCollections[authBox.globallyUniqueUserIdentifier] = !response.value.collections.isEmpty
    }
    
    // MARK: Relationship buttons
    @ViewBuilder private var relationshipButtons: some View {
        if let currentAcct = authenticationObserver.currentActiveUser?.cachedAccount {
            // Followers
            timelineRow(.followers(ofUserId: currentAcct.id), image: Image(phosphor: .usersThree))
            // Following
            timelineRow(.accountsFollowed(byUserId: currentAcct.id), image: Image(phosphor: .usersFour))
            // Blocked Accounts
            timelineRow(.myBlockedAccounts, image: Image(phosphor: .prohibit))
        }
    }
    
    @State private var isConfirmingLogOut: LogOutConfirmationType?
    @ViewBuilder private var logOutActiveUserButton: some View {
        menuRow(L10n.Scene.AccountList.logout, icon: .image(Image(phosphor: .signOut)), role: .destructive) {
            isConfirmingLogOut = .logOutActiveAccount
        }
        .disabled(isConfirmingLogOut != nil)
        .confirmationDialog(isConfirmingLogOut?.title ?? "",
                            isPresented:
                                Binding<Bool>(
                                    get: { isConfirmingLogOut == .logOutActiveAccount },
                                    set: { newValue in
                                        if !newValue {
                                            isConfirmingLogOut = nil
                                        }
                                    }),
                            presenting: isConfirmingLogOut) { logOutType in
            Button(role: .destructive) {
                isConfirmingLogOut = nil
                guard let currentUser = authenticationObserver.currentActiveUser else { return }
                Task {
                    await AuthenticationServiceProvider.shared.signOutMastodonUser(authentication: currentUser.authentication)
                }
            } label: {
                Text(logOutType.buttonText)
            }
            Button(role: .cancel) {
                isConfirmingLogOut = nil
            } label: {
                Text(L10n.Common.Controls.Actions.cancel)
            }
        } message: { logOutType in
            Text(logOutType.message)
        }
    }
    
    @ViewBuilder private var alternateAccountButtons: some View {
        // List additional logged-in accounts, with their unread notification counts if non-zero
        ForEach(authenticationObserver.allLoggedInUsers.filter({ $0.globallyUniqueUserIdentifier != authenticationObserver.currentActiveUser?.globallyUniqueUserIdentifier }), id: \.self.globallyUniqueUserIdentifier) { authBox in
            
            let account = authBox.cachedAccount
            menuRow(account.map{ "@\($0.acctWithDomain)" } ?? "", icon: .avatar(account?.avatarURL)) {
                authenticationObserver.switchTo(authBox)
            } accessory: {
                let unreadNotificationCount = UnreadNotificationCounts.shared.unreadCount(for: authBox)
                if unreadNotificationCount > 0 {
                    Text(unreadNotificationCount.formatted())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder private var pendingRegistrationButtons: some View {
        // List accounts that have been registered using the app but have not yet been verified/approved
        ForEach(authenticationObserver.pendingRegistrations, id: \.self.globallyUniqueUserIdentifier) { authBox in
            let account = authBox.cachedAccount
            menuRow(account.map { "@\($0.acctWithDomain)" } ?? "@\(authBox.authentication.username)@\(authBox.domain)", icon: .avatar(account?.avatarURL)) {
                navigator.presentSheet(.pendingRegistration(authBox), afterDeconflictionDelay: false)
            } accessory: {
                Text(L10nLookup.Scene.Onboarding.AccountNonfunctional.pendingRegistrationTag)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder private var addAccountButton: some View {
        menuRow(L10n.Scene.AccountList.addAccount, icon: .image(Image(phosphor: .userPlus))) {
            navigator.presentSheet(.welcome, afterDeconflictionDelay: false)
        }
    }
    
    private enum MenuRowIcon {
        case image(Image)
        case avatar(URL?)
    }
    private let avatarSize = AvatarSize.small
    private var iconSlotSize: CGFloat { avatarSize.rawValue }
    private let iconFontSize: CGFloat = 26
    @ViewBuilder private func rowIcon(_ icon: MenuRowIcon) -> some View {
        switch icon {
        case .image(let image):
            image
                .font(.system(size: iconFontSize))
        case .avatar(let url):
            AvatarView(style: .circular, size: avatarSize, avatarSource: .url(url))
        }
    }
    
    @ViewBuilder private func menuRow<Accessory: View>(_ title: String, icon: MenuRowIcon, role: ButtonRole? = nil, action: @escaping () -> Void, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) -> some View {
        Button(role: role, action: action) {
            HStack(alignment: .firstTextBaseline) {
                Label {
                    Text(title)
                        .font(.body)
                } icon: {
                    rowIcon(icon)
                        .frame(width: iconSlotSize, height: iconSlotSize)
                }
                Spacer()
                accessory()
            }
            .contentShape(Rectangle())
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.xs)
    }
    
    @ViewBuilder private func navigationRow(_ title: String, icon: MenuRowIcon, navigatingTo destination: MastodonNavigationDestination) -> some View {
        menuRow(title, icon: icon, role: nil) { navigator.push(destination) }
    }
    
    @ViewBuilder private func timelineRow(_ timelineType: MastodonTimelineType, image: Image) -> some View {
        navigationRow(timelineType.navigationTitle ?? "", icon: .image(image), navigatingTo: .timeline(timelineType))
    }
}

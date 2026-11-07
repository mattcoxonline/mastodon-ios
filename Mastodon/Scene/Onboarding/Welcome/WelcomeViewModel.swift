//
//  WelcomeViewModel.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-9-15.
//

import Foundation
import Combine
import MastodonCore
import MastodonSDK

@MainActor
final class WelcomeViewModel {
 
    var disposeBag = Set<AnyCancellable>()
    var randomDefaultServer: Mastodon.Entity.Server?
    
    // output
    @Published var needsShowDismissEntry = false
    
    init() {
        AuthenticationServiceProvider.shared.$mastodonAuthenticationBoxes
            .map { !$0.isEmpty }
            .assign(to: &$needsShowDismissEntry)
    }

    // oslo.town is a single-instance app: the only server offered
    func downloadDefaultServer(completion: (() -> Void)? = nil) {
        randomDefaultServer = Mastodon.Entity.Server.osloDotTown
        completion?()
    }

    func pickRandomDefaultServer() -> Mastodon.Entity.Server? {
        Mastodon.Entity.Server.osloDotTown
    }
}

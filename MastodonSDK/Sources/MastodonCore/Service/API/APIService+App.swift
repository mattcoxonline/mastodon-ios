//
//  APIService+App.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021/2/2.
//

import Foundation
import Combine
import MastodonSDK

extension APIService {

    private static let clientName = "oslo.town for iOS"

    private static let appWebsite = "https://oslo.town"
    
    public func createApplication(domain: String) async throws -> Mastodon.Entity.Application {
        let query = Mastodon.API.App.CreateQuery(
            clientName: APIService.clientName,
            redirectURIs: APIService.oauthCallbackURL,
            website: APIService.appWebsite
        )
        return try await Mastodon.API.App.create(
            session: session,
            domain: domain,
            query: query
        )
    }

}


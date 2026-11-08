//
//  AppContext.swift
//  
//
//  Created by MainasuK on 22/9/30.
//

import UIKit
import SwiftUI
import Combine
import SDWebImage

@MainActor
public class AppContext: ObservableObject {
    public static let shared = { AppContext() }()
    
    public var disposeBag = Set<AnyCancellable>()

    public let placeholderImageCacheService = PlaceholderImageCacheService()
    public let blurhashImageCacheService = BlurhashImageCacheService.shared
    
    let overrideTraitCollection = CurrentValueSubject<UITraitCollection?, Never>(nil)
    let timestampUpdatePublisher = Timer.publish(every: 1.0, on: .main, in: .common)
        .autoconnect()
        .share()
        .eraseToAnyPublisher()
    
    private init() {
        // Cap the image cache so timeline media and avatars don't
        // accumulate to hundreds of MB of decoded pixels. 100MB memory
        // covers roughly 250 screen-sized images — enough for a full
        // scroll session. SDWebImage also auto-purges on background
        // entry and memory warnings (built-in).
        SDImageCache.shared.config.maxMemoryCost = 100 * 1024 * 1024
        SDImageCache.shared.config.maxDiskSize = 200 * 1024 * 1024
        SDImageCache.shared.config.maxDiskAge = 7 * 24 * 60 * 60 // 1 week
    }
}

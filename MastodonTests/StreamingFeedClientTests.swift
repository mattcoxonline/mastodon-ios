//  StreamingFeedClientTests.swift
//  MastodonTests

import XCTest
@testable import Mastodon

final class StreamingFeedClientTests: XCTestCase {

    // A capture-shaped `update` frame (the payload is a JSON document encoded
    // as a string inside the outer frame), with neutralized content.
    private static let updateFrame = #"""
{"stream":["user"],"event":"update","payload":"{\"id\":\"12345\",\"created_at\":\"2026-11-08T18:06:22.000Z\",\"in_reply_to_id\":null,\"in_reply_to_account_id\":null,\"sensitive\":false,\"spoiler_text\":\"\",\"visibility\":\"public\",\"language\":\"en\",\"uri\":\"https://oslo.town/users/example/statuses/12345\",\"url\":\"https://oslo.town/@example/12345\",\"replies_count\":0,\"reblogs_count\":0,\"favourites_count\":0,\"quotes_count\":0,\"edited_at\":null,\"content\":\"<p>hello from the streaming server</p>\",\"reblog\":null,\"account\":{\"id\":\"42\",\"username\":\"example\",\"acct\":\"example@oslo.town\",\"display_name\":\"Example User\",\"locked\":false,\"bot\":true,\"discoverable\":true,\"indexable\":true,\"group\":false,\"created_at\":\"2025-02-21T00:00:00.000Z\",\"note\":\"<p>example bio</p>\",\"url\":\"https://oslo.town/@example\",\"uri\":\"https://oslo.town/users/example\",\"avatar\":\"https://oslo.town/avatars/example.png\",\"avatar_static\":\"https://oslo.town/avatars/example.png\",\"avatar_description\":\"graphic that says make art not billionaires in pink and green with a spray painted smiley face in the center\",\"header\":\"https://oslo.town/headers/example.png\",\"header_static\":\"https://oslo.town/headers/example.png\",\"header_description\":\"a cartoon catellite in white against a green background\",\"followers_count\":234,\"following_count\":6,\"statuses_count\":16583,\"last_status_at\":\"2026-11-08\",\"hide_collections\":true,\"show_media\":true,\"show_media_replies\":true,\"show_featured\":true,\"feature_approval\":{\"automatic\":[\"public\"],\"manual\":[],\"current_user\":\"denied\"},\"emojis\":[],\"fields\":[{\"name\":\"LISTEN LIVE\",\"value\":\"<a href=\\\"https://theindiebeat.fm\\\" rel=\\\"nofollow noopener\\\" translate=\\\"no\\\" target=\\\"_blank\\\"><span class=\\\"invisible\\\">https://</span><span class=\\\"\\\">theindiebeat.fm</span><span class=\\\"invisible\\\"></span></a>\",\"verified_at\":null},{\"name\":\"FEDIWALL\",\"value\":\"<a href=\\\"https://fediwall.social/?servers=mastodon.social&amp;tags=tibrnowplaying&amp;accounts=&amp;hide=replies,boosts&amp;title=Now+Playing+on+The+Indie+Beat+Radio+theindiebeat.fm&amp;theme=auto&amp;limit=100&amp;interval=30\\\" rel=\\\"nofollow noopener\\\" translate=\\\"no\\\" target=\\\"_blank\\\"><span class=\\\"invisible\\\">https://</span><span class=\\\"ellipsis\\\">fediwall.social/?servers=masto</span><span class=\\\"invisible\\\">don.social&amp;tags=tibrnowplaying&amp;accounts=&amp;hide=replies,boosts&amp;title=Now+Playing+on+The+Indie+Beat+Radio+theindiebeat.fm&amp;theme=auto&amp;limit=100&amp;interval=30</span></a>\",\"verified_at\":null},{\"name\":\"WATCH TV\",\"value\":\"<a href=\\\"https://tv.theindiebeat.fm\\\" rel=\\\"nofollow noopener\\\" translate=\\\"no\\\" target=\\\"_blank\\\"><span class=\\\"invisible\\\">https://</span><span class=\\\"\\\">tv.theindiebeat.fm</span><span class=\\\"invisible\\\"></span></a>\",\"verified_at\":null},{\"name\":\"NOW PLAYING TV\",\"value\":\"<span class=\\\"h-card\\\" translate=\\\"no\\\"><a href=\\\"https://mastodon.social/@tibtvnowplayingbot\\\" class=\\\"u-url mention\\\" rel=\\\"nofollow noopener\\\" target=\\\"_blank\\\">@<span>tibtvnowplayingbot</span></a></span>\",\"verified_at\":null}]},\"media_attachments\":[],\"mentions\":[],\"tags\":[],\"emojis\":[],\"tagged_collections\":[],\"quote\":null,\"card\":null,\"poll\":null,\"quote_approval\":{\"automatic\":[\"public\"],\"manual\":[],\"current_user\":\"denied\"}}"}
"""#

    private static let deleteFrame = #"""
{"stream":["user"],"event":"delete","payload":"12345"}
"""#

    private static let statusUpdateFrame = #"""
{"stream":["user"],"event":"status.update","payload":"{\"id\":\"12345\",\"created_at\":\"2026-11-08T18:06:22.000Z\",\"in_reply_to_id\":null,\"in_reply_to_account_id\":null,\"sensitive\":false,\"spoiler_text\":\"\",\"visibility\":\"public\",\"language\":\"en\",\"uri\":\"https://oslo.town/users/example/statuses/12345\",\"url\":\"https://oslo.town/@example/12345\",\"replies_count\":0,\"reblogs_count\":0,\"favourites_count\":0,\"quotes_count\":0,\"edited_at\":null,\"content\":\"<p>hello from the streaming server</p>\",\"reblog\":null,\"account\":{\"id\":\"42\",\"username\":\"example\",\"acct\":\"example@oslo.town\",\"display_name\":\"Example User\",\"locked\":false,\"bot\":true,\"discoverable\":true,\"indexable\":true,\"group\":false,\"created_at\":\"2025-02-21T00:00:00.000Z\",\"note\":\"<p>example bio</p>\",\"url\":\"https://oslo.town/@example\",\"uri\":\"https://oslo.town/users/example\",\"avatar\":\"https://oslo.town/avatars/example.png\",\"avatar_static\":\"https://oslo.town/avatars/example.png\",\"avatar_description\":\"graphic that says make art not billionaires in pink and green with a spray painted smiley face in the center\",\"header\":\"https://oslo.town/headers/example.png\",\"header_static\":\"https://oslo.town/headers/example.png\",\"header_description\":\"a cartoon catellite in white against a green background\",\"followers_count\":234,\"following_count\":6,\"statuses_count\":16583,\"last_status_at\":\"2026-11-08\",\"hide_collections\":true,\"show_media\":true,\"show_media_replies\":true,\"show_featured\":true,\"feature_approval\":{\"automatic\":[\"public\"],\"manual\":[],\"current_user\":\"denied\"},\"emojis\":[],\"fields\":[{\"name\":\"LISTEN LIVE\",\"value\":\"<a href=\\\"https://theindiebeat.fm\\\" rel=\\\"nofollow noopener\\\" translate=\\\"no\\\" target=\\\"_blank\\\"><span class=\\\"invisible\\\">https://</span><span class=\\\"\\\">theindiebeat.fm</span><span class=\\\"invisible\\\"></span></a>\",\"verified_at\":null},{\"name\":\"FEDIWALL\",\"value\":\"<a href=\\\"https://fediwall.social/?servers=mastodon.social&amp;tags=tibrnowplaying&amp;accounts=&amp;hide=replies,boosts&amp;title=Now+Playing+on+The+Indie+Beat+Radio+theindiebeat.fm&amp;theme=auto&amp;limit=100&amp;interval=30\\\" rel=\\\"nofollow noopener\\\" translate=\\\"no\\\" target=\\\"_blank\\\"><span class=\\\"invisible\\\">https://</span><span class=\\\"ellipsis\\\">fediwall.social/?servers=masto</span><span class=\\\"invisible\\\">don.social&amp;tags=tibrnowplaying&amp;accounts=&amp;hide=replies,boosts&amp;title=Now+Playing+on+The+Indie+Beat+Radio+theindiebeat.fm&amp;theme=auto&amp;limit=100&amp;interval=30</span></a>\",\"verified_at\":null},{\"name\":\"WATCH TV\",\"value\":\"<a href=\\\"https://tv.theindiebeat.fm\\\" rel=\\\"nofollow noopener\\\" translate=\\\"no\\\" target=\\\"_blank\\\"><span class=\\\"invisible\\\">https://</span><span class=\\\"\\\">tv.theindiebeat.fm</span><span class=\\\"invisible\\\"></span></a>\",\"verified_at\":null},{\"name\":\"NOW PLAYING TV\",\"value\":\"<span class=\\\"h-card\\\" translate=\\\"no\\\"><a href=\\\"https://mastodon.social/@tibtvnowplayingbot\\\" class=\\\"u-url mention\\\" rel=\\\"nofollow noopener\\\" target=\\\"_blank\\\">@<span>tibtvnowplayingbot</span></a></span>\",\"verified_at\":null}]},\"media_attachments\":[],\"mentions\":[],\"tags\":[],\"emojis\":[],\"tagged_collections\":[],\"quote\":null,\"card\":null,\"poll\":null,\"quote_approval\":{\"automatic\":[\"public\"],\"manual\":[],\"current_user\":\"denied\"}}"}
"""#

    func test_decodeUpdateFrame() {
        let event = StreamingFeedClient.decodeEvent(fromText: Self.updateFrame)
        guard case .newPost(let status) = event else {
            return XCTFail("expected .newPost, got \(String(describing: event))")
        }
        XCTAssertEqual(status.id, "12345")
        XCTAssertEqual(status.account.acct, "example@oslo.town")
        XCTAssertEqual(status.account.displayName, "Example User")
        XCTAssertTrue(status.content?.contains("streaming server") == true)
        XCTAssertTrue(status.createdAt.timeIntervalSince1970 > 1_000_000_000)
    }

    func test_decodeDeleteFrame() {
        let event = StreamingFeedClient.decodeEvent(fromText: Self.deleteFrame)
        guard case .deletedPost(let id) = event else {
            return XCTFail("expected .deletedPost")
        }
        XCTAssertEqual(id, "12345")
    }

    func test_ignoresStatusUpdateFrame() {
        XCTAssertNil(StreamingFeedClient.decodeEvent(fromText: Self.statusUpdateFrame))
    }

    func test_ignoresNonFrameText() {
        XCTAssertNil(StreamingFeedClient.decodeEvent(fromText: "not json at all"))
    }
}

//  StreamingFeedClient.swift
//  Mastodon
//
//  Maintains a Mastodon streaming (WebSocket) connection for one feed channel.
//  Phase 1 scope: the `user` channel (home timeline), handling `update` and
//  `delete` events. Other events are decoded-and-discarded.
//

import Foundation
import MastodonSDK

enum StreamedFeedEvent {
    case newPost(Mastodon.Entity.Status)
    case deletedPost(Mastodon.Entity.Status.ID)
}

@MainActor
final class StreamingFeedClient: NSObject {

    /// Delivered on the main actor. `newPost` payloads are decoded off the main
    /// actor before delivery.
    var onEvent: ((StreamedFeedEvent) -> Void)?
    /// Fired when a previously-established connection is re-established after a
    /// drop (not on the first connect). Callers use this to gap-fill via REST.
    var onReconnected: (() -> Void)?

    private let domain: String
    private let accessToken: String
    private let streamName: String

    private var session: URLSession?
    private var socket: URLSessionWebSocketTask?
    private var generation = 0
    private var hasConnectedBefore = false
    private var shouldReconnect = false
    private var reconnectAttempt = 0
    private var isReconnectPending = false

    enum ConnectionState {
        case idle
        case connecting
        case connected
    }
    private(set) var state: ConnectionState = .idle

    init(domain: String, accessToken: String, stream: String = "user") {
        self.domain = domain
        self.accessToken = accessToken
        self.streamName = stream
        super.init()
    }

    // MARK: - Lifecycle

    deinit {
        // In case deinit happens without a stop(): cancel the socket directly.
        // Stored-property access in deinit is nonisolated; URLSession calls are
        // safe off the main actor.
        socket?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }

    func start() {
        guard state == .idle else { return }
        connect()
    }

    func stop() {
        shouldReconnect = false
        isReconnectPending = false
        generation &+= 1
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        state = .idle
    }

    private func connect() {
        guard let url = url else { return }
        shouldReconnect = true
        state = .connecting
        generation &+= 1
        let session = URLSession(configuration: .ephemeral, delegate: DelegateRef(client: self), delegateQueue: nil)
        self.session = session
        let socket = session.webSocketTask(with: url)
        self.socket = socket
        socket.resume()
    }

    private func scheduleReconnect() {
        guard shouldReconnect, !isReconnectPending else { return }
        isReconnectPending = true
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(reconnectAttempt - 1)), 30.0)
        let scheduledGeneration = generation
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.shouldReconnect, self.generation == scheduledGeneration else { return }
            self.isReconnectPending = false
            self.connect()
        }
    }

    private var url: URL? {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = domain
        components.path = "/api/v1/streaming"
        components.queryItems = [
            URLQueryItem(name: "access_token", value: accessToken),
            URLQueryItem(name: "stream", value: streamName)
        ]
        return components.url
    }

    // MARK: - Socket events (called on the main actor via the delegate shim)

    fileprivate func didOpen() {
        guard shouldReconnect else { return } // stop() may have raced the open handshake
        state = .connected
        reconnectAttempt = 0
        if hasConnectedBefore {
            onReconnected?()
        }
        hasConnectedBefore = true
        receiveNext()
    }

    fileprivate func didDrop() {
        guard shouldReconnect, state != .idle else { return }
        state = .connecting
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        scheduleReconnect()
    }

    private func receiveNext() {
        guard state == .connected else { return }
        socket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handleReceive(result)
            }
        }
    }

    private func handleReceive(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(.string(let text)):
            if let event = Self.decodeEvent(fromText: text) {
                onEvent?(event)
            }
            receiveNext()
        case .success:
            receiveNext()
        case .failure:
            // receive failure means the connection is gone; the close/error
            // delegate callbacks will drive reconnection
            didDrop()
        }
    }

    // MARK: - Frame decoding

    private struct StreamingFrame: Decodable {
        let stream: [String]?
        let event: String
        let payload: String?
    }

    /// A single streaming frame, as sent by the Mastodon streaming server.
    /// `payload` is a string: for `update` it contains the post's JSON; for
    /// `delete` it is the deleted status ID.
    nonisolated static func decodeEvent(fromText text: String) -> StreamedFeedEvent? {
        guard let frameData = text.data(using: .utf8),
              let frame = try? JSONDecoder().decode(StreamingFrame.self, from: frameData),
              let payload = frame.payload else { return nil }
        switch frame.event {
        case "update":
            guard let payloadData = payload.data(using: .utf8),
                  let status = try? Self.payloadDecoder.decode(Mastodon.Entity.Status.self, from: payloadData) else { return nil }
            return .newPost(status)
        case "delete":
            return .deletedPost(payload)
        default:
            return nil
        }
    }

    /// Mirrors the SDK's decoder date strategy (fractional-second ISO 8601,
    /// plain ISO 8601, or a unix timestamp).
    private nonisolated static let payloadDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder throws -> Date in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions.insert(.withFractionalSeconds)
            if let date = fractionalFormatter.date(from: string) { return date }
            let fullDateFormatter = ISO8601DateFormatter()
            fullDateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            if let date = fullDateFormatter.date(from: string) { return date }
            if let date = ISO8601DateFormatter().date(from: string) { return date }
            if let timestamp = TimeInterval(string) { return Date(timeIntervalSince1970: timestamp) }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unparseable date: \(string)")
        }
        return decoder
    }()
}

/// Delegate shim: URLSession holds its delegate strongly, so the client is
/// wrapped weakly to avoid a retain cycle; methods hop to the main actor.
private final class DelegateRef: NSObject, URLSessionWebSocketDelegate {
    weak var client: StreamingFeedClient?

    init(client: StreamingFeedClient) {
        self.client = client
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor [weak self] in
            self?.client?.didOpen()
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor [weak self] in
            self?.client?.didDrop()
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        Task { @MainActor [weak self] in
            self?.client?.didDrop()
        }
    }
}

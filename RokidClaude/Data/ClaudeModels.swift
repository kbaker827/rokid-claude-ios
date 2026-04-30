import Foundation

// MARK: - Conversation message

struct ClaudeMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id        = id
        self.role      = role
        self.content   = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user, assistant, system
}

// MARK: - API request / response models

struct ClaudeAPIRequest: Encodable {
    let model:      String
    let maxTokens:  Int
    let system:     String?
    let messages:   [APIMessage]
    let stream:     Bool

    struct APIMessage: Encodable {
        let role:    String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, system
        case maxTokens = "max_tokens"
    }
}

struct ClaudeAPIResponse: Decodable {
    let id:      String
    let type:    String
    let content: [ContentBlock]
    let usage:   Usage?

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    struct Usage: Decodable {
        let inputTokens:  Int
        let outputTokens: Int
        enum CodingKeys: String, CodingKey {
            case inputTokens  = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    var fullText: String {
        content.compactMap { $0.text }.joined()
    }
}

// MARK: - Streaming SSE event types

struct StreamDelta: Decodable {
    let type:  String
    let delta: DeltaPayload?
    let index: Int?

    struct DeltaPayload: Decodable {
        let type: String?
        let text: String?
    }
}

// MARK: - Available models

struct ClaudeModel: Identifiable, Equatable {
    let id: String
    let displayName: String
    let description: String

    static let all: [ClaudeModel] = [
        ClaudeModel(id: "claude-haiku-4-5",  displayName: "Claude Haiku",   description: "Fastest — ideal for real-time glasses HUD"),
        ClaudeModel(id: "claude-sonnet-4-5",  displayName: "Claude Sonnet",  description: "Balanced speed and intelligence"),
        ClaudeModel(id: "claude-opus-4-5",    displayName: "Claude Opus",    description: "Most capable, slower"),
    ]

    static let `default` = all[0]
}

// MARK: - Glasses display format

enum GlassesFormat: String, CaseIterable, Identifiable {
    case streaming, summary, minimal
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .streaming: return "Streaming"
        case .summary:   return "Summary"
        case .minimal:   return "Minimal"
        }
    }
    var description: String {
        switch self {
        case .streaming: return "Show response as it arrives"
        case .summary:   return "Show first 2 sentences"
        case .minimal:   return "Show single key phrase"
        }
    }
}

// MARK: - Input mode

enum InputMode {
    case idle, listening, thinking, responding
    var label: String {
        switch self {
        case .idle:      return "Ready"
        case .listening: return "Listening…"
        case .thinking:  return "Thinking…"
        case .responding: return "Responding…"
        }
    }
}

// MARK: - Glasses wire protocol

struct GlassesPacket {
    /// Query sent FROM glasses/TCP client → phone
    static func parseQuery(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("QUERY:") {
            return String(trimmed.dropFirst("QUERY:".count)).trimmingCharacters(in: .whitespaces)
        }
        // Plain text with no prefix also accepted as query
        if !trimmed.isEmpty && !trimmed.hasPrefix("{") { return trimmed }
        return nil
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case noAPIKey
    case httpError(Int, String)
    case streamError(String)
    case speechUnavailable

    var errorDescription: String? {
        switch self {
        case .noAPIKey:               return "No API key. Enter it in Settings."
        case .httpError(let c, let m): return "API error \(c): \(m)"
        case .streamError(let m):     return "Stream error: \(m)"
        case .speechUnavailable:      return "Speech recognition unavailable on this device."
        }
    }
}

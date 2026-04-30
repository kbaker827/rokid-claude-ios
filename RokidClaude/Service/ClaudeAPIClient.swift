import Foundation

// MARK: - Claude API Client (streaming SSE)

actor ClaudeAPIClient {

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 120
        return URLSession(configuration: cfg)
    }()

    // MARK: - Streaming send

    /// Sends messages to Claude and returns an AsyncStream of text deltas.
    /// The stream ends when Claude finishes, or throws on error.
    func stream(
        messages: [ClaudeMessage],
        apiKey:   String,
        modelId:  String,
        systemPrompt: String?,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = try self.buildRequest(
                        messages:     messages,
                        apiKey:       apiKey,
                        modelId:      modelId,
                        systemPrompt: systemPrompt,
                        maxTokens:    maxTokens,
                        stream:       true
                    )

                    let (bytes, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                        // Collect error body
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line }
                        throw ClaudeError.httpError(http.statusCode, errorBody.prefix(300).description)
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst("data: ".count))
                        guard jsonStr != "[DONE]" else { break }
                        guard let data = jsonStr.data(using: .utf8) else { continue }

                        if let event = try? JSONDecoder().decode(StreamDelta.self, from: data) {
                            if event.type == "content_block_delta",
                               let text = event.delta?.text {
                                continuation.yield(text)
                            }
                            if event.type == "message_stop" { break }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Non-streaming (for completions where full response is needed)

    func send(
        messages: [ClaudeMessage],
        apiKey:   String,
        modelId:  String,
        systemPrompt: String?,
        maxTokens: Int
    ) async throws -> String {
        let request = try buildRequest(
            messages:     messages,
            apiKey:       apiKey,
            modelId:      modelId,
            systemPrompt: systemPrompt,
            maxTokens:    maxTokens,
            stream:       false
        )
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ClaudeError.httpError(http.statusCode, body.prefix(300).description)
        }
        let resp = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
        return resp.fullText
    }

    // MARK: - Request builder

    private func buildRequest(
        messages:     [ClaudeMessage],
        apiKey:       String,
        modelId:      String,
        systemPrompt: String?,
        maxTokens:    Int,
        stream:       Bool
    ) throws -> URLRequest {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,              forHTTPHeaderField: "x-api-key")
        req.setValue(apiVersion,          forHTTPHeaderField: "anthropic-version")

        let apiMessages = messages
            .filter { $0.role != .system }
            .map { ClaudeAPIRequest.APIMessage(role: $0.role.rawValue, content: $0.content) }

        let body = ClaudeAPIRequest(
            model:       modelId,
            maxTokens:   maxTokens,
            system:      systemPrompt?.isEmpty == false ? systemPrompt : nil,
            messages:    apiMessages,
            stream:      stream
        )

        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(body)
        return req
    }
}

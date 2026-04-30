import Foundation
import Combine

@MainActor
final class ClaudeViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var messages:      [ClaudeMessage] = []
    @Published private(set) var inputMode:     InputMode = .idle
    @Published private(set) var streamingText: String = ""
    @Published private(set) var glassesClientCount = 0
    @Published              var draftText:     String = ""
    @Published private(set) var error: String?

    // MARK: - Dependencies

    let settings      = SettingsStore.shared
    let speechManager = SpeechManager()
    private let api   = ClaudeAPIClient()
    private let glasses = GlassesServer()

    // MARK: - Streaming task

    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        glasses.start()
        glasses.onRemoteQuery = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self, self.settings.glassesQueryEnabled else { return }
                await self.send(text: text, fromGlasses: true)
            }
        }
        speechManager.onSilence = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self, self.settings.autoSendVoice else { return }
                await self.send(text: text, fromGlasses: false)
            }
        }
        Task { await speechManager.requestPermissions() }
    }

    deinit {
        streamTask?.cancel()
    }

    // MARK: - Send message

    func sendDraft() async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draftText = ""
        await send(text: text, fromGlasses: false)
    }

    func send(text: String, fromGlasses: Bool) async {
        guard settings.hasAPIKey else {
            error = ClaudeError.noAPIKey.localizedDescription
            return
        }
        guard inputMode == .idle else { return }

        error = nil

        // Add user message
        let userMsg = ClaudeMessage(role: .user, content: text)
        messages.append(userMsg)
        glasses.sendQuery(text)

        // Add placeholder assistant message for streaming
        let assistantMsg = ClaudeMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantIdx = messages.count - 1

        inputMode     = .thinking
        streamingText = ""
        glasses.sendThinking()

        // Build history (trimmed to maxHistory pairs)
        let history = trimmedHistory()

        streamTask?.cancel()
        streamTask = Task {
            var fullText = ""
            do {
                let stream = await api.stream(
                    messages:     history,
                    apiKey:       settings.apiKey,
                    modelId:      settings.modelId,
                    systemPrompt: settings.systemPrompt,
                    maxTokens:    settings.maxTokens
                )

                inputMode = .responding

                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    fullText += chunk
                    streamingText = fullText

                    // Update the assistant message in place
                    if assistantIdx < messages.count {
                        messages[assistantIdx].content = fullText
                    }

                    // Stream chunk to glasses
                    if settings.glassesFormat == .streaming {
                        glasses.sendChunk(chunk)
                    }
                }

                // Send final formatted response
                if !fullText.isEmpty {
                    glasses.sendResponse(fullText, format: settings.glassesFormat)
                }

            } catch {
                if !Task.isCancelled {
                    let msg = error.localizedDescription
                    self.error = msg
                    glasses.sendError(msg)
                    if assistantIdx < messages.count {
                        messages.remove(at: assistantIdx)
                    }
                }
            }

            streamingText = ""
            inputMode     = .idle
            glassesClientCount = glasses.clientCount
        }
    }

    // MARK: - Voice

    func startVoice() {
        guard inputMode == .idle else { return }
        speechManager.startListening()
        inputMode = .listening
    }

    func stopVoice() async {
        let text = speechManager.stopListening()
        inputMode = .idle
        if !text.isEmpty { await send(text: text, fromGlasses: false) }
    }

    func cancelVoice() {
        speechManager.cancelListening()
        inputMode = .idle
    }

    // MARK: - Stop streaming

    func stopStream() {
        streamTask?.cancel()
        streamTask  = nil
        inputMode   = .idle
        streamingText = ""
    }

    // MARK: - Clear conversation

    func clearConversation() {
        streamTask?.cancel()
        messages      = []
        streamingText = ""
        inputMode     = .idle
        draftText     = ""
        error         = nil
        glasses.sendClear()
    }

    // MARK: - History trimming

    private func trimmedHistory() -> [ClaudeMessage] {
        // Keep the last N user+assistant pairs, excluding the streaming placeholder
        let completed = messages.dropLast()  // drop current empty assistant message
        let max       = settings.maxHistory * 2
        let trimmed   = completed.suffix(max)
        return Array(trimmed)
    }

    // MARK: - Quick prompts

    var suggestedPrompts: [String] = [
        "What time is it?",
        "Give me a quick fun fact.",
        "Summarize what AR glasses are.",
        "What's 15% of 85?",
        "Tell me a one-sentence joke.",
        "What should I know about this situation?",
    ]
}

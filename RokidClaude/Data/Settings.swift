import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Key {
        static let apiKey         = "claude_api_key"
        static let modelId        = "claude_model_id"
        static let systemPrompt   = "system_prompt"
        static let glassesFormat  = "glasses_format"
        static let maxTokens      = "max_tokens"
        static let maxHistory     = "max_history"
        static let voiceEnabled   = "voice_enabled"
        static let autoSendVoice  = "auto_send_voice"
        static let glassesQuery   = "glasses_query_enabled"
    }

    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Key.apiKey) }
    }
    @Published var modelId: String {
        didSet { UserDefaults.standard.set(modelId, forKey: Key.modelId) }
    }
    @Published var systemPrompt: String {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: Key.systemPrompt) }
    }
    @Published var glassesFormat: GlassesFormat {
        didSet { UserDefaults.standard.set(glassesFormat.rawValue, forKey: Key.glassesFormat) }
    }
    @Published var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: Key.maxTokens) }
    }
    @Published var maxHistory: Int {
        didSet { UserDefaults.standard.set(maxHistory, forKey: Key.maxHistory) }
    }
    @Published var voiceEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceEnabled, forKey: Key.voiceEnabled) }
    }
    @Published var autoSendVoice: Bool {
        didSet { UserDefaults.standard.set(autoSendVoice, forKey: Key.autoSendVoice) }
    }
    @Published var glassesQueryEnabled: Bool {
        didSet { UserDefaults.standard.set(glassesQueryEnabled, forKey: Key.glassesQuery) }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    var selectedModel: ClaudeModel {
        ClaudeModel.all.first { $0.id == modelId } ?? ClaudeModel.default
    }

    private init() {
        let ud = UserDefaults.standard
        apiKey      = ud.string(forKey: Key.apiKey)   ?? ""
        modelId     = ud.string(forKey: Key.modelId)  ?? ClaudeModel.default.id
        systemPrompt = ud.string(forKey: Key.systemPrompt) ??
            "You are a helpful AI assistant displayed on Rokid AR glasses. Keep responses concise and clear — ideally 1–3 sentences for simple questions. For complex topics, give a short summary first, then offer to elaborate."
        maxTokens    = ud.object(forKey: Key.maxTokens)  as? Int    ?? 512
        maxHistory   = ud.object(forKey: Key.maxHistory) as? Int    ?? 10
        voiceEnabled     = ud.object(forKey: Key.voiceEnabled)    as? Bool ?? true
        autoSendVoice    = ud.object(forKey: Key.autoSendVoice)   as? Bool ?? true
        glassesQueryEnabled = ud.object(forKey: Key.glassesQuery) as? Bool ?? true

        if let raw = ud.string(forKey: Key.glassesFormat),
           let fmt = GlassesFormat(rawValue: raw) {
            glassesFormat = fmt
        } else {
            glassesFormat = .streaming
        }
    }
}

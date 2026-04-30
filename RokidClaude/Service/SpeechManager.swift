import Foundation
import Speech
import AVFoundation

// MARK: - Speech recognition manager

@MainActor
final class SpeechManager: ObservableObject {

    @Published private(set) var transcript   = ""
    @Published private(set) var isListening  = false
    @Published private(set) var isAvailable  = false
    @Published private(set) var error: String?

    private var recognizer:    SFSpeechRecognizer?
    private var audioEngine:   AVAudioEngine?
    private var request:       SFSpeechAudioBufferRecognitionRequest?
    private var task:          SFSpeechRecognitionTask?

    private var silenceTimer:  Timer?
    private let silenceTimeout = 1.8     // seconds of silence → auto-submit

    // Called when silence timeout fires (for auto-send)
    var onSilence: ((String) -> Void)?

    // MARK: - Init

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale.current)
        checkAuthorization()
    }

    // MARK: - Authorization

    func requestPermissions() async {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.isAvailable = (status == .authorized)
                    if status != .authorized {
                        self?.error = "Speech recognition not authorized."
                    }
                }
                cont.resume()
            }
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Microphone access failed: \(error.localizedDescription)"
        }
    }

    private func checkAuthorization() {
        let status = SFSpeechRecognizer.authorizationStatus()
        isAvailable = (status == .authorized)
    }

    // MARK: - Start / Stop

    func startListening() {
        guard !isListening else { return }
        guard let recognizer, recognizer.isAvailable else {
            error = "Speech recognizer not available."
            return
        }

        do {
            try startSession(recognizer: recognizer)
            isListening = true
            transcript  = ""
            error       = nil
        } catch {
            self.error = "Failed to start: \(error.localizedDescription)"
        }
    }

    func stopListening() -> String {
        let final = transcript
        cleanUp()
        return final
    }

    func cancelListening() {
        cleanUp()
        transcript = ""
    }

    // MARK: - Internal

    private func startSession(recognizer: SFSpeechRecognizer) throws {
        let engine  = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        let inputNode = engine.inputNode
        let format    = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                }
                if let error {
                    let code = (error as NSError).code
                    // 203 = no speech, 1110 = recognition cancelled — both normal
                    if code != 203 && code != 1110 {
                        self.error = error.localizedDescription
                    }
                    self.cleanUp()
                }
                if result?.isFinal == true {
                    self.cleanUp()
                }
            }
        }

        self.audioEngine = engine
        self.request     = request
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        guard !transcript.isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isListening else { return }
                let text = self.stopListening()
                if !text.isEmpty { self.onSilence?(text) }
            }
        }
    }

    private func cleanUp() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        task?.cancel()
        task = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        request?.endAudio()
        request = nil
        isListening = false
    }
}

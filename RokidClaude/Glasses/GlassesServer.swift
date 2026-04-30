import Foundation
import Network

// MARK: - Bidirectional Glasses TCP Server (port 8095)
//
// Phone → Glasses:  JSON lines  {"type":"query"|"thinking"|"chunk"|"response"|"error","text":"..."}
// Glasses → Phone:  Plain text  "QUERY: What is the weather?\n"  or just  "What is the weather?\n"

@MainActor
final class GlassesServer {

    // Called when a TCP client sends a query
    var onRemoteQuery: ((String) -> Void)?

    private var listener:    NWListener?
    private var connections: [ConnectionWrapper] = []
    private(set) var clientCount = 0

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        do { listener = try NWListener(using: .tcp, on: 8095) } catch { return }
        listener?.stateUpdateHandler = { [weak self] state in
            if case .failed = state { Task { @MainActor [weak self] in self?.restart() } }
        }
        listener?.newConnectionHandler = { [weak self] conn in
            Task { @MainActor [weak self] in self?.accept(conn) }
        }
        listener?.start(queue: .main)
        print("[GlassesServer] Listening on :8095")
    }

    func stop() {
        listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll(); clientCount = 0
    }

    private func restart() {
        stop()
        Task { @MainActor in try? await Task.sleep(for: .seconds(3)); self.start() }
    }

    // MARK: - Connection management

    private func accept(_ conn: NWConnection) {
        let wrapper = ConnectionWrapper(connection: conn)
        wrapper.onLine = { [weak self] line in
            Task { @MainActor [weak self] in
                if let query = GlassesPacket.parseQuery(from: line) {
                    self?.onRemoteQuery?(query)
                }
            }
        }
        wrapper.onClose = { [weak self] in
            Task { @MainActor [weak self] in
                self?.connections.removeAll { $0 === wrapper }
                self?.clientCount = self?.connections.count ?? 0
            }
        }
        connections.append(wrapper)
        clientCount = connections.count
        conn.start(queue: .main)
        wrapper.startReading()
    }

    // MARK: - Broadcast helpers

    private func broadcast(_ dict: [String: Any]) {
        guard !connections.isEmpty else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str  = String(data: data, encoding: .utf8) else { return }
        let payload = (str + "\n").data(using: .utf8)!
        connections.forEach { $0.send(payload) }
    }

    // MARK: - Public send API

    /// Show the user's query on glasses
    func sendQuery(_ text: String) {
        broadcast(["type": "query", "text": "🧑 \(text)"])
    }

    /// Show "thinking…" indicator
    func sendThinking() {
        broadcast(["type": "thinking", "text": "⏳ Thinking…"])
    }

    /// Send a streaming chunk of Claude's response
    func sendChunk(_ text: String) {
        broadcast(["type": "chunk", "text": text])
    }

    /// Send the final complete response (or a summary/minimal version)
    func sendResponse(_ text: String, format: GlassesFormat) {
        let display: String
        switch format {
        case .streaming:
            display = text  // already sent incrementally; send final for completeness
        case .summary:
            // First 2 sentences
            let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            display = sentences.prefix(2).joined(separator: ". ")
                + (sentences.count > 2 ? "…" : "")
        case .minimal:
            // First sentence only
            let first = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? text
            display = first.trimmingCharacters(in: .whitespaces)
        }
        broadcast(["type": "response", "text": "🤖 \(display)"])
    }

    func sendError(_ message: String) {
        broadcast(["type": "error", "text": "❌ \(message)"])
    }

    func sendClear() {
        broadcast(["type": "clear", "text": ""])
    }
}

// MARK: - Connection wrapper (handles bidirectional read + write)

private final class ConnectionWrapper {
    let connection: NWConnection
    var onLine:  ((String) -> Void)?
    var onClose: (() -> Void)?

    private var receiveBuffer = Data()

    init(connection: NWConnection) {
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.onClose?()
            default: break
            }
        }
    }

    func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func cancel() {
        connection.cancel()
    }

    func startReading() {
        receiveNext()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            if let data = content { self.receiveBuffer.append(data) }
            self.parseLines()
            if isComplete || error != nil { self.onClose?() }
            else { self.receiveNext() }
        }
    }

    private func parseLines() {
        while let newline = receiveBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = receiveBuffer[receiveBuffer.startIndex...newline]
            receiveBuffer.removeSubrange(receiveBuffer.startIndex...newline)
            if let line = String(data: lineData, encoding: .utf8) {
                onLine?(line)
            }
        }
    }
}

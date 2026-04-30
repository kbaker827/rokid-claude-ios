import SwiftUI

struct GlassesPreviewView: View {
    @EnvironmentObject private var vm: ClaudeViewModel
    @EnvironmentObject private var settings: SettingsStore

    // What would currently be shown on glasses
    private var glassesText: String {
        switch vm.inputMode {
        case .listening:  return "🎙 Listening…  \"\(vm.speechManager.transcript)\""
        case .thinking:   return "⏳ Thinking…"
        case .responding:
            let text = vm.streamingText
            guard !text.isEmpty else { return "⏳ Thinking…" }
            switch settings.glassesFormat {
            case .streaming: return "🤖 \(text.suffix(140))"
            case .summary:
                let s = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                return "🤖 " + (s.prefix(2).joined(separator: ". "))
            case .minimal:
                let s = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                    .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? text
                return "🤖 \(s)"
            }
        case .idle:
            if let last = vm.messages.last(where: { $0.role == .assistant }), !last.content.isEmpty {
                switch settings.glassesFormat {
                case .streaming: return "🤖 \(last.content.suffix(140))"
                case .summary:
                    let s = last.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    return "🤖 " + (s.prefix(2).joined(separator: ". "))
                case .minimal:
                    return "🤖 " + (last.content.components(separatedBy: CharacterSet(charactersIn: ".!?"))
                        .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? last.content)
                }
            }
            return "Ready — speak or type a question"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Format picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Format").font(.headline)
                        ForEach(GlassesFormat.allCases) { fmt in
                            Button {
                                settings.glassesFormat = fmt
                            } label: {
                                HStack {
                                    Image(systemName: settings.glassesFormat == fmt ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(settings.glassesFormat == fmt ? .accentColor : .secondary)
                                    VStack(alignment: .leading) {
                                        Text(fmt.displayName).font(.subheadline.weight(.medium))
                                        Text(fmt.description).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Glasses mockup
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10).fill(Color.black)
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Color.gray.opacity(0.4), lineWidth: 1)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(glassesText)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color(red: 0.4, green: 0.9, blue: 1.0))  // cyan
                                .lineLimit(6)
                                .animation(.easeInOut(duration: 0.1), value: glassesText)
                        }
                        .padding(12)
                    }
                    .aspectRatio(16/5, contentMode: .fit)
                    .padding(.horizontal)

                    // Status
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle().fill(vm.glassesClientCount > 0 ? Color.green : Color.gray).frame(width: 8, height: 8)
                            Text("TCP :8095  ·  \(vm.glassesClientCount) client(s)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(vm.inputMode.label)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Wire protocol reference
                    GroupBox("TCP Protocol") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Phone → Glasses (JSON lines):")
                                .font(.caption.weight(.semibold))
                            protocolLine(#"{"type":"query","text":"🧑 What is…"}"#)
                            protocolLine(#"{"type":"thinking","text":"⏳ Thinking…"}"#)
                            protocolLine(#"{"type":"chunk","text":" Paris"}"#)
                            protocolLine(#"{"type":"response","text":"🤖 Paris is…"}"#)
                            Spacer(minLength: 8)
                            Text("Glasses → Phone (plain text):")
                                .font(.caption.weight(.semibold))
                            protocolLine("QUERY: What is the capital of France?")
                            protocolLine("What time is it?")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Glasses Preview")
        }
    }

    @ViewBuilder
    private func protocolLine(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(4)
            .background(Color(.systemFill))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

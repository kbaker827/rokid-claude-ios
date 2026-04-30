import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var vm: ClaudeViewModel
    @EnvironmentObject private var settings: SettingsStore
    @Namespace private var bottomID

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !settings.hasAPIKey {
                    noKeyBanner
                }

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if vm.messages.isEmpty {
                                emptyState
                            } else {
                                ForEach(vm.messages) { msg in
                                    MessageBubble(message: msg)
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: vm.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: vm.streamingText) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }

                Divider()

                // Status bar
                if vm.inputMode != .idle {
                    statusBar
                }

                // Input bar
                inputBar
            }
            .navigationTitle("Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    glassesIndicator
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !vm.messages.isEmpty {
                        Button(role: .destructive) { vm.clearConversation() } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - No key banner

    private var noKeyBanner: some View {
        HStack {
            Image(systemName: "key.slash").foregroundStyle(.orange)
            Text("Enter your Anthropic API key in Settings")
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Ask Claude Anything")
                .font(.title2.bold())
            Text("Your question streams live to the Rokid glasses.\nType, speak, or send from the glasses over TCP :8095.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            // Suggested prompts
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(vm.suggestedPrompts, id: \.self) { prompt in
                    Button {
                        Task { await vm.send(text: prompt, fromGlasses: false) }
                    } label: {
                        Text(prompt)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(!settings.hasAPIKey)
                }
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(vm.inputMode.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if vm.inputMode == .responding {
                Button("Stop") { vm.stopStream() }
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            // Voice button
            if settings.voiceEnabled {
                Button {
                    if vm.inputMode == .listening {
                        Task { await vm.stopVoice() }
                    } else {
                        vm.startVoice()
                    }
                } label: {
                    Image(systemName: vm.inputMode == .listening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(vm.inputMode == .listening ? .red : .accentColor)
                        .symbolEffect(.pulse, isActive: vm.inputMode == .listening)
                }
                .disabled(!vm.speechManager.isAvailable || (vm.inputMode != .idle && vm.inputMode != .listening))
            }

            // Text field
            TextField("Ask Claude…", text: $vm.draftText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(vm.inputMode == .responding || vm.inputMode == .thinking)
                .onSubmit { Task { await vm.sendDraft() } }

            // Send button
            Button {
                Task { await vm.sendDraft() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(vm.draftText.isEmpty || !settings.hasAPIKey ? .secondary : .accentColor)
            }
            .disabled(vm.draftText.trimmingCharacters(in: .whitespaces).isEmpty
                      || !settings.hasAPIKey
                      || vm.inputMode == .responding
                      || vm.inputMode == .thinking)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: - Glasses indicator

    private var glassesIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(vm.glassesClientCount > 0 ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(":8095")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ClaudeMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // Claude avatar
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.15))
                    Text("C").font(.caption.bold()).foregroundStyle(.accentColor)
                }
                .frame(width: 30, height: 30)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty ? "…" : message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.accentColor : Color(.secondarySystemBackground))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                ZStack {
                    Circle().fill(Color.accentColor)
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .frame(width: 30, height: 30)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

#Preview {
    ChatView()
        .environmentObject(ClaudeViewModel())
        .environmentObject(SettingsStore.shared)
}

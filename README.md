# Rokid Claude HUD


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that bridges **Claude AI** (Anthropic) with **Rokid AR glasses** — fully bidirectional.

```
🗣 Voice / 📱 Type / 👓 Glasses query
         ↓
  iPhone (RokidClaude)
         ↓  Claude API (streaming SSE)
  api.anthropic.com
         ↓  streams tokens back
  iPhone ──Bluetooth/RokidSDK──▶ Rokid Glasses (response appears in real time)
```

## How it works

The glasses are a **first-class input source** — not just a display. The glasses can send voice queries (via `onAsrResult()`) and receive streaming responses. The phone is the bridge.

### Three ways to ask Claude:

| Method | How |
|--------|-----|
| 🗣 **Voice** | Tap mic → speak → auto-sends after 1.8 s of silence |
| ⌨️ **Type** | Text field in the Chat tab |
| 👓 **Glasses** | Speak your question — received via RokidSDK `onAsrResult()` |

### What the glasses see (streamed in real time):

```json
{"type":"query",    "text":"🧑 What is the capital of France?"}
{"type":"thinking", "text":"⏳ Thinking…"}
{"type":"chunk",    "text":"The"}
{"type":"chunk",    "text":" capital"}
{"type":"chunk",    "text":" of France is Paris."}
{"type":"response", "text":"🤖 The capital of France is Paris."}
```

## Display formats

| Format | Behavior |
|--------|----------|
| **Streaming** | Every token chunk sent live as Claude generates it |
| **Summary** | Wait for full response, then send first 2 sentences |
| **Minimal** | Wait for full response, then send first sentence only |

## Features

- **Streaming SSE** — response tokens appear on glasses token-by-token
- **Voice input** — iOS `SFSpeechRecognizer` with auto-submit on silence
- **Conversation memory** — configurable history (1–20 message pairs)
- **Model selector** — Claude Haiku (fastest), Sonnet, Opus
- **Custom system prompt** — set Claude's persona and style
- **Bidirectional** — glasses receive streamed output and send voice queries via RokidSDK `onAsrResult()`
- **Suggested prompts** — quick-start questions on empty state

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into the glasses Swift file:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Setup

1. Open `RokidClaude.xcworkspace` in Xcode 15+ (after running `pod install`) 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. Grant **microphone** and **speech recognition** permissions when prompted.
5. In **Settings**: paste your [Anthropic API key](https://console.anthropic.com).
6. Choose a model (Claude Haiku recommended for fastest glasses response).
7. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Communication protocol

### Phone → Glasses
```
{"type":"query",    "text":"🧑 <user question>"}
{"type":"thinking", "text":"⏳ Thinking…"}
{"type":"chunk",    "text":"<token>"}          ← streaming mode only
{"type":"response", "text":"🤖 <full or summary answer>"}
{"type":"error",    "text":"❌ <error message>"}
{"type":"clear",    "text":""}
```

### Glasses → Phone
```
QUERY: What is the weather today?\n
What time is it?\n
```
Plain text lines are also accepted as queries.

## Claude API

Uses the [Anthropic Messages API](https://docs.anthropic.com/en/api/messages) with streaming:

```
POST https://api.anthropic.com/v1/messages
x-api-key: <your-key>
anthropic-version: 2023-06-01

{"model":"claude-haiku-4-5","max_tokens":512,"stream":true,"messages":[...]}
```

Responses come back as Server-Sent Events parsed in Swift via `URLSession.bytes(for:)`.

## Recommended model for glasses

**Claude Haiku** — lowest latency, first token appears on glasses in ~300ms. Perfect for real-time AR display.

## Requirements

- iOS 17.0+
- Xcode 15+
- Anthropic API key ([console.anthropic.com](https://console.anthropic.com))
- Rokid AI glasses (paired via Bluetooth — no Wi-Fi needed) (optional — app works standalone as a Claude chat client)

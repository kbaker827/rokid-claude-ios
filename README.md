# Rokid Claude HUD

iOS app that bridges **Claude AI** (Anthropic) with **Rokid AR glasses** — fully bidirectional.

```
🗣 Voice / 📱 Type / 👓 Glasses query
         ↓
  iPhone (RokidClaude)
         ↓  Claude API (streaming SSE)
  api.anthropic.com
         ↓  streams tokens back
  iPhone ──TCP :8095──▶ Rokid Glasses (response appears in real time)
```

## How it works

The glasses are a **first-class input source** — not just a display. Any TCP client connected to port 8095 can send a text question and get Claude's answer streamed back. The phone is the bridge.

### Three ways to ask Claude:

| Method | How |
|--------|-----|
| 🗣 **Voice** | Tap mic → speak → auto-sends after 1.8 s of silence |
| ⌨️ **Type** | Text field in the Chat tab |
| 👓 **Glasses** | Send `QUERY: <question>\n` (or plain text) over TCP :8095 |

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
- **Bidirectional TCP server** — glasses can both receive output AND send queries
- **Suggested prompts** — quick-start questions on empty state

## Setup

1. Open `RokidClaude.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. Grant **microphone** and **speech recognition** permissions when prompted.
5. In **Settings**: paste your [Anthropic API key](https://console.anthropic.com).
6. Choose a model (Claude Haiku recommended for fastest glasses response).
7. Connect Rokid glasses to the same Wi-Fi; point TCP client at `<phone-ip>:8095`.

## TCP protocol (port 8095)

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
- Rokid AR glasses on the same Wi-Fi (optional — app works standalone as a Claude chat client)

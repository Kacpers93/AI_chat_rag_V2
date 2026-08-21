# AI Chat RAG V2

SwiftUI macOS app for chatting with a local Ollama model, with optional RAG (Retrieval-Augmented Generation) based on indexed notes.

## Features

- Chat UI with conversation history
- Local Ollama integration via `/api/chat`
- Optional RAG mode using note embeddings
- Notes management tab (manual notes, sample notes, clear index)
- Local embedding storage in JSON (`rag_embeddings.json`)

## Requirements

- macOS with Xcode (SwiftUI project)
- Running Ollama server (default: `http://127.0.0.1:11434`)
- Chat model available in Ollama (default: `llama3:latest`)
- Embedding model available in Ollama (`nomic-embed-text`)

## Configuration

Model and server configuration are defined in:

- `/home/runner/work/AI_chat_rag_V2/AI_chat_rag_V2/test_AI/Model_Config.swift`

Defaults:

- `baseURL`: `http://127.0.0.1:11434`
- `defaultModel`: `llama3:latest`

## Run

1. Start Ollama locally.
2. Ensure required models are pulled in Ollama.
3. Open `/home/runner/work/AI_chat_rag_V2/AI_chat_rag_V2/AI_chat_rag_V2.xcodeproj` in Xcode.
4. Build and run the app.

## RAG Flow

1. Add notes in the **Notatki** tab (or load sample notes).
2. App generates embeddings using Ollama `/api/embed`.
3. Embeddings are stored locally and used for similarity search.
4. In chat, enable **RAG** to inject relevant note context into prompts.

## Notes

- The app stores indexed note embeddings in the user documents directory.
- If no notes are indexed, chat works in standard (non-RAG) mode.

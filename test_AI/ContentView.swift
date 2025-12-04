import SwiftUI

// Pomocnicza struktura do API Ollama /api/chat
struct ChatAPIMessage: Codable {
    let role: String
    let content: String
}

struct ContentView: View {
    @State private var prompt: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    @State private var ragEnabled: Bool = false
    
    @StateObject private var ragManager = RAGManager()
    private let ollamaService = OllamaService()
    
    var body: some View {
        TabView {
            // Zakładka Chat
            ChatTabView(
                messages: $messages,
                prompt: $prompt,
                isLoading: $isLoading,
                ragEnabled: $ragEnabled,
                ragManager: ragManager,
                ollamaService: ollamaService,
                sendMessage: sendMessage
            )
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }
            
            // Zakładka Notatki
            NotesManagerView(ragManager: ragManager)
                .tabItem {
                    Label("Notatki", systemImage: "doc.text.fill")
                }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // Funkcje sendMessage i sendToOllama pozostają bez zmian
    private func sendMessage() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let userMessage = ChatMessage(content: trimmed, isUser: true)
        messages.append(userMessage)
        prompt = ""
        isLoading = true
        
        if ragEnabled {
            ragManager.searchRelevant(query: trimmed, topK: 2) { contextChunks in
                self.sendToOllama(userQuery: trimmed, contextFromRAG: contextChunks)
            }
        } else {
            sendToOllama(userQuery: trimmed, contextFromRAG: [])
        }
    }
    
    private func sendToOllama(userQuery: String, contextFromRAG: [String]) {
        var history: [ChatAPIMessage] = messages.dropLast().map { msg in
            ChatAPIMessage(
                role: msg.isUser ? "user" : "assistant",
                content: msg.content
            )
        }
        
        if !contextFromRAG.isEmpty {
            let contextString = contextFromRAG.joined(separator: "\n\n---\n\n")
            let systemPrompt = """
            Odpowiadaj na pytania używając poniższego kontekstu z notatek. \
            Jeśli odpowiedź nie znajduje się w kontekście, powiedz to wprost.
            
            KONTEKST Z NOTATEK:
            \(contextString)
            """
            
            history.insert(ChatAPIMessage(role: "system", content: systemPrompt), at: 0)
        }
        
        history.append(ChatAPIMessage(role: "user", content: userQuery))
        
        ollamaService.sendChat(messagesHistory: history) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let responseText):
                    let aiMessage = ChatMessage(content: responseText, isUser: false)
                    messages.append(aiMessage)
                    
                case .failure(let error):
                    let errorMessage = ChatMessage(
                        content: "Błąd: \(error.localizedDescription)",
                        isUser: false
                    )
                    messages.append(errorMessage)
                }
            }
        }
    }
}


// Wygląd pojedynczego dymka wiadomości (BEZ ZMIAN)
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(
                alignment: message.isUser ? .trailing : .leading,
                spacing: 4
            ) {
                Text(message.content)
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
                    .frame(
                        maxWidth: 400,
                        alignment: message.isUser ? .trailing : .leading
                    )
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

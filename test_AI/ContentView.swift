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
    
    // ZMIANA 1: Dodaj RAGManager i przełącznik
    @StateObject private var ragManager = RAGManager()
    @State private var ragEnabled: Bool = false
    
    private let ollamaService = OllamaService()
    
    var body: some View {
        VStack(spacing: 0) {
            // ZMIANA 2: Rozszerz nagłówek o przełącznik RAG i menu
            HStack {
                Text("\(OllamaConfig.defaultModel) chat")
                    .font(.headline)
                Spacer()
                
                // Przełącznik RAG
                Toggle("RAG", isOn: $ragEnabled)
                    .disabled(ragManager.documentsCount == 0)
                    .help(ragManager.documentsCount > 0
                          ? "Używaj kontekstu z \(ragManager.documentsCount) notatek"
                          : "Najpierw zaindeksuj notatki")
                
                // Menu z opcjami
                Menu {
                    Button("📚 Zaindeksuj przykładowe notatki") {
                        indexSampleNotes()
                    }
                    Button("🗑️ Wyczyść indeks") {
                        ragManager.clearIndex()
                    }
                } label: {
                    Image(systemName: "gear")
                }
            }
            .padding()
            
            Divider()
            
            // Historia czatu (BEZ ZMIAN)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Myślę...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // ZMIANA 3: Zaktualizuj tekst pod TextEditorem
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 40, maxHeight: 100)
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5))
                        )
                        .background(Color(NSColor.textBackgroundColor))
                        .lineSpacing(2)
                    
                    // Zaktualizowany status
                    Text(ragEnabled
                         ? "RAG aktywny • \(ragManager.documentsCount) notatek zaindeksowanych"
                         : "Enter = nowa linia • Kliknij przycisk, aby wysłać")
                        .font(.caption2)
                        .foregroundColor(ragEnabled ? .green : .secondary)
                }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray
                                : Color.blue
                        )
                        .clipShape(Circle())
                }
                .disabled(isLoading || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
    }
    
    // ZMIANA 4: Przepisz funkcję sendMessage – dodaj logikę RAG
    private func sendMessage() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Dodaj wiadomość użytkownika do historii
        let userMessage = ChatMessage(content: trimmed, isUser: true)
        messages.append(userMessage)
        prompt = ""
        isLoading = true
        
        // Jeśli RAG jest włączony, wyszukaj kontekst
        if ragEnabled {
            ragManager.searchRelevant(query: trimmed, topK: 2) { contextChunks in
                self.sendToOllama(userQuery: trimmed, contextFromRAG: contextChunks)
            }
        } else {
            // Normalny chat bez RAG
            sendToOllama(userQuery: trimmed, contextFromRAG: [])
        }
    }
    
    // ZMIANA 5: Nowa funkcja – wysyłanie do Ollamy z opcjonalnym kontekstem
    private func sendToOllama(userQuery: String, contextFromRAG: [String]) {
        // Zbuduj historię (wszystkie wiadomości oprócz ostatniej, bo ją dodamy z kontekstem)
        var history: [ChatAPIMessage] = messages.dropLast().map { msg in
            ChatAPIMessage(
                role: msg.isUser ? "user" : "assistant",
                content: msg.content
            )
        }
        
        // Jeśli mamy kontekst z RAG, dodaj jako system message
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
        
        // Dodaj aktualne pytanie użytkownika
        history.append(ChatAPIMessage(role: "user", content: userQuery))
        
        // Wyślij do Ollamy
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
    
    // ZMIANA 6: Nowa funkcja – indeksowanie przykładowych notatek
    private func indexSampleNotes() {
        let sampleNotes = [
            "Quicksort to algorytm sortowania w miejscu. Średnia złożoność to O(n log n), ale najgorsza O(n²) występuje gdy pivot jest źle wybrany.",
            "Indeksy B-tree w bazach danych przyspieszają SELECT, ale spowalniają INSERT i UPDATE, bo indeks musi być aktualizowany.",
            "Overfitting w machine learning to gdy model za dobrze dopasowuje się do danych treningowych i źle generalizuje. Regularyzacja L1 i L2 pomaga to ograniczyć.",
            "REST API używa metod HTTP: GET do odczytu, POST do tworzenia, PUT/PATCH do aktualizacji, DELETE do usuwania.",
            "Git rebase przepisuje historię commitów, a merge tworzy nowy commit łączący. Rebase daje liniową historię, ale nie używaj go na publicznych branchach."
        ]
        
        ragManager.indexDocuments(texts: sampleNotes, source: "przykładowe_notatki")
    }
    
    // RESZTA BEZ ZMIAN (MessageBubble i timeString)
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

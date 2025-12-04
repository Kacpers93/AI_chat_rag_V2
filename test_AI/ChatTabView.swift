import SwiftUI

struct ChatTabView: View {
    @Binding var messages: [ChatMessage]
    @Binding var prompt: String
    @Binding var isLoading: Bool
    @Binding var ragEnabled: Bool
    
    @ObservedObject var ragManager: RAGManager
    let ollamaService: OllamaService
    let sendMessage: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Nagłówek
            HStack {
                Text("\(OllamaConfig.defaultModel) chat")
                    .font(.headline)
                Spacer()
                
                // Status RAG
                if ragManager.documentsCount > 0 {
                    Toggle("RAG (\(ragManager.documentsCount) notatek)", isOn: $ragEnabled)
                        .toggleStyle(.switch)
                } else {
                    Text("Brak notatek – dodaj w zakładce 'Notatki'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Divider()
            
            // Historia czatu
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
            
            // Input
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
                    
                    Text(ragEnabled
                         ? "RAG aktywny • \(ragManager.documentsCount) notatek"
                         : "Tryb normalny • bez RAG")
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
}

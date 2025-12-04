import SwiftUI

struct NotesManagerView: View {
    @ObservedObject var ragManager: RAGManager
    @State private var newNoteText: String = ""
    @State private var isIndexing: Bool = false
    @State private var showImportSheet: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Nagłówek
            HStack {
                Text("Zarządzanie notatkami")
                    .font(.title2)
                    .bold()
                Spacer()
                
                Text("\(ragManager.documentsCount) zaindeksowanych fragmentów")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // Główna zawartość
            ScrollView {
                VStack(spacing: 20) {
                    // Sekcja: Dodaj nową notatkę
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dodaj nową notatkę")
                            .font(.headline)
                        
                        TextEditor(text: $newNoteText)
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5))
                            )
                            .overlay(
                                Group {
                                    if newNoteText.isEmpty {
                                        Text("Wpisz tekst notatki (np. definicja, fragment wykładu)...")
                                            .foregroundColor(.gray)
                                            .padding(8)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                        
                        HStack {
                            Button("Dodaj i zaindeksuj") {
                                addNote()
                            }
                            .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isIndexing)
                            .buttonStyle(.borderedProminent)
                            
                            if isIndexing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Indeksuję...")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Sekcja: Szybkie akcje
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Szybkie akcje")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            Button("📚 Załaduj przykładowe notatki") {
                                loadSampleNotes()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("📄 Import z pliku (TODO)") {
                                showImportSheet = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(true) // Możesz to włączyć później
                            
                            Spacer()
                            
                            Button("🗑️ Wyczyść wszystko") {
                                ragManager.clearIndex()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(ragManager.documentsCount == 0)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Sekcja: Podgląd zaindeksowanych notatek
                    if ragManager.documentsCount > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Zaindeksowane fragmenty")
                                .font(.headline)
                            
                            Text("(podgląd wymaga rozszerzenia RAGManager o listę)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // TODO: Tu możesz dodać listę notatek, jeśli RAGManager
                            // udostępni publiczny dostęp do `documents`
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
        }
    }
    
    // Dodaj pojedynczą notatkę
    private func addNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isIndexing = true
        
        // Zaindeksuj jako tablicę z jednym elementem
        ragManager.indexDocuments(texts: [trimmed], source: "ręcznie_dodana")
        
        // Po zakończeniu wyczyść pole
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            newNoteText = ""
            isIndexing = false
        }
    }
    
    // Załaduj przykładowe notatki
    private func loadSampleNotes() {
        let samples = [
            "Quicksort to algorytm sortowania w miejscu. Średnia złożoność to O(n log n), ale najgorsza O(n²) występuje gdy pivot jest źle wybrany.",
            "Indeksy B-tree w bazach danych przyspieszają SELECT, ale spowalniają INSERT i UPDATE, bo indeks musi być aktualizowany.",
            "Overfitting w machine learning to gdy model za dobrze dopasowuje się do danych treningowych i źle generalizuje. Regularyzacja L1 i L2 pomaga to ograniczyć.",
            "REST API używa metod HTTP: GET do odczytu, POST do tworzenia, PUT/PATCH do aktualizacji, DELETE do usuwania.",
            "Git rebase przepisuje historię commitów, a merge tworzy nowy commit łączący. Rebase daje liniową historię, ale nie używaj go na publicznych branchach."
        ]
        
        ragManager.indexDocuments(texts: samples, source: "przykładowe_notatki")
    }
}

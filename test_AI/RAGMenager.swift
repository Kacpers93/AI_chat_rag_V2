import Foundation

// Model dla dokumentu z embeddingiem
struct DocumentChunk: Codable, Identifiable {
    let id: String
    let text: String
    let embedding: [Float]
    let source: String // np. "notatki.txt"
}

class RAGManager: ObservableObject {
    @Published var isIndexing = false
    @Published var documentsCount = 0
    
    private var documents: [DocumentChunk] = []
    private let ollamaService = OllamaService()
    
    // Ścieżka do pliku JSON z embeddingami
    private let storageURL: URL = {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return documentsPath.appendingPathComponent("rag_embeddings.json")
    }()
    
    init() {
        loadDocuments()
        documentsCount = documents.count
    }
    
    // KROK 1: Indeksuj teksty (zamień na embeddingi)
    func indexDocuments(texts: [String], source: String = "notatki") {
        isIndexing = true
        documents = []
        
        let group = DispatchGroup()
        
        for (index, text) in texts.enumerated() {
            group.enter()
            
            ollamaService.getEmbedding(text: text) { [weak self] result in
                defer { group.leave() }
                
                switch result {
                case .success(let embedding):
                    let chunk = DocumentChunk(
                        id: UUID().uuidString,
                        text: text,
                        embedding: embedding,
                        source: source
                    )
                    self?.documents.append(chunk)
                    print("✓ Zaindeksowano \(index + 1)/\(texts.count)")
                    
                case .failure(let error):
                    print("✗ Błąd embeddingu: \(error)")
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.saveDocuments()
            self?.documentsCount = self?.documents.count ?? 0
            self?.isIndexing = false
            print("✅ Zapisano \(self?.documents.count ?? 0) fragmentów")
        }
    }
    
    // KROK 2: Wyszukaj podobne fragmenty do pytania
    func searchRelevant(query: String, topK: Int = 2, completion: @escaping ([String]) -> Void) {
        guard !documents.isEmpty else {
            completion([])
            return
        }
        
        // Generuj embedding dla pytania
        ollamaService.getEmbedding(text: query) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let queryEmbedding):
                // Oblicz podobieństwo dla każdego dokumentu
                let scored = self.documents.map { doc -> (String, Float) in
                    let similarity = self.cosineSimilarity(queryEmbedding, doc.embedding)
                    return (doc.text, similarity)
                }
                
                // Posortuj i weź top K
                let topResults = scored
                    .sorted { $0.1 > $1.1 }
                    .prefix(topK)
                    .map { $0.0 }
                
                completion(Array(topResults))
                
            case .failure(let error):
                print("Błąd wyszukiwania: \(error)")
                completion([])
            }
        }
    }
    
    // Cosine similarity
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    // Zapis/odczyt z JSON
    private func saveDocuments() {
        if let data = try? JSONEncoder().encode(documents) {
            try? data.write(to: storageURL)
        }
    }
    
    private func loadDocuments() {
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([DocumentChunk].self, from: data) {
            documents = decoded
        }
    }
    
    // Usuń bazę (przydatne do testów)
    func clearIndex() {
        documents = []
        try? FileManager.default.removeItem(at: storageURL)
        documentsCount = 0
    }
}

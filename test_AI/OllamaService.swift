import Foundation

enum OllamaError: Error {
    case invalidURL
    case noData
    case invalidResponse
    case custom(String)
}

class OllamaService {
    private let baseURL: String
    private let model: String

    private let session: URLSession = {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300    // np. 180 s
            config.timeoutIntervalForResource = 600   // np. 300 s
            return URLSession(configuration: config)
        }()

    init(
        baseURL: String = OllamaConfig.baseURL,
        model: String = OllamaConfig.defaultModel
    ) {
        self.baseURL = baseURL
        self.model = model
    }

    func sendChat(
        messagesHistory: [ChatAPIMessage],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            completion(.failure(OllamaError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": messagesHistory.map { ["role": $0.role, "content": $0.content] },
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(OllamaError.noData))
                return
            }

            // Debug: podejrzyj odpowiedź
            if let raw = String(data: data, encoding: .utf8) {
                print("Ollama raw response:", raw)
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content))
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorMessage = json["error"] as? String {
                    completion(.failure(OllamaError.custom(errorMessage)))
                } else {
                    completion(.failure(OllamaError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
//╔════════════════════════════════════════════════════════════════════════╗
//║                          EMBEDING                                      ║
//╚════════════════════════════════════════════════════════════════════════╝
    func getEmbedding(
        text: String,
        model: String = "nomic-embed-text",  // ZMIANA tutaj
        completion: @escaping (Result<[Float], Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/api/embed") else {
            completion(.failure(OllamaError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "input": text
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(OllamaError.noData))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let embeddingArray = json["embeddings"] as? [[Double]] {
                    // Ollama zwraca tablicę tablic, bierzemy pierwszą
                    let floats = embeddingArray.first?.map { Float($0) } ?? []
                    completion(.success(floats))
                } else {
                    completion(.failure(OllamaError.invalidResponse))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

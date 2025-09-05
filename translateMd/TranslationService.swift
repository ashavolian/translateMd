import Foundation

@MainActor
class TranslationService: ObservableObject {
    private let baseURL = "http://localhost:3030" // Dev token server
    
    @Published var isConnected = false
    
    init() {
        // Initialize translation service
    }
    
    
    // MARK: - Translation
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async -> String? {
        // Use the token server's translate endpoint which handles the API call properly
        guard let url = URL(string: "\(baseURL)/translate") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "text": text,
            "from": sourceLanguage,
            "to": targetLanguage
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let translationResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
            return translationResponse.translation
        } catch {
            print("Translation error: \(error)")
            return "Translation failed: \(error.localizedDescription)"
        }
    }
    
}

// MARK: - Response Models
struct TranslationResponse: Codable {
    let translation: String
}

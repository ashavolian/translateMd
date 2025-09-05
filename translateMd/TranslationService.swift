import Foundation

@MainActor
class TranslationService: ObservableObject {
    private let baseURL = "http://localhost:3030" // Dev token server
    private var ephemeralToken: String?
    
    @Published var isConnected = false
    
    init() {
        // Initialize translation service
    }
    
    // MARK: - Token Management
    private func getEphemeralToken() async -> String? {
        guard let url = URL(string: "\(baseURL)/session") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SessionResponse.self, from: data)
            return response.client_secret?.value
        } catch {
            print("Failed to get ephemeral token: \(error)")
            return nil
        }
    }
    
    // MARK: - Translation
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async -> String? {
        // For now, use a simple HTTP-based translation approach
        // In production, this would use OpenAI Realtime API with WebSocket/WebRTC
        
        guard let token = await getEphemeralToken() else {
            return "Error: Could not authenticate"
        }
        
        // Simulate OpenAI API call for translation
        let prompt = """
        Translate the following text from \(sourceLanguage) to \(targetLanguage). 
        This is for medical communication between a clinician and patient.
        Provide only the translation, no explanations.
        
        Text: \(text)
        """
        
        return await callOpenAIAPI(prompt: prompt, token: token)
    }
    
    private func callOpenAIAPI(prompt: String, token: String) async -> String? {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a medical interpreter. Provide accurate, professional translations for clinical conversations."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 150,
            "temperature": 0.3
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            return response.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Translation error: \(error)")
            return "Translation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Response Models
struct SessionResponse: Codable {
    let client_secret: ClientSecret?
    
    struct ClientSecret: Codable {
        let value: String
    }
}

struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String?
    }
}

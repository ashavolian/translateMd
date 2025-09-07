import Foundation

@MainActor
class TranslationService: ObservableObject {
    private let baseURL = "http://localhost:3030" // Dev token server
    
    @Published var isConnected = false
    
    init() {
        // Initialize translation service
    }
    
    // MARK: - Language Detection
    func detectLanguage(text: String) async -> String? {
        guard let url = URL(string: "\(baseURL)/detect-language") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "text": text
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let detectionResponse = try JSONDecoder().decode(LanguageDetectionResponse.self, from: data)
            return detectionResponse.language
        } catch {
            print("Language detection error: \(error)")
            return nil
        }
    }
    
    // MARK: - Audio Transcription
    func transcribeAudio(audioData: Data) async -> TranscriptionResult? {
        guard let url = URL(string: "\(baseURL)/transcribe") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return TranscriptionResult(
                transcription: transcriptionResponse.transcription,
                language: transcriptionResponse.language,
                confidence: transcriptionResponse.confidence
            )
        } catch {
            print("Transcription error: \(error)")
            return nil
        }
    }
    
    // MARK: - Translation
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async -> TranslationResult? {
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log the response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("Translation response status: \(httpResponse.statusCode)")
            }
            
            let translationResponse = try JSONDecoder().decode(EnhancedTranslationResponse.self, from: data)
            return TranslationResult(
                translation: translationResponse.translation,
                detectedLanguage: translationResponse.detectedLanguage
            )
        } catch {
            print("Translation error: \(error)")
            if let data = try? JSONSerialization.data(withJSONObject: body),
               let responseString = String(data: data, encoding: .utf8) {
                print("Request body: \(responseString)")
            }
            return nil
        }
    }
    
    // MARK: - Convenience Methods
    func translateWithAutoDetection(text: String, to targetLanguage: String) async -> TranslationResult? {
        return await translate(text: text, from: "auto", to: targetLanguage)
    }
    
}

// MARK: - Response Models
struct TranslationResponse: Codable {
    let translation: String
}

struct LanguageDetectionResponse: Codable {
    let language: String
}

struct TranscriptionResponse: Codable {
    let transcription: String
    let language: String
    let confidence: Double
}

struct EnhancedTranslationResponse: Codable {
    let translation: String
    let detectedLanguage: String?
}

// MARK: - Result Models
struct TranslationResult {
    let translation: String
    let detectedLanguage: String?
}

struct TranscriptionResult {
    let transcription: String
    let language: String
    let confidence: Double
}

import Foundation
import Network

enum Speaker {
    case clinician, patient, none
}

struct TranslationResult {
    let text: String
    let confidence: Double
    let targetSpeaker: Speaker
}

enum RealtimeError: Error {
    case noEphemeralToken
    case connectionFailed
    case translationFailed
}

class RealtimeClient: NSObject, ObservableObject {
    private let serverURL = "http://localhost:3030"
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession = URLSession.shared
    
    @Published var isConnected = false
    @Published var lastError: Error?
    
    private var ephemeralToken: String?
    
    func getEphemeralToken() async throws -> String {
        guard let url = URL(string: "\(serverURL)/session") else {
            throw RealtimeError.connectionFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RealtimeError.connectionFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let clientSecret = json?["client_secret"] as? [String: Any],
              let token = clientSecret["value"] as? String else {
            throw RealtimeError.noEphemeralToken
        }
        
        ephemeralToken = token
        return token
    }
    
    func connect() async throws {
        let token = try await getEphemeralToken()
        
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview") else {
            throw RealtimeError.connectionFailed
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        await MainActor.run {
            isConnected = true
        }
        
        // Start listening for messages
        listenForMessages()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        Task { @MainActor in
            isConnected = false
        }
    }
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                // Continue listening
                self?.listenForMessages()
            case .failure(let error):
                print("WebSocket error: \(error)")
                Task { @MainActor in
                    self?.lastError = error
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            print("Received message: \(text)")
            // Handle realtime API messages here
        case .data(let data):
            print("Received data: \(data)")
        @unknown default:
            break
        }
    }
    
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String {
        guard isConnected else {
            try await connect()
        }
        
        let translationPrompt = """
        Translate the following text from \(sourceLanguage) to \(targetLanguage) for a clinical/medical setting. 
        Be accurate, concise, and appropriate for healthcare communication:
        
        \(text)
        """
        
        let message = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [
                    [
                        "type": "input_text",
                        "text": translationPrompt
                    ]
                ]
            ]
        ] as [String: Any]
        
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        try await webSocketTask?.send(.string(jsonString))
        
        // For now, return a placeholder translation
        // In a full implementation, you'd wait for the response and parse it
        return "Translation of: \(text)"
    }
}
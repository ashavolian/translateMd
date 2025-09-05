import Foundation

class TranslationManager: ObservableObject {
    @Published var translatedText = TranslationResult(text: "", confidence: 0.0, targetSpeaker: .none)
    @Published var lastConfidence: Double = 1.0
    @Published var clinicianLanguage = "en-US"
    @Published var patientLanguage = "es-ES"
    @Published var confidenceThreshold = 0.7
    @Published var saveHistory = true
    
    private let realtimeClient = RealtimeClient()
    private var translationHistory: [TranslationResult] = []
    
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String, for targetSpeaker: Speaker) {
        Task {
            do {
                let translatedText = try await realtimeClient.translate(
                    text: text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                // Calculate confidence (simplified heuristic for prototype)
                let confidence = calculateConfidence(originalText: text, translatedText: translatedText)
                
                let result = TranslationResult(
                    text: translatedText,
                    confidence: confidence,
                    targetSpeaker: targetSpeaker
                )
                
                await MainActor.run {
                    self.translatedText = result
                    self.lastConfidence = confidence
                    
                    if saveHistory {
                        translationHistory.append(result)
                    }
                }
            } catch {
                print("Translation error: \(error)")
                // Fallback to simple placeholder translation for prototype
                let fallbackTranslation = "Translation: \(text)"
                let result = TranslationResult(
                    text: fallbackTranslation,
                    confidence: 0.5,
                    targetSpeaker: targetSpeaker
                )
                
                await MainActor.run {
                    self.translatedText = result
                    self.lastConfidence = 0.5
                }
            }
        }
    }
    
    private func calculateConfidence(originalText: String, translatedText: String) -> Double {
        // Simplified confidence calculation for prototype
        // In production, this would use more sophisticated metrics
        
        let originalLength = originalText.count
        let translatedLength = translatedText.count
        
        // Basic heuristic: if translated text is too short or too long compared to original, lower confidence
        let lengthRatio = Double(translatedLength) / Double(max(originalLength, 1))
        
        var confidence = 1.0
        
        if lengthRatio < 0.5 || lengthRatio > 2.0 {
            confidence -= 0.3
        }
        
        // Check for common translation issues (very basic)
        if translatedText.lowercased().contains("translation") && originalText.lowercased().contains("translation") {
            confidence -= 0.2 // Likely untranslated
        }
        
        return max(0.0, min(1.0, confidence))
    }
    
    func clearHistory() {
        translationHistory.removeAll()
    }
    
    func getHistory() -> [TranslationResult] {
        return translationHistory
    }
    
    func updateLanguages(clinician: String, patient: String) {
        clinicianLanguage = clinician
        patientLanguage = patient
    }
    
    func updateConfidenceThreshold(_ threshold: Double) {
        confidenceThreshold = threshold
    }
    
    func toggleSaveHistory() {
        saveHistory.toggle()
        if !saveHistory {
            clearHistory()
        }
    }
}
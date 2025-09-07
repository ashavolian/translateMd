import Foundation
import Speech

struct Language: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let flag: String
    let isoCode: String // BCP-47 for speech recognition
    let translationCode: String // ISO 639-1/BCP-47 for translation
    let isAppleSpeechSupported: Bool
    
    init(id: String, displayName: String, flag: String, isoCode: String, translationCode: String? = nil, isAppleSpeechSupported: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.flag = flag
        self.isoCode = isoCode
        self.translationCode = translationCode ?? isoCode
        self.isAppleSpeechSupported = isAppleSpeechSupported
    }
    
    // Curated list of supported languages
    static let supportedLanguages: [Language] = [
        // Major languages with Apple Speech support
        Language(id: "en-US", displayName: "English (US)", flag: "🇺🇸", isoCode: "en-US", translationCode: "en"),
        Language(id: "en-GB", displayName: "English (UK)", flag: "🇬🇧", isoCode: "en-GB", translationCode: "en"),
        Language(id: "es-ES", displayName: "Spanish (Spain)", flag: "🇪🇸", isoCode: "es-ES", translationCode: "es"),
        Language(id: "es-MX", displayName: "Spanish (Mexico)", flag: "🇲🇽", isoCode: "es-MX", translationCode: "es"),
        Language(id: "fr-FR", displayName: "French", flag: "🇫🇷", isoCode: "fr-FR", translationCode: "fr"),
        Language(id: "de-DE", displayName: "German", flag: "🇩🇪", isoCode: "de-DE", translationCode: "de"),
        Language(id: "it-IT", displayName: "Italian", flag: "🇮🇹", isoCode: "it-IT", translationCode: "it"),
        Language(id: "pt-BR", displayName: "Portuguese (Brazil)", flag: "🇧🇷", isoCode: "pt-BR", translationCode: "pt"),
        Language(id: "pt-PT", displayName: "Portuguese (Portugal)", flag: "🇵🇹", isoCode: "pt-PT", translationCode: "pt"),
        Language(id: "ru-RU", displayName: "Russian", flag: "🇷🇺", isoCode: "ru-RU", translationCode: "ru"),
        Language(id: "ja-JP", displayName: "Japanese", flag: "🇯🇵", isoCode: "ja-JP", translationCode: "ja"),
        Language(id: "ko-KR", displayName: "Korean", flag: "🇰🇷", isoCode: "ko-KR", translationCode: "ko"),
        Language(id: "zh-CN", displayName: "Chinese (Simplified)", flag: "🇨🇳", isoCode: "zh-CN", translationCode: "zh-Hans"),
        Language(id: "zh-TW", displayName: "Chinese (Traditional)", flag: "🇹🇼", isoCode: "zh-TW", translationCode: "zh-Hant"),
        Language(id: "ar-SA", displayName: "Arabic", flag: "🇸🇦", isoCode: "ar-SA", translationCode: "ar"),
        Language(id: "hi-IN", displayName: "Hindi", flag: "🇮🇳", isoCode: "hi-IN", translationCode: "hi"),
        Language(id: "nl-NL", displayName: "Dutch", flag: "🇳🇱", isoCode: "nl-NL", translationCode: "nl"),
        Language(id: "sv-SE", displayName: "Swedish", flag: "🇸🇪", isoCode: "sv-SE", translationCode: "sv"),
        Language(id: "no-NO", displayName: "Norwegian", flag: "🇳🇴", isoCode: "no-NO", translationCode: "no"),
        Language(id: "da-DK", displayName: "Danish", flag: "🇩🇰", isoCode: "da-DK", translationCode: "da"),
        Language(id: "fi-FI", displayName: "Finnish", flag: "🇫🇮", isoCode: "fi-FI", translationCode: "fi"),
        Language(id: "pl-PL", displayName: "Polish", flag: "🇵🇱", isoCode: "pl-PL", translationCode: "pl"),
        Language(id: "tr-TR", displayName: "Turkish", flag: "🇹🇷", isoCode: "tr-TR", translationCode: "tr"),
        Language(id: "he-IL", displayName: "Hebrew", flag: "🇮🇱", isoCode: "he-IL", translationCode: "he"),
        Language(id: "th-TH", displayName: "Thai", flag: "🇹🇭", isoCode: "th-TH", translationCode: "th"),
        Language(id: "vi-VN", displayName: "Vietnamese", flag: "🇻🇳", isoCode: "vi-VN", translationCode: "vi"),
        Language(id: "id-ID", displayName: "Indonesian", flag: "🇮🇩", isoCode: "id-ID", translationCode: "id"),
        Language(id: "ms-MY", displayName: "Malay", flag: "🇲🇾", isoCode: "ms-MY", translationCode: "ms"),
        Language(id: "tl-PH", displayName: "Filipino", flag: "🇵🇭", isoCode: "tl-PH", translationCode: "tl"),
        
        // Auto-detect language (always uses server transcription initially)
        Language(id: "auto", displayName: "Auto-detect", flag: "🔍", isoCode: "auto", translationCode: "auto", isAppleSpeechSupported: false),
        Language(id: "ur-PK", displayName: "Urdu", flag: "🇵🇰", isoCode: "ur-PK", translationCode: "ur", isAppleSpeechSupported: false),
        Language(id: "bn-BD", displayName: "Bengali", flag: "🇧🇩", isoCode: "bn-BD", translationCode: "bn", isAppleSpeechSupported: false),
        Language(id: "ta-IN", displayName: "Tamil", flag: "🇮🇳", isoCode: "ta-IN", translationCode: "ta", isAppleSpeechSupported: false),
        Language(id: "te-IN", displayName: "Telugu", flag: "🇮🇳", isoCode: "te-IN", translationCode: "te", isAppleSpeechSupported: false),
        Language(id: "gu-IN", displayName: "Gujarati", flag: "🇮🇳", isoCode: "gu-IN", translationCode: "gu", isAppleSpeechSupported: false),
        Language(id: "kn-IN", displayName: "Kannada", flag: "🇮🇳", isoCode: "kn-IN", translationCode: "kn", isAppleSpeechSupported: false),
        Language(id: "ml-IN", displayName: "Malayalam", flag: "🇮🇳", isoCode: "ml-IN", translationCode: "ml", isAppleSpeechSupported: false),
        Language(id: "pa-IN", displayName: "Punjabi", flag: "🇮🇳", isoCode: "pa-IN", translationCode: "pa", isAppleSpeechSupported: false),
        Language(id: "or-IN", displayName: "Odia", flag: "🇮🇳", isoCode: "or-IN", translationCode: "or", isAppleSpeechSupported: false),
        Language(id: "as-IN", displayName: "Assamese", flag: "🇮🇳", isoCode: "as-IN", translationCode: "as", isAppleSpeechSupported: false),
        Language(id: "ne-NP", displayName: "Nepali", flag: "🇳🇵", isoCode: "ne-NP", translationCode: "ne", isAppleSpeechSupported: false),
        Language(id: "si-LK", displayName: "Sinhala", flag: "🇱🇰", isoCode: "si-LK", translationCode: "si", isAppleSpeechSupported: false),
        Language(id: "my-MM", displayName: "Burmese", flag: "🇲🇲", isoCode: "my-MM", translationCode: "my", isAppleSpeechSupported: false),
        Language(id: "km-KH", displayName: "Khmer", flag: "🇰🇭", isoCode: "km-KH", translationCode: "km", isAppleSpeechSupported: false),
        Language(id: "lo-LA", displayName: "Lao", flag: "🇱🇦", isoCode: "lo-LA", translationCode: "lo", isAppleSpeechSupported: false),
        Language(id: "ka-GE", displayName: "Georgian", flag: "🇬🇪", isoCode: "ka-GE", translationCode: "ka", isAppleSpeechSupported: false),
        Language(id: "am-ET", displayName: "Amharic", flag: "🇪🇹", isoCode: "am-ET", translationCode: "am", isAppleSpeechSupported: false),
        Language(id: "sw-KE", displayName: "Swahili", flag: "🇰🇪", isoCode: "sw-KE", translationCode: "sw", isAppleSpeechSupported: false),
        Language(id: "zu-ZA", displayName: "Zulu", flag: "🇿🇦", isoCode: "zu-ZA", translationCode: "zu", isAppleSpeechSupported: false),
        Language(id: "af-ZA", displayName: "Afrikaans", flag: "🇿🇦", isoCode: "af-ZA", translationCode: "af", isAppleSpeechSupported: false),
        Language(id: "is-IS", displayName: "Icelandic", flag: "🇮🇸", isoCode: "is-IS", translationCode: "is", isAppleSpeechSupported: false),
        Language(id: "ga-IE", displayName: "Irish", flag: "🇮🇪", isoCode: "ga-IE", translationCode: "ga", isAppleSpeechSupported: false),
        Language(id: "cy-GB", displayName: "Welsh", flag: "🏴󠁧󠁢󠁷󠁬󠁳󠁿", isoCode: "cy-GB", translationCode: "cy", isAppleSpeechSupported: false),
        Language(id: "mt-MT", displayName: "Maltese", flag: "🇲🇹", isoCode: "mt-MT", translationCode: "mt", isAppleSpeechSupported: false),
        Language(id: "lv-LV", displayName: "Latvian", flag: "🇱🇻", isoCode: "lv-LV", translationCode: "lv", isAppleSpeechSupported: false),
        Language(id: "lt-LT", displayName: "Lithuanian", flag: "🇱🇹", isoCode: "lt-LT", translationCode: "lt", isAppleSpeechSupported: false),
        Language(id: "et-EE", displayName: "Estonian", flag: "🇪🇪", isoCode: "et-EE", translationCode: "et", isAppleSpeechSupported: false),
        Language(id: "sk-SK", displayName: "Slovak", flag: "🇸🇰", isoCode: "sk-SK", translationCode: "sk", isAppleSpeechSupported: false),
        Language(id: "sl-SI", displayName: "Slovenian", flag: "🇸🇮", isoCode: "sl-SI", translationCode: "sl", isAppleSpeechSupported: false),
        Language(id: "hr-HR", displayName: "Croatian", flag: "🇭🇷", isoCode: "hr-HR", translationCode: "hr", isAppleSpeechSupported: false),
        Language(id: "bg-BG", displayName: "Bulgarian", flag: "🇧🇬", isoCode: "bg-BG", translationCode: "bg", isAppleSpeechSupported: false),
        Language(id: "ro-RO", displayName: "Romanian", flag: "🇷🇴", isoCode: "ro-RO", translationCode: "ro", isAppleSpeechSupported: false),
        Language(id: "hu-HU", displayName: "Hungarian", flag: "🇭🇺", isoCode: "hu-HU", translationCode: "hu", isAppleSpeechSupported: false),
        Language(id: "cs-CZ", displayName: "Czech", flag: "🇨🇿", isoCode: "cs-CZ", translationCode: "cs", isAppleSpeechSupported: false),
        Language(id: "uk-UA", displayName: "Ukrainian", flag: "🇺🇦", isoCode: "uk-UA", translationCode: "uk", isAppleSpeechSupported: false),
        Language(id: "be-BY", displayName: "Belarusian", flag: "🇧🇾", isoCode: "be-BY", translationCode: "be", isAppleSpeechSupported: false),
        Language(id: "mk-MK", displayName: "Macedonian", flag: "🇲🇰", isoCode: "mk-MK", translationCode: "mk", isAppleSpeechSupported: false),
        Language(id: "sq-AL", displayName: "Albanian", flag: "🇦🇱", isoCode: "sq-AL", translationCode: "sq", isAppleSpeechSupported: false),
        Language(id: "sr-RS", displayName: "Serbian", flag: "🇷🇸", isoCode: "sr-RS", translationCode: "sr", isAppleSpeechSupported: false),
        Language(id: "bs-BA", displayName: "Bosnian", flag: "🇧🇦", isoCode: "bs-BA", translationCode: "bs", isAppleSpeechSupported: false),
        Language(id: "me-ME", displayName: "Montenegrin", flag: "🇲🇪", isoCode: "me-ME", translationCode: "me", isAppleSpeechSupported: false),
        Language(id: "eu-ES", displayName: "Basque", flag: "🇪🇸", isoCode: "eu-ES", translationCode: "eu", isAppleSpeechSupported: false),
        Language(id: "ca-ES", displayName: "Catalan", flag: "🇪🇸", isoCode: "ca-ES", translationCode: "ca", isAppleSpeechSupported: false),
        Language(id: "gl-ES", displayName: "Galician", flag: "🇪🇸", isoCode: "gl-ES", translationCode: "gl", isAppleSpeechSupported: false),
    ]
    
    // Default languages for quick access
    static let defaultDoctorLanguage = supportedLanguages.first { $0.id == "en-US" }!
    static let defaultPatientLanguage = supportedLanguages.first { $0.id == "es-ES" }!
    
    // Helper to get language by ID
    static func language(by id: String) -> Language? {
        return supportedLanguages.first { $0.id == id }
    }
    
    // Helper to check if a locale is supported by Apple Speech
    static func isAppleSpeechSupported(localeIdentifier: String) -> Bool {
        return SFSpeechRecognizer.supportedLocales().contains { $0.identifier == localeIdentifier }
    }
    
    // Get Apple Speech supported languages
    // Note: This dynamically checks against SFSpeechRecognizer.supportedLocales()
    // Some languages may show as supported but have limited functionality in simulator
    static var appleSpeechSupportedLanguages: [Language] {
        return supportedLanguages.filter { language in
            SFSpeechRecognizer.supportedLocales().contains { $0.identifier == language.isoCode }
        }
    }
    
    // Get server-only languages
    static var serverOnlyLanguages: [Language] {
        return supportedLanguages.filter { !$0.isAppleSpeechSupported }
    }
}

// MARK: - Patient Identification Model
struct PatientIdentification: Codable, Identifiable {
    let id = UUID()
    let fullName: String?
    let mrn: String?
    let encounterId: String?
    let dateOfBirth: String?
    let timestamp: Date
    
    var hasAnyIdentification: Bool {
        return !(fullName?.isEmpty ?? true) || 
               !(mrn?.isEmpty ?? true) || 
               !(encounterId?.isEmpty ?? true) || 
               !(dateOfBirth?.isEmpty ?? true)
    }
    
    var displayString: String {
        var components: [String] = []
        
        if let fullName = fullName, !fullName.isEmpty {
            components.append("Name: \(fullName)")
        }
        if let mrn = mrn, !mrn.isEmpty {
            components.append("MRN: \(mrn)")
        }
        if let encounterId = encounterId, !encounterId.isEmpty {
            components.append("Encounter: \(encounterId)")
        }
        if let dateOfBirth = dateOfBirth, !dateOfBirth.isEmpty {
            components.append("DOB: \(dateOfBirth)")
        }
        
        return components.isEmpty ? "Anonymous Patient" : components.joined(separator: " • ")
    }
}

// MARK: - Persistent Conversation Model
struct SavedConversation: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let doctorLanguage: String
    let patientLanguage: String
    let patientIdentification: PatientIdentification?
    let entries: [SavedConversationEntry]
    
    var title: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

struct SavedConversationEntry: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let speaker: String // "doctor" or "patient"
    let originalText: String
    let translatedText: String
    let originalLanguage: String
    let targetLanguage: String
    let confidence: Double
    let isServerTranscription: Bool
}

// MARK: - UserDefaults Extension for Persistence
extension UserDefaults {
    private enum Keys {
        static let doctorLanguage = "doctorLanguage"
        static let patientLanguage = "patientLanguage"
        static let savedConversations = "savedConversations"
        static let autoTurnOffDelay = "autoTurnOffDelay"
    }
    
    var doctorLanguage: Language {
        get {
            if let data = data(forKey: Keys.doctorLanguage),
               let language = try? JSONDecoder().decode(Language.self, from: data) {
                return language
            }
            return Language.defaultDoctorLanguage
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: Keys.doctorLanguage)
            }
        }
    }
    
    var patientLanguage: Language {
        get {
            if let data = data(forKey: Keys.patientLanguage),
               let language = try? JSONDecoder().decode(Language.self, from: data) {
                return language
            }
            return Language.defaultPatientLanguage
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: Keys.patientLanguage)
            }
        }
    }
    
    // Conversation history persistence
    var savedConversations: [SavedConversation] {
        get {
            if let data = data(forKey: Keys.savedConversations),
               let conversations = try? JSONDecoder().decode([SavedConversation].self, from: data) {
                return conversations.sorted { $0.timestamp > $1.timestamp }
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: Keys.savedConversations)
            }
        }
    }
    
    func saveConversation(_ conversation: SavedConversation) {
        var conversations = savedConversations
        conversations.append(conversation)
        // Keep only last 50 conversations to prevent storage bloat
        if conversations.count > 50 {
            conversations = Array(conversations.suffix(50))
        }
        savedConversations = conversations
    }
    
    // Auto-turn off delay setting (in seconds)
    var autoTurnOffDelay: TimeInterval {
        get {
            let stored = double(forKey: Keys.autoTurnOffDelay)
            if stored == 0 {
                return 30.0 // Default 30 seconds
            }
            return max(15.0, min(120.0, stored)) // Clamp between 15s and 2min
        }
        set {
            let clampedValue = max(15.0, min(120.0, newValue))
            set(clampedValue, forKey: Keys.autoTurnOffDelay)
        }
    }
}

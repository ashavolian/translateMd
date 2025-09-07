import SwiftUI

// MARK: - Conversation History Model
struct ConversationEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let speaker: Speaker
    let originalText: String
    let translatedText: String
    let originalLanguage: String
    let targetLanguage: String
    let confidence: Double
    let isServerTranscription: Bool
    
    enum Speaker {
        case doctor, patient
        
        var displayName: String {
            switch self {
            case .doctor: return "Doctor"
            case .patient: return "Patient"
            }
        }
        
        var color: Color {
            switch self {
            case .doctor: return .blue
            case .patient: return .green
            }
        }
    }
}

struct ConversationView: View {
    @ObservedObject var audioManager: AudioManager
    let patientIdentification: PatientIdentification?
    @StateObject private var translationService = TranslationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var clinicianText = ""
    @State private var patientText = ""
    @State private var isClinicianSpeaking = false
    @State private var isPatientSpeaking = false
    @State private var confidenceScore: Double = 1.0
    
    // Language selection
    @State private var doctorLanguage: Language = UserDefaults.standard.doctorLanguage
    @State private var patientLanguage: Language = UserDefaults.standard.patientLanguage
    @State private var showingDoctorLanguagePicker = false
    @State private var showingPatientLanguagePicker = false
    @State private var showingLowConfidenceAlert = false
    @State private var lastTranscriptionText = ""
    @State private var isUsingServerTranscription = false
    @State private var conversationHistory: [ConversationEntry] = []
    @State private var showingConversationHistory = false
    
    // Debouncing for conversation history
    @State private var pendingDoctorEntry: ConversationEntry?
    @State private var pendingPatientEntry: ConversationEntry?
    @State private var saveHistoryTimer: Timer?
    
    // Auto turn-off functionality
    @State private var inactivityTimer: Timer?
    @State private var lastActivityTime = Date()
    @State private var showingInactivityAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Patient-facing panel (top, rotated 180°)
                ZStack {
                    VStack {
                        Spacer()
                        
                        Text(patientText)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding()
                            .rotationEffect(.degrees(180))
                        
                        Spacer()
                    }
                    
                    // Patient language indicator (not rotated, readable by doctor)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showingPatientLanguagePicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Text(patientLanguage.flag)
                                    Text(patientLanguage.displayName)
                                        .font(.caption)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(patientLanguage.isAppleSpeechSupported ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                                .cornerRadius(8)
                            }
                            .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                }
                .frame(height: geometry.size.height / 2)
                .background(Color.green.opacity(0.1))
                .border(Color.green, width: isPatientSpeaking ? 3 : 1)
                
                // Clinician-facing panel (bottom, normal orientation)
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showingDoctorLanguagePicker = true
                        }) {
                            HStack(spacing: 4) {
                                Text(doctorLanguage.flag)
                                Text(doctorLanguage.displayName)
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(doctorLanguage.isAppleSpeechSupported ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    Text(clinicianText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Spacer()
                }
                .frame(height: geometry.size.height / 2)
                .background(Color.blue.opacity(0.1))
                .border(Color.blue, width: isClinicianSpeaking ? 3 : 1)
            }
            .overlay(alignment: .bottom) {
                // Doctor control area - compact
                HStack(spacing: 10) {
                    Button("End") {
                        audioManager.stopRecording()
                        dismiss()
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)
                    
                    
                    Button(action: {
                        showingConversationHistory = true
                    }) {
                        HStack(spacing: 4) {
                            Text("History")
                                .font(.caption)
                            if !conversationHistory.isEmpty {
                                Text("(\(conversationHistory.count))")
                                    .font(.caption2)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(conversationHistory.isEmpty ? Color.purple.opacity(0.6) : Color.purple)
                        .cornerRadius(8)
                    }
                    
                    // Confidence indicator
                    confidenceBadge
                    
                    // Server transcription indicator
                    if isUsingServerTranscription {
                        HStack(spacing: 4) {
                            Image(systemName: "cloud")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("Server")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    
                    
                    Spacer()
                    
                    // Doctor toggle button - compact
                    Button(action: {
                        if isClinicianSpeaking {
                            // Switch to patient mode
                            isClinicianSpeaking = false
                            isPatientSpeaking = true
                        } else {
                            // Switch to doctor mode
                            isClinicianSpeaking = true
                            isPatientSpeaking = false
                        }
                        updateAudioManagerForCurrentSpeaker()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isClinicianSpeaking ? "mic.fill" : "mic")
                                .font(.callout)
                                .foregroundColor(.white)
                            Text(isClinicianSpeaking ? "Doctor" : "Doctor")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isClinicianSpeaking ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(15)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            audioManager.delegate = self
            
            // Start with patient speaking (recording)
            isPatientSpeaking = true
            isClinicianSpeaking = false
            
            // Initialize audio immediately since language was selected in ContentView
            Task {
                await audioManager.requestPermissions()
                if audioManager.hasPermissions {
                    let currentLanguage = isClinicianSpeaking ? doctorLanguage : patientLanguage
                    audioManager.updateLocale(currentLanguage.isoCode)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.audioManager.startRecording()
                        // Start inactivity timer after recording begins
                        self.startInactivityTimer()
                    }
                }
            }
        }
        .onDisappear {
            audioManager.stopRecording()
            // Save any pending entries before leaving
            saveHistoryTimer?.invalidate()
            savePendingEntries()
            
            // Clean up inactivity timer
            inactivityTimer?.invalidate()
            
            // Save the conversation to persistent storage if it has content
            saveConversationToPersistentStorage()
        }
        .sheet(isPresented: $showingDoctorLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: $doctorLanguage,
                title: "Doctor Language"
            ) { newLanguage in
                doctorLanguage = newLanguage
                UserDefaults.standard.doctorLanguage = newLanguage
                updateAudioManagerForCurrentSpeaker()
            }
        }
        .sheet(isPresented: $showingPatientLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: $patientLanguage,
                title: "Patient Language"
            ) { newLanguage in
                patientLanguage = newLanguage
                UserDefaults.standard.patientLanguage = newLanguage
                updateAudioManagerForCurrentSpeaker()
            }
        }
        .alert("Low Confidence Transcription", isPresented: $showingLowConfidenceAlert) {
            Button("Try Again") {
                // Restart recording for better transcription
                audioManager.stopRecording()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    audioManager.startRecording()
                }
            }
            Button("Use Anyway") {
                // Keep the current transcription
            }
        } message: {
            Text("The speech recognition confidence is low (\(Int(confidenceScore * 100))%). You can try speaking again for better accuracy.")
        }
        .sheet(isPresented: $showingConversationHistory) {
            ConversationHistoryView(conversationHistory: $conversationHistory)
        }
        .alert("Recording Stopped", isPresented: $showingInactivityAlert) {
            Button("Resume Recording") {
                startInactivityTimer()
                if audioManager.hasPermissions {
                    audioManager.startRecording()
                }
            }
            Button("End Session") {
                dismiss()
            }
        } message: {
            Text("Recording has been automatically stopped due to inactivity. Would you like to resume or end this session?")
        }
    }
    
    @ViewBuilder
    private var confidenceBadge: some View {
        Button(action: {
            if confidenceScore < 0.6 {
                showingLowConfidenceAlert = true
            }
        }) {
            HStack(spacing: 4) {
                Circle()
                    .fill(confidenceColor)
                    .frame(width: 8, height: 8)
                Text("\(Int(confidenceScore * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                if confidenceScore < 0.6 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.8))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var confidenceColor: Color {
        if confidenceScore >= 0.8 { return .green }
        if confidenceScore >= 0.6 { return .orange }
        return .red
    }
    
    private func updateAudioManagerForCurrentSpeaker() {
        let currentLanguage = isClinicianSpeaking ? doctorLanguage : patientLanguage
        print("Switching to \(currentLanguage.displayName) for \(isClinicianSpeaking ? "doctor" : "patient")")
        
        // Stop current recording first
        audioManager.stopRecording()
        
        // Update locale and restart recording
        audioManager.updateLocale(currentLanguage.isoCode)
        
        // Update server transcription indicator
        isUsingServerTranscription = !currentLanguage.isAppleSpeechSupported
        
        // Reset inactivity timer when switching speakers
        startInactivityTimer()
        
        // Restart recording after a brief delay to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.audioManager.hasPermissions {
                self.audioManager.startRecording()
            }
        }
    }
    
    // MARK: - Inactivity Timer Management
    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        lastActivityTime = Date()
        
        let delay = UserDefaults.standard.autoTurnOffDelay
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            self.handleInactivityTimeout()
        }
    }
    
    private func resetInactivityTimer() {
        lastActivityTime = Date()
        startInactivityTimer()
    }
    
    private func handleInactivityTimeout() {
        DispatchQueue.main.async {
            // Stop recording
            self.audioManager.stopRecording()
            
            // Show alert
            self.showingInactivityAlert = true
            
            print("Recording stopped due to inactivity after \(UserDefaults.standard.autoTurnOffDelay) seconds")
        }
    }
    
}

// MARK: - AudioManagerDelegate
extension ConversationView: AudioManagerDelegate {
    func didReceiveTranscription(_ text: String, confidence: Float) {
        DispatchQueue.main.async {
            self.confidenceScore = Double(confidence)
            self.lastTranscriptionText = text
            
            // Reset inactivity timer on transcription activity
            if !text.isEmpty {
                self.resetInactivityTimer()
            }
            
            // Check for low confidence and show warning
            if confidence < 0.6 && !text.isEmpty {
                // Don't auto-show alert for partial results, only for final results
                // The user can tap the confidence badge to see the alert
            }
            
            if self.isClinicianSpeaking {
                self.clinicianText = text
                // Translate to patient's language
                Task {
                    let result = await self.translationService.translate(
                        text: text,
                        from: self.doctorLanguage.translationCode,
                        to: self.patientLanguage.translationCode
                    )
                    DispatchQueue.main.async {
                        let translation = result?.translation ?? "Translation failed"
                        self.patientText = translation
                        
                        // Update pending entry and debounce saving to history
                        let entry = ConversationEntry(
                            timestamp: Date(),
                            speaker: .doctor,
                            originalText: text,
                            translatedText: translation,
                            originalLanguage: self.doctorLanguage.displayName,
                            targetLanguage: self.patientLanguage.displayName,
                            confidence: Double(confidence),
                            isServerTranscription: false
                        )
                        self.debounceSaveToHistory(entry: entry)
                    }
                }
            } else if self.isPatientSpeaking {
                self.patientText = text
                // Translate to clinician's language
                Task {
                    let result = await self.translationService.translate(
                        text: text,
                        from: self.patientLanguage.translationCode,
                        to: self.doctorLanguage.translationCode
                    )
                    DispatchQueue.main.async {
                        let translation = result?.translation ?? "Translation failed"
                        self.clinicianText = translation
                        
                        // Update pending entry and debounce saving to history
                        let entry = ConversationEntry(
                            timestamp: Date(),
                            speaker: .patient,
                            originalText: text,
                            translatedText: translation,
                            originalLanguage: self.patientLanguage.displayName,
                            targetLanguage: self.doctorLanguage.displayName,
                            confidence: Double(confidence),
                            isServerTranscription: false
                        )
                        self.debounceSaveToHistory(entry: entry)
                    }
                }
            }
        }
    }
    
    func didEncounterError(_ error: Error) {
        print("Audio error: \(error)")
        
        // Handle specific error cases
        if let speechError = error as? NSError {
            switch speechError.code {
            case 1110: // No speech detected
                print("No speech detected - this is normal in simulator")
                return
            case 203: // Speech recognition not available
                print("Speech recognition not available - falling back to server transcription")
                return
            case 301: // Recognition request was canceled
                print("Recognition request was canceled - this is normal when switching languages")
                return
            default:
                print("Unhandled speech error: \(speechError.code) - \(error.localizedDescription)")
                break
            }
        }
        
        // For other errors, you might want to show an alert to the user
        // but for now, just log them
    }
    
    func didReceiveServerTranscription(_ text: String, confidence: Float, language: String) {
        DispatchQueue.main.async {
            self.confidenceScore = Double(confidence)
            self.lastTranscriptionText = text
            
            // Reset inactivity timer on server transcription activity
            if !text.isEmpty {
                self.resetInactivityTimer()
            }
            
            if self.isClinicianSpeaking {
                self.clinicianText = text
                // Translate to patient's language
                Task {
                    let result = await self.translationService.translate(
                        text: text,
                        from: language,
                        to: self.patientLanguage.translationCode
                    )
                    DispatchQueue.main.async {
                        let translation = result?.translation ?? "Translation failed"
                        self.patientText = translation
                        
                        // Update pending entry and debounce saving to history
                        let entry = ConversationEntry(
                            timestamp: Date(),
                            speaker: .doctor,
                            originalText: text,
                            translatedText: translation,
                            originalLanguage: self.doctorLanguage.displayName,
                            targetLanguage: self.patientLanguage.displayName,
                            confidence: Double(confidence),
                            isServerTranscription: true
                        )
                        self.debounceSaveToHistory(entry: entry)
                    }
                }
            } else if self.isPatientSpeaking {
                self.patientText = text
                // Translate to clinician's language
                Task {
                    let result = await self.translationService.translate(
                        text: text,
                        from: language,
                        to: self.doctorLanguage.translationCode
                    )
                    DispatchQueue.main.async {
                        let translation = result?.translation ?? "Translation failed"
                        self.clinicianText = translation
                        
                        // Update pending entry and debounce saving to history
                        let entry = ConversationEntry(
                            timestamp: Date(),
                            speaker: .patient,
                            originalText: text,
                            translatedText: translation,
                            originalLanguage: self.patientLanguage.displayName,
                            targetLanguage: self.doctorLanguage.displayName,
                            confidence: Double(confidence),
                            isServerTranscription: true
                        )
                        self.debounceSaveToHistory(entry: entry)
                    }
                }
            }
        }
    }
    
    func didDetectLanguage(_ languageCode: String) {
        // No longer using auto-detection, but keep the method for compatibility
        print("Language detection disabled")
    }
    
    // Debounced history saving - only save after user stops speaking for 2 seconds
    private func debounceSaveToHistory(entry: ConversationEntry) {
        // Skip very short or empty text
        guard !entry.originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              entry.originalText.count >= 3 else {
            return
        }
        
        // Update the pending entry for this speaker
        switch entry.speaker {
        case .doctor:
            pendingDoctorEntry = entry
        case .patient:
            pendingPatientEntry = entry
        }
        
        // Cancel existing timer and start a new one
        saveHistoryTimer?.invalidate()
        saveHistoryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            self.savePendingEntries()
        }
    }
    
    private func savePendingEntries() {
        // Save any pending entries to the actual history
        if let doctorEntry = pendingDoctorEntry {
            // Only save if it's not a duplicate of the last saved entry
            if conversationHistory.isEmpty || 
               conversationHistory.last?.originalText != doctorEntry.originalText ||
               conversationHistory.last?.speaker != doctorEntry.speaker {
                conversationHistory.append(doctorEntry)
                print("Saved doctor entry: \(doctorEntry.originalText)")
            }
            pendingDoctorEntry = nil
        }
        
        if let patientEntry = pendingPatientEntry {
            // Only save if it's not a duplicate of the last saved entry
            if conversationHistory.isEmpty || 
               conversationHistory.last?.originalText != patientEntry.originalText ||
               conversationHistory.last?.speaker != patientEntry.speaker {
                conversationHistory.append(patientEntry)
                print("Saved patient entry: \(patientEntry.originalText)")
            }
            pendingPatientEntry = nil
        }
    }
    
    private func saveConversationToPersistentStorage() {
        // Only save if there's meaningful conversation content
        guard !conversationHistory.isEmpty else { return }
        
        // Filter out very short entries
        let meaningfulEntries = conversationHistory.filter { entry in
            entry.originalText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
        }
        
        guard !meaningfulEntries.isEmpty else { return }
        
        // Convert to saved conversation format
        let savedEntries = meaningfulEntries.map { entry in
            SavedConversationEntry(
                timestamp: entry.timestamp,
                speaker: entry.speaker == .doctor ? "doctor" : "patient",
                originalText: entry.originalText,
                translatedText: entry.translatedText,
                originalLanguage: entry.originalLanguage,
                targetLanguage: entry.targetLanguage,
                confidence: entry.confidence,
                isServerTranscription: entry.isServerTranscription
            )
        }
        
        let savedConversation = SavedConversation(
            timestamp: Date(),
            doctorLanguage: doctorLanguage.displayName,
            patientLanguage: patientLanguage.displayName,
            patientIdentification: patientIdentification,
            entries: savedEntries
        )
        
        UserDefaults.standard.saveConversation(savedConversation)
        print("Saved conversation with \(savedEntries.count) entries")
    }
}

// MARK: - Language Picker View
struct LanguagePickerView: View {
    @Binding var selectedLanguage: Language
    let title: String
    let onLanguageSelected: (Language) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Apple Speech Supported")) {
                    ForEach(Language.appleSpeechSupportedLanguages) { language in
                        LanguageRowView(
                            language: language,
                            isSelected: language.id == selectedLanguage.id
                        ) {
                            selectedLanguage = language
                            onLanguageSelected(language)
                            dismiss()
                        }
                    }
                }
                
                Section(header: Text("Server Transcription Only"), footer: Text("These languages use server-side transcription via Whisper API.")) {
                    ForEach(Language.serverOnlyLanguages.filter { $0.id != "auto" }) { language in
                        LanguageRowView(
                            language: language,
                            isSelected: language.id == selectedLanguage.id
                        ) {
                            selectedLanguage = language
                            onLanguageSelected(language)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LanguageRowView: View {
    let language: Language
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(language.flag)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(language.isoCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
                
                if !language.isAppleSpeechSupported {
                    Image(systemName: "cloud")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Patient Identification View
struct PatientIdentificationView: View {
    let onIdentificationComplete: (PatientIdentification?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var fullName = ""
    @State private var mrn = ""
    @State private var encounterId = ""
    @State private var dateOfBirth = ""
    
    private var hasAnyInput: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !mrn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !encounterId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "person.text.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Patient Identification")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("How would you like to identify this patient?")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Name")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("Enter patient's full name", text: $fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Medical Record Number (MRN)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("Enter MRN", text: $mrn)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Encounter ID")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("Enter encounter ID", text: $encounterId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date of Birth")
                            .font(.headline)
                            .foregroundColor(.primary)
                        TextField("MM/DD/YYYY", text: $dateOfBirth)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numbersAndPunctuation)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Continue") {
                        let identification = PatientIdentification(
                            fullName: fullName.isEmpty ? nil : fullName,
                            mrn: mrn.isEmpty ? nil : mrn,
                            encounterId: encounterId.isEmpty ? nil : encounterId,
                            dateOfBirth: dateOfBirth.isEmpty ? nil : dateOfBirth,
                            timestamp: Date()
                        )
                        onIdentificationComplete(identification)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(hasAnyInput ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(!hasAnyInput)
                    
                    Button("Skip Patient Identification") {
                        onIdentificationComplete(nil)
                        dismiss()
                    }
                    .font(.body)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Patient Language Prompt View
struct PatientLanguagePromptView: View {
    let patientIdentification: PatientIdentification?
    let onLanguageSelected: (Language) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingFullLanguagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Select Patient Language")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let patientId = patientIdentification {
                        VStack(spacing: 8) {
                            Text("Patient Information")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(patientId.displayString)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    Text("Choose the language your patient will speak in")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ForEach(Language.appleSpeechSupportedLanguages.prefix(8)) { language in
                        Button(action: {
                            onLanguageSelected(language)
                            dismiss()
                        }) {
                            VStack(spacing: 8) {
                                Text(language.flag)
                                    .font(.largeTitle)
                                Text(language.displayName)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("More Languages...") {
                    showingFullLanguagePicker = true
                }
                .font(.body)
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingFullLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: .constant(Language.defaultPatientLanguage),
                title: "Patient Language"
            ) { selectedLanguage in
                onLanguageSelected(selectedLanguage)
                dismiss()
            }
        }
    }
}

// MARK: - Conversation History View
struct ConversationHistoryView: View {
    @Binding var conversationHistory: [ConversationEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearAlert = false
    @State private var showOnlyTranslations = false
    
    private var doctorLanguage: String {
        UserDefaults.standard.doctorLanguage.displayName
    }
    
    var body: some View {
        NavigationView {
            List {
                if conversationHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "message.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No conversation history yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Start speaking to see the conversation transcript here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(conversationHistory.reversed()) { entry in
                        ConversationEntryRowView(entry: entry, showOnlyTranslations: showOnlyTranslations)
                    }
                }
            }
            .navigationTitle("Conversation History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showOnlyTranslations.toggle()
                        }) {
                            HStack {
                                Text(showOnlyTranslations ? "Show Original Text" : "View \(doctorLanguage) Only")
                                Image(systemName: showOnlyTranslations ? "eye" : "eye.slash")
                            }
                        }
                        
                        Divider()
                        
                        Button("Clear History", role: .destructive) {
                            showingClearAlert = true
                        }
                        Button("Export") {
                            // TODO: Implement export functionality
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Clear Conversation History", isPresented: $showingClearAlert) {
            Button("Clear", role: .destructive) {
                conversationHistory.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all conversation history. This action cannot be undone.")
        }
    }
}

struct ConversationEntryRowView: View {
    let entry: ConversationEntry
    let showOnlyTranslations: Bool
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var confidenceColor: Color {
        if entry.confidence >= 0.8 { return .green }
        if entry.confidence >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with speaker, time, and confidence
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.speaker.color)
                        .frame(width: 8, height: 8)
                    Text(entry.speaker.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(entry.speaker.color)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    // Confidence indicator
                    HStack(spacing: 2) {
                        Circle()
                            .fill(confidenceColor)
                            .frame(width: 6, height: 6)
                        Text("\(Int(entry.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Transcription method
                    Image(systemName: entry.isServerTranscription ? "cloud" : "mic")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(timeFormatter.string(from: entry.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if showOnlyTranslations {
                // When "View Doctor Language Only" is enabled:
                // - Show doctor's original text
                // - Show patient's translated text (to doctor's language)
                if entry.speaker == .doctor {
                    // Show doctor's original text
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Doctor (\(entry.originalLanguage))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Text(entry.originalText)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(entry.speaker.color.opacity(0.1))
                            .cornerRadius(8)
                    }
                } else {
                    // Show patient's translated text (to doctor's language)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Patient (\(entry.targetLanguage))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Text(entry.translatedText)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(entry.speaker.color.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else {
                // Show both original and translated text for all entries (default behavior)
                
                // Original text
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Original (\(entry.originalLanguage))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(entry.originalText)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(entry.speaker.color.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Translated text
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Translation (\(entry.targetLanguage))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Text(entry.translatedText)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationView(audioManager: AudioManager(), patientIdentification: nil)
}

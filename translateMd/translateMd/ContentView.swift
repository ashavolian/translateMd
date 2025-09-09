import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var translationManager = TranslationManager()
    @StateObject private var speechManager = SpeechManager()
    @State private var showingSettings = false
    @State private var clinicianText = ""
    @State private var patientText = ""
    @State private var currentSpeaker: Speaker = .none
    @State private var isListening = false
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Patient panel (top, rotated 180°)
                VStack {
                    HStack {
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        .rotationEffect(.degrees(180))
                        
                        Spacer()
                        
                        Text("Patient")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(180))
                        
                        Spacer()
                        
                        ConfidenceView(confidence: translationManager.lastConfidence)
                            .rotationEffect(.degrees(180))
                    }
                    .padding()
                    
                    Spacer()
                    
                    ScrollView {
                        Text(patientText.isEmpty ? "Translation will appear here" : patientText)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .rotationEffect(.degrees(180))
                    
                    Spacer()
                    
                    // Patient microphone button (rotated)
                    Button(action: { startListening(for: .patient) }) {
                        Image(systemName: currentSpeaker == .patient && isListening ? "mic.fill" : "mic")
                            .font(.system(size: 40))
                            .foregroundColor(currentSpeaker == .patient && isListening ? .red : .blue)
                            .padding()
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    .rotationEffect(.degrees(180))
                    .padding()
                }
                .frame(height: geometry.size.height / 2)
                .background(Color(.systemGray6))
                .border(Color.gray, width: 1)
                
                // Clinician panel (bottom)
                VStack {
                    // Clinician microphone button
                    Button(action: { startListening(for: .clinician) }) {
                        Image(systemName: currentSpeaker == .clinician && isListening ? "mic.fill" : "mic")
                            .font(.system(size: 40))
                            .foregroundColor(currentSpeaker == .clinician && isListening ? .red : .blue)
                            .padding()
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                    }
                    .padding()
                    
                    Spacer()
                    
                    ScrollView {
                        Text(clinicianText.isEmpty ? "Translation will appear here" : clinicianText)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Spacer()
                    
                    HStack {
                        ConfidenceView(confidence: translationManager.lastConfidence)
                        
                        Spacer()
                        
                        Text("Clinician")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                    .padding()
                }
                .frame(height: geometry.size.height / 2)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            audioManager.setup()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onReceive(speechManager.$recognizedText) { text in
            handleRecognizedText(text)
        }
        .onReceive(translationManager.$translatedText) { text in
            handleTranslatedText(text)
        }
    }
    
    private func startListening(for speaker: Speaker) {
        if isListening && currentSpeaker == speaker {
            // Stop listening
            speechManager.stopRecording()
            isListening = false
            currentSpeaker = .none
        } else {
            // Start listening
            currentSpeaker = speaker
            isListening = true
            
            // Clear the opposite panel
            if speaker == .clinician {
                patientText = ""
            } else {
                clinicianText = ""
            }
            
            speechManager.startRecording(
                sourceLanguage: speaker == .clinician ? 
                    translationManager.clinicianLanguage : 
                    translationManager.patientLanguage
            )
        }
    }
    
    private func handleRecognizedText(_ text: String) {
        guard !text.isEmpty else { return }
        
        // Show the recognized text in the current speaker's panel
        if currentSpeaker == .clinician {
            clinicianText = text
        } else if currentSpeaker == .patient {
            patientText = text
        }
        
        // Translate the text
        translationManager.translate(
            text: text,
            from: currentSpeaker == .clinician ? 
                translationManager.clinicianLanguage : 
                translationManager.patientLanguage,
            to: currentSpeaker == .clinician ? 
                translationManager.patientLanguage : 
                translationManager.clinicianLanguage,
            for: currentSpeaker == .clinician ? .patient : .clinician
        )
    }
    
    private func handleTranslatedText(_ translation: TranslationResult) {
        // Show translation in the opposite panel
        if translation.targetSpeaker == .clinician {
            clinicianText = translation.text
        } else {
            patientText = translation.text
        }
        
        // Speak the translation
        speechManager.speak(
            text: translation.text,
            language: translation.targetSpeaker == .clinician ? 
                translationManager.clinicianLanguage : 
                translationManager.patientLanguage
        )
        
        // Stop listening after translation
        isListening = false
        currentSpeaker = .none
    }
}

#Preview {
    ContentView()
}
import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingConversation = false
    @State private var showingPatientIdentification = false
    @State private var showingPatientLanguagePrompt = false
    @State private var selectedPatientLanguage: Language = UserDefaults.standard.patientLanguage
    @State private var patientIdentification: PatientIdentification?
    @State private var showingPastConversations = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 30) {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            Text("Clinical Interpreter")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Real-time translation for clinician-patient communication")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                Task {
                                    await audioManager.requestPermissions()
                                    if audioManager.hasPermissions {
                                        showingPatientIdentification = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                    Text("Start Conversation")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            
                            Button("Settings") {
                                showingSettings = true
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                            
                            Button("Past Conversations") {
                                showingPastConversations = true
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("⚠️ PROTOTYPE ONLY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("Uses public OpenAI API. Not HIPAA-compliant.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPatientIdentification) {
            PatientIdentificationView { identification in
                patientIdentification = identification
                showingPatientLanguagePrompt = true
            }
        }
        .sheet(isPresented: $showingPatientLanguagePrompt) {
            PatientLanguagePromptView(patientIdentification: patientIdentification) { selectedLanguage in
                selectedPatientLanguage = selectedLanguage
                UserDefaults.standard.patientLanguage = selectedLanguage
                showingConversation = true
            }
        }
        .sheet(isPresented: $showingPastConversations) {
            PastConversationsView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $showingConversation) {
            ConversationView(audioManager: audioManager, patientIdentification: patientIdentification)
        }
    }
}

// MARK: - Past Conversations View
struct PastConversationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var savedConversations: [SavedConversation] = []
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: SavedConversation?
    
    var body: some View {
        NavigationView {
            Group {
                if savedConversations.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Past Conversations")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Your conversation history will appear here after you complete conversations.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Spacer()
                        
                        Button("Start New Conversation") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                } else {
                    List {
                        ForEach(savedConversations) { conversation in
                            NavigationLink(destination: SavedConversationDetailView(conversation: conversation)) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(conversation.title)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(conversation.entries.count) entries")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let patientId = conversation.patientIdentification {
                                        Text(patientId.displayString)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                    }
                                    
                                    HStack {
                                        Label(conversation.doctorLanguage, systemImage: "stethoscope")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                        
                                        Label(conversation.patientLanguage, systemImage: "person")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    
                                    if let firstEntry = conversation.entries.first {
                                        Text(firstEntry.originalText)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                }
            }
            .navigationTitle("Past Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !savedConversations.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .onAppear {
                loadSavedConversations()
            }
        }
    }
    
    private func loadSavedConversations() {
        savedConversations = UserDefaults.standard.savedConversations
    }
    
    private func deleteConversations(offsets: IndexSet) {
        var conversations = UserDefaults.standard.savedConversations
        conversations.remove(atOffsets: offsets)
        UserDefaults.standard.savedConversations = conversations
        loadSavedConversations()
    }
}

// MARK: - Saved Conversation Detail View
struct SavedConversationDetailView: View {
    let conversation: SavedConversation
    
    var body: some View {
        List {
            Section(header: Text("Conversation Details")) {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(conversation.title)
                        .foregroundColor(.secondary)
                }
                
                if let patientId = conversation.patientIdentification {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Patient Information")
                        Text(patientId.displayString)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Doctor Language")
                    Spacer()
                    Text(conversation.doctorLanguage)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Patient Language")
                    Spacer()
                    Text(conversation.patientLanguage)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Total Entries")
                    Spacer()
                    Text("\(conversation.entries.count)")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Conversation Transcript")) {
                ForEach(conversation.entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(entry.speaker.capitalized)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(entry.speaker == "doctor" ? .blue : .green)
                            
                            Spacer()
                            
                            Text(DateFormatter.timeFormatter.string(from: entry.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if entry.isServerTranscription {
                                Image(systemName: "cloud")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Text(entry.originalText)
                            .font(.body)
                        
                        if !entry.translatedText.isEmpty && entry.translatedText != entry.originalText {
                            Text(entry.translatedText)
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("\(entry.originalLanguage) → \(entry.targetLanguage)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(String(format: "%.0f%% confidence", entry.confidence * 100))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var doctorLanguage: Language = UserDefaults.standard.doctorLanguage
    @State private var showingDoctorLanguagePicker = false
    @State private var autoTurnOffDelay: Double = UserDefaults.standard.autoTurnOffDelay
    
    private func formatDuration(_ seconds: Double) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
            if remainingSeconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(remainingSeconds)s"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Default Languages")) {
                    Button(action: {
                        showingDoctorLanguagePicker = true
                    }) {
                        HStack {
                            Text("Doctor Language")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(doctorLanguage.flag)
                            Text(doctorLanguage.displayName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Recording Settings"), footer: Text("Automatically stop recording after a period of silence to conserve battery and prevent accidental recordings.")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Auto Turn-Off Delay")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(formatDuration(autoTurnOffDelay))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $autoTurnOffDelay, in: 15...120, step: 5) {
                            Text("Auto Turn-Off Delay")
                        }
                        .onChange(of: autoTurnOffDelay) { oldValue, newValue in
                            UserDefaults.standard.autoTurnOffDelay = newValue
                        }
                        
                        HStack {
                            Text("15s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("2m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("⚠️ PROTOTYPE ONLY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("This app uses public OpenAI APIs and is not HIPAA-compliant. Do not use with real patient data.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDoctorLanguagePicker) {
                LanguagePickerView(
                    selectedLanguage: $doctorLanguage,
                    title: "Doctor Language"
                ) { newLanguage in
                    doctorLanguage = newLanguage
                    UserDefaults.standard.doctorLanguage = newLanguage
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

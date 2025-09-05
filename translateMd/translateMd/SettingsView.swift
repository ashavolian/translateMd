import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var translationManager = TranslationManager()
    
    private let supportedLanguages = [
        ("en-US", "English (US)"),
        ("es-ES", "Spanish (Spain)"),
        ("es-MX", "Spanish (Mexico)"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("zh-CN", "Chinese (Simplified)"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("ar-SA", "Arabic"),
        ("hi-IN", "Hindi"),
        ("ru-RU", "Russian")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Language Settings") {
                    Picker("Clinician Language", selection: $translationManager.clinicianLanguage) {
                        ForEach(supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                    
                    Picker("Patient Language", selection: $translationManager.patientLanguage) {
                        ForEach(supportedLanguages, id: \.0) { code, name in
                            Text(name).tag(code)
                        }
                    }
                }
                
                Section("Confidence Settings") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Confidence Threshold")
                            Spacer()
                            Text("\(Int(translationManager.confidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $translationManager.confidenceThreshold, in: 0.3...0.9, step: 0.1)
                            .accentColor(.blue)
                    }
                    
                    Text("Translations below this threshold will show a warning indicator")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Privacy & Storage") {
                    Toggle("Save Translation History", isOn: $translationManager.saveHistory)
                    
                    if translationManager.saveHistory {
                        Text("Conversations are stored locally on device only")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Conversations are not saved")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear History") {
                        translationManager.clearHistory()
                    }
                    .foregroundColor(.red)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Prototype)")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("⚠️ Prototype Disclaimer")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        Text("This is a prototype application using the public OpenAI API. It is NOT HIPAA-compliant and MUST NOT be used with PHI/PII in production settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                
                Section("Support") {
                    Link("OpenAI Realtime API Documentation", 
                         destination: URL(string: "https://platform.openai.com/docs/guides/realtime")!)
                    
                    HStack {
                        Text("Server Status")
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
        }
    }
}

#Preview {
    SettingsView()
}
import SwiftUI

struct ConversationView: View {
    @ObservedObject var audioManager: AudioManager
    @StateObject private var translationService = TranslationService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var clinicianText = ""
    @State private var patientText = ""
    @State private var isClinicianSpeaking = false
    @State private var isPatientSpeaking = false
    @State private var confidenceScore: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Patient-facing panel (top, rotated 180°)
                VStack {
                    HStack {
                        Text("Patient")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        confidenceBadge
                    }
                    .padding(.horizontal)
                    .rotationEffect(.degrees(180))
                    
                    Spacer()
                    
                    Text(isClinicianSpeaking ? clinicianText : patientText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .rotationEffect(.degrees(180))
                    
                    Spacer()
                    
                    HStack {
                        micButton(isActive: $isPatientSpeaking, label: "Patient Mic")
                        Spacer()
                        Text("🇪🇸 Spanish")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .rotationEffect(.degrees(180))
                }
                .frame(height: geometry.size.height / 2)
                .background(Color.green.opacity(0.1))
                .border(Color.green, width: isPatientSpeaking ? 3 : 1)
                
                // Clinician-facing panel (bottom, normal orientation)
                VStack {
                    HStack {
                        Text("🇺🇸 English")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        Spacer()
                        micButton(isActive: $isClinicianSpeaking, label: "Clinician Mic")
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Text(isPatientSpeaking ? patientText : clinicianText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Spacer()
                    
                    HStack {
                        confidenceBadge
                        Spacer()
                        Text("Clinician")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                .frame(height: geometry.size.height / 2)
                .background(Color.blue.opacity(0.1))
                .border(Color.blue, width: isClinicianSpeaking ? 3 : 1)
            }
            .overlay(alignment: .center) {
                // Control bar
                HStack(spacing: 20) {
                    Button("End") {
                        audioManager.stopRecording()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(20)
                    
                    Button("Clear") {
                        clinicianText = ""
                        patientText = ""
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(20)
                }
                .background(Color.black.opacity(0.8))
                .cornerRadius(25)
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            audioManager.delegate = self
        }
    }
    
    @ViewBuilder
    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            Text("\(Int(confidenceScore * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.8))
        .cornerRadius(12)
    }
    
    private var confidenceColor: Color {
        if confidenceScore >= 0.8 { return .green }
        if confidenceScore >= 0.6 { return .orange }
        return .red
    }
    
    @ViewBuilder
    private func micButton(isActive: Binding<Bool>, label: String) -> some View {
        Button(action: {
            if isActive.wrappedValue {
                audioManager.stopRecording()
                isActive.wrappedValue = false
            } else {
                audioManager.startRecording()
                isActive.wrappedValue = true
                // Stop the other mic
                if label.contains("Clinician") {
                    isPatientSpeaking = false
                } else {
                    isClinicianSpeaking = false
                }
            }
        }) {
            Image(systemName: isActive.wrappedValue ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundColor(isActive.wrappedValue ? .red : .primary)
                .frame(width: 44, height: 44)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
    }
}

// MARK: - AudioManagerDelegate
extension ConversationView: AudioManagerDelegate {
    func didReceiveTranscription(_ text: String, confidence: Float) {
        DispatchQueue.main.async {
            self.confidenceScore = Double(confidence)
            
            if self.isClinicianSpeaking {
                self.clinicianText = text
                // TODO: Translate to patient's language
                Task {
                    let translation = await self.translationService.translate(
                        text: text,
                        from: "en",
                        to: "es"
                    )
                    DispatchQueue.main.async {
                        self.patientText = translation ?? "Translation failed"
                    }
                }
            } else if self.isPatientSpeaking {
                self.patientText = text
                // TODO: Translate to clinician's language
                Task {
                    let translation = await self.translationService.translate(
                        text: text,
                        from: "es", 
                        to: "en"
                    )
                    DispatchQueue.main.async {
                        self.clinicianText = translation ?? "Translation failed"
                    }
                }
            }
        }
    }
    
    func didEncounterError(_ error: Error) {
        print("Audio error: \(error)")
    }
}

#Preview {
    ConversationView(audioManager: AudioManager())
}

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
                    Spacer()
                    
                    Text(patientText)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .padding()
                        .rotationEffect(.degrees(180))
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Text("🇪🇸 Spanish")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .rotationEffect(.degrees(180))
                }
                .frame(height: geometry.size.height / 2)
                .background(Color.green.opacity(0.1))
                .border(Color.green, width: isPatientSpeaking ? 3 : 1)
                
                // Clinician-facing panel (bottom, normal orientation)
                VStack {
                    HStack {
                        Spacer()
                        Text("🇺🇸 English")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
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
                    
                    Button("Clear") {
                        clinicianText = ""
                        patientText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                    
                    // Confidence indicator
                    confidenceBadge
                    
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
            Task {
                await audioManager.requestPermissions()
                if audioManager.hasPermissions {
                    audioManager.startRecording()
                }
            }
        }
        .onDisappear {
            audioManager.stopRecording()
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

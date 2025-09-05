import SwiftUI

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingConversation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack {
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
                        .padding(.horizontal)
                }
                
                VStack(spacing: 20) {
                    Button(action: {
                        Task {
                            await audioManager.requestPermissions()
                            showingConversation = true
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
                        // TODO: Settings view
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    Button("Past Conversations") {
                        // TODO: History view
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack {
                    Text("⚠️ PROTOTYPE ONLY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Uses public OpenAI API. Not HIPAA-compliant.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingConversation) {
            ConversationView(audioManager: audioManager)
        }
    }
}

#Preview {
    ContentView()
}

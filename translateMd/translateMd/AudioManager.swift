import AVFoundation
import Foundation

class AudioManager: ObservableObject {
    private var audioSession: AVAudioSession
    
    init() {
        self.audioSession = AVAudioSession.sharedInstance()
    }
    
    func setup() {
        do {
            // Configure audio session for recording and playback
            try audioSession.setCategory(.playAndRecord, 
                                       mode: .default, 
                                       options: [.defaultToSpeaker, .allowBluetooth])
            
            // Set preferred sample rate and buffer duration for optimal performance
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            
            // Activate the session
            try audioSession.setActive(true)
            
            print("Audio session configured successfully")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func deactivateSession() {
        do {
            try audioSession.setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
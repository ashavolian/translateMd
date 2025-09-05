import Foundation
import AVFoundation
import Speech

protocol AudioManagerDelegate {
    func didReceiveTranscription(_ text: String, confidence: Float)
    func didEncounterError(_ error: Error)
}

@MainActor
class AudioManager: NSObject, ObservableObject {
    var delegate: AudioManagerDelegate?
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioSession = AVAudioSession.sharedInstance()
    
    @Published var isRecording = false
    @Published var hasPermissions = false
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    func requestPermissions() async {
        do {
            // Request microphone permission
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            // Request speech recognition permission
            let speechAuthStatus = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            
            await MainActor.run {
                hasPermissions = speechAuthStatus == .authorized
            }
            
        } catch {
            delegate?.didEncounterError(error)
        }
    }
    
    func startRecording() {
        guard hasPermissions else {
            Task { await requestPermissions() }
            return
        }
        
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        
        // Use on-device recognition if available
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
        }
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            
            // Start recognition
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    let confidence = result.bestTranscription.segments.last?.confidence ?? 0.0
                    
                    Task { @MainActor in
                        self?.delegate?.didReceiveTranscription(transcription, confidence: confidence)
                    }
                }
                
                if let error = error {
                    Task { @MainActor in
                        self?.delegate?.didEncounterError(error)
                        self?.stopRecording()
                    }
                }
            }
            
        } catch {
            delegate?.didEncounterError(error)
            stopRecording()
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopRecording()
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension AudioManager: @preconcurrency SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // Handle availability changes
        if !available {
            Task { @MainActor [weak self] in
                self?.stopRecording()
            }
        }
    }
}
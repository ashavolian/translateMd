import Foundation
import AVFoundation
import Speech

// MARK: - Server Response Models
struct TranscriptionServerResponse: Codable {
    let transcription: String
    let language: String
    let confidence: Double
}

protocol AudioManagerDelegate {
    func didReceiveTranscription(_ text: String, confidence: Float)
    func didEncounterError(_ error: Error)
    func didReceiveServerTranscription(_ text: String, confidence: Float, language: String)
    func didDetectLanguage(_ languageCode: String)
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
    @Published var currentLocale: String = "en-US"
    @Published var isServerTranscription = false
    
    // Audio recording for server transcription
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var serverTranscriptionTimer: Timer?
    private var audioSettings: [String: Any] = [:]
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    convenience init(localeIdentifier: String) {
        self.init()
        updateLocale(localeIdentifier)
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLocale))
        speechRecognizer?.delegate = self
    }
    
    func updateLocale(_ localeIdentifier: String) {
        currentLocale = localeIdentifier
        
        // Check if the locale is supported by Apple Speech
        let locale = Locale(identifier: localeIdentifier)
        if SFSpeechRecognizer.supportedLocales().contains(locale) {
            speechRecognizer = SFSpeechRecognizer(locale: locale)
            speechRecognizer?.delegate = self
            isServerTranscription = false
            print("Using Apple Speech Recognition for \(localeIdentifier)")
        } else {
            // Fall back to server transcription for unsupported locales
            speechRecognizer = nil
            isServerTranscription = true
            print("Using server transcription for \(localeIdentifier)")
        }
    }
    
    func requestPermissions() async {
        do {
            // Set up audio session
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
                print("Speech recognition permission: \(speechAuthStatus == .authorized ? "granted" : "denied")")
            }
            
        } catch {
            print("Permission request failed: \(error)")
            delegate?.didEncounterError(error)
        }
    }
    
    func startRecording() {
        guard hasPermissions else {
            print("No permissions for recording")
            return
        }
        
        guard !isRecording else {
            print("Already recording, ignoring start request")
            return
        }
        
        print("Starting recording with locale: \(currentLocale), server: \(isServerTranscription)")
        
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        if isServerTranscription {
            // For server transcription, we'll collect audio and send it to the server
            startServerTranscription()
        } else {
            // Use Apple Speech Recognition
            startAppleSpeechRecognition()
        }
    }
    
    private func startAppleSpeechRecognition() {
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
    
    private func startServerTranscription() {
        print("Starting real server transcription for \(currentLocale)")
        
        // Create a temporary file for recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        
        // Clean up any existing recording files
        cleanupOldRecordings()
        
        // Audio settings for recording - optimized for speed
        audioSettings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0, // Whisper prefers 16kHz
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue // Optimize for speed over size
        ]
        
        do {
            // Ensure the directory exists
            try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)
            
            // Create and start audio recorder
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: audioSettings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            
            // Set up timer to periodically send audio to server
            // Use 1.5 second intervals for responsive transcription
            let interval = 1.5
            
            print("Audio recording started to: \(recordingURL?.lastPathComponent ?? "unknown"), will transcribe every \(interval) seconds")
            serverTranscriptionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                Task {
                    await self.transcribeCurrentRecording()
                }
            }
            
            
        } catch {
            print("Failed to start audio recording: \(error)")
            delegate?.didEncounterError(error)
        }
    }
    
    private func cleanupOldRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.hasPrefix("recording_") && file.pathExtension == "wav" {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("Error cleaning up old recordings: \(error)")
        }
    }
    
    private func transcribeCurrentRecording() async {
        guard let recordingURL = recordingURL,
              FileManager.default.fileExists(atPath: recordingURL.path) else {
            print("No recording file found")
            return
        }
        
        do {
            // Stop current recording temporarily to get the data
            audioRecorder?.pause()
            
            // Read the audio file
            let audioData = try Data(contentsOf: recordingURL)
            
            // Skip if file is too small
            let minSize = 768
            guard audioData.count > minSize else {
                print("Audio file too small (\(audioData.count) bytes), skipping transcription")
                // Resume recording
                audioRecorder?.record()
                return
            }
            
            print("Sending \(audioData.count) bytes to server for transcription")
            
            // Send to server
            let result = await sendAudioToServer(audioData)
            
            if let result = result, !result.transcription.isEmpty {
                DispatchQueue.main.async {
                    self.delegate?.didReceiveServerTranscription(
                        result.transcription,
                        confidence: Float(result.confidence),
                        language: result.language
                    )
                }
            }
            
            // Start a new recording segment immediately for continuous capture
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newRecordingURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
            
            // Start new recording while keeping the old one for processing
            do {
                let newRecorder = try AVAudioRecorder(url: newRecordingURL, settings: audioSettings)
                newRecorder.prepareToRecord()
                newRecorder.record()
                
                // Switch to new recorder
                audioRecorder?.stop()
                audioRecorder = newRecorder
                self.recordingURL = newRecordingURL
                
                print("Started new recording segment: \(newRecordingURL.lastPathComponent)")
            } catch {
                print("Failed to start new recording segment: \(error)")
                // Fallback: clean up and restart current recording
                try? FileManager.default.removeItem(at: recordingURL)
                audioRecorder?.record()
            }
            
        } catch {
            print("Error transcribing audio: \(error)")
            // Make sure recording continues
            audioRecorder?.record()
        }
    }
    
    private func sendAudioToServer(_ audioData: Data) async -> (transcription: String, language: String, confidence: Double)? {
        guard let url = URL(string: "http://localhost:3030/transcribe") else {
            print("Invalid server URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Transcription response status: \(httpResponse.statusCode)")
            }
            
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionServerResponse.self, from: data)
            
            return (
                transcription: transcriptionResponse.transcription,
                language: transcriptionResponse.language,
                confidence: transcriptionResponse.confidence
            )
            
        } catch {
            print("Server transcription error: \(error)")
            return nil
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Stop server transcription if active
        serverTranscriptionTimer?.invalidate()
        serverTranscriptionTimer = nil
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        // Clean up recording file
        if let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
        }
        
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
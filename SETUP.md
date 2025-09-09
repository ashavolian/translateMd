# translateMd Setup Guide

## Overview
This is a clinical interpreter iOS app prototype that provides real-time translation between clinicians and patients using Apple's on-device speech recognition and OpenAI's Realtime API.

## ⚠️ Important Disclaimer
**This is a prototype application using the public OpenAI API. It is NOT HIPAA-compliant and MUST NOT be used with PHI/PII in production settings.**

## Prerequisites
- Xcode 15+ with iOS 17+ SDK
- iPhone device for testing (recommended for speech features)
- Node.js 18+ for the development server
- OpenAI API key with Realtime API access

## Setup Instructions

### 1. Server Setup
1. Navigate to the server directory:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create environment file:
   ```bash
   cp .env.example .env
   ```

4. Edit `.env` and add your OpenAI API key:
   ```
   OPENAI_API_KEY=sk-your-openai-api-key-here
   ```

5. Start the development server:
   ```bash
   npm start
   ```
   
   The server will run on `http://localhost:3030`

### 2. iOS App Setup
1. Open `translateMd/translateMd.xcodeproj` in Xcode

2. Configure your development team:
   - Select the translateMd target
   - Go to "Signing & Capabilities"
   - Select your development team

3. Update the bundle identifier if needed:
   - Change `com.example.translateMd` to your preferred identifier

4. Build and run on a physical device (recommended for speech features)

### 3. Permissions
The app will request the following permissions on first launch:
- Microphone access (for speech recognition)
- Speech recognition (for on-device ASR)

## Features

### Split-Screen UI
- Top panel: Patient-facing (rotated 180°)
- Bottom panel: Clinician-facing
- Tap microphone buttons to start/stop listening

### Language Support
- English (US)
- Spanish (Spain/Mexico)
- French, German, Italian
- Portuguese (Brazil)
- Chinese (Simplified)
- Japanese, Korean
- Arabic, Hindi, Russian

### Confidence Metrics
- Visual indicators for translation confidence
- Green: High confidence (80%+)
- Orange: Medium confidence (60-79%)
- Red: Low confidence (<60%)

### Settings
- Language pair selection
- Confidence threshold adjustment
- Translation history toggle
- Privacy controls

## Architecture

### Audio Flow
1. Microphone input → AVAudioSession
2. Speech recognition → Apple on-device ASR (primary) or OpenAI Realtime (fallback)
3. Translation → OpenAI Realtime API
4. Text-to-speech → AVSpeechSynthesizer (on-device)

### Key Components
- `AudioManager`: Configures audio session for recording/playback
- `SpeechManager`: Handles ASR and TTS using Apple frameworks
- `RealtimeClient`: Manages WebSocket connection to OpenAI Realtime API
- `TranslationManager`: Orchestrates translation workflow and confidence metrics
- `ContentView`: Main split-screen UI
- `SettingsView`: Configuration interface
- `ConfidenceView`: Translation confidence indicators

## Development Notes

### Testing
- Test on physical device for best speech recognition performance
- Ensure good audio quality (quiet environment, clear speech)
- Test with different language pairs

### Troubleshooting
1. **Server connection issues**: Ensure the dev server is running on localhost:3030
2. **Speech recognition not working**: Check microphone permissions and device support
3. **Translation failures**: Verify OpenAI API key and Realtime API access
4. **Audio issues**: Check AVAudioSession configuration and device audio settings

### Known Limitations
- Prototype-level translation confidence metrics
- Simplified error handling
- Development server only (no production deployment)
- Limited offline functionality

## Next Steps for Production

1. **HIPAA Compliance**:
   - Switch to HIPAA-eligible translation provider with BAA
   - Implement end-to-end encryption
   - Add audit logging
   - Secure data handling policies

2. **Enhanced Features**:
   - Improved confidence calibration
   - Better error handling and recovery
   - Offline language packs
   - FHIR integration for medical records

3. **Production Infrastructure**:
   - Secure token management
   - Load balancing
   - Monitoring and analytics
   - MDM policy support

## License
For internal prototyping and evaluation only.
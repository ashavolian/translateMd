## translate - IOS — Clinical Interpreter (Prototype)

> Prototype for clinician–patient translation. Fast, simple UI. Uses Apple on-device TTS and the public OpenAI Realtime API for translation/streaming (for now).

IMPORTANT: This prototype uses the public OpenAI API (including Realtime). It is NOT HIPAA-compliant and MUST NOT be used with PHI/PII in production settings. The long‑term plan is to swap to a HIPAA-eligible provider with a BAA. Until then, treat this as a tech demo only.

### Goals
- **Low-latency, bidirectional translation** between clinician and patient.
- **On-device text-to-speech (TTS)** via `AVSpeechSynthesizer` for speed and privacy.
- **Confidence metrics** to flag low-confidence segments and prompt clarification.
- **Simple split-screen UI**: phone screen split horizontally; patient-facing text is flipped 180°.

### Current scope (prototype)
- **ASR**: Prefer Apple on-device speech recognition when supported; otherwise, stream mic audio to OpenAI Realtime for transcription.
- **Translation**: OpenAI Realtime (streaming) to minimize latency.
- **TTS**: Apple `AVSpeechSynthesizer` on-device voices.
- **Storage**: Local-only during prototype; optional “Save history” toggle. No cloud sync.
- **Compliance**: Prototype only. Do not handle PHI/PII outside controlled demos.

---

## Quickstart

### Requirements
- Xcode 15+ and iOS 17+
- An iPhone with on-device speech packs for your test languages (optional but recommended)
- OpenAI API key with Realtime access

### Configure secrets
- Create an environment entry (for development only):
  - Xcode scheme env var: `OPENAI_API_KEY=sk-...` (for the dev token-minting server below)
  - The iOS app will request a short-lived ephemeral token from your local server instead of embedding the key.

### Run a tiny dev server for Realtime ephemeral tokens
The OpenAI Realtime API should be called from the app using ephemeral tokens minted by your server. This prevents embedding your API key in the app.

Example (Node/Express, development only):

```ts
import express from 'express';
import fetch from 'node-fetch';

const app = express();
const port = 3030;

// Issues a short-lived Realtime session token
app.post('/session', async (_req, res) => {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'Missing OPENAI_API_KEY' });

  const r = await fetch('https://api.openai.com/v1/realtime/sessions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'gpt-4o-realtime-preview',
      voice: 'verse' // optional
    })
  });

  const json = await r.json();
  if (!r.ok) return res.status(r.status).json(json);
  return res.json(json); // includes client_secret.value
});

app.listen(port, () => console.log(`Dev token server running on http://localhost:${port}`));
```

Use `client_secret.value` from `/session` as the bearer for your app’s Realtime connection (WebRTC or WebSocket).

### iOS project setup
1. Add usage descriptions to `Info.plist`:
   - `NSMicrophoneUsageDescription`
   - `NSSpeechRecognitionUsageDescription`
2. Configure `AVAudioSession` for `playAndRecord`, `defaultToSpeaker`.
3. Ensure background audio is OFF for now (prototype).
4. Build and run on device.

---

## Architecture (prototype)

- Microphone → VAD/turn-taking → ASR → Translation → On-device TTS → Split-screen render.
- Two lanes: Clinician→Patient and Patient→Clinician. When one side speaks, the opposite panel shows the translation and the local panel clears to show the current utterance.

### Components
- **ASR**
  - Primary: Apple on-device recognition if available for the language pair.
  - Fallback: OpenAI Realtime stream (send audio frames; receive partial transcripts).
- **Translation**
  - OpenAI Realtime; prompt configured to “translate from <source> to <target> succinctly for clinical settings.”
- **TTS**
  - `AVSpeechSynthesizer` with `AVSpeechSynthesisVoice(language:)` per target language.
- **Confidence metrics**
  - Combine ASR segment confidence (when available) + MT heuristic (e.g., back-translation consistency) into a single score.
  - Visual badge (green/amber/red); tap to see rationale and quick actions (Repeat/Confirm).

---

## Split-screen UI behavior

- Screen is split horizontally.
- Top panel: patient-facing, rotated 180° to be readable across the device.
- Bottom panel: clinician-facing.
- When the clinician speaks, the patient-facing panel shows the translated text; when the patient speaks, the clinician-facing panel shows the translated text.
- When one side starts speaking, the other panel clears to avoid confusion; history is still retained (unless "Save history" is off).

Minimal rendering snippet (for reference):

```swift
Text(patientFacingText)
  .rotationEffect(.degrees(180))
  .lineLimit(nil)
```

---

## Realtime integration (high level)

- The app obtains an ephemeral token from `/session` and establishes a Realtime connection to OpenAI via WebRTC (recommended) or WebSocket.
- For WebSocket mode, send binary audio frames (PCM/opus) as `input_audio_buffer` events and request `response.create` with system/prompt that instructs translation. Receive partials and final segments in near real time.
- The app performs TTS locally with `AVSpeechSynthesizer` as soon as a stable segment arrives.

References:
- [OpenAI Realtime API](`https://platform.openai.com/docs/guides/realtime`)

---

## Configuration

- **Language Pair**: Select source/target per side; auto-detect is supported but less predictable.
- **Confidence Threshold**: Default 0.7; below triggers a visual alert.
- **Save History**: On by default in prototype; turn off to avoid persisting content.
- **Redaction**: Optional automatic PHI heuristics + manual review UI (in progress).

---

## Privacy and Compliance (prototype disclaimer)

- Uses the public OpenAI API today. No BAA. Not HIPAA-compliant.
- Do not record or export conversations containing PHI/PII.
- Future: swap to HIPAA-eligible provider (BAA), encrypted at rest with device key, admin policies (MDM), FHIR export with PHI controls.

---

## Roadmap

- HIPAA-eligible translation provider (primary) with BAA; public OpenAI retained for non-PHI demos only.
- FHIR `Communication` + `DocumentReference` export; "Share without PHI" option.
- Confidence calibration per language pair; clinician feedback loop.
- On-device NER-based PHI redaction and manual review before export.
- Offline packs for selected language pairs.

---

## Development notes

- Keep your API key on the server only; the iOS app should request ephemeral Realtime tokens.
- Prefer on-device ASR when available for latency and privacy; fall back to Realtime for coverage.
- TTS is on-device by default; no network required for playback.

---

## License

TBD. For internal prototyping and evaluation only.



import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || 3030;

// Middleware
app.use(cors());
app.use('/transcribe', express.raw({ type: 'audio/*', limit: '10mb' }));
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Issues a short-lived Realtime session token
app.post('/session', async (req, res) => {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: 'Missing OPENAI_API_KEY environment variable' });
  }

  try {
    const response = await fetch('https://api.openai.com/v1/realtime/sessions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-realtime-preview',
        voice: 'verse'
      })
    });

    const data = await response.json();
    
    if (!response.ok) {
      console.error('OpenAI API error:', data);
      return res.status(response.status).json(data);
    }

    console.log('Generated ephemeral token for client');
    return res.json(data);
    
  } catch (error) {
    console.error('Server error:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Language detection endpoint
app.post('/detect-language', async (req, res) => {
  const { text } = req.body;
  const apiKey = process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    return res.status(500).json({ error: 'Missing OPENAI_API_KEY' });
  }

  if (!text) {
    return res.status(400).json({ error: 'Missing required field: text' });
  }

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'Identify the language (ISO 639-1/BCP-47) of the given text. Only return the language code, nothing else.'
          },
          {
            role: 'user',
            content: `Identify the language of: "${text}"`
          }
        ],
        max_tokens: 10,
        temperature: 0.1
      })
    });

    const data = await response.json();
    
    if (!response.ok) {
      return res.status(response.status).json(data);
    }

    const detectedLanguage = data.choices?.[0]?.message?.content?.trim();
    return res.json({ language: detectedLanguage });
    
  } catch (error) {
    console.error('Language detection error:', error);
    return res.status(500).json({ error: 'Language detection failed' });
  }
});

// Audio transcription endpoint using Whisper
app.post('/transcribe', async (req, res) => {
  const apiKey = process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    return res.status(500).json({ error: 'Missing OPENAI_API_KEY' });
  }

  try {
    // Get audio data from request body
    const audioBuffer = req.body;
    
    if (!audioBuffer || audioBuffer.length === 0) {
      return res.status(400).json({ error: 'No audio data provided' });
    }

    console.log(`Received audio data: ${audioBuffer.length} bytes`);

    // Create form data for Whisper API
    const formData = new FormData();
    
    // Convert buffer to blob for form data
    const audioBlob = new Blob([audioBuffer], { type: 'audio/wav' });
    formData.append('file', audioBlob, 'audio.wav');
    formData.append('model', 'whisper-1');
    formData.append('response_format', 'verbose_json');
    formData.append('temperature', '0'); // Use deterministic mode for faster processing
    
    // Call OpenAI Whisper API
    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
      },
      body: formData
    });

    const data = await response.json();
    
    if (!response.ok) {
      console.error('Whisper API error:', data);
      return res.status(response.status).json(data);
    }

    console.log('Whisper response:', data);

    // Extract transcription and language from Whisper response
    const transcription = data.text || '';
    const language = data.language || 'unknown';
    
    // Skip empty or very short transcriptions to reduce noise
    if (!transcription.trim() || transcription.trim().length < 2) {
      return res.json({ 
        transcription: '',
        language: language === null ? 'unknown' : language,
        confidence: 0.0
      });
    }
    
    // Calculate confidence from segments if available
    let confidence = 0.8; // Default confidence
    if (data.segments && data.segments.length > 0) {
      const avgConfidence = data.segments.reduce((sum, segment) => {
        return sum + (segment.avg_logprob || 0);
      }, 0) / data.segments.length;
      
      // Convert log probability to confidence (rough approximation)
      confidence = Math.max(0.1, Math.min(1.0, Math.exp(avgConfidence)));
    }

    return res.json({ 
      transcription: transcription.trim(),
      language: language === null ? 'unknown' : language,
      confidence: parseFloat(confidence.toFixed(2))
    });
    
  } catch (error) {
    console.error('Transcription error:', error);
    return res.status(500).json({ error: 'Transcription failed: ' + error.message });
  }
});

// Enhanced translation endpoint with auto-detection support
app.post('/translate', async (req, res) => {
  const { text, from, to } = req.body;
  const apiKey = process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    return res.status(500).json({ error: 'Missing OPENAI_API_KEY' });
  }

  if (!text || !to) {
    return res.status(400).json({ error: 'Missing required fields: text, to' });
  }

  try {
    let sourceLanguage = from;
    
    // If source language is "auto", detect it first
    if (from === 'auto' || !from) {
      const detectResponse = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'Identify the language (ISO 639-1/BCP-47) of the given text. Only return the language code, nothing else.'
            },
            {
              role: 'user',
              content: `Identify the language of: "${text}"`
            }
          ],
          max_tokens: 10,
          temperature: 0.1
        })
      });

      const detectData = await detectResponse.json();
      
      if (!detectResponse.ok) {
        return res.status(detectResponse.status).json(detectData);
      }

      sourceLanguage = detectData.choices?.[0]?.message?.content?.trim() || 'en';
    }

    // Now translate from detected/specified source to target
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'You are a professional translator. Provide accurate translations between languages. Respond only with the translation, no explanations or additional commentary.'
          },
          {
            role: 'user',
            content: `Translate from ${sourceLanguage} to ${to}: ${text}`
          }
        ],
        max_tokens: 150,
        temperature: 0.3
      })
    });

    const data = await response.json();
    
    if (!response.ok) {
      return res.status(response.status).json(data);
    }

    const translation = data.choices?.[0]?.message?.content?.trim();
    return res.json({ 
      translation,
      detectedLanguage: sourceLanguage
    });
    
  } catch (error) {
    console.error('Translation error:', error);
    return res.status(500).json({ error: 'Translation failed' });
  }
});

app.listen(port, () => {
  console.log(`🚀 Token server running on http://localhost:${port}`);
  console.log(`📋 Endpoints:`);
  console.log(`   POST /session - Get Realtime ephemeral token`);
  console.log(`   POST /translate - Enhanced translation with auto-detection`);
  console.log(`   POST /detect-language - Language detection`);
  console.log(`   POST /transcribe - Audio transcription (Whisper)`);
  console.log(`   GET /health - Health check`);
  console.log(`⚠️  Make sure OPENAI_API_KEY is set in your environment`);
});

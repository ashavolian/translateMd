import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || 3030;

// Middleware
app.use(cors());
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

// Basic translation endpoint (fallback for when Realtime isn't available)
app.post('/translate', async (req, res) => {
  const { text, from, to } = req.body;
  const apiKey = process.env.OPENAI_API_KEY;
  
  if (!apiKey) {
    return res.status(500).json({ error: 'Missing OPENAI_API_KEY' });
  }

  if (!text || !from || !to) {
    return res.status(400).json({ error: 'Missing required fields: text, from, to' });
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
            content: 'You are a medical interpreter. Provide accurate, professional translations for clinical conversations. Respond only with the translation, no explanations.'
          },
          {
            role: 'user',
            content: `Translate from ${from} to ${to}: ${text}`
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
    return res.json({ translation });
    
  } catch (error) {
    console.error('Translation error:', error);
    return res.status(500).json({ error: 'Translation failed' });
  }
});

app.listen(port, () => {
  console.log(`🚀 Token server running on http://localhost:${port}`);
  console.log(`📋 Endpoints:`);
  console.log(`   POST /session - Get Realtime ephemeral token`);
  console.log(`   POST /translate - Basic translation (fallback)`);
  console.log(`   GET /health - Health check`);
  console.log(`⚠️  Make sure OPENAI_API_KEY is set in your environment`);
});

import express from 'express';
import fetch from 'node-fetch';
import cors from 'cors';

const app = express();
const port = 3030;

// Enable CORS for iOS app
app.use(cors());
app.use(express.json());

// Issues a short-lived Realtime session token
app.post('/session', async (_req, res) => {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    console.error('Missing OPENAI_API_KEY environment variable');
    return res.status(500).json({ error: 'Missing OPENAI_API_KEY' });
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
        voice: 'verse' // optional
      })
    });

    const json = await response.json();
    if (!response.ok) {
      console.error('OpenAI API error:', json);
      return res.status(response.status).json(json);
    }
    
    console.log('Session token created successfully');
    return res.json(json); // includes client_secret.value
  } catch (error) {
    console.error('Error creating session token:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Health check endpoint
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
  console.log(`Dev token server running on http://localhost:${port}`);
  console.log('Make sure to set OPENAI_API_KEY environment variable');
});
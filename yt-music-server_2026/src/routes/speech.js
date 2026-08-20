const { Router } = require('express');
const https = require('https');

const router = Router();

// Speech-to-Text via Groq Whisper AI
router.post('/api/speech-to-text', async (req, res) => {
  try {
    const { audio, locale = 'th-TH' } = req.body;

    if (!audio) {
      return res.status(400).json({ error: 'Missing audio data' });
    }

    const groqKey = process.env.GROQ_API_KEY || '';
    if (!groqKey) {
      return res.status(503).json({ error: 'GROQ_API_KEY not configured' });
    }
    const audioBuffer = Buffer.from(audio, 'base64');
    const lang = locale.toLowerCase().startsWith('th') ? 'th' : 'en';

    // Build Multipart Form-Data (no extra npm library needed)
    const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
    const parts = [];

    const fields = {
      model: 'whisper-large-v3-turbo',
      language: lang,
      temperature: '0.0',
      response_format: 'json',
    };

    for (const [key, value] of Object.entries(fields)) {
      parts.push(
        Buffer.from(
          `--${boundary}\r\nContent-Disposition: form-data; name="${key}"\r\n\r\n${value}\r\n`
        )
      );
    }

    parts.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="speech.m4a"\r\nContent-Type: audio/m4a\r\n\r\n`
      )
    );
    parts.push(audioBuffer);
    parts.push(Buffer.from(`\r\n--${boundary}--\r\n`));

    const postBody = Buffer.concat(parts);

    const options = {
      hostname: 'api.groq.com',
      path: '/openai/v1/audio/transcriptions',
      method: 'POST',
      headers: {
        Authorization: `Bearer ${groqKey}`,
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Content-Length': postBody.length,
      },
    };

    const reqGroq = https.request(options, (resGroq) => {
      let body = '';
      resGroq.on('data', (chunk) => (body += chunk));
      resGroq.on('end', () => {
        try {
          const json = JSON.parse(body);
          if (json.text) {
            console.log(`🤖 Groq Whisper recognized: "${json.text}"`);
            return res.json({ text: json.text, success: true });
          } else {
            console.warn('⚠️ Groq Whisper output empty:', body);
            return res.json({ text: null, success: true });
          }
        } catch (e) {
          console.error('Groq response parse error:', e.message, body);
          return res.status(500).json({ error: 'Failed to parse Groq response' });
        }
      });
    });

    reqGroq.on('error', (e) => {
      console.error('Groq API request error:', e.message);
      return res.status(500).json({ error: 'Groq Whisper API request failed' });
    });

    reqGroq.write(postBody);
    reqGroq.end();
  } catch (error) {
    console.error('Speech-to-text error:', error.message);
    res.status(500).json({ error: 'Speech recognition failed' });
  }
});

module.exports = router;

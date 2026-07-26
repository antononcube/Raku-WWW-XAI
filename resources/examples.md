
## Code

```
curl https://api.x.ai/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -d '{
    "model": "grok-4.5",
    "input": "Fix this function and explain the bug: function median(a){a.sort();return a[a.length/2]}"
}'
```

## Chat

```
curl https://api.x.ai/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -d '{
    "model": "grok-4.5",
    "input": [
        {
            "role": "system",
            "content": "You are Grok, a highly intelligent, helpful AI assistant."
        },
        {
            "role": "user",
            "content": "What is the meaning of life, the universe, and everything?"
        }
    ]
}'
```

## Image

```
curl -s https://api.x.ai/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -d '{
    "model": "grok-imagine-image-quality",
    "prompt": "A collage of London landmarks in a stenciled street-art style"
  }'
```

## Models

```
curl https://api.x.ai/v1/models  -H "Authorization: Bearer $XAI_API_KEY" 
```

## Video

```
# 1. Start generation
REQUEST_ID=$(curl -sS -X POST https://api.x.ai/v1/videos/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -d '{
    "model": "grok-imagine-video",
    "prompt": "A glowing crystal-powered rocket launching from Mars"
  }' | jq -r '.request_id')

# 2. Poll until done
while true; do
  RESULT=$(curl -sS "https://api.x.ai/v1/videos/$REQUEST_ID" \
    -H "Authorization: Bearer $XAI_API_KEY")
  STATUS=$(echo "$RESULT" | jq -r '.status')
  if [ "$STATUS" = "done" ]; then
    echo "$RESULT" | jq -r '.video.url'
    break
  fi
  if [ "$STATUS" = "failed" ] || [ "$STATUS" = "expired" ]; then
    echo "$RESULT" >&2
    exit 1
  fi
  sleep 5
done
```

## Voice

```
HTTP_CODE=$(curl -sS -X POST https://api.x.ai/v1/tts \
  -H "Authorization: Bearer $XAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello! Welcome to the xAI Text to Speech API.",
    "voice_id": "eve",
    "language": "en"
  }' \
  --output hello.mp3 \
  --write-out '%{http_code}')

if [ "$HTTP_CODE" != "200" ]; then
  echo "TTS error $HTTP_CODE: $(cat hello.mp3)" >&2
  rm -f hello.mp3
else
  echo "Saved to hello.mp3"
fi
```


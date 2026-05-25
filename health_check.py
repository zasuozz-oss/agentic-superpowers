#!/usr/bin/env python3
import time
from datetime import datetime
import anthropic

try:
    start_time = time.time()
    client = anthropic.Anthropic()

    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=10,
        messages=[
            {"role": "user", "content": "ping"}
        ]
    )

    response_time = time.time() - start_time
    timestamp = datetime.now().isoformat()

    print(f"[{timestamp}] Health check: OK (response time: {response_time:.2f}s)")

except Exception as e:
    timestamp = datetime.now().isoformat()
    print(f"[{timestamp}] Health check: FAILED ({str(e)})")

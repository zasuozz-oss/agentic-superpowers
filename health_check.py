#!/usr/bin/env python3
import time
from datetime import datetime
from anthropic import Anthropic

def health_check():
    timestamp = datetime.utcnow().isoformat() + "Z"
    start_time = time.time()

    try:
        client = Anthropic()
        message = client.messages.create(
            model="claude-opus-4-7",
            max_tokens=10,
            messages=[{"role": "user", "content": "ping"}]
        )
        response_time = time.time() - start_time
        print(f"[{timestamp}] Health check: OK (response time: {response_time:.2f}s)")
        return True
    except Exception as e:
        response_time = time.time() - start_time
        print(f"[{timestamp}] Health check: FAILED (error: {str(e)}, response time: {response_time:.2f}s)")
        return False

if __name__ == "__main__":
    health_check()

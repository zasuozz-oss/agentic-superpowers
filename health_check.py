#!/usr/bin/env python3
"""Health check for Anthropic API connectivity."""

import time
from datetime import datetime
from anthropic import Anthropic

def health_check():
    """Call Anthropic API with minimal message and log results."""
    timestamp = datetime.now().isoformat()
    start_time = time.time()

    try:
        client = Anthropic()
        response = client.messages.create(
            model="claude-opus-4-8",
            max_tokens=10,
            messages=[
                {"role": "user", "content": "ping"}
            ]
        )

        elapsed_time = time.time() - start_time
        status = "OK"
        output = f"[{timestamp}] Health check: {status} ({elapsed_time:.3f}s)"

    except Exception as e:
        elapsed_time = time.time() - start_time
        status = "FAILED"
        output = f"[{timestamp}] Health check: {status} ({elapsed_time:.3f}s) - {str(e)}"

    print(output)
    return output

if __name__ == "__main__":
    health_check()

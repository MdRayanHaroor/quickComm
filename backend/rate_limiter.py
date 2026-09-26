import time
from collections import defaultdict
from fastapi import Request, HTTPException, status

# Sliding window rate limiter for binary file uploads
# Max 15 file uploads per 60 seconds per client IP
UPLOAD_RATE_LIMIT = 15
WINDOW_SECONDS = 60.0

_upload_records = defaultdict(list)


def upload_rate_limiter(request: Request):
    """
    Dependency that enforces a sliding-window rate limit on binary file uploads.
    Does not affect ordinary JSON requests or external URL additions.
    """
    client_ip = request.client.host if request.client else "unknown_client"
    now = time.time()
    window_start = now - WINDOW_SECONDS

    # Filter out timestamps older than the window
    timestamps = [t for t in _upload_records[client_ip] if t > window_start]

    if len(timestamps) >= UPLOAD_RATE_LIMIT:
        retry_after = int(timestamps[0] + WINDOW_SECONDS - now) + 1
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Upload rate limit exceeded. Maximum 15 image uploads per minute allowed. Please try again shortly.",
            headers={"Retry-After": str(max(1, retry_after))},
        )

    timestamps.append(now)
    _upload_records[client_ip] = timestamps

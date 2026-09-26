# 04 — Consistent Error Handling Format (Task 8.5)

## Objective
Standardize all API error responses into a single predictable JSON contract across FastAPI exceptions, Pydantic validation errors, and uncaught 500 runtime exceptions, while maintaining 100% backward compatibility with existing frontends.

---

## 1. Problem Statement
Previously, error shapes were inconsistent:
- FastAPI `HTTPException` returned `{"detail": "..."}`.
- Pydantic schema validation failures returned raw validation lists.
- Unhandled Python errors dumped internal 500 HTML or tracebacks.
Clients (Flutter & React) had to handle multiple disparate formats, risking silent UI failures or ugly unparsed error alerts.

---

## 2. Standardized Error Response Contract

```json
{
  "success": false,
  "detail": "Friendly error message string for legacy compatibility",
  "error": {
    "code": "ERROR_CODE_STRING",
    "message": "Friendly human-readable error description",
    "details": []
  }
}
```

### Key Highlights:
1. `success: false` flag for rapid boolean status checking.
2. `detail` maintained alongside `error.message` so existing Axios interceptors and Flutter code reading `res.data.detail` do not break.
3. Machine-readable `code` for programmatic logic (e.g. `UNAUTHORIZED`, `FORBIDDEN`, `VALIDATION_ERROR`, `NOT_FOUND`, `RATE_LIMIT_EXCEEDED`).
4. `details` array containing specific field-level validation errors when applicable.

---

## 3. Technical Implementation
In `backend/main.py`:
- `HTTPException` handler: maps status codes to standard error codes and extracts messages cleanly.
- `RequestValidationError` handler: maps Pydantic validation failures into structured field messages.
- Catch-all `Exception` handler: logs server-side stack trace securely while returning a clean non-leaking JSON error to the client.

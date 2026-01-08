# HRAS API Documentation

Base URL: `http://localhost:8000`

## Endpoints

### Health

#### GET /
Root endpoint.

**Response:**
```json
{
  "message": "Welcome to HRAS - Human Rights Advisory System"
}
```

#### GET /health
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "version": "0.1.0",
  "service": "HRAS - Human Rights Advisory System"
}
```

**Example:**
```bash
curl http://localhost:8000/health
```

---

### Chat

#### POST /api/v1/chat
Send a message and receive an AI-generated response with relevant sources.

**Request Body:**
```json
{
  "message": "What are the key human rights concerns in Kenya?",
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000"  // optional
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `message` | string | Yes | User message (1-4000 chars) |
| `conversation_id` | UUID | No | Existing conversation ID to continue |

**Response:**
```json
{
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": {
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "role": "assistant",
    "content": "Based on UHRI recommendations, key human rights concerns in Kenya include...",
    "created_at": "2024-01-15T10:30:00.000Z"
  },
  "sources": [
    {
      "country": "Kenya",
      "mechanism": "UPR",
      "year": "2023",
      "theme": "Civil and Political Rights",
      "status": "Pending",
      "snippet": "The Committee recommends that Kenya..."
    }
  ]
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What are the key human rights concerns in Kenya?"}'
```

---

### Admin

#### POST /api/v1/admin/ingest
Ingest UHRI data into the vector store.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clear_existing` | boolean | false | Clear existing data before ingesting |
| `use_sample` | boolean | true | Use sample data (faster for testing) |

**Response:**
```json
{
  "documents_added": 150,
  "total_documents": 150,
  "collection": "uhri_recommendations",
  "message": "Data ingestion completed successfully"
}
```

**Examples:**
```bash
# Ingest sample data
curl -X POST http://localhost:8000/api/v1/admin/ingest

# Clear and re-ingest
curl -X POST "http://localhost:8000/api/v1/admin/ingest?clear_existing=true"

# Ingest full dataset
curl -X POST "http://localhost:8000/api/v1/admin/ingest?use_sample=false"
```

#### GET /api/v1/admin/stats
Get vector store statistics.

**Response:**
```json
{
  "name": "uhri_recommendations",
  "count": 150
}
```

**Example:**
```bash
curl http://localhost:8000/api/v1/admin/stats
```

---

## Error Responses

All endpoints return errors in this format:

```json
{
  "detail": "Error message describing what went wrong"
}
```

**HTTP Status Codes:**
| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Bad Request (invalid input) |
| 500 | Internal Server Error |

---

## Rate Limits

No rate limits are currently implemented. The API is intended for internal use.

---

## Authentication

No authentication is currently required. The API is intended for local development and internal deployment.

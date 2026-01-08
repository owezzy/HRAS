# HRAS - API Reference Documentation

This document provides comprehensive API reference for the HRAS (Human Rights Advisory System) backend services.

## Base URL

```
http://localhost:8000
```

## API Versioning

All endpoints are versioned under `/api/v1/` to support future iterations.

## Authentication

The API is currently designed for internal use and does not require authentication. However, the following considerations apply:

- All endpoints are rate-limited to prevent abuse
- Input validation ensures data integrity
- Output sanitization prevents injection attacks

## API Endpoints

### 1. Health Endpoints

#### GET `/` - Root Endpoint
Returns a welcome message.

```json
{
  "message": "Welcome to HRAS - Human Rights Advisory System"
}
```

#### GET `/health` - Health Check
Health check endpoint.

```json
{
  "status": "healthy",
  "version": "0.2.0",
  "service": "HRAS - Human Rights Advisory System"
}
```

### 2. Chat Interface

#### POST `/api/v1/chat` - Send Message
Send a message and receive an AI-generated response with relevant sources.

**Request Body:**
```json
{
  "message": "What are the key human rights concerns in Kenya?",
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000"  // optional
}
```

**Parameters:**
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

#### POST `/api/v1/chat/suggestions` - Get Suggestions
Get suggested questions based on user query.

### 3. Admin Endpoints

#### POST `/api/v1/admin/ingest` - Ingest Data
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

#### GET `/api/v1/admin/stats` - Get Statistics
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

### 4. Error Responses

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

## API Examples

### 1. Basic Chat Request

```bash
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What are the key human rights concerns in Kenya?"}'
```

### 2. Continue Conversation

```bash
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Tell me more about the recommendations",
    "conversation_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

### 3. Ingest Sample Data

```bash
curl -X POST http://localhost:8000/api/v1/admin/ingest
```

## API Testing

### 1. Using HTTPie

```bash
# Install HTTPie: pip install httpie
http POST http://localhost:8000/api/v1/chat message="What are human rights?"
```

### 2. Using Python Requests

```python
import requests

url = "http://localhost:8000/api/v1/chat"
headers = {"Content-Type": "application/json"}
data = {"message": "What are human rights?", "conversation_id": "test-id"}

response = requests.post(url, json=data, headers=headers)
print(response.json())
```

## API Roadmap

### Planned Enhancements:
1. **Authentication System:** JWT-based authentication for production use
2. **Rate Limiting:** Configurable rate limiting per endpoint
3. **WebSockets:** Real-time streaming of response generation
4. **Webhook Support:** Callback notifications for async operations
5. **API Versioning Strategy:** Support for multiple API versions
6. **OpenAPI Specification:** Formal OpenAPI 3.0 specification
7. **API Documentation Portal:** Interactive Swagger UI documentation
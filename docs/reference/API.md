# 🔌 HRAS API Reference

*Complete REST API documentation for the Human Rights Advisory System*

---

## 🚀 Quick Start

**Local Development:**
```bash
# Health check - verify HRAS is running
curl http://localhost:8000/health

# Ask a question
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What human rights issues exist in Kenya?"}'

# Check data ingestion status
curl http://localhost:8000/api/v1/admin/stats
```

**Production:**
```bash
# Health check
curl https://hetzner-api.hras.owezzy.tech/health

# Ask a question
curl -X POST https://hetzner-api.hras.owezzy.tech/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What human rights issues exist in Kenya?"}'

# Check data ingestion status
curl https://hetzner-api.hras.owezzy.tech/api/v1/admin/stats
```

---

## 🏗️ API Overview

| Component | Details |
|-----------|---------|
| **Base URL (Development)** | `http://localhost:8000` |
| **Base URL (Production)** | `https://hetzner-api.hras.owezzy.tech` |
| **Version** | v1 (all endpoints under `/api/v1/`) |
| **Format** | JSON request/response |
| **Authentication** | None required (internal use) |
| **Rate Limits** | Configured per endpoint |
| **TLS/HTTPS** | Let's Encrypt via Caddy (production) |

---

## 📋 Endpoint Reference

### 🏥 Health & Status

#### `GET /health` - System Health Check
*Quick verification that HRAS is running and responsive*

**Response:**
```json
{
  "status": "healthy",
  "version": "0.2.0",
  "service": "HRAS - Human Rights Advisory System"
}
```

**Use Cases:**
- Monitoring scripts and health checks
- Load balancer health probes
- Deployment verification

---

#### `GET /` - Welcome Message
*Basic endpoint that returns service information*

**Response:**
```json
{
  "message": "Welcome to HRAS - Human Rights Advisory System"
}
```

---

### 💬 Chat Interface

#### `POST /api/v1/chat` - Send Message
*Main endpoint for asking questions and getting AI-powered responses*

**Request:**
```json
{
  "message": "What are the key human rights concerns in Kenya?",
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000"  // optional
}
```

**Request Schema:**
| Field | Type | Required | Constraints | Description |
|-------|------|----------|-------------|-------------|
| `message` | string | ✅ | 1-4000 chars | Your question about human rights |
| `conversation_id` | UUID string | ❌ | Valid UUIDv4 | Continue existing conversation |

**Response:**
```json
{
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": {
    "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "role": "assistant",
    "content": "Based on UHRI recommendations, key human rights concerns in Kenya include police brutality, gender-based violence, and restrictions on freedom of assembly. The Universal Periodic Review in 2023 highlighted several areas requiring immediate attention...",
    "created_at": "2024-01-15T10:30:00.000Z"
  },
  "sources": [
    {
      "country": "Kenya",
      "mechanism": "UPR",
      "year": "2023",
      "theme": "Civil and Political Rights",
      "status": "Pending",
      "snippet": "The Committee recommends that Kenya strengthen its legal framework to prevent torture and ensure accountability for law enforcement violations."
    },
    {
      "country": "Kenya",
      "mechanism": "CEDAW",
      "year": "2022",
      "theme": "Women's Rights",
      "status": "Under Review",
      "snippet": "Concern about the high prevalence of gender-based violence and inadequate access to justice for women."
    }
  ]
}
```

**Response Schema:**
| Field | Type | Description |
|-------|------|-------------|
| `conversation_id` | UUID string | Conversation identifier for follow-ups |
| `message.id` | UUID string | Unique message identifier |
| `message.role` | string | Always "assistant" |
| `message.content` | string | AI-generated response with analysis |
| `message.created_at` | ISO 8601 string | Response timestamp |
| `sources[]` | array | Supporting UN documents |
| `sources[].country` | string | Country referenced |
| `sources[].mechanism` | string | UN mechanism (UPR, CEDAW, etc.) |
| `sources[].year` | string | Document year |
| `sources[].theme` | string | Human rights theme |
| `sources[].status` | string | Recommendation status |
| `sources[].snippet` | string | Relevant excerpt from document |

**Example Usage:**

```javascript
// JavaScript/Node.js
const response = await fetch('http://localhost:8000/api/v1/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: "What recommendations were made for prison conditions in Brazil?",
    conversation_id: "existing-conversation-id" // optional
  })
});

const data = await response.json();
console.log(data.message.content);  // AI response
console.log(data.sources.length);   // Number of supporting documents
```

```python
# Python
import requests

response = requests.post('http://localhost:8000/api/v1/chat',
  json={
    "message": "How does the UN address child labor violations?",
    "conversation_id": None  # Start new conversation
  }
)

data = response.json()
print(f"Response: {data['message']['content']}")
print(f"Sources: {len(data['sources'])} documents")
```

---

### ⚙️ Administration

#### `POST /api/v1/admin/ingest` - Ingest Data
*Load UHRI documents into the vector store for AI analysis*

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `clear_existing` | boolean | `false` | Remove existing data before ingesting |
| `use_sample` | boolean | `true` | Use sample data (faster) vs full dataset |

**Examples:**

```bash
# Ingest sample data (quick, good for development)
curl -X POST http://localhost:8000/api/v1/admin/ingest

# Clear existing data and re-ingest
curl -X POST "http://localhost:8000/api/v1/admin/ingest?clear_existing=true"

# Ingest full dataset (slower, production use)
curl -X POST "http://localhost:8000/api/v1/admin/ingest?use_sample=false"
```

**Response:**
```json
{
  "documents_added": 150,
  "total_documents": 150,
  "collection": "uhri_recommendations",
  "message": "Data ingestion completed successfully"
}
```

**Use Cases:**
- Initial system setup
- Data refresh after UHRI updates
- Development environment reset
- Kubernetes automatic deployment (via Job)

---

#### `GET /api/v1/admin/stats` - Get Statistics
*Check vector store status and document counts*

**Response:**
```json
{
  "name": "uhri_recommendations",
  "count": 150
}
```

**Example:**
```bash
# Check ingestion status
curl http://localhost:8000/api/v1/admin/stats | jq '.'
```

**Use Cases:**
- Verify successful data ingestion
- Monitor system capacity
- Debugging document retrieval issues

---

## 🚨 Error Handling

### Error Response Format
All errors return this consistent structure:

```json
{
  "detail": "Human-readable error message explaining what went wrong"
}
```

### HTTP Status Codes

| Code | Meaning | When It Happens | How to Fix |
|------|---------|-----------------|------------|
| **200** | Success | Request processed successfully | Continue normally |
| **400** | Bad Request | Invalid input (missing message, malformed JSON) | Check request format |
| **422** | Validation Error | Data doesn't meet requirements (message too long) | Validate input parameters |
| **500** | Internal Error | Server-side issue (AI service down, database error) | Check logs, retry, contact support |

### Example Error Responses

```json
// 400 Bad Request - Missing message
{
  "detail": "Field required: message"
}

// 422 Validation Error - Message too long
{
  "detail": "Message must be between 1 and 4000 characters"
}

// 500 Internal Error - AI service unavailable
{
  "detail": "Ollama service unavailable. Please try again later."
}
```

---

## 🧪 Testing & Development

### Testing with HTTPie
```bash
# Install HTTPie
pip install httpie

# Test chat endpoint
http POST localhost:8000/api/v1/chat message="What are human rights?"

# Test with conversation ID
http POST localhost:8000/api/v1/chat \
  message="Tell me more about that" \
  conversation_id="550e8400-e29b-41d4-a716-446655440000"
```

### Testing with Postman
1. Create new POST request to `http://localhost:8000/api/v1/chat`
2. Set Content-Type header to `application/json`
3. Add JSON body: `{"message": "Your question here"}`
4. Send and examine response structure

### Load Testing
```bash
# Simple load test with curl
for i in {1..10}; do
  curl -X POST localhost:8000/api/v1/chat \
    -H "Content-Type: application/json" \
    -d '{"message": "Test question '$i'"}'  &
done
wait
```

---

## 🔮 API Roadmap

### 🚀 **Coming Soon**
- **WebSocket Support**: Real-time streaming responses
- **Batch Processing**: Multiple questions in one request
- **Advanced Filtering**: Filter by country, mechanism, date range
- **Export Formats**: PDF, CSV, JSON export of responses

### 🔐 **Security Enhancements**
- **API Authentication**: JWT-based access control
- **Rate Limiting**: Configurable per-user limits
- **Input Sanitization**: Enhanced protection against injection attacks
- **Audit Logging**: Detailed request/response logging

### 📊 **Analytics & Monitoring**
- **Usage Metrics**: Track popular queries and response times
- **Quality Metrics**: Response accuracy and user feedback
- **Performance Monitoring**: Detailed latency and throughput metrics

### 🌐 **Integration Features**
- **Webhooks**: Callback notifications for long-running operations
- **GraphQL API**: Alternative query interface for complex data needs
- **OpenAPI Spec**: Machine-readable API specification

---

## 📘 Interactive Documentation

**Local Development:**
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

**Production:**
- **Swagger UI**: https://hetzner-api.hras.owezzy.tech/docs
- **ReDoc**: https://hetzner-api.hras.owezzy.tech/redoc

These interfaces let you test endpoints directly from your browser and see real-time examples.

---

## 💡 Best Practices

### For Integration Developers
1. **Always check health endpoint** before making chat requests
2. **Handle conversation IDs** properly for multi-turn conversations
3. **Implement retry logic** for 500 errors with exponential backoff
4. **Cache responses** when appropriate to reduce API calls
5. **Validate input** on client side before sending requests

### For Frontend Developers
1. **Show loading states** - AI responses take time to generate
2. **Display source citations** - users need to verify information
3. **Handle long responses** - implement proper text rendering
4. **Preserve conversation context** - store and reuse conversation IDs
5. **Implement error boundaries** - gracefully handle API failures

### For Monitoring & Operations
1. **Monitor health endpoint** for system availability
2. **Track response times** and set alerting thresholds
3. **Monitor error rates** and investigate 500 errors promptly
4. **Use admin endpoints** for operational insights
5. **Implement log aggregation** for troubleshooting

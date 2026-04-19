# HRAS System Diagrams

This document contains visual diagrams explaining the HRAS (Human Rights Advisory System) architecture, data flow, and database structure.

> **SVG files are available in:** `docs/architecture/diagrams/`

---

## 1. System Flowchart

This flowchart shows the high-level system architecture and how components interact.

![System Flowchart](./diagrams/01-system-flowchart.svg)

<details>
<summary>View Mermaid Source</summary>

```mermaid
flowchart TB
    subgraph Frontend["Frontend Layer (Next.js 15)"]
        UI[Web Interface]
        Chat[Chat Component]
        Sources[Source Citations Display]
    end

    subgraph API["API Layer (FastAPI)"]
        Router[API Router]
        ChatRoute["/api/v1/chat"]
        AdminRoute["/api/v1/admin"]
        ConvRoute["/api/v1/conversations"]
        HealthRoute["/health"]
    end

    subgraph Services["Service Layer"]
        ChatService[Chat Service]
        IngestionService[Data Ingestion Service]
    end

    subgraph MultiAgent["Multi-Agent System (LangGraph)"]
        Supervisor[Supervisor Node]
        Research[Research Agent]
        Advisory[Advisory Agent]
        Compare[Compare Agent]
    end

    subgraph Tools["Agent Tools"]
        SearchTool[search_recommendations]
        CountryTool[get_country_recommendations]
        CompareTool[compare_countries]
        MechanismTool[get_mechanism_overview]
    end

    subgraph RAG["RAG Pipeline"]
        RAGChain[RAG Chain]
        Prompt[Prompt Templates]
    end

    subgraph AI["AI/ML Layer"]
        Ollama[Ollama LLM Server]
        LLM[Nemotron 3 Nano 30B]
        Embeddings[nomic-embed-text]
    end

    subgraph Storage["Data Storage"]
        ChromaDB[(ChromaDB Vector Store)]
        PostgreSQL[(PostgreSQL Database)]
        SQLite[(SQLite - Dev)]
    end

    subgraph External["External Data"]
        UHRI[UHRI Data Sources]
        UNDocs[UN Documents]
    end

    UI --> Chat
    Chat --> Router
    Router --> ChatRoute
    Router --> AdminRoute
    Router --> ConvRoute
    Router --> HealthRoute

    ChatRoute --> ChatService
    AdminRoute --> IngestionService

    ChatService --> MultiAgent
    ChatService --> RAGChain

    Supervisor --> Research
    Supervisor --> Advisory
    Supervisor --> Compare
    Research --> Advisory
    Compare --> Advisory

    Research --> Tools
    Compare --> Tools
    Tools --> ChromaDB

    RAGChain --> Prompt
    RAGChain --> ChromaDB
    Prompt --> LLM

    MultiAgent --> Ollama
    Ollama --> LLM
    Ollama --> Embeddings
    Embeddings --> ChromaDB

    IngestionService --> UHRI
    UHRI --> UNDocs
    IngestionService --> ChromaDB

    ChatService --> PostgreSQL
    ChatService --> SQLite

    Advisory --> ChatService
    ChatService --> Sources
    Sources --> UI
```

</details>

---

## 2. Sequence Diagram

This sequence diagram shows the complete request/response flow when a user asks a question.

![Sequence Diagram](./diagrams/02-sequence-diagram.svg)

<details>
<summary>View Mermaid Source</summary>

```mermaid
sequenceDiagram
    autonumber
    participant User
    participant Frontend as Frontend (Next.js)
    participant API as FastAPI Router
    participant ChatSvc as Chat Service
    participant Supervisor as Supervisor Agent
    participant Research as Research Agent
    participant Advisory as Advisory Agent
    participant Tools as Agent Tools
    participant VectorDB as ChromaDB
    participant LLM as Ollama LLM
    participant DB as PostgreSQL

    User->>Frontend: Enter question
    Frontend->>API: POST /api/v1/chat
    Note over API: Validate ChatRequest

    API->>ChatSvc: process_message(request)
    ChatSvc->>VectorDB: get_collection_stats()
    VectorDB-->>ChatSvc: {count: N}

    alt Database is empty
        ChatSvc-->>API: Database not initialized
        API-->>Frontend: Error response
        Frontend-->>User: Show error message
    else Database has documents
        ChatSvc->>Supervisor: run_agent_workflow(question)

        Note over Supervisor: Classify query type

        Supervisor->>LLM: Analyze question
        LLM-->>Supervisor: {query_type, countries, themes}

        alt Query type: research
            Supervisor->>Research: Execute research
            Research->>Tools: search_recommendations(query)
            Tools->>VectorDB: similarity_search_with_score()
            VectorDB-->>Tools: Relevant documents
            Tools-->>Research: Formatted results

            Research->>Tools: get_country_recommendations(country)
            Tools->>VectorDB: similarity_search(filter: country)
            VectorDB-->>Tools: Country documents
            Tools-->>Research: Country results

            Research->>LLM: Generate research summary
            LLM-->>Research: Research summary
            Research->>Advisory: Hand off to advisory

        else Query type: compare
            Supervisor->>Research: Compare Agent handles
            Research->>Tools: compare_countries(countries)
            Tools->>VectorDB: Multiple country queries
            VectorDB-->>Tools: Comparison data
            Tools-->>Research: Comparison results
            Research->>LLM: Generate comparison
            LLM-->>Research: Comparison analysis
            Research->>Advisory: Hand off to advisory

        else Query type: advisory
            Supervisor->>Advisory: Direct to advisory
        end

        Advisory->>LLM: Generate final response
        LLM-->>Advisory: Final response with citations

        Advisory-->>ChatSvc: {answer, sources, query_type}

        opt PostgreSQL enabled
            ChatSvc->>DB: persist_messages()
            DB-->>ChatSvc: Saved
        end

        ChatSvc-->>API: ChatResponse
        API-->>Frontend: JSON response
        Frontend-->>User: Display answer with sources
    end
```

</details>

---

## 3. Entity Relationship Diagram

This ER diagram shows the database schema and relationships between entities.

![Entity Relationship Diagram](./diagrams/03-entity-relationship.svg)

<details>
<summary>View Mermaid Source</summary>

```mermaid
erDiagram
    CONVERSATION ||--o{ MESSAGE : contains
    MESSAGE ||--o{ MESSAGE_SOURCE : has

    CONVERSATION {
        string id PK
        string title
        datetime created_at
        datetime updated_at
    }

    MESSAGE {
        string id PK
        string conversation_id FK
        string role
        text content
        datetime created_at
    }

    MESSAGE_SOURCE {
        string id PK
        string message_id FK
        string country
        string mechanism
        string year
        string theme
        string status
        text snippet
    }

    VECTOR_DOCUMENT {
        string id PK
        text content
        vector embedding
        string country
        string mechanism
        string year
        string theme
        string status
        float relevance_score
    }

    MESSAGE_SOURCE }o--|| VECTOR_DOCUMENT : references
```

</details>

### Database Schema Details

| Table | Column | Type | Description |
|-------|--------|------|-------------|
| **CONVERSATION** | id | UUID | Primary key |
| | title | VARCHAR(255) | Conversation title |
| | created_at | TIMESTAMP | Creation time (with timezone) |
| | updated_at | TIMESTAMP | Last update (auto-update) |
| **MESSAGE** | id | UUID | Primary key |
| | conversation_id | UUID (FK) | References CONVERSATION |
| | role | VARCHAR(20) | "user" or "assistant" |
| | content | TEXT | Message text |
| | created_at | TIMESTAMP | Creation time |
| **MESSAGE_SOURCE** | id | UUID | Primary key |
| | message_id | UUID (FK) | References MESSAGE |
| | country | VARCHAR(100) | Country name |
| | mechanism | VARCHAR(100) | UPR, CERD, CAT, etc. |
| | year | VARCHAR(10) | Document year |
| | theme | VARCHAR(255) | Human rights theme |
| | status | VARCHAR(50) | Recommendation status |
| | snippet | TEXT | Document excerpt |

---

## 4. Multi-Agent Workflow Diagram

This diagram shows the LangGraph multi-agent orchestration workflow.

![Multi-Agent Workflow](./diagrams/04-multi-agent-workflow.svg)

<details>
<summary>View Mermaid Source</summary>

```mermaid
stateDiagram-v2
    [*] --> Supervisor: User Question

    state Supervisor {
        [*] --> Classify
        Classify --> RouteDecision
        RouteDecision --> [*]
    }

    Supervisor --> Research: query_type = research
    Supervisor --> Compare: query_type = compare
    Supervisor --> Advisory: query_type = advisory

    state Research {
        [*] --> SearchDocs
        SearchDocs --> GetCountryRecs
        GetCountryRecs --> GenerateSummary
        GenerateSummary --> [*]
    }

    state Compare {
        [*] --> CompareCountries
        CompareCountries --> AnalyzePatterns
        AnalyzePatterns --> [*]
    }

    state Advisory {
        [*] --> AssembleContext
        AssembleContext --> GenerateResponse
        GenerateResponse --> FormatCitations
        FormatCitations --> [*]
    }

    Research --> Advisory: research_summary
    Compare --> Advisory: comparison_result

    Advisory --> [*]: final_response
```

</details>

### Agent Responsibilities

| Agent | Role | Key Actions |
|-------|------|-------------|
| **Supervisor** | Query classifier and router | Analyzes question, extracts countries/themes, routes to appropriate agent |
| **Research Agent** | Document retrieval and summarization | Searches vector store, retrieves country-specific recommendations, generates research summary |
| **Compare Agent** | Cross-country analysis | Compares recommendations across countries, identifies patterns |
| **Advisory Agent** | Response generation | Synthesizes final response with citations, ensures professional UN-style language |

---

## 5. Data Ingestion Pipeline

This flowchart shows how UN documents are ingested into the vector store.

![Data Ingestion Pipeline](./diagrams/05-data-ingestion-pipeline.svg)

<details>
<summary>View Mermaid Source</summary>

```mermaid
flowchart LR
    subgraph Sources["Data Sources"]
        UHRI[UHRI API]
        Sample[Sample Data]
    end

    subgraph Loader["Document Loader"]
        Fetch[Fetch Documents]
        Parse[Parse Content]
        Extract[Extract Metadata]
    end

    subgraph Processing["Processing"]
        Chunk[Text Chunking]
        Embed[Generate Embeddings]
    end

    subgraph Storage["Vector Storage"]
        Collection[uhri_recommendations Collection]
        Index[Vector Index]
        Meta[Metadata Store]
    end

    subgraph Verification["Verification"]
        Stats[Collection Stats]
        Validate[Validate Ingestion]
    end

    UHRI --> Fetch
    Sample --> Fetch
    Fetch --> Parse
    Parse --> Extract
    Extract --> Chunk
    Chunk --> Embed
    Embed --> Collection
    Collection --> Index
    Collection --> Meta
    Index --> Stats
    Meta --> Stats
    Stats --> Validate
```

</details>

### Ingestion Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| Chunk Size | 1024 tokens | Optimal size for retrieval |
| Overlap | 20% | Prevents context loss at boundaries |
| Embedding Model | nomic-embed-text | Via Ollama |
| Vector Dimension | 768 | Embedding dimensions |
| Distance Metric | Cosine similarity | For relevance ranking |

---

## 6. API Architecture

This diagram shows the API layer structure and middleware stack.

![API Architecture](./diagrams/06-api-architecture.svg)

<details>
<summary>View Mermaid Source</summary>

```mermaid
flowchart TB
    subgraph Client["Client"]
        Browser[Web Browser]
        API_Client[API Client]
    end

    subgraph Middleware["Middleware Stack"]
        CORS[CORS Middleware]
        Security[Security Headers]
        Logging[Request Logging]
        Metrics[Prometheus Metrics]
        TrustedHost[Trusted Host]
    end

    subgraph Routes["API Routes"]
        Health[/health]
        Chat[/api/v1/chat]
        Admin[/api/v1/admin]
        Conv[/api/v1/conversations]
        MetricsEnd[/metrics]
    end

    subgraph Handlers["Route Handlers"]
        HealthCheck[Health Check]
        ChatHandler[Chat Handler]
        IngestHandler[Ingest Handler]
        StatsHandler[Stats Handler]
        ConvHandler[Conversation CRUD]
    end

    Browser --> CORS
    API_Client --> CORS
    CORS --> Security
    Security --> Logging
    Logging --> Metrics
    Metrics --> TrustedHost
    TrustedHost --> Routes

    Health --> HealthCheck
    Chat --> ChatHandler
    Admin --> IngestHandler
    Admin --> StatsHandler
    Conv --> ConvHandler
    MetricsEnd --> Metrics
```

</details>

### API Endpoints Summary

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check and readiness probe |
| `/api/v1/chat` | POST | Process chat message through RAG pipeline |
| `/api/v1/admin/ingest` | POST | Ingest documents into vector store |
| `/api/v1/admin/stats` | GET | Get vector store statistics |
| `/api/v1/conversations` | GET | List all conversations |
| `/api/v1/conversations/{id}` | GET/DELETE | Get or delete conversation |
| `/metrics` | GET | Prometheus metrics endpoint |

---

## File Locations

All SVG diagram files are located in:

```
docs/architecture/diagrams/
├── 01-system-flowchart.svg
├── 02-sequence-diagram.svg
├── 03-entity-relationship.svg
├── 04-multi-agent-workflow.svg
├── 05-data-ingestion-pipeline.svg
└── 06-api-architecture.svg
```

---

## Related Documentation

- [Architecture Overview](./ARCHITECTURE.md) - Detailed system architecture
- [AI/ML Pipeline](./AI_ML.md) - RAG and multi-agent details
- [API Reference](../reference/API.md) - REST endpoint documentation

# LangSmith Integration Setup

This guide covers setting up LangSmith tracing and evaluation for the HRAS system.

## Overview

LangSmith provides monitoring, tracing, and evaluation capabilities for the multi-agent RAG system. It complements (doesn't replace) existing Prometheus monitoring with:

- **Trace Visualization**: See complete multi-agent workflow execution paths
- **Input/Output Inspection**: Analyze LLM inputs, outputs, and transformations
- **Quality Evaluation**: Automated evaluation of response quality and relevance
- **Performance Monitoring**: Track agent performance and identify bottlenecks
- **Cost Analysis**: Monitor token usage and API costs

## Production Setup

### 1. Create LangSmith Account

1. Visit [LangSmith](https://smith.langchain.com) and create an account
2. Create a new project named `hras-production`
3. Generate an API key from Account Settings

### 2. Add GitHub Secret

Add the LangSmith API key as a GitHub secret:

```bash
# In GitHub repository settings > Secrets and variables > Actions
LANGSMITH_API_KEY=ls-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Required GitHub Secrets for LangSmith:**

| Secret | Description | Example |
|--------|-------------|---------|
| `LANGSMITH_API_KEY` | LangSmith API key | `ls-xxxxx-xxxx-xxxx...` |

### 3. Deployment

The CI/CD pipeline automatically configures LangSmith for production:

- **Enabled**: `USE_LANGSMITH_TRACING=true`
- **Project**: `hras-production`
- **Sampling Rate**: 10% (cost control)
- **Privacy**: Automatic input sanitization enabled

## Development Setup

### 1. Local Configuration

```bash
# In backend/.env
USE_LANGSMITH_TRACING=true
LANGSMITH_API_KEY=ls-xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
LANGSMITH_PROJECT=hras-development
LANGSMITH_SAMPLING_RATE=0.5  # 50% for development
```

### 2. Install Dependencies

```bash
cd backend
uv sync  # Installs langsmith>=0.3.13
```

### 3. Test Integration

```bash
# Run health check
curl http://localhost:8000/health

# Check logs for LangSmith initialization
tail -f logs/app.log | grep langsmith
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `USE_LANGSMITH_TRACING` | `false` | Enable/disable tracing |
| `LANGSMITH_API_KEY` | `None` | LangSmith API key |
| `LANGSMITH_PROJECT` | `hras-production` | Project name |
| `LANGSMITH_ENDPOINT` | `https://api.smith.langchain.com` | API endpoint |
| `LANGSMITH_SAMPLING_RATE` | `0.1` | Sampling rate (0.0-1.0) |

### Privacy Controls

The integration includes automatic data sanitization:

- **Email addresses** → `[REDACTED]`
- **API keys/tokens** → `[REDACTED]`
- **High-privacy countries** → `[COUNTRY_xxxxxxxx]` (hashed)
- **Credit card numbers** → `[REDACTED]`

### Feature Flags

LangSmith tracing is controlled by feature flags for safe rollout:

```python
# Gradual rollout
USE_LANGSMITH_TRACING=false  # Disabled by default
LANGSMITH_SAMPLING_RATE=0.1  # 10% sampling when enabled
```

## Usage

### 1. Automatic Tracing

Multi-agent workflows are automatically traced when feature flag is enabled:

```python
# Traces are automatically created for:
# - Agent graph execution (supervisor → research → advisory)
# - LLM calls within agents
# - Vector store searches
# - Tool usage (UHRI API calls)
```

### 2. Manual Tracing

For custom components:

```python
from src.app.core.tracing import hras_traceable, langsmith_trace_session

@hras_traceable(name="custom_agent", run_type="agent")
async def my_custom_agent(state: AgentState) -> AgentState:
    # Function is automatically traced
    return state

# Group related operations
async with langsmith_trace_session("user_query_123") as session_id:
    result = await run_agent_workflow(question)
```

### 3. Chain Integration

For LangChain LCEL chains:

```python
from src.app.core.tracing import get_langchain_tracer

tracer = get_langchain_tracer()
if tracer:
    chain = prompt | llm | output_parser
    result = await chain.ainvoke(inputs, config={"callbacks": [tracer]})
```

## Monitoring

### Health Check

```bash
# Check LangSmith integration status
curl http://localhost:8000/health | jq '.langsmith'
```

### Dashboard Access

1. **LangSmith Console**: https://smith.langchain.com
2. **Project Dashboard**: Navigate to `hras-production` project
3. **Traces**: View individual request traces and agent workflows
4. **Evaluations**: Review automated quality assessments

### Integration with Existing Monitoring

LangSmith **complements** existing Prometheus/Grafana monitoring:

| System | Purpose | Metrics |
|--------|---------|---------|
| **Prometheus** | System metrics, performance | Request rate, latency, errors |
| **LangSmith** | AI-specific insights | Trace visualization, quality scores |
| **Loki** | Log aggregation | Structured logs with trace IDs |

**Trace ID Correlation**: LangSmith trace IDs are included in structured logs for cross-system correlation.

## Cost Management

### Sampling Strategy

- **Production**: 10% sampling (`LANGSMITH_SAMPLING_RATE=0.1`)
- **Development**: 50% sampling for testing
- **Debugging**: 100% sampling (temporary)

### Usage Estimation

For ~1000 requests/day with 10% sampling:
- **Traces**: ~100 traces/day
- **Cost**: ~$5-10/month (varies by trace complexity)
- **Storage**: ~1GB/month

### Cost Controls

1. **Feature Flag**: Can be disabled instantly if needed
2. **Sampling Rate**: Adjustable via environment variable
3. **Input Sanitization**: Reduces data volume
4. **Session Grouping**: Efficient trace organization

## Troubleshooting

### Common Issues

1. **Tracing Not Working**
   ```bash
   # Check feature flag
   grep USE_LANGSMITH_TRACING .env

   # Check API key
   grep LANGSMITH_API_KEY .env

   # Check logs
   tail -f logs/app.log | grep langsmith
   ```

2. **API Connection Failed**
   ```bash
   # Test connectivity
   curl -H "x-api-key: $LANGSMITH_API_KEY" https://api.smith.langchain.com/info
   ```

3. **High Costs**
   ```bash
   # Reduce sampling rate
   echo "LANGSMITH_SAMPLING_RATE=0.05" >> .env  # 5% sampling
   ```

### Debug Mode

Enable verbose tracing for debugging:

```bash
# Temporary 100% sampling
LANGSMITH_SAMPLING_RATE=1.0
USE_LANGSMITH_TRACING=true
```

## Security Considerations

1. **API Key Protection**: Store in GitHub Secrets, never commit to code
2. **Data Sanitization**: Automatic removal of sensitive patterns
3. **Privacy Compliance**: Extra sanitization for high-privacy countries
4. **Network Security**: HTTPS-only communication with LangSmith API
5. **Access Control**: Project-level access in LangSmith console

## Support

- **Documentation**: https://docs.smith.langchain.com
- **API Reference**: https://api.python.langchain.com/en/latest/langsmith_api_reference.html
- **GitHub Issues**: Open issue with `[langsmith]` tag

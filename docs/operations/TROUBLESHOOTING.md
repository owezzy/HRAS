# 🔍 HRAS Troubleshooting Guide

*Quick fixes for common issues - get back up and running fast*

---

## 🚨 Emergency Quick Fixes

**System completely down?** Try these in order:

1. `make dev` - Restart everything
2. `curl http://localhost:8000/health` - Check if backend is responding
3. Check browser console (F12) for frontend errors
4. `make clean && make install` - Clean restart
5. Check if Ollama is running: `ollama serve`

---

## 🎯 Problem Categories

### 🔥 **Critical Issues** (System Broken)
- [HRAS won't start](#system-wont-start)
- [Getting error messages instead of answers](#error-responses)
- [Docker/Kubernetes deployment failing](#docker-kubernetes-issues)

### ⚡ **Performance Issues** (System Slow)
- [Responses take forever](#slow-response-times)
- [High CPU/memory usage](#resource-usage-problems)
- [Data ingestion stuck](#data-ingestion-issues)

### 🤔 **Usage Issues** (System Confusing)
- [Answers don't make sense](#irrelevant-responses)
- [Missing source citations](#missing-sources)
- [Conversation context lost](#conversation-problems)

---

## 🔥 Critical Issues

### System Won't Start

#### **Symptoms:**
- `make dev` fails with errors
- Nothing loads at http://localhost:3000 or http://localhost:8000
- Services crash immediately on startup

#### **Quick Diagnosis:**
```bash
# Check what's running
lsof -i :3000  # Frontend port
lsof -i :8000  # Backend port
lsof -i :11434 # Ollama port

# Check service health
curl http://localhost:8000/health
curl http://localhost:11434/api/tags
```

#### **Common Fixes:**

**🔧 Port Conflicts**
```bash
# Kill processes using required ports
sudo lsof -ti:3000 | xargs kill -9
sudo lsof -ti:8000 | xargs kill -9
sudo lsof -ti:11434 | xargs kill -9

# Then restart
make dev
```

**🔧 Missing Dependencies**
```bash
# Reinstall everything
make clean
make install

# Or individually
cd frontend && npm install
cd backend && uv sync
```

**🔧 Ollama Not Running**
```bash
# Start Ollama service
ollama serve

# Pull required models
ollama pull nomic-embed-text
ollama pull nemotron-3-nano:30b-cloud
```

**🔧 Environment Variables**
```bash
# Copy example files
cp backend/.env.example backend/.env
cp frontend/.env.local.example frontend/.env.local

# Edit .env files with correct values
```

---

### Error Responses

#### **Symptoms:**
- Getting `{"detail": "Error message"}` instead of AI responses
- 500 Internal Server Error
- 400 Bad Request errors

#### **Diagnostic Steps:**
```bash
# Check backend logs
cd backend && uv run uvicorn src.app.main:app --reload --log-level debug

# Test API directly
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "test"}'

# Check Ollama connectivity
curl http://localhost:11434/api/tags
```

#### **Error-Specific Fixes:**

**🔧 "Ollama service unavailable"**
```bash
# Restart Ollama
ollama serve

# Test model availability
ollama list
ollama pull nemotron-3-nano:30b-cloud
```

**🔧 "ChromaDB connection failed"**
```bash
# Check ChromaDB directory
ls -la backend/chroma_db/
rm -rf backend/chroma_db/  # Delete if corrupted
make ingest  # Rebuild database
```

**🔧 "Field required: message"**
```bash
# Request format issue - check JSON structure
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Your question here"}'  # Correct format
```

---

### Docker/Kubernetes Issues

#### **Symptoms:**
- `make kind-deploy` fails
- Pods stuck in "Pending" or "CrashLoopBackOff"
- Images not building

#### **Quick Diagnosis:**
```bash
# Check Kind cluster
kind get clusters
kubectl get pods -n hras-system

# Check image builds
docker images | grep hras
make docker-build

# Check pod logs
kubectl logs -n hras-system -l app=backend
```

#### **Common Fixes:**

**🔧 Kind Cluster Issues**
```bash
# Recreate cluster
make kind-delete
make kind-create
make kind-load
make kind-deploy
```

**🔧 Image Build Problems**
```bash
# Clean rebuild
docker system prune -f
make docker-build
make kind-load
```

**🔧 Pod Startup Issues**
```bash
# Check resource limits
kubectl describe pod -n hras-system [pod-name]

# Check ConfigMaps
kubectl get configmap -n hras-system

# Check ingestion job
kubectl get jobs -n hras-system
```

---

## ⚡ Performance Issues

### Slow Response Times

#### **Symptoms:**
- Queries take > 10 seconds to respond
- System feels sluggish
- Browser shows loading indefinitely

#### **Performance Diagnosis:**
```bash
# Check system resources
top -p $(pgrep -f "uvicorn\|node")

# Test response time
time curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "quick test"}'

# Check ChromaDB size
du -sh backend/chroma_db/
```

#### **Performance Fixes:**

**🔧 Optimize Vector Database**
```bash
# Clear and rebuild with sample data (faster)
make ingest-clear use_sample=true

# Check database stats
make db-stats
```

**🔧 Reduce Query Complexity**
- Ask shorter, more specific questions
- Avoid very broad queries like "tell me everything about human rights"
- Break complex questions into smaller parts

**🔧 System Resource Optimization**
```bash
# Close unnecessary applications
# Ensure sufficient RAM (8GB+ recommended)
# Check available disk space
df -h

# Monitor resource usage during queries
htop
```

---

### Resource Usage Problems

#### **Symptoms:**
- High CPU usage (>90%)
- Memory usage growing continuously
- Disk space filling up

#### **Resource Monitoring:**
```bash
# Monitor real-time usage
htop
watch -n 1 'free -m'
watch -n 1 'df -h'

# Check Docker resource usage
docker stats
```

#### **Resource Fixes:**

**🔧 Memory Leaks**
```bash
# Restart services periodically
make dev  # Restarts with fresh memory

# Limit ChromaDB memory usage
# Edit backend/.env
CHROMA_PERSIST_DIRECTORY=./chroma_db
```

**🔧 Disk Space Issues**
```bash
# Clean Docker artifacts
docker system prune -f
docker volume prune -f

# Clean build artifacts
make clean
rm -rf frontend/.next
rm -rf backend/.pytest_cache
```

---

### Data Ingestion Issues

#### **Symptoms:**
- `make ingest` hangs or fails
- ChromaDB shows 0 documents after ingestion
- Ingestion progress never completes

#### **Ingestion Diagnosis:**
```bash
# Check ingestion status
make db-stats

# Test with sample data
curl -X POST "http://localhost:8000/api/v1/admin/ingest?use_sample=true"

# Check backend logs during ingestion
cd backend && uv run uvicorn src.app.main:app --reload --log-level debug
```

#### **Ingestion Fixes:**

**🔧 Clear and Restart Ingestion**
```bash
# Complete reset
rm -rf backend/chroma_db/
make ingest-clear
```

**🔧 Network Timeout Issues**
```bash
# Use sample data for development
make ingest use_sample=true

# Check internet connectivity for full ingestion
ping 8.8.8.8
```

**🔧 Memory Issues During Ingestion**
```bash
# Reduce batch size (if configurable)
# Ensure 8GB+ RAM available during ingestion
# Close other applications
```

---

## 🤔 Usage Issues

### Irrelevant Responses

#### **Symptoms:**
- AI gives generic answers unrelated to your question
- Responses don't cite UN documents
- Answers seem to ignore context

#### **Quality Diagnosis:**
```bash
# Check if data was ingested properly
make db-stats

# Test with known good question
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What human rights recommendations exist for Kenya?"}'
```

#### **Quality Fixes:**

**🔧 Improve Question Phrasing**
- Be specific: "Kenya UPR 2023 recommendations" vs "tell me about Kenya"
- Use UN terminology: "Universal Periodic Review" vs "human rights review"
- Include context: "civil and political rights" vs "rights"

**🔧 Verify Data Ingestion**
```bash
# Re-ingest with sample data
make ingest-clear use_sample=true

# Check document count
make db-stats  # Should show > 0 documents
```

---

### Missing Sources

#### **Symptoms:**
- Responses don't include source citations
- "sources" array is empty
- No document references in answers

#### **Sources Diagnosis:**
```bash
# Test a query and check response structure
curl -s -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "test"}' | jq '.sources'
```

#### **Sources Fix:**
```bash
# Ensure documents were ingested with metadata
make ingest-clear
make ingest

# Verify ChromaDB contains documents with metadata
make db-stats
```

---

### Conversation Problems

#### **Symptoms:**
- Follow-up questions don't understand context
- System treats each question as new conversation
- Conversation ID not working

#### **Conversation Diagnosis:**
```bash
# Test conversation flow
# Step 1: Start conversation
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What about Kenya?"}' > response1.json

# Step 2: Get conversation_id from response
CONV_ID=$(jq -r '.conversation_id' response1.json)

# Step 3: Continue conversation
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d "{\"message\": \"Tell me more about that\", \"conversation_id\": \"$CONV_ID\"}"
```

#### **Conversation Fix:**
- Ensure you're passing `conversation_id` from previous responses
- Check that conversation_id is a valid UUID format
- Conversations expire after ~24 hours (start fresh if needed)

---

## 🛠️ Advanced Troubleshooting Tools

### Log Analysis
```bash
# Backend detailed logs
cd backend && PYTHONPATH=. uv run uvicorn src.app.main:app --reload --log-level debug

# Frontend build logs
cd frontend && npm run dev

# Docker container logs
docker logs hras-backend
docker logs hras-frontend
```

### Health Check Scripts
```bash
# Create health check script
cat > health_check.sh << 'EOF'
#!/bin/bash
echo "🏥 HRAS Health Check"
echo "===================="

echo -n "Backend Health: "
curl -s http://localhost:8000/health > /dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "Ollama Health: "
curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "Frontend Health: "
curl -s http://localhost:3000 > /dev/null && echo "✅ OK" || echo "❌ FAIL"

echo -n "ChromaDB Health: "
make db-stats > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"
EOF

chmod +x health_check.sh
./health_check.sh
```

### Performance Monitoring
```bash
# Monitor API response times
while true; do
  echo "$(date): $(time curl -s -o /dev/null -w '%{time_total}' -X POST http://localhost:8000/api/v1/chat -H 'Content-Type: application/json' -d '{\"message\": \"test\"}')s"
  sleep 5
done
```

---

## 📞 Getting Help

### 🆘 **When to Escalate**
Contact support for:
- Issues not resolved by this guide
- Suspected security problems
- Data corruption or loss
- Performance degradation despite following fixes

### 📧 **Support Information**
- **Email**: [Your support email]
- **Include**: Error messages, system info, steps to reproduce
- **Logs**: Attach relevant log files
- **Environment**: OS, browser, HRAS version (0.2.0)

### 📚 **Additional Resources**
- [Development Guide](DEVELOPMENT.md) - For code-related issues
- [Configuration Reference](CONFIGURATION.md) - For setup problems
- [Architecture Guide](ARCHITECTURE.md) - To understand system behavior

---

## ✅ Prevention Checklist

Daily maintenance to prevent issues:

- [ ] Check system health: `./health_check.sh`
- [ ] Monitor disk space: `df -h`
- [ ] Verify Ollama models: `ollama list`
- [ ] Test basic query: Quick API test
- [ ] Check logs for errors: Review application logs
- [ ] Backup ChromaDB: `cp -r backend/chroma_db/ backup/`

**Remember**: Most issues can be resolved by restarting services with `make dev`. When in doubt, restart first!

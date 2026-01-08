# HRAS - Troubleshooting Guide

This document provides comprehensive troubleshooting guidance for the HRAS (Human Rights Advisory System).

## Troubleshooting Methodology

### 1. Diagnostic Approach

1. **Identify Symptoms:** Clearly describe the issue experienced
2. **Gather Information:** Collect error messages, logs, and usage context
3. **Check Basic Functionality:** Verify system connectivity and dependencies
4. **Apply Systematic Tests:** Isolate components to identify root cause
5. **Implement Solutions:** Apply fixes and verify resolution
6. **Document Findings:** Record troubleshooting steps and outcomes

### 2. Troubleshooting Tools

- **System Logs:** Check application logs for error details
- **Health Checks:** Use `/health` endpoint to verify service status
- **Verbose Mode:** Enable detailed logging for debugging
- **Debug Console:** Access development tools for deeper inspection

## Common Issues and Solutions

### 1. System Not Responding

#### Symptoms:
- No response when submitting queries
- Application appears frozen or unresponsive
- White screen or loading indefinitely

#### Root Causes:
- Network connectivity issues
- Backend service not running
- Frontend build failure
- Database connection problems

#### Diagnostic Steps:
1. Check network connection
2. Verify backend server status: `curl http://localhost:8000/health`
3. Check frontend status: Open browser dev tools (F12) and check console
4. Check database connectivity
5. Review application logs for errors

#### Solutions:
- Restart backend service: `make backend-dev`
- Restart frontend service: `make frontend-dev`
- Clear browser cache and reload
- Ensure all required services are running

### 2. Slow Response Times

#### Symptoms:
- Queries take unusually long to process
- Response generation is delayed
- System appears sluggish

#### Root Causes:
- Heavy computational load
- Large vector database queries
- Network latency
- Resource constraints

#### Diagnostic Steps:
1. Check system metrics (CPU, memory, disk I/O)
2. Monitor backend service performance
3. Review query processing logs
4. Check vector search performance
5. Test with simpler queries

#### Solutions:
- Optimize query parameters
- Increase resource allocation if needed
- Clear unused data from vector store
- Consider pagination for large result sets
- Enable caching for frequent queries

### 3. Error Responses

#### Symptoms:
- Error messages returned instead of responses
- "Internal Server Error" or "Bad Request" messages
- Application crashes or restarts

#### Root Causes:
- Invalid input data
- Missing dependencies
- Configuration errors
- Permission issues
- Database corruption

#### Diagnostic Steps:
1. Identify specific error message
2. Check application logs for stack trace
3. Review input validation
4. Verify configuration files
5. Test with sample inputs

#### Common Error Solutions:
- **400 Bad Request:** Validate input format and content
- **500 Internal Server Error:** Check for unhandled exceptions
- **Database Connection Errors:** Verify database URL and credentials
- **Ollama API Errors:** Check model availability and access

### 4. Data Ingestion Issues

#### Symptoms:
- Data ingestion fails silently or with errors
- Vector store appears empty or incomplete
- Progress tracking shows errors

#### Root Causes:
- UHRI API rate limiting
- Network connectivity to data sources
- Malformed document content
- Storage permission issues
- Memory constraints during processing

#### Diagnostic Steps:
1. Check ingestion logs for details
2. Verify network connectivity to UHRI sources
3. Test with smaller data subsets
4. Check storage permissions
5. Monitor memory usage during ingestion

#### Solutions:
- Implement retry mechanism with exponential backoff
- Use sample data for testing
- Increase memory allocation if needed
- Handle API rate limits gracefully
- Validate document format before processing

### 5. Docker and Kubernetes Issues

#### Symptoms:
- Deployment fails with various errors
- Services don't start properly
- Pods crash or remain in pending state

#### Root Causes:
- Image build failures
- Configuration errors
- Resource constraints
- Network policies blocking communication
- Volume mount issues

#### Diagnostic Steps:
1. Check Docker/Kubernetes logs
2. Verify image build process
3. Test configuration templates
4. Check resource limits and requests
5. Validate network connectivity between services

#### Common Solutions:
- Build images manually: `docker build -t hras-frontend .`
- Test configuration files locally
- Increase resource limits in deployment manifests
- Check service dependencies and network policies
- Verify volume permissions and paths

## Advanced Troubleshooting Techniques

### 1. Log Analysis

The system implements structured logging with the following key components:

- **Log Levels:** DEBUG, INFO, WARNING, ERROR, CRITICAL
- **Context Attributes:** Include request ID, user ID, operation type
- **Structured Format:** JSON logs for easy parsing and analysis

#### Common Log Analysis Patterns:

1. **Error Pattern Recognition:**
   ```bash
   grep -i "error" logs/app.log | tail -20
   grep -i "database" logs/app.log | grep -i "connection"
   ```

2. **Performance Pattern Analysis:**
   ```bash
   grep -i "latency" logs/app.log | awk '{print $2,$3}' | sort -n
   grep -i "response" logs/app.log | tail -10
   ```

3. **Security Pattern Detection:**
   ```bash
   grep -i "auth" logs/app.log | grep -i "failure"
   grep -i "permission" logs/app.log
   ```

### 2. Performance Monitoring

The system includes performance monitoring capabilities:

1. **Response Time Tracking:**
   - End-to-end query processing time
   - Retrieval component latency
   - Generation component processing time

2. **Resource Utilization:**
   - CPU and memory usage per service
   - Disk I/O for vector store operations
   - Network throughput between components

3. **Query Analytics:**
   - Query frequency by type
   - Success/failure rates
   - Popular query patterns
   - Source citation frequency

## User Support Guide

### 1. When to Contact Support

Contact support if you experience:

- Persistent system errors
- Data inconsistency issues
- Security concerns
- Feature requests or bugs
- Performance degradation not resolved by standard troubleshooting

### 2. Support Information

- **Email:** support@hras.example.com
- **Required Information:**
  - Description of the issue
  - Steps to reproduce
  - Screenshots or error messages
  - System information (browser, OS)
  - Time and date of occurrence
  - Any recent changes to your environment

### 3. Knowledge Base

The knowledge base contains:
- FAQ section
- Step-by-step guides
- Video tutorials
- Community forums
- Developer documentation

## Preventive Maintenance

### 1. Regular Maintenance Tasks

1. **System Updates:**
   - Keep dependencies updated
   - Apply security patches promptly
   - Monitor for breaking changes

2. **Database Maintenance:**
   - Perform regular backups
   - Optimize vector store indexes
   - Monitor database health
   - Implement retention policies

3. **Security Audits:**
   - Review access controls
   - Scan for vulnerabilities
   - Update encryption protocols
   - Monitor for suspicious activity

4. **Performance Optimization:**
   - Analyze usage patterns
   - Tune resource allocation
   - Optimize query performance
   - Clean up unused data

### 2. Monitoring Checklist

- [ ] System health status
- [ ] Resource utilization metrics
- [ ] Database connection status
- [ ] API endpoint availability
- [ ] Error rate monitoring
- [ ] Backup job success
- [ ] Security scan results

## System Recovery Procedures

### 1. Backup and Restore

1. **Database Backup:**
   ```bash
   # Backup SQLite database
   cp has_ras.db has_ras.backup.db
   
   # Or use pg_dump for PostgreSQL
   pg_dump -U username db_name > backup.sql
   ```

2. **Vector Store Backup:**
   ```bash
   # Copy ChromaDB directory
   cp -r chroma_db/ chroma_db_backup/
   
   # Or use ChromaDB export functionality
   python -c "from chromadb.utils import export; export('chroma_db', 'backup_chroma')"
   ```

3. **Configuration Backup:**
   ```bash
   # Backup environment files
   cp backend/.env backend/.env.backup
   cp frontend/.env.local frontend/.env.local.backup
   
   # Backup Kubernetes configs
   kubectl config view > k8s-config-backup.yaml
   ```

### 2. Recovery Steps

1. **Restore Database:**
   ```bash
   cp has_ras.backup.db has_ras.db
   ```

2. **Restore Vector Store:**
   ```bash
   cp -r chroma_db_backup/ chroma_db/
   ```

3. **Restore Configuration:**
   ```bash
   cp backend/.env.backup backend/.env
   cp frontend/.env.local.backup frontend/.env.local
   ```

4. **Restart Services:**
   ```bash
   make dev  # Restart all services
   ```

### 2. Disaster Recovery

#### Recovery Time Objective (RTO): 2 hours
#### Recovery Point Objective (RPO): 15 minutes

1. **Emergency Procedures:**
   - Activate backup systems
   - Redirect traffic to failover instances
   - Notify stakeholders of incident

2. **Data Restoration:**
   - Restore from most recent backup
   - Verify data integrity
   - Resume normal operations

3. **Post-Incident Review:**
   - Document incident timeline
   - Identify root cause
   - Implement preventive measures
   - Update incident response plan

## Best Practices for Users

1. **Regular Backups:** Perform regular backups of critical data
2. **Monitoring:** Check system status regularly
3. **Updates:** Keep software up to date with security patches
4. **Documentation:** Keep records of configuration changes
5. **Testing:** Test recovery procedures periodically
6. **Documentation:** Maintain clear documentation of recovery procedures
7. **Communication:** Establish clear communication channels during incidents
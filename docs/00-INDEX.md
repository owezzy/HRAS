# 📚 HRAS Documentation Hub

Welcome to the **Human Rights Advisory System (HRAS)** documentation! This AI-powered advisory system helps UN human rights officers access and analyze UHRI (UN Human Rights Index) documents through intelligent conversational interfaces.

> **Version:** 0.2.0 | **Last Updated:** January 2026

---

## 🚀 Quick Navigation

### 👨‍💻 **For Developers**
| Document | What's Inside | Best For |
|----------|---------------|----------|
| [🏗️ **Architecture**](ARCHITECTURE.md) | System design, data flow, multi-agent setup | Understanding how HRAS works |
| [⚙️ **Development**](DEVELOPMENT.md) | Setup, coding standards, workflows | Contributing to HRAS |
| [🔧 **Configuration**](CONFIGURATION.md) | Environment variables, settings | Customizing your installation |

### 🚀 **For Operators**
| Document | What's Inside | Best For |
|----------|---------------|----------|
| [📦 **Deployment**](DEPLOYMENT.md) | Local, Docker, Kubernetes deployment | Getting HRAS running |
| [📊 **Monitoring**](DEPLOYMENT.md#prometheus-monitoring-stack) | Prometheus, Grafana, alerts | Setting up observability |
| [🔍 **Troubleshooting**](TROUBLESHOOTING.md) | Common issues, debugging, recovery | Solving problems quickly |
| [🔌 **API Reference**](API.md) | REST endpoints, examples, testing | Integration and automation |

### 👥 **For End Users**
| Document | What's Inside | Best For |
|----------|---------------|----------|
| [👤 **User Guide**](USER_GUIDE.md) | How to ask questions, interpret results | Using HRAS effectively |
| [🤖 **AI/ML Pipeline**](AI_ML.md) | RAG system, embeddings, prompt engineering | Understanding AI behavior |

---

## 🎯 Start Here Based on Your Role

### **🔧 I want to run HRAS locally**
1. Check [Prerequisites](DEPLOYMENT.md#prerequisites)
2. Follow [Quick Start](DEPLOYMENT.md#local-development-setup) 
3. Run `make dev` and visit http://localhost:3000

### **🏢 I want to deploy HRAS in production**
1. Review [Kubernetes Guide](DEPLOYMENT.md#kubernetes-deployment-kind)
2. Set up [Environment Variables](CONFIGURATION.md)
3. Configure [Monitoring](TROUBLESHOOTING.md#monitoring-and-health-checks)

### **💻 I want to contribute code**
1. Read [Development Setup](DEVELOPMENT.md#development-environment-setup)
2. Study [Code Structure](DEVELOPMENT.md#code-structure)
3. Follow [Commit Conventions](DEVELOPMENT.md#commit-conventions)

### **❓ I want to use HRAS to answer questions**
1. Start with [User Guide Basics](USER_GUIDE.md#getting-started)
2. Learn [Best Practices for Questions](USER_GUIDE.md#asking-questions)
3. Understand [Response Format](USER_GUIDE.md#interpreting-results)

---

## 🛠️ Technology Stack

| Layer | Technology | Version |
|-------|------------|---------|
| **Frontend** | Next.js + React + MUI + TailwindCSS | 15.3.5 / 19.1.0 / 7.2.0 / 4.1.4 |
| **Backend** | Python + FastAPI + LangChain | 3.12+ / 0.115.0+ / 0.3.0+ |
| **AI/LLM** | Ollama + Nemotron 3 Nano (30B) | Latest |
| **Embeddings** | nomic-embed-text (via Ollama) | Latest |
| **Vector Store** | ChromaDB | 0.5.0+ |
| **Orchestration** | LangGraph (Multi-agent) | 0.2.0+ |
| **Deployment** | Docker + Kubernetes (Kind) | Latest |

---

## 💡 Key Features

- **🔍 Intelligent Document Search**: Semantic search across UN human rights documents
- **💬 Conversational AI**: Natural language Q&A with source citations  
- **🤖 Multi-Agent System**: Specialized agents for retrieval, generation, and validation
- **📊 Source Attribution**: Every answer includes document references and citations
- **⚡ Fast Deployment**: One-command deployment with automatic data ingestion
- **🔄 Real-time Updates**: Live document processing and vector store updates

---

## 🆘 Need Help?

- **🐛 Found a bug?** Check [Troubleshooting Guide](TROUBLESHOOTING.md) or create an issue
- **💡 Have a feature idea?** Review [Development Guide](DEVELOPMENT.md#contributing-guide)
- **📧 Need support?** Contact the development team

---

## 📋 Documentation Standards

All HRAS documentation follows these principles:
- **Accessibility**: Clear language for all skill levels
- **Accuracy**: Verified against current codebase (v0.2.0)
- **Actionability**: Every guide includes concrete next steps
- **Consistency**: Unified formatting and terminology throughout
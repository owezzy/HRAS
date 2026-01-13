# HRAS - Development Guide

This document provides comprehensive development guidelines for contributing to the HRAS (Human Rights Advisory System) project.

## Table of Contents

1. [Development Environment Setup](#development-environment-setup)
2. [Code Structure](#code-structure)
3. [Development Workflow](#development-workflow)
4. [Making Changes](#making-changes)
5. [Testing](#testing)
6. [Code Formatting](#code-formatting)
7. [Commit Conventions](#commit-conventions)
8. [Contributing Guide](#contributing-guide)

## Development Environment Setup

### 1. Prerequisites

- Node.js >= 22.12.0
- Python 3.12+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- [Ollama](https://ollama.com/) installed and running
- [uvx](https://docs.uvicorn.org/) for development tools

### 2. Environment Configuration

Create necessary configuration files:

```bash
# Copy environment template
cp backend/.env.example backend/.env

# Create frontend environment
touch frontend/.env.local
```

### 3. Development Commands

| Command | Description |
|---------|-------------|
| `make dev` | Run frontend + backend in dev mode |
| `make frontend-dev` | Run frontend only (Next.js with Turbopack) |
| `make backend-dev` | Run backend only (FastAPI with hot reload) |
| `make install` | Install all dependencies |
| `make lint` | Run linters (ESLint + Ruff) |
| `make test` | Run backend tests |
| `make format` | Format code |
| `make ingest` | Ingest UHRI data |
| `make db-stats` | Show vector store statistics |

## Code Structure

### 1. Project Layout

```
/HRAS
├── frontend/              # Next.js application
│   ├── src/
│   │   ├── app/           # App router pages
│   │   ├── @fuse/         # Fuse UI components
│   │   └── components/    # Reusable components
│   └── package.json
├── backend/               # FastAPI application
│   ├── src/app/
│   │   ├── api/           # API routes (thin, validation only)
│   │   ├── services/      # Business logic
│   │   ├── repositories/  # Database access layer
│   │   ├── models/        # SQLAlchemy ORM models
│   │   ├── schemas/       # Pydantic schemas
│   │   └── core/          # Config, dependencies, exceptions
│   └── pyproject.toml
├── agents/                # LangGraph agents
├── chains/                # LangChain LCEL chains
├── vectorstore/           # ChromaDB management
└── prompts/               # Prompt templates
```

### 2. Backend Layered Architecture

```
src/app/
├── api/          # REST API routes (FastAPI routers)
│   ├── __init__.py
│   └── v1/         # Version 1 of API
│       ├── __init__.py
│       └── chat.py # Chat endpoint implementation
├── core/         # Core configuration and dependencies
│   ├── __init__.py
│   ├── config.py   # Settings management
│   └── dependencies.py # Dependency injection
├── models/       # SQLAlchemy ORM models
│   ├── __init__.py
│   └── user.py     # User model definition
├── repositories/ # Data access layer
│   ├── __init__.py
│   └── user_repo.py # User repository implementation
├── schemas/      # Pydantic request/response models
│   ├── __init__.py
│   ├── base.py     # Base schema definitions
│   └── chat.py     # Chat message schema
└── services/     # Business logic layer
    ├── __init__.py
    ├── chat_service.py # Chat service implementation
    └── ingestion_service.py # Data ingestion service
```

## Development Workflow

### 1. Starting Development Servers

```bash
# Run both frontend and backend
make dev

# Or run separately:
make frontend-dev  # Terminal 1 - http://localhost:3000
make backend-dev   # Terminal 2 - http://localhost:8000
```

### 2. Making Code Changes

1. **Follow the Layered Architecture:**
   - API Routes → Validate input → Call Service
   - Service → Business Logic → Repository Call
   - Repository → Database Access

2. **Follow Naming Conventions:**
   - Services end with `Service`
   - Repositories end with `Repository`
   - Models represent database tables
   - Schemas validate input/output data

3. **Use Dependency Injection:**
   - Register dependencies in `core/dependencies.py`
   - Inject dependencies into services/functions
   - Use FastAPI's `Depends()` mechanism

### 3. Code Style

#### Python Backend Style

- **Imports:** Sorted imports (isort-compatible)
- **Line Length:** 120 characters max
- **Type Hints:** All functions must have type hints
- **Docstrings:** Follow Google style or PEP 257
- **Class Structure:**
  ```python
  class UserService:
      def __init__(self, user_repo: UserRepository):
          self.user_repo = user_repo

      async def get_user_by_id(self, user_id: str) -> Optional[User]:
          return await self.user_repo.find_by_id(user_id)
  ```

#### JavaScript/TypeScript Frontend Style

- **Prettier Configuration:**
  ```json
  {
    "tabWidth": 4,
    "useTabs": false,
    "semi": true,
    "singleQuote": true,
    "printWidth": 120,
    "trailingComma": "none",
    "jsxBracketSameLine": false
  }
  ```
- **ESLint Rules:**
  - `unused-imports/no-unused-imports`: error
  - `no-console`: error (except console.error)
  - Unused vars with `_` prefix are allowed
  - Blank lines required around functions and if statements

## Testing

### 1. Backend Testing

```bash
# Run all tests
make test

# Run specific test
pytest backend/tests/test_chat_service.py

# Run tests with coverage
pytest --cov=src tests/
```

### 2. Testing Patterns

- **Fixtures:** Use pytest fixtures for setup
- **Async Tests:** Use `pytest-asyncio` for async tests
- **Mocking:** Use `pytest-mock` for external services
- **API Tests:** Use `httpx.AsyncClient` for HTTP testing

### 3. Testing Best Practices

1. **Arrange-Act-Assert Pattern:**
   - Arrange test data and dependencies
   - Act on the function under test
   - Assert expected outcomes

2. **Edge Case Testing:**
   - Test invalid inputs
   - Test error conditions
   - Test boundary values

3. **Test Coverage:**
   - Aim for 80%+ coverage on new code
   - Focus on critical paths first
   - Test integration between components

## Code Formatting

### 1. Formatting Tools

```bash
# Format Python code
make format

# Lint Python code
make lint

# Auto-fix linting issues
make lint:fix
```

### 2. Formatting Rules

- **Python:** Black formatter with 120 line length
- **TypeScript:** Prettier with specific rules
- **Imports:** Sorted imports, no unused imports
- **Spacing:** Blank lines around functions, if statements

### 3. Pre-Commit Hooks

- Automatic formatting on commit
- Linting checks before commit
- Test execution before commit

## Commit Conventions

### 1. Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 2. Supported Types

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code formatting, no functional changes
- `refactor:` Code restructuring without functional changes
- `test:` Adding or modifying tests
- `chore:` Maintenance tasks

### 3. Example Commit Messages

```
feat(chat): implement basic conversation endpoint

- Add POST /api/v1/chat endpoint
- Integrate with LangChain RAG pipeline
- Add source citation functionality

fix(admin): resolve data ingestion memory leak

- Optimize vector store indexing
- Fix memory leak in document processing
- Add progress tracking to ingestion

docs(development): update setup guide for new contributors

- Add detailed environment setup instructions
- Include Docker configuration examples
- Add troubleshooting common issues section
```

## Contributing Guide

### 1. Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run tests and ensure they pass
5. Submit a pull request

### 2. Development Process

1. **Issue Tracking:** Use GitHub Issues for tracking work
2. **Pull Requests:** Review required from at least one maintainer
3. **CI/CD:** All tests run on push to main branch
4. **Documentation:** Update docs for any functional changes

### 3. Code Review Checklist

- [ ] Follows project conventions
- [ ] Has adequate test coverage
- [ ] Includes documentation updates
- [ ] No obvious security issues
- [ ] Performance considerations addressed
- [ ] Edge cases handled appropriately

### 4. Release Process

1. **Versioning:** Semantic versioning (MAJOR.MINOR.PATCH)
2. **Release Branches:** Created from `develop` branch
3. **Hotfixes:** Applied directly to `main` branch
4. **Release Notes:** Generated from commit messages

## Troubleshooting Common Issues

### 1. Ollama Connection Issues

- Verify Ollama is running: `ollama serve`
- Check Ollama logs: `ollama logs`
- Test model availability: `ollama list`
- Ensure correct model name in `.env`

### 2. Database Connection Problems

- Check SQLite file permissions
- Verify database URL in `.env`
- Test database connectivity: `python -c "import database; print('Connected')"`
- Check for database locks during concurrent access

### 3. Port Conflicts

- Check if ports 3000 (frontend) and 8000 (backend) are available
- Identify conflicting processes: `lsof -i :3000` or `lsof -i :8000`
- Change application ports in configuration files

### 4. Memory Issues with Large Models

- Reduce context window size in prompts
- Use smaller models for development
- Monitor memory usage with `htop` or Activity Monitor
- Consider using quantization for production deployments

### 5. Virtual Environment Activation

- Ensure you're in the correct directory
- Activate virtual environment: `source .venv/bin/activate` (Linux/Mac) or `.venv\Scripts\activate` (Windows)
- Verify Python version: `python --version`
- Check installed packages: `pip list`

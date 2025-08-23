# Docker Development Setup Documentation

## Overview

This document describes the Docker-based development environment setup for OnboardAI, including PostgreSQL with pgvector extension, pgAdmin, and a containerized Rails application.

## Architecture

The development environment consists of three main services:

1. **PostgreSQL Database** - PostgreSQL 16 with pgvector extension
2. **Rails Web Application** - Containerized Rails app with auto-reloading
3. **pgAdmin** - Web-based PostgreSQL administration interface

## Files Created/Modified

### New Files
- `Dockerfile.dev` - Development-optimized Docker image for Rails app
- `bin/docker-dev` - Startup script that handles database readiness and setup
- `docker-compose.yml` - Multi-service development environment
- `.dockerignore` - Optimizes Docker build context
- `env.example` - Sample environment configuration

### Modified Files
- `Gemfile` - Added `dotenv-rails` and `pgvector` gems
- `config/database.yml` - Updated for environment variable configuration
- `db/migrate/*_enable_vector_extension.rb` - Rails migration to enable pgvector

## Business Benefits

### Development Efficiency
- **One-command setup**: `docker-compose up -d` starts entire development environment
- **No local dependencies**: Only requires Docker, no Ruby/Node.js/PostgreSQL installation needed
- **Consistent environment**: Same setup across all developer machines
- **Hot reloading**: CSS/JS changes automatically compile via `bin/dev`

### Database Management
- **pgvector support**: Ready for AI/ML features requiring vector similarity search
- **Visual interface**: pgAdmin provides GUI for database management
- **Migration-based setup**: Vector extension enabled through Rails migrations
- **Port isolation**: PostgreSQL runs on 5433 to avoid conflicts with local installations

### DevOps Improvements
- **Volume caching**: Bundler and Node modules cached for fast rebuilds
- **Health checks**: Startup script waits for PostgreSQL readiness
- **Error handling**: Graceful failure handling in startup process
- **Development/Production separation**: Separate Dockerfiles for different environments

## Technical Implementation

### Network Architecture
- All services communicate through `onboard_ai_network` Docker network
- Internal service discovery (web → postgres:5432)
- External access via mapped ports (localhost:5433 → postgres:5432)

### Environment Variables
Development environment uses these key variables:
```
DATABASE_HOST=postgres (internal Docker hostname)
DATABASE_PORT=5432 (internal Docker port)
DATABASE_NAME=onboard_ai_development
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=password
```

### Startup Sequence
1. PostgreSQL starts with pgvector extension loaded
2. Web service waits for PostgreSQL readiness
3. Ruby gems installed (including development group)
4. Node.js dependencies installed
5. Database created and migrated
6. Rails server starts with CSS/JS compilation

### Volumes
- `postgres_data`: Persistent database storage
- `pgadmin_data`: pgAdmin configuration persistence
- `bundle_cache`: Ruby gems cache for faster rebuilds
- `node_modules`: Node.js packages cache
- `.:/app`: Live code mounting for development

## Usage Patterns

### Full Docker Development (Recommended)
```bash
docker-compose up -d          # Start all services
docker-compose logs -f web    # Monitor Rails logs
docker-compose down           # Stop all services
```

### Hybrid Development (Local Rails + Docker Database)
```bash
docker-compose up postgres pgadmin -d  # Start only database services
cp env.example .env                     # Configure environment
bundle install && yarn install         # Install dependencies locally
rails db:create db:migrate             # Setup database
bin/dev                                 # Start Rails with asset compilation
```

## Monitoring and Troubleshooting

### Service Health
- Rails app: http://localhost:3000
- pgAdmin: http://localhost:5050
- PostgreSQL: localhost:5433

### Common Issues
- **Port conflicts**: Change ports in docker-compose.yml if 3000, 5050, or 5433 are in use
- **Build failures**: Use `docker-compose build --no-cache` to rebuild from scratch
- **Database connection**: Check `docker-compose logs postgres` for database status

## Future Enhancements

### Potential Improvements
- Add Redis service for caching/background jobs
- Include Elasticsearch for full-text search
- Add monitoring tools (Prometheus/Grafana)
- Implement health check endpoints
- Add backup/restore scripts for development data

### Production Considerations
- The production `Dockerfile` remains separate and optimized
- Environment variables should be secured in production
- Consider using Docker secrets for sensitive data
- Implement proper logging and monitoring for production deployments

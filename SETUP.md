# OnboardAI Setup Guide

## Prerequisites
- Docker and Docker Compose installed

For local development (optional):
- Ruby 3.x and Rails 8.x
- Node.js and Yarn

## Setup Options

Choose one of the following setup methods:

### Option A: Full Docker Setup (Recommended)

This runs everything in containers including the Rails app.

#### 1. Build and Start All Services
```bash
# Build the development image and start all services
docker-compose up -d --build

# View logs (optional)
docker-compose logs -f web
```

**Note**: Use `--build` flag on first run or after any Gemfile/package.json changes.

The Rails app will automatically:
- Wait for PostgreSQL to be ready
- Install Ruby gems (including development gems)
- Install Node.js dependencies
- Create and migrate databases (including vector extension)
- Build CSS assets initially
- Start the server with JavaScript hot-reloading

**Note**: JavaScript changes auto-reload. For CSS changes, run `docker-compose exec web yarn build:css` to rebuild manually.

### Option B: Local Development with Dockerized Database

This runs Rails locally but uses Docker for PostgreSQL.

#### 1. Install Dependencies
```bash
bundle install
yarn install
```

#### 2. Set up Environment Variables
```bash
# Copy the example environment file and edit as needed
cp env.example .env
```

#### 3. Start Docker Services (Database only)
```bash
# Start only PostgreSQL and pgAdmin
docker-compose up postgres pgadmin -d

# Wait a few seconds for services to be ready
sleep 10
```

#### 4. Setup Database
```bash
# Create databases
rails db:create

# Run migrations (including vector extension setup)
rails db:migrate

# Seed database (optional)
rails db:seed
```

#### 5. Start Development Server
```bash
# This starts Rails server + CSS/JS compilation with watch mode
bin/dev
```

## Services

### PostgreSQL Database
- **Host**: localhost:5433 (external port, avoids conflicts)
- **Internal Host**: postgres:5432 (for Docker containers)
- **Database**: onboard_ai_development
- **Username**: postgres
- **Password**: password

### pgAdmin (Database Management)
- **URL**: http://localhost:5050
- **Email**: admin@onboardai.com
- **Password**: admin

To connect to the database in pgAdmin:
- Host: postgres (within Docker network)
- Port: 5432 (internal port)
- Database: onboard_ai_development
- Username: postgres
- Password: password

### Application
- **URL**: http://localhost:3000
- **Runs in**: Docker container (Option A) or locally (Option B)

## pgvector Setup

The PostgreSQL container includes pgvector extension which is enabled through a Rails migration (`EnableVectorExtension`). After running `rails db:migrate`, you can use vector operations in your Rails models:

```ruby
# Example model with vector support
class Document < ApplicationRecord
  has_neighbors :embedding
end

# Example usage
document = Document.create(content: "Hello world", embedding: [0.1, 0.2, 0.3])
similar_docs = Document.nearest_neighbors(:embedding, [0.1, 0.2, 0.3], distance: "cosine")
```

## Development Workflow

### Option A (Full Docker):
1. Run `docker-compose up -d --build` to start all services
2. JavaScript changes will auto-compile within the container
3. For CSS changes: `docker-compose exec web yarn build:css`
4. View logs: `docker-compose logs -f web`
5. Access app at http://localhost:3000

### Option B (Local Rails):
1. Run `docker-compose up postgres pgadmin -d` for database services
2. Run `bin/dev` to start Rails + CSS/JS compilation locally
3. CSS changes in `app/assets/stylesheets/` will auto-compile
4. JS changes in `app/javascript/` will auto-compile

### Both Options:
- Database is accessible via pgAdmin at http://localhost:5050
- PostgreSQL is available at localhost:5433

## Stopping Services

```bash
# Stop all Docker services
docker-compose down

# Stop with data cleanup (removes volumes)
docker-compose down -v

# For Option B, also stop local Rails server (Ctrl+C)
```

## Troubleshooting

### Docker Build Issues
If you encounter build issues, try:
```bash
# Rebuild without cache
docker-compose build --no-cache web

# Or rebuild everything
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### JavaScript Watch Process Stopping
If the JavaScript build process stops unexpectedly:
- The setup now uses `--watch=forever` to prevent stdin closure issues
- Check logs: `docker-compose logs -f web`
- Restart if needed: `docker-compose restart web`

### Rails Server Issues
If you see "Unrecognized command" errors:
- The container now uses `Procfile.docker` optimized for containers
- Ensures Rails server binds to `0.0.0.0` for Docker access
- Uses foreman for better process management

### Database Connection Issues
If the web service can't connect to PostgreSQL:
```bash
# Check if PostgreSQL is ready
docker-compose logs postgres

# Restart the web service
docker-compose restart web
```

### Port Conflicts
If port 5433 or 3000 is already in use:
```bash
# Check what's using the ports
lsof -i :5433
lsof -i :3000

# Stop conflicting processes or change ports in docker-compose.yml
```

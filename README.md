# OnboardAI

OnboardAI is an intelligent onboarding platform that uses AI to create personalized training courses and interactive learning experiences. The platform leverages document-based course generation, AI-powered quizzes, and vector embeddings to deliver effective employee onboarding and training programs.

## 🚀 Features

- **AI-Powered Course Generation**: Automatically generate training courses from uploaded documents using OpenAI
- **Document Processing**: Upload and process PDF, Word, and text documents with vector embeddings
- **Interactive Quizzes**: AI-generated quizzes with multiple-choice questions and instant feedback
- **Real-time Chat**: Built-in chat interface for course generation and assistance
- **Progress Tracking**: Monitor user progress through courses and modules
- **Admin Dashboard**: Comprehensive admin interface for managing courses, users, and content
- **Responsive Design**: Modern UI built with Hotwire (Turbo/Stimulus) and Tailwind CSS

## 🛠️ Technologies

- **Backend**: Ruby on Rails 8.x
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL with pgvector extension for embeddings
- **AI Integration**: OpenAI API with Azure OpenAI support
- **Background Jobs**: Rails ActiveJob
- **Containerization**: Docker and Docker Compose

## 📋 Prerequisites

- **Docker and Docker Compose** (recommended for development)
- **Ruby 3.x and Rails 8.x** (for local development)
- **Node.js and Yarn** (for asset compilation)
- **OpenAI API Key** (for AI features)

## ⚡ Quick Start

### Option 1: Full Docker Setup (Recommended)

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd OnboardAI
   ```

2. **Set up environment variables**
   ```bash
   cp env.example .env
   # Edit .env with your OpenAI API key and other configurations
   ```

3. **Start all services**
   ```bash
   docker-compose up -d --build
   ```

4. **Access the application**
   - Application: http://localhost:3000
   - pgAdmin (database): http://localhost:5050

### Option 2: Local Development with Docker Database

1. **Clone and install dependencies**
   ```bash
   git clone <repository-url>
   cd OnboardAI
   bundle install
   yarn install
   ```

2. **Set up environment variables**
   ```bash
   cp env.example .env
   # Edit .env with your configurations
   ```

3. **Start database services**
   ```bash
   docker-compose up postgres pgadmin -d
   ```

4. **Setup database**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

5. **Start development server**
   ```bash
   bin/dev
   ```

## 🔧 Configuration

### Environment Variables

Key environment variables you need to configure in your `.env` file:

```bash
# OpenAI Configuration
OPENAI_API_KEY=your-openai-api-key-here
AZURE_OPENAI_ENDPOINT=https://your-resource-name.openai.azure.com/
AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT=text-embedding-3-small

# Database Configuration (for local development)
DATABASE_HOST=localhost
DATABASE_PORT=5433
DATABASE_NAME=onboard_ai_development
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=password

# pgAdmin Configuration
PGADMIN_EMAIL=admin@onboardai.com
PGADMIN_PASSWORD=admin
```

### Services Access

- **Rails Application**: http://localhost:3000
- **pgAdmin**: http://localhost:5050 (admin@onboardai.com / admin)
- **PostgreSQL**: localhost:5433 (postgres / password)

## 📚 Documentation

For detailed setup instructions and troubleshooting, see:

- **[Setup Guide](SETUP.md)** - Comprehensive setup instructions for both Docker and local development
- **[Docker Setup](docs/docker-setup.md)** - Technical documentation for Docker environment
- **[Project Documentation](docs/)** - Additional feature documentation and guides

## 🏗️ Project Structure

```
OnboardAI/
├── app/
│   ├── controllers/        # Rails controllers
│   ├── models/            # ActiveRecord models
│   ├── views/             # ERB templates
│   ├── javascript/        # Stimulus controllers
│   ├── jobs/              # Background jobs
│   └── services/          # Service objects
├── config/                # Rails configuration
├── db/                    # Database migrations and schema
├── docs/                  # Project documentation
├── sample_documents/      # Example documents for testing
└── docker-compose.yml     # Docker development environment
```

## 🧪 Development Workflow

### Making Changes

1. **CSS Changes**: Auto-compiled with `bin/dev` or `yarn build:css` in Docker
2. **JavaScript Changes**: Auto-compiled with hot reloading
3. **Ruby Changes**: Restart Rails server as needed
4. **Database Changes**: Create migrations with `rails generate migration`

### Background Jobs

The application uses Rails ActiveJob for background processing of:
- Document processing and embedding generation
- AI course generation
- Conversation title generation

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 🆘 Support

If you encounter any issues during setup or development:

1. Check the [troubleshooting section](SETUP.md#troubleshooting) in the setup guide
2. Review the logs: `docker-compose logs -f web`
3. Open an issue on GitHub with detailed error information

## 🚀 Getting Started with OnboardAI

Once you have the application running:

1. **Upload Documents**: Go to Admin → Documents to upload training materials
2. **Generate Course**: Use the AI course generator to create courses from your documents
3. **Create Quizzes**: Generate interactive quizzes for your courses
4. **Assign Users**: Manage user assignments and track progress

Ready to transform your onboarding process with AI? Let's get started! 🎉

# Azure OpenAI Integration for Embeddings

## Overview

OnboardAI now supports **Azure OpenAI** for embedding generation while maintaining regular OpenAI compatibility for other features. This hybrid approach allows you to:

- 🔵 Use **Azure OpenAI** for embedding generation (text-embedding-3-small)
- 🟢 Use **Regular OpenAI** for chat completions and course generation
- 🔄 **Automatic fallback** when Azure is not configured

## Why Azure OpenAI for Embeddings?

### **Enterprise Benefits**
- 🏢 **Enterprise-grade security** and compliance
- 🌍 **Regional data residency** requirements
- 📊 **Better cost management** and billing controls
- 🛡️ **Private network access** and VNet integration
- 📈 **Higher rate limits** for production workloads

### **GPT-4.1 Compatibility**
- ✅ GPT-4.1 models work seamlessly with Azure OpenAI embeddings
- 🔗 Proper integration with Azure's deployment model
- 📋 Supports the latest text-embedding-3-small model

## Configuration

### Environment Variables

Add these to your `.env` file:

```env
# Regular OpenAI (for chat/completion features)
OPENAI_ACCESS_TOKEN=sk-your-openai-api-key-here
OPENAI_ORGANIZATION_ID=org-your-organization-id

# Azure OpenAI (for embeddings)
AZURE_OPENAI_ENDPOINT=https://your-resource-name.openai.azure.com/
AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT=text-embedding-3-small
OPENAI_API_KEY=your-openai-api-key-here
```

### Azure OpenAI Setup

#### **1. Create Azure OpenAI Resource**
```bash
# Using Azure CLI
az cognitiveservices account create \
  --name "your-openai-resource" \
  --resource-group "your-resource-group" \
  --location "East US" \
  --kind "OpenAI" \
  --sku "S0"
```

#### **2. Deploy Embedding Model**
1. Go to **Azure OpenAI Studio**
2. Navigate to **Deployments**
3. Create new deployment:
   - **Model**: `text-embedding-3-small`
   - **Deployment name**: `text-embedding-3-small`
   - **Version**: Latest available

#### **3. Get Configuration Values**
```bash
# Endpoint
https://your-resource-name.openai.azure.com/

# API Key (from Azure Portal > Keys and Endpoint)
your-32-character-api-key

# Deployment Name
text-embedding-3-small
```

## Technical Implementation

### **Dual Client Architecture**

```ruby
class OpenaiService
  # Regular OpenAI client for chat/completions
  def self.client
    @client ||= OpenAI::Client.new
  end

  # Azure OpenAI client specifically for embeddings
  def self.azure_embedding_client
    @azure_embedding_client ||= begin
      if ENV['AZURE_OPENAI_ENDPOINT'].present?
        ::OpenAI::Client.new(
          access_token: ENV.fetch("OPENAI_API_KEY"),
          uri_base: File.join(
            ENV.fetch("AZURE_OPENAI_ENDPOINT"),
            "openai",
            "deployments",
            ENV.fetch("AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT", "text-embedding-3-small")
          ),
          api_version: "2023-12-01-preview"
        )
      else
        # Fallback to regular OpenAI
        client
      end
    end
  end
end
```

### **Smart Embedding Generation**

```ruby
def self.generate_embedding(text)
  Rails.logger.info "Generating embedding using Azure OpenAI"

  embedding_client = azure_embedding_client

  response = embedding_client.embeddings(
    parameters: {
      model: "text-embedding-3-small",
      input: truncated_text
    }
  )

  # Process response and return embedding array
end
```

### **Configuration Detection**

The system automatically detects your configuration:

```ruby
# Priority order:
# 1. Azure OpenAI (if configured)
# 2. Regular OpenAI (fallback)
# 3. Skip with warning (if neither configured)

unless ENV['AZURE_OPENAI_ENDPOINT'].present? || ENV['OPENAI_ACCESS_TOKEN'].present?
  Rails.logger.warn "⚠️ No OpenAI configuration found"
  return
end
```

## Usage Examples

### **Configuration Scenarios**

#### **Scenario 1: Azure + Regular OpenAI (Recommended)**
```env
# Azure for embeddings
AZURE_OPENAI_ENDPOINT=https://company.openai.azure.com/
OPENAI_API_KEY=abc123...
AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT=text-embedding-3-small

# Regular OpenAI for chat
OPENAI_ACCESS_TOKEN=sk-proj-xyz...
```

#### **Scenario 2: Regular OpenAI Only**
```env
# Regular OpenAI for everything
OPENAI_ACCESS_TOKEN=sk-proj-xyz...
OPENAI_ORGANIZATION_ID=org-abc123
```

#### **Scenario 3: Azure OpenAI Only**
```env
# Azure OpenAI for embeddings (chat features limited)
AZURE_OPENAI_ENDPOINT=https://company.openai.azure.com/
OPENAI_API_KEY=abc123...
AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT=text-embedding-3-small
```

## Monitoring & Debugging

### **Log Output Examples**

#### **Azure OpenAI Success**
```
🔧 Configuring Azure OpenAI client for embeddings
   Endpoint: https://company.openai.azure.com/
   Deployment: text-embedding-3-small
Generating embedding for text (1247 characters) using Azure OpenAI
✅ Successfully generated embedding with 1536 dimensions via Azure OpenAI
```

#### **Fallback to Regular OpenAI**
```
⚠️ Azure OpenAI not configured, falling back to regular OpenAI for embeddings
   Missing: AZURE_OPENAI_ENDPOINT and/or AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT
Generating embedding using regular OpenAI client
```

#### **Configuration Missing**
```
⚠️ Neither Azure OpenAI nor regular OpenAI configured - skipping embedding generation
   Set AZURE_OPENAI_ENDPOINT + OPENAI_API_KEY for Azure OpenAI
   OR set OPENAI_ACCESS_TOKEN for regular OpenAI
```

### **HTTP Request Logging**

With httplog, you'll see detailed Azure OpenAI API calls:

```
[HTTP] POST https://company.openai.azure.com/openai/deployments/text-embedding-3-small/embeddings?api-version=2023-12-01-preview
[HTTP] Request Body: {"input":"Document content...","model":"text-embedding-3-small"}
[HTTP] Response Status: 200 OK
[HTTP] Response Body: {"object":"list","data":[{"object":"embedding","embedding":[...],"index":0}]}
[HTTP] Benchmark: 0.95s
```

## Feature Compatibility

### **What Works with Azure OpenAI**
- ✅ **Document embedding generation**
- ✅ **Semantic search across documents**
- ✅ **AI-ready document status tracking**
- ✅ **Background job processing**
- ✅ **Error handling and retries**

### **What Uses Regular OpenAI**
- 🟢 **Chat completions** (course generation, AI assistant)
- 🟢 **Task list generation**
- 🟢 **Course content creation**
- 🟢 **Interactive chat responses**

## Production Deployment

### **Azure OpenAI Best Practices**

#### **1. Resource Planning**
```bash
# Production resource configuration
az cognitiveservices account create \
  --name "prod-openai-embeddings" \
  --resource-group "prod-ai-resources" \
  --location "East US 2" \
  --kind "OpenAI" \
  --sku "S0" \
  --tags environment=production service=embeddings
```

#### **2. Network Security**
```bash
# Configure VNet integration
az cognitiveservices account network-rule add \
  --resource-group "prod-ai-resources" \
  --name "prod-openai-embeddings" \
  --vnet-resource-id "/subscriptions/.../virtualNetworks/prod-vnet" \
  --subnet "ai-services-subnet"
```

#### **3. Monitoring Setup**
```bash
# Enable diagnostic settings
az monitor diagnostic-settings create \
  --name "openai-diagnostics" \
  --resource "/subscriptions/.../cognitiveServices/prod-openai-embeddings" \
  --logs '[{"category":"Audit","enabled":true}]' \
  --workspace "/subscriptions/.../workspaces/prod-log-analytics"
```

### **Environment Configuration**

#### **Production .env**
```env
# Azure OpenAI (Primary)
AZURE_OPENAI_ENDPOINT=https://prod-openai-embeddings.openai.azure.com/
OPENAI_API_KEY=${OPENAI_API_KEY}
AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT=text-embedding-3-small

# Regular OpenAI (Fallback)
OPENAI_ACCESS_TOKEN=${OPENAI_ACCESS_TOKEN}
OPENAI_ORGANIZATION_ID=${OPENAI_ORG_ID}
```

## Cost Optimization

### **Azure OpenAI Pricing**
- **text-embedding-3-small**: ~$0.00002 per 1K tokens
- **Regional pricing** may vary
- **Volume discounts** available for enterprise

### **Cost Comparison**
```bash
# Example document processing costs:
Document Size: 10KB (~2500 tokens)
Chunks: 6 chunks × 400 tokens each = 2400 tokens

Azure OpenAI: 2.4K tokens × $0.00002 = $0.000048
Regular OpenAI: 2.4K tokens × $0.00002 = $0.000048

# Benefits: Azure provides better SLA and enterprise features
```

## Troubleshooting

### **Common Issues**

#### **1. Authentication Errors**
```
Error: 401 Unauthorized
```
**Solution**: Verify `OPENAI_API_KEY` is correct

#### **2. Deployment Not Found**
```
Error: The API deployment for this resource does not exist
```
**Solution**: Check `AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT` matches your deployment name

#### **3. Network Access Issues**
```
Error: Connection timeout
```
**Solution**: Ensure your network can reach `*.openai.azure.com`

#### **4. API Version Issues**
```
Error: Invalid API version
```
**Solution**: Update to latest supported API version in the service

### **Health Check Script**

```ruby
# Rails console health check
def check_embedding_config
  puts "🔍 Checking embedding configuration..."

  # Check environment variables
  azure_configured = ENV['AZURE_OPENAI_ENDPOINT'].present? && ENV['OPENAI_API_KEY'].present?
  openai_configured = ENV['OPENAI_ACCESS_TOKEN'].present?

  puts "📊 Configuration Status:"
  puts "   Azure OpenAI: #{azure_configured ? '✅ Configured' : '❌ Not configured'}"
  puts "   Regular OpenAI: #{openai_configured ? '✅ Configured' : '❌ Not configured'}"

  # Test embedding generation
  if azure_configured || openai_configured
    puts "🧪 Testing embedding generation..."
    embedding = OpenaiService.generate_embedding("Test embedding generation")
    puts "   Result: #{embedding ? "✅ Success (#{embedding.length} dimensions)" : '❌ Failed'}"
  else
    puts "⚠️  No OpenAI configuration found"
  end
end

# Run the check
check_embedding_config
```

## Migration Guide

### **From Regular OpenAI to Azure OpenAI**

#### **Step 1: Set up Azure OpenAI**
1. Create Azure OpenAI resource
2. Deploy `text-embedding-3-small` model
3. Get endpoint and API key

#### **Step 2: Update Environment**
```bash
# Add Azure OpenAI variables to .env
echo "AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/" >> .env
echo "OPENAI_API_KEY=your-api-key" >> .env
echo "AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT=text-embedding-3-small" >> .env
```

#### **Step 3: Test Configuration**
```bash
# Restart application
docker-compose restart web

# Test embedding generation
docker-compose exec web rails console
> OpenaiService.generate_embedding("Test")
```

#### **Step 4: Monitor Transition**
```bash
# Watch logs for Azure OpenAI usage
docker-compose logs -f web | grep "Azure OpenAI"
```

The Azure OpenAI integration provides enterprise-grade embedding generation while maintaining full compatibility with your existing OpenAI workflows! 🔵✨

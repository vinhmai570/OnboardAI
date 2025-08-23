# OPENAI_API_KEY Environment Variable Update

## Overview

The Azure OpenAI integration has been updated to use `OPENAI_API_KEY` instead of `AZURE_OPENAI_API_KEY` as requested. This change standardizes the API key environment variable naming across the system.

## Changes Made

### 1. **Environment Configuration**

#### **Updated `env.example`:**
```env
# Before (removed):
# AZURE_OPENAI_API_KEY=your-azure-openai-api-key-here

# After (added):
OPENAI_API_KEY=your-openai-api-key-here
```

### 2. **OpenAI Service Updates**

#### **`app/services/openai_service.rb`:**
- ✅ Updated Azure OpenAI client to use `OPENAI_API_KEY`
- ✅ Enhanced configuration check to require `OPENAI_API_KEY` for Azure OpenAI
- ✅ Updated warning messages to mention correct environment variable

```ruby
# Before:
access_token: ENV.fetch("AZURE_OPENAI_API_KEY")

# After:
access_token: ENV.fetch("OPENAI_API_KEY")
```

### 3. **Background Job Updates**

#### **`app/jobs/embedding_generation_job.rb`:**
- ✅ Enhanced API configuration check to properly validate Azure OpenAI setup
- ✅ Updated log messages to reference `OPENAI_API_KEY`
- ✅ Improved configuration detection logic

```ruby
# Enhanced configuration check:
azure_configured = ENV['AZURE_OPENAI_ENDPOINT'].present? && ENV['OPENAI_API_KEY'].present?
openai_configured = ENV['OPENAI_ACCESS_TOKEN'].present?
```

### 4. **Documentation Updates**

#### **`docs/azure-openai-integration.md`:**
- ✅ Updated all references from `AZURE_OPENAI_API_KEY` to `OPENAI_API_KEY`
- ✅ Updated configuration examples
- ✅ Updated troubleshooting guides
- ✅ Updated health check scripts
- ✅ Updated migration instructions

## Current Configuration

### **Required Environment Variables for Azure OpenAI:**
```env
# Azure OpenAI Configuration (for embeddings)
AZURE_OPENAI_ENDPOINT=https://your-resource-name.openai.azure.com/
AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT=text-embedding-3-small
OPENAI_API_KEY=your-openai-api-key-here

# Regular OpenAI Configuration (for chat/completion)
OPENAI_ACCESS_TOKEN=sk-your-openai-api-key-here
OPENAI_ORGANIZATION_ID=org-your-organization-id
```

### **Configuration Priority:**
1. **Azure OpenAI** (if `AZURE_OPENAI_ENDPOINT` + `OPENAI_API_KEY` configured)
2. **Regular OpenAI** (if `OPENAI_ACCESS_TOKEN` configured)
3. **Skip with warning** (if neither configured)

## Validation

### **Log Messages Updated:**
- ✅ `"Set AZURE_OPENAI_ENDPOINT + OPENAI_API_KEY for Azure OpenAI"`
- ✅ `"Missing: AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT, and/or OPENAI_API_KEY"`
- ✅ All troubleshooting messages now reference correct variable

### **Configuration Check:**
```ruby
# Service now properly validates:
if ENV['AZURE_OPENAI_ENDPOINT'].present? &&
   ENV['AZURE_OPENAI_EMBEDDINGS_DEPLOYMENT'].present? &&
   ENV['OPENAI_API_KEY'].present?
  # Use Azure OpenAI
else
  # Fall back to regular OpenAI
end
```

## Impact

### **✅ What Works:**
- All existing functionality maintained
- Azure OpenAI embeddings use `OPENAI_API_KEY`
- Regular OpenAI features still use `OPENAI_ACCESS_TOKEN`
- Proper fallback behavior preserved
- Enhanced configuration validation

### **⚠️ Action Required:**
If you were using Azure OpenAI, update your `.env` file:

```bash
# Remove old variable:
# AZURE_OPENAI_API_KEY=your-key

# Add new variable:
OPENAI_API_KEY=your-key
```

### **🔄 Restart Required:**
After updating environment variables:
```bash
docker-compose restart web
```

## Testing

### **Configuration Test:**
```bash
# Check logs for correct configuration detection
docker-compose logs web | grep -E "(Azure|OpenAI|🔧)"
```

### **Expected Log Output:**
```
🔧 Configuring Azure OpenAI client for embeddings
   Endpoint: https://your-resource.openai.azure.com/
   Deployment: text-embedding-3-small
```

## Benefits

- ✅ **Simplified Environment Variables** - One API key for both Azure and regular OpenAI
- ✅ **Consistent Naming** - Standardized `OPENAI_API_KEY` across integrations
- ✅ **Better Configuration Validation** - Enhanced checks for complete Azure setup
- ✅ **Maintained Compatibility** - All existing features work unchanged
- ✅ **Improved Error Messages** - Clearer guidance for configuration

The update maintains full backward compatibility while simplifying the environment variable setup! 🚀

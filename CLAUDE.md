# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a serverless temperature monitoring application built on AWS with Cognito authentication. The architecture consists of a single-page frontend (HTML/JS), AWS Lambda backend, and DynamoDB storage, all deployed via CloudFormation Infrastructure as Code.

## Development Commands

### Local Development
```bash
# Install dependencies for local server
npm install

# Copy environment template and configure
cp .env.example .env
# Edit .env with actual Cognito values from AWS deployment

# Start local development server (serves on http://localhost:3000)
npm start

# Alternative start commands
npm run dev    # development mode
npm run prod   # production mode
```

### AWS Deployment
```bash
# Deploy entire AWS infrastructure and Lambda functions
cd aws
./deploy.sh

# The deploy script automatically:
# - Validates AWS CLI setup
# - Packages Lambda functions with dependencies
# - Creates/updates CloudFormation stack
# - Updates Lambda function code
# - Outputs configuration values for environment setup
```

### Testing
```bash
# Test API endpoints with curl (replace URL with your deployment)
curl 'https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/sessions' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN'

# View Lambda logs for debugging
aws logs tail /aws/lambda/TemperatureMonitor-ListSessions-prod --follow
```

## Architecture

### Authentication Flow
The application uses AWS Cognito User Pools for authentication:
1. User signs up/in through frontend Cognito integration
2. Frontend receives JWT ID token from Cognito
3. All API calls include `Authorization: Bearer <jwt-token>` header
4. API Gateway validates tokens via Cognito authorizer before Lambda execution

### Configuration Management
The app uses a dual configuration approach:
- **Local Development**: Environment variables via `.env` file served through `/api/config` endpoint
- **Production**: User prompted for configuration values that are stored in browser memory only

### Data Flow
```
Frontend (HTML/JS) → API Gateway → Lambda → DynamoDB
                 ↖ Cognito User Pool (Auth)
```

### Key Components
- **Frontend**: `temperature-monitor.html` - Single HTML file with embedded CSS/JS, no build process required
- **Backend**: `/aws/lambda/` - Three Lambda functions handling different API operations
- **Infrastructure**: `/aws/cloudformation-template.yaml` - Complete AWS resource definitions
- **Local Server**: `server.js` - Secure configuration serving and CORS handling

## Important Implementation Details

### Security Architecture
- **No hardcoded secrets**: API configuration loaded at runtime via secure endpoint
- **JWT Authentication**: All API endpoints require valid Cognito ID tokens
- **CORS Configuration**: Both API Gateway and Lambda functions include CORS headers
- **Input Validation**: Server-side validation in all Lambda functions
- **TTL Data Cleanup**: DynamoDB records automatically expire after 1 year

### Error Handling Patterns
The application implements comprehensive error handling:
- **Retry Logic**: Automatic retries for network failures with exponential backoff
- **Fallback Storage**: localStorage backup when API is unavailable
- **Graceful Degradation**: Application continues to function offline with local data
- **User Feedback**: Clear error messages displayed via alert system

### DynamoDB Schema
- **Primary Key**: `sessionId` (partition) + `timestamp` (sort key)
- **GSI**: `SensorIndex` for querying by sensor name and timestamp
- **Attributes**: temperature, sensorName, rateOfRise, unit, sessionStartTime, createdAt, ttl

### Frontend State Management
- **Global Variables**: temperatureData, visibilitySettings, rateOfRiseSettings, currentUnit
- **Session Management**: currentSession, currentSessionId, sessionStartTime
- **Authentication State**: idToken, cognitoUser, COGNITO_CONFIG
- **Backup System**: Automatic localStorage backup every 30 seconds

## Debugging Common Issues

### CORS 403 Errors
When debugging CORS issues (especially on sessions endpoint):
1. Check browser console for detailed logging (enhanced debugging already implemented)
2. Verify JWT token is valid and properly formatted
3. Confirm API Gateway authorizer configuration
4. Check Lambda function CORS headers match API Gateway configuration

### Authentication Issues
- Ensure Cognito User Pool configuration matches frontend settings
- Verify JWT token is not expired (tokens have limited lifetime)
- Check that user account is confirmed in Cognito console

### Deployment Issues
- Verify AWS CLI is configured with sufficient permissions
- Check CloudFormation events in AWS console for detailed error messages
- Ensure S3 bucket for deployment artifacts exists and is accessible

## File Structure Patterns

- **Single HTML Application**: All frontend code in one file for simplicity
- **Lambda Organization**: Each function in separate file with minimal dependencies
- **Infrastructure as Code**: Complete environment defined in single CloudFormation template
- **Secure Configuration**: Environment variables isolated from code, served via secure endpoint
- **No Build Process**: Application runs directly in browser with CDN dependencies

When making changes, test locally first with `npm start`, then deploy to AWS with `./deploy.sh` to ensure the complete authentication and data flow works end-to-end.
# Temperature Monitor Security Recommendations

## Immediate Actions Required

### 1. Enable API Gateway API Keys
```bash
# Add to CloudFormation template
ApiKey:
  Type: AWS::ApiGateway::ApiKey
  Properties:
    Name: TemperatureMonitorKey
    Enabled: true

UsagePlan:
  Type: AWS::ApiGateway::UsagePlan
  Properties:
    UsagePlanName: TemperatureMonitorPlan
    Throttle:
      BurstLimit: 100
      RateLimit: 50
```

### 2. Fix CORS (Replace in all Lambda functions)
```javascript
const CORS_HEADERS = {
    'Access-Control-Allow-Origin': 'https://yourdomain.com', // Replace with actual domain
    'Access-Control-Allow-Headers': 'Content-Type,X-API-Key',
    'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
};
```

### 3. Add Input Validation
```javascript
// In store-reading.js
function validateReading(body) {
    if (!body.sessionId || body.sessionId.length > 100) {
        throw new Error('Invalid session ID');
    }
    if (!body.sensorName || body.sensorName.length > 50) {
        throw new Error('Invalid sensor name');
    }
    if (typeof body.temperature !== 'number' || 
        body.temperature < -100 || body.temperature > 200) {
        throw new Error('Invalid temperature range');
    }
    // Add timestamp validation
    const timestamp = new Date(body.timestamp);
    if (isNaN(timestamp.getTime())) {
        throw new Error('Invalid timestamp');
    }
}
```

### 4. Enable Request Logging
```javascript
// Add to each Lambda function
console.log('Request from IP:', event.requestContext.identity.sourceIp);
console.log('User Agent:', event.requestContext.identity.userAgent);
```

## Current Risk Level: HIGH
## Target Risk Level: MEDIUM (after implementing fixes)

## Compliance Considerations
- **GDPR**: No personal data handling currently
- **SOC2**: Needs access controls and monitoring
- **Healthcare**: Not suitable for medical data without encryption

## Cost Impact of Security
- API Gateway API Keys: Free
- CloudWatch Logs: ~$0.50/GB
- Rate limiting: Minimal cost
- Authentication: Depends on solution chosen
# Temperature Monitor - Serverless Application

A real-time temperature monitoring application with serverless AWS backend using DynamoDB, Lambda, and API Gateway.

## 🏗️ Architecture

- **Frontend**: HTML/JavaScript with Chart.js
- **Backend**: AWS Lambda functions
- **Database**: Amazon DynamoDB
- **API**: Amazon API Gateway
- **Security**: IAM roles and policies (no user authentication required)

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```

2. **AWS Account** with permissions to create:
   - DynamoDB tables
   - Lambda functions
   - API Gateway APIs
   - IAM roles and policies
   - CloudFormation stacks

### Deployment

1. **Clone and navigate to the project**
   ```bash
   cd /Users/marklusby/Code/testapp
   ```

2. **Deploy the AWS infrastructure**
   ```bash
   cd aws
   ./deploy.sh
   ```

3. **Update the frontend configuration**
   - Copy the API Gateway URL from the deployment output
   - Update the `API_BASE_URL` in `temperature-monitor.html` (line ~13)
   
   ```javascript
   const API_BASE_URL = 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/prod';
   ```

4. **Open the application**
   ```bash
   open ../temperature-monitor.html
   ```

## 📊 Features

### Core Functionality
- ✅ Real-time temperature reading input with timestamps
- ✅ Interactive charts with multiple sensor support
- ✅ Automatic Celsius/Fahrenheit conversion
- ✅ Rate of rise calculations
- ✅ Session-based data organization
- ✅ Data persistence in DynamoDB

### Advanced Features
- ✅ File export/import (JSON format)
- ✅ Plot visibility toggles
- ✅ Auto-save functionality
- ✅ Session management
- ✅ Offline backup to localStorage
- ✅ Error handling and retry logic

## 🔧 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/readings` | Store a temperature reading |
| GET | `/readings?sessionId=<id>` | Get all readings for a session |
| GET | `/sessions` | List all available sessions |

### API Examples

**Store a reading:**
```bash
curl -X POST https://your-api-gateway-url.amazonaws.com/prod/readings \
  -H 'Content-Type: application/json' \
  -d '{
    \"sessionId\": \"test-session\",
    \"sensorName\": \"Sensor1\",
    \"temperature\": 25.5,
    \"timestamp\": \"2024-01-01T12:00:00.000Z\"
  }'
```

**Get readings:**
```bash
curl 'https://your-api-gateway-url.amazonaws.com/prod/readings?sessionId=test-session'
```

**List sessions:**
```bash
curl 'https://your-api-gateway-url.amazonaws.com/prod/sessions'
```

## 🔒 Security Features

### Credentials Security
- **No hardcoded credentials** in the frontend code
- **IAM roles** provide secure access to AWS services
- **API Gateway** handles CORS and request validation
- **DynamoDB** access through least-privilege IAM policies

### Data Protection
- **Automatic TTL** - Data expires after 1 year
- **Condition checks** prevent duplicate readings
- **Input validation** on all API endpoints
- **Error handling** prevents information leakage

### Production Security Recommendations
1. **Configure specific CORS origins** (not `*`)
2. **Enable API Gateway throttling**
3. **Add API key authentication** if needed
4. **Use custom domain** with SSL certificate
5. **Enable CloudTrail** for audit logging

## 🗄️ Database Schema

### DynamoDB Table: `TemperatureReadings`

**Primary Key:**
- **Partition Key**: `sessionId` (String)
- **Sort Key**: `timestamp` (String)

**Attributes:**
- `sensorName` (String) - Name of the temperature sensor
- `temperature` (Number) - Temperature value in Celsius
- `rateOfRise` (Number) - Rate of temperature change per minute
- `unit` (String) - Original unit ('celsius' or 'fahrenheit')
- `sessionStartTime` (String) - ISO timestamp of session start
- `createdAt` (String) - ISO timestamp of record creation
- `ttl` (Number) - Time-to-live for automatic cleanup

**Global Secondary Index:**
- **SensorIndex**: Query by `sensorName` and `timestamp`

## 📁 Project Structure

```
testapp/
├── temperature-monitor.html      # Main application file
├── recordings/                   # Directory for saved recordings
├── aws/                         # AWS infrastructure
│   ├── cloudformation-template.yaml
│   ├── deploy.sh
│   ├── config.js
│   ├── dynamodb-table.json
│   └── lambda/
│       ├── store-reading.js
│       ├── get-readings.js
│       ├── list-sessions.js
│       └── package.json
└── README.md
```

## 🔧 Configuration

### Environment Variables (Lambda)
- `DYNAMODB_TABLE` - DynamoDB table name
- `ENVIRONMENT` - Environment name (dev/staging/prod)

### Frontend Configuration
Update these values in `temperature-monitor.html`:
- `API_BASE_URL` - Your API Gateway URL
- `CORS_ORIGIN` - Allowed origins for CORS

## 🚨 Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure API Gateway CORS is properly configured
   - Check that `Access-Control-Allow-Origin` headers are set

2. **403 Forbidden Errors**
   - Verify IAM roles have correct permissions
   - Check API Gateway resource policies

3. **DynamoDB Access Denied**
   - Ensure Lambda execution role has DynamoDB permissions
   - Verify table name in environment variables

4. **Lambda Timeout**
   - Increase Lambda timeout in CloudFormation template
   - Optimize query patterns for large datasets

### Debugging

1. **Enable CloudWatch Logs**
   ```bash
   aws logs describe-log-groups --log-group-name-prefix /aws/lambda/TemperatureMonitor
   ```

2. **View Lambda Logs**
   ```bash
   aws logs tail /aws/lambda/TemperatureMonitor-StoreReading-prod --follow
   ```

3. **Test API Endpoints**
   ```bash
   # Test with curl
   curl -v https://your-api-gateway-url.amazonaws.com/prod/sessions
   ```

## 💰 Cost Optimization

- **DynamoDB**: Pay-per-request billing
- **Lambda**: Pay-per-execution (generous free tier)
- **API Gateway**: Pay-per-API call
- **Data TTL**: Automatic cleanup reduces storage costs

Estimated monthly cost for moderate usage (1000 readings/month): **$1-5**

## 🔄 Updates and Maintenance

### Updating Lambda Functions
```bash
cd aws
./deploy.sh  # Re-runs deployment with latest code
```

### Monitoring
- **CloudWatch Metrics**: Track API calls, errors, latency
- **DynamoDB Metrics**: Monitor read/write capacity
- **Cost Explorer**: Track spending by service

## 📈 Future Enhancements

- [ ] Real-time updates with WebSockets
- [ ] Data export to S3
- [ ] Email/SMS alerts for temperature thresholds
- [ ] Mobile app using AWS Amplify
- [ ] Machine learning predictions with SageMaker
- [ ] Multi-region deployment for global access

## 📄 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

For questions or support, please check the CloudWatch logs or open an issue in the repository.
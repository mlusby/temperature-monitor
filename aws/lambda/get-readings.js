// AWS SDK v3 is included in Node.js 18.x runtime
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamoDB = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.DYNAMODB_TABLE || 'TemperatureReadings';
const CORS_HEADERS = {
    'Access-Control-Allow-Origin': process.env.CORS_ORIGIN || 'http://localhost:3000',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-API-Key',
    'Access-Control-Allow-Methods': 'OPTIONS,GET',
    'Access-Control-Allow-Credentials': 'false'
};

exports.handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers: CORS_HEADERS,
            body: ''
        };
    }
    
    try {
        const queryParams = event.queryStringParameters || {};
        const sessionId = queryParams.sessionId;
        
        if (!sessionId) {
            return {
                statusCode: 400,
                headers: CORS_HEADERS,
                body: JSON.stringify({ 
                    error: 'sessionId query parameter is required' 
                })
            };
        }
        
        // Query DynamoDB for all readings in the session
        const params = {
            TableName: TABLE_NAME,
            KeyConditionExpression: 'sessionId = :sessionId',
            ExpressionAttributeValues: {
                ':sessionId': sessionId
            },
            ScanIndexForward: true // Sort by timestamp ascending
        };
        
        const result = await dynamoDB.send(new QueryCommand(params));
        
        // Group readings by sensor name
        const groupedReadings = {};
        const sessionMetadata = {
            sessionId: sessionId,
            sessionStartTime: null,
            unit: 'celsius'
        };
        
        result.Items.forEach(item => {
            if (!groupedReadings[item.sensorName]) {
                groupedReadings[item.sensorName] = [];
            }
            
            groupedReadings[item.sensorName].push({
                timestamp: item.timestamp,
                temperature: item.temperature,
                rateOfRise: item.rateOfRise || 0
            });
            
            // Extract session metadata from first item
            if (!sessionMetadata.sessionStartTime && item.sessionStartTime) {
                sessionMetadata.sessionStartTime = item.sessionStartTime;
                sessionMetadata.unit = item.unit || 'celsius';
            }
        });
        
        const response = {
            sessionId: sessionId,
            sessionMetadata: sessionMetadata,
            temperatureData: groupedReadings,
            totalReadings: result.Items.length,
            retrievedAt: new Date().toISOString()
        };
        
        console.log(`Retrieved ${result.Items.length} readings for session ${sessionId}`);
        
        return {
            statusCode: 200,
            headers: CORS_HEADERS,
            body: JSON.stringify(response)
        };
        
    } catch (error) {
        console.error('Error retrieving readings:', error);
        
        return {
            statusCode: 500,
            headers: CORS_HEADERS,
            body: JSON.stringify({ 
                error: 'Internal server error',
                details: error.message 
            })
        };
    }
};
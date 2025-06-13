// AWS SDK v3 is included in Node.js 18.x runtime
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const dynamoDB = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.DYNAMODB_TABLE || 'TemperatureReadings-prod';
const CORS_HEADERS = {
    'Access-Control-Allow-Origin': process.env.CORS_ORIGIN || 'http://localhost:3000',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-API-Key',
    'Access-Control-Allow-Methods': 'OPTIONS,POST',
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
    
    // Simple health check
    if (event.httpMethod === 'GET') {
        return {
            statusCode: 200,
            headers: CORS_HEADERS,
            body: JSON.stringify({ 
                message: 'Store Reading Lambda is healthy',
                tableName: TABLE_NAME,
                timestamp: new Date().toISOString()
            })
        };
    }
    
    try {
        console.log('Environment DYNAMODB_TABLE:', process.env.DYNAMODB_TABLE);
        console.log('Table name:', TABLE_NAME);
        
        if (!event.body) {
            console.log('No request body provided');
            return {
                statusCode: 400,
                headers: CORS_HEADERS,
                body: JSON.stringify({ error: 'No request body provided' })
            };
        }
        
        const body = JSON.parse(event.body);
        console.log('Parsed body:', body);
        
        // Validate required fields
        if (!body.sessionId || !body.sensorName || typeof body.temperature !== 'number' || !body.timestamp) {
            return {
                statusCode: 400,
                headers: CORS_HEADERS,
                body: JSON.stringify({ 
                    error: 'Missing required fields: sessionId, sensorName, temperature, timestamp' 
                })
            };
        }
        
        // Prepare item for DynamoDB
        const item = {
            sessionId: body.sessionId,
            timestamp: body.timestamp,
            sensorName: body.sensorName,
            temperature: Number(body.temperature),
            rateOfRise: Number(body.rateOfRise || 0),
            unit: body.unit || 'celsius',
            sessionStartTime: body.sessionStartTime,
            createdAt: new Date().toISOString(),
            ttl: Math.floor(Date.now() / 1000) + (365 * 24 * 60 * 60) // 1 year TTL
        };
        
        // Store in DynamoDB
        const params = {
            TableName: TABLE_NAME,
            Item: item
        };
        
        await dynamoDB.send(new PutCommand(params));
        
        console.log('Successfully stored reading:', item);
        
        return {
            statusCode: 201,
            headers: CORS_HEADERS,
            body: JSON.stringify({ 
                message: 'Reading stored successfully',
                id: `${item.sessionId}#${item.timestamp}`
            })
        };
        
    } catch (error) {
        console.error('Error storing reading:', error);
        
        // Handle condition check failures (duplicate readings)
        if (error.code === 'ConditionalCheckFailedException') {
            return {
                statusCode: 409,
                headers: CORS_HEADERS,
                body: JSON.stringify({ 
                    error: 'Reading already exists for this timestamp' 
                })
            };
        }
        
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
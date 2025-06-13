// AWS SDK v3 is included in Node.js 18.x runtime
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, ScanCommand } = require('@aws-sdk/lib-dynamodb');

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
        // Scan for unique session IDs (with pagination support)
        const queryParams = event.queryStringParameters || {};
        const limit = parseInt(queryParams.limit) || 50;
        const lastEvaluatedKey = queryParams.lastEvaluatedKey ? 
            JSON.parse(decodeURIComponent(queryParams.lastEvaluatedKey)) : null;
        
        const params = {
            TableName: TABLE_NAME,
            ProjectionExpression: 'sessionId, sessionStartTime, sensorName, createdAt',
            Limit: limit * 10 // Over-fetch to account for duplicates
        };
        
        // Only add ExclusiveStartKey if it exists
        if (lastEvaluatedKey) {
            params.ExclusiveStartKey = lastEvaluatedKey;
        }
        
        const result = await dynamoDB.send(new ScanCommand(params));
        
        // Group by session to get unique sessions with metadata
        const sessionsMap = new Map();
        
        result.Items.forEach(item => {
            const sessionId = item.sessionId;
            
            if (!sessionsMap.has(sessionId)) {
                sessionsMap.set(sessionId, {
                    sessionId: sessionId,
                    sessionStartTime: item.sessionStartTime,
                    createdAt: item.createdAt,
                    sensors: new Set(),
                    readingCount: 0
                });
            }
            
            const session = sessionsMap.get(sessionId);
            session.sensors.add(item.sensorName);
            session.readingCount++;
            
            // Keep the earliest creation time
            if (item.createdAt < session.createdAt) {
                session.createdAt = item.createdAt;
            }
        });
        
        // Convert to array and sort by creation time (newest first)
        const sessions = Array.from(sessionsMap.values())
            .map(session => ({
                ...session,
                sensors: Array.from(session.sensors),
                sensorCount: session.sensors.length
            }))
            .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
            .slice(0, limit);
        
        const response = {
            sessions: sessions,
            totalReturned: sessions.length,
            hasMore: !!result.LastEvaluatedKey,
            lastEvaluatedKey: result.LastEvaluatedKey ? 
                encodeURIComponent(JSON.stringify(result.LastEvaluatedKey)) : null,
            retrievedAt: new Date().toISOString()
        };
        
        console.log(`Retrieved ${sessions.length} unique sessions`);
        
        return {
            statusCode: 200,
            headers: CORS_HEADERS,
            body: JSON.stringify(response)
        };
        
    } catch (error) {
        console.error('Error retrieving sessions:', error);
        
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
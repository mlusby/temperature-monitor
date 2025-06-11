#!/bin/bash

# Temperature Monitor - AWS Deployment Script
# This script deploys the serverless backend infrastructure

set -e

# Configuration
STACK_NAME="TemperatureMonitor-$(date +%m%d%H%M)"
ENVIRONMENT="prod"
REGION="us-east-1"
CORS_ORIGIN="*"  # Change to specific domain in production

echo "🚀 Deploying Temperature Monitor Backend..."
echo "Stack Name: $STACK_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

echo "✅ AWS CLI configured"
echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo "Region: $(aws configure get region)"
echo ""

# Package Lambda functions
echo "📦 Packaging Lambda functions..."
cd lambda
zip -r ../lambda-functions.zip *.js package.json
cd ..
echo "✅ Lambda functions packaged"

# Create S3 bucket for deployment artifacts (if it doesn't exist)
BUCKET_NAME="temperature-monitor-deployment-$(aws sts get-caller-identity --query Account --output text)-$REGION"
echo "📦 Creating/checking deployment bucket: $BUCKET_NAME"

if ! aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "✅ Bucket already exists"
else
    aws s3 mb "s3://$BUCKET_NAME" --region $REGION
    echo "✅ Bucket created"
fi

# Upload Lambda package
echo "⬆️  Uploading Lambda package..."
aws s3 cp lambda-functions.zip "s3://$BUCKET_NAME/lambda-functions.zip"
echo "✅ Lambda package uploaded"

# Deploy CloudFormation stack
echo "🏗️  Deploying CloudFormation stack..."

# Function to monitor stack progress
monitor_stack_progress() {
    local stack_name=$1
    local operation=$2
    local start_time=$(date +%s)
    
    echo "⏳ Monitoring stack $operation progress..."
    echo "   Stack: $stack_name"
    echo "   Started: $(date)"
    echo ""
    
    while true; do
        # Get current stack status
        STACK_STATUS=$(aws cloudformation describe-stacks \
            --stack-name $stack_name \
            --region $REGION \
            --query 'Stacks[0].StackStatus' \
            --output text 2>/dev/null)
        
        if [ $? -ne 0 ]; then
            echo "❌ Failed to get stack status"
            return 1
        fi
        
        # Calculate elapsed time
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        elapsed_min=$((elapsed / 60))
        elapsed_sec=$((elapsed % 60))
        
        # Show progress
        printf "\r⏱️  Elapsed: %02d:%02d | Status: %-35s" $elapsed_min $elapsed_sec "$STACK_STATUS"
        
        # Check for completion or failure
        case $STACK_STATUS in
            *_FAILED|*_ROLLBACK_COMPLETE)
                echo ""
                echo "❌ Stack $operation failed with status: $STACK_STATUS"
                echo ""
                echo "🔍 Recent stack events (last 10):"
                aws cloudformation describe-stack-events \
                    --stack-name $stack_name \
                    --region $REGION \
                    --query 'StackEvents[0:9].[Timestamp,LogicalResourceId,ResourceStatus,ResourceStatusReason]' \
                    --output table 2>/dev/null
                return 1
                ;;
            CREATE_COMPLETE|UPDATE_COMPLETE)
                echo ""
                echo "✅ Stack $operation completed successfully"
                return 0
                ;;
            *_IN_PROGRESS)
                # Show recent events every 30 seconds
                if [ $((elapsed % 30)) -eq 0 ] && [ $elapsed -gt 0 ]; then
                    echo ""
                    echo "📋 Recent activity:"
                    aws cloudformation describe-stack-events \
                        --stack-name $stack_name \
                        --region $REGION \
                        --query 'StackEvents[0:2].[Timestamp,LogicalResourceId,ResourceStatus]' \
                        --output table 2>/dev/null | tail -n +4
                fi
                ;;
        esac
        
        sleep 5
    done
}

# Check if stack exists and get its status
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION >/dev/null 2>&1; then
    CURRENT_STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].StackStatus' \
        --output text)
    
    echo "Stack exists with status: $CURRENT_STATUS"
    
    # Handle different stack states
    case $CURRENT_STATUS in
        *_IN_PROGRESS)
            echo "⚠️  Stack is currently in progress. Waiting for current operation to complete..."
            monitor_stack_progress $STACK_NAME "current operation"
            if [ $? -ne 0 ]; then
                echo "❌ Current operation failed. Please check AWS console for details."
                exit 1
            fi
            # After completion, try to update
            echo "Updating existing stack..."
            ;;
        *_ROLLBACK_COMPLETE)
            echo "⚠️  Stack is in rollback complete state. Deleting and recreating..."
            aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION
            echo "⏳ Waiting for stack deletion..."
            if aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $REGION; then
                echo "✅ Stack deleted successfully"
                echo "Creating new stack..."
                aws cloudformation create-stack \
                    --stack-name $STACK_NAME \
                    --template-body file://cloudformation-template.yaml \
                    --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT ParameterKey=CorsOrigin,ParameterValue="$CORS_ORIGIN" \
                    --capabilities CAPABILITY_NAMED_IAM \
                    --region $REGION
                
                if [ $? -eq 0 ]; then
                    monitor_stack_progress $STACK_NAME "creation"
                else
                    echo "❌ CloudFormation creation failed"
                    exit 1
                fi
            else
                echo "❌ Stack deletion failed"
                exit 1
            fi
            ;;
        *)
            # For normal states like CREATE_COMPLETE, UPDATE_COMPLETE, etc.
            echo "Updating existing stack..."
            ;;
    esac
    
    # Only try to update if we didn't already handle creation above
    if [[ "$CURRENT_STATUS" != *"ROLLBACK_COMPLETE"* ]]; then
        UPDATE_OUTPUT=$(aws cloudformation update-stack \
            --stack-name $STACK_NAME \
            --template-body file://cloudformation-template.yaml \
            --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT ParameterKey=CorsOrigin,ParameterValue="$CORS_ORIGIN" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region $REGION 2>&1)
        
        UPDATE_RESULT=$?
        if [ $UPDATE_RESULT -eq 0 ]; then
            monitor_stack_progress $STACK_NAME "update"
            if [ $? -ne 0 ]; then
                echo "❌ Stack update failed"
                exit 1
            fi
        elif echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
            echo "✅ No updates needed for CloudFormation stack"
        else
            echo "❌ CloudFormation update failed: $UPDATE_OUTPUT"
            exit 1
        fi
    fi
else
    # Stack doesn't exist, create it
    echo "Stack doesn't exist, creating new stack..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation-template.yaml \
        --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT ParameterKey=CorsOrigin,ParameterValue="$CORS_ORIGIN" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        monitor_stack_progress $STACK_NAME "creation"
    else
        echo "❌ CloudFormation creation failed"
        exit 1
    fi
fi

# Update Lambda function code
echo "🔄 Updating Lambda function code..."

# Get function names from CloudFormation outputs
echo "📋 Retrieving function names from stack outputs..."
STORE_FUNCTION_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`StoreReadingFunctionName`].OutputValue' \
    --output text \
    --region $REGION)

GET_FUNCTION_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`GetReadingsFunctionName`].OutputValue' \
    --output text \
    --region $REGION)

LIST_FUNCTION_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ListSessionsFunctionName`].OutputValue' \
    --output text \
    --region $REGION)

# Verify function names were retrieved
if [ -z "$STORE_FUNCTION_NAME" ] || [ "$STORE_FUNCTION_NAME" = "None" ]; then
    echo "❌ Could not retrieve StoreReadingFunctionName from stack outputs"
    exit 1
fi

if [ -z "$GET_FUNCTION_NAME" ] || [ "$GET_FUNCTION_NAME" = "None" ]; then
    echo "❌ Could not retrieve GetReadingsFunctionName from stack outputs"
    exit 1
fi

if [ -z "$LIST_FUNCTION_NAME" ] || [ "$LIST_FUNCTION_NAME" = "None" ]; then
    echo "❌ Could not retrieve ListSessionsFunctionName from stack outputs"
    exit 1
fi

echo "📋 Function names retrieved:"
echo "  Store Reading: $STORE_FUNCTION_NAME"
echo "  Get Readings: $GET_FUNCTION_NAME"
echo "  List Sessions: $LIST_FUNCTION_NAME"

# Update each Lambda function
echo "🔄 Updating StoreReading function..."
if aws lambda update-function-code \
    --function-name $STORE_FUNCTION_NAME \
    --s3-bucket $BUCKET_NAME \
    --s3-key lambda-functions.zip \
    --region $REGION >/dev/null; then
    echo "✅ StoreReading function updated"
else
    echo "❌ Failed to update StoreReading function"
    exit 1
fi

echo "🔄 Updating GetReadings function..."
if aws lambda update-function-code \
    --function-name $GET_FUNCTION_NAME \
    --s3-bucket $BUCKET_NAME \
    --s3-key lambda-functions.zip \
    --region $REGION >/dev/null; then
    echo "✅ GetReadings function updated"
else
    echo "❌ Failed to update GetReadings function"
    exit 1
fi

echo "🔄 Updating ListSessions function..."
if aws lambda update-function-code \
    --function-name $LIST_FUNCTION_NAME \
    --s3-bucket $BUCKET_NAME \
    --s3-key lambda-functions.zip \
    --region $REGION >/dev/null; then
    echo "✅ ListSessions function updated"
else
    echo "❌ Failed to update ListSessions function"
    exit 1
fi

echo "✅ All Lambda functions updated successfully"

# Get API Gateway URL and API Key
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text \
    --region $REGION)

API_KEY_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiKeyId`].OutputValue' \
    --output text \
    --region $REGION)

# Get the actual API key value
API_KEY_VALUE=$(aws apigateway get-api-key \
    --api-key $API_KEY_ID \
    --include-value \
    --query 'value' \
    --output text \
    --region $REGION)

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "====================="
echo "API Gateway URL: $API_URL"
echo "API Key ID: $API_KEY_ID"
echo "API Key Value: $API_KEY_VALUE"
echo ""
echo "Endpoints:"
echo "Store Reading: POST $API_URL/readings"
echo "Get Readings:  GET  $API_URL/readings?sessionId=<sessionId>"
echo "List Sessions: GET  $API_URL/sessions"
echo ""
echo "📝 Next Steps:"
echo "1. Copy your .env.example to .env:"
echo "   cp .env.example .env"
echo ""
echo "2. Update your .env file with these values:"
echo "   TEMPERATURE_MONITOR_API_KEY=$API_KEY_VALUE"
echo "   TEMPERATURE_MONITOR_API_URL=$API_URL"
echo ""
echo "3. Start the secure application:"
echo "   npm install && npm start"
echo ""
echo "4. Access your application at: http://localhost:3000"
echo ""
echo "🧪 Test Commands (with API key):"
echo "# Store a reading:"
echo "curl -X POST $API_URL/readings \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -H 'X-API-Key: $API_KEY_VALUE' \\"
echo "  -d '{\"sessionId\":\"test-session\",\"sensorName\":\"Sensor1\",\"temperature\":25.5,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"}'"
echo ""
echo "# Get readings:"
echo "curl -H 'X-API-Key: $API_KEY_VALUE' '$API_URL/readings?sessionId=test-session'"
echo ""
echo "# List sessions:"
echo "curl -H 'X-API-Key: $API_KEY_VALUE' '$API_URL/sessions'"

# Cleanup
rm -f lambda-functions.zip
echo ""
echo "🧹 Cleanup completed"
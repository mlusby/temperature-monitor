#!/bin/bash

# Temperature Monitor - AWS Deployment Script
# This script deploys the serverless backend infrastructure

set -e

# Configuration
STACK_NAME="TemperatureMonitor"
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

# Check if stack exists
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION >/dev/null 2>&1; then
    echo "Stack exists, updating..."
    UPDATE_OUTPUT=$(aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation-template.yaml \
        --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT ParameterKey=CorsOrigin,ParameterValue="$CORS_ORIGIN" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION 2>&1)
    
    UPDATE_RESULT=$?
    if [ $UPDATE_RESULT -eq 0 ]; then
        aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION
        echo "✅ CloudFormation stack updated successfully"
    elif echo "$UPDATE_OUTPUT" | grep -q "No updates are to be performed"; then
        echo "✅ No updates needed for CloudFormation stack"
    else
        echo "❌ CloudFormation update failed: $UPDATE_OUTPUT"
        exit 1
    fi
else
    echo "Stack doesn't exist, creating..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://cloudformation-template.yaml \
        --parameters ParameterKey=Environment,ParameterValue=$ENVIRONMENT ParameterKey=CorsOrigin,ParameterValue="$CORS_ORIGIN" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
        echo "✅ CloudFormation stack created successfully"
    else
        echo "❌ CloudFormation creation failed"
        exit 1
    fi
fi

# Update Lambda function code
echo "🔄 Updating Lambda function code..."

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

# Update each Lambda function
aws lambda update-function-code \
    --function-name $STORE_FUNCTION_NAME \
    --s3-bucket $BUCKET_NAME \
    --s3-key lambda-functions.zip \
    --region $REGION

aws lambda update-function-code \
    --function-name $GET_FUNCTION_NAME \
    --s3-bucket $BUCKET_NAME \
    --s3-key lambda-functions.zip \
    --region $REGION

aws lambda update-function-code \
    --function-name $LIST_FUNCTION_NAME \
    --s3-bucket $BUCKET_NAME \
    --s3-key lambda-functions.zip \
    --region $REGION

echo "✅ Lambda functions updated"

# Get API Gateway URL
API_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayUrl`].OutputValue' \
    --output text \
    --region $REGION)

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "====================="
echo "API Gateway URL: $API_URL"
echo "Store Reading: POST $API_URL/readings"
echo "Get Readings:  GET  $API_URL/readings?sessionId=<sessionId>"
echo "List Sessions: GET  $API_URL/sessions"
echo ""
echo "📝 Next Steps:"
echo "1. Update your frontend application with the API Gateway URL"
echo "2. Test the endpoints using curl or Postman"
echo "3. Configure your domain/CORS settings for production"
echo ""
echo "🧪 Test Commands:"
echo "# Store a reading:"
echo "curl -X POST $API_URL/readings \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"sessionId\":\"test-session\",\"sensorName\":\"Sensor1\",\"temperature\":25.5,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"}'"
echo ""
echo "# Get readings:"
echo "curl '$API_URL/readings?sessionId=test-session'"
echo ""
echo "# List sessions:"
echo "curl '$API_URL/sessions'"

# Cleanup
rm -f lambda-functions.zip
echo ""
echo "🧹 Cleanup completed"
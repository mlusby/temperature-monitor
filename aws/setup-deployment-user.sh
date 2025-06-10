#!/bin/bash

# Script to create a deployment user with minimum required permissions
# Run this script with admin privileges to set up the deployment user

set -e

USER_NAME="TemperatureMonitor-Deployer"
POLICY_NAME="TemperatureMonitor-DeploymentPolicy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔐 Setting up deployment user for Temperature Monitor..."
echo "User Name: $USER_NAME"
echo "Policy Name: $POLICY_NAME"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if user has admin privileges
if ! aws iam list-users &> /dev/null; then
    echo "❌ You need admin privileges to create IAM users and policies."
    echo "Please run this script with an admin user or ask your AWS administrator."
    exit 1
fi

echo "✅ AWS CLI configured with admin privileges"
echo ""

# Create the policy
echo "📋 Creating IAM policy..."
POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://"$SCRIPT_DIR/iam-deployment-policy.json" \
    --description "Minimum permissions for Temperature Monitor deployment" \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || \
aws iam get-policy \
    --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$POLICY_NAME" \
    --query 'Policy.Arn' \
    --output text)

echo "✅ Policy created/exists: $POLICY_ARN"

# Create the user
echo "👤 Creating IAM user..."
aws iam create-user \
    --user-name "$USER_NAME" \
    --tags Key=Purpose,Value=TemperatureMonitorDeployment Key=CreatedBy,Value=SetupScript \
    2>/dev/null || echo "ℹ️  User already exists"

echo "✅ User created/exists: $USER_NAME"

# Attach policy to user
echo "🔗 Attaching policy to user..."
aws iam attach-user-policy \
    --user-name "$USER_NAME" \
    --policy-arn "$POLICY_ARN"

echo "✅ Policy attached to user"

# Create access keys
echo "🔑 Creating access keys..."
CREDENTIALS=$(aws iam create-access-key --user-name "$USER_NAME" 2>/dev/null || echo "")

if [ -n "$CREDENTIALS" ]; then
    ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.AccessKey.AccessKeyId')
    SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.AccessKey.SecretAccessKey')
    
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "📋 Deployment User Credentials:"
    echo "================================"
    echo "User Name: $USER_NAME"
    echo "Access Key ID: $ACCESS_KEY_ID"
    echo "Secret Access Key: $SECRET_ACCESS_KEY"
    echo ""
    echo "⚠️  IMPORTANT: Save these credentials securely!"
    echo "⚠️  The secret access key will not be shown again."
    echo ""
    echo "🔧 To configure AWS CLI with these credentials:"
    echo "aws configure --profile temperature-monitor"
    echo "# Then enter the credentials above"
    echo ""
    echo "🚀 To use this profile for deployment:"
    echo "export AWS_PROFILE=temperature-monitor"
    echo "./deploy.sh"
    echo ""
else
    echo "ℹ️  User already has access keys. If you need new ones:"
    echo "1. Delete existing keys: aws iam list-access-keys --user-name $USER_NAME"
    echo "2. Delete: aws iam delete-access-key --user-name $USER_NAME --access-key-id <KEY_ID>"
    echo "3. Create new: aws iam create-access-key --user-name $USER_NAME"
fi

echo "📄 User Summary:"
echo "==============="
aws iam get-user --user-name "$USER_NAME" --query 'User.{UserName:UserName,CreateDate:CreateDate,Arn:Arn}' --output table

echo ""
echo "📋 Attached Policies:"
echo "===================="
aws iam list-attached-user-policies --user-name "$USER_NAME" --output table

echo ""
echo "✅ Deployment user setup complete!"
echo ""
echo "Next steps:"
echo "1. Configure AWS CLI with the new credentials"
echo "2. Run the deployment script: ./deploy.sh"
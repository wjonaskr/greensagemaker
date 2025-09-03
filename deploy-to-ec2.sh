#!/bin/bash

# EC2 Instance ID from the documentation
INSTANCE_ID="i-05d1c3de1532a30e7"
REGION="ap-northeast-2"
JAR_FILE="target/sagemaker-async-app-1.0.0.jar"
APP_DIR="/home/ec2-user/sagemaker-async-app"

echo "🚀 Deploying SageMaker Async App to EC2..."

# Check if JAR file exists
if [ ! -f "$JAR_FILE" ]; then
    echo "❌ JAR file not found. Building application..."
    mvn clean package -DskipTests
fi

# Copy JAR file to EC2 via S3 (temporary storage)
S3_BUCKET="greenenergy-ai-app-d-an2-s3-gem"
S3_KEY="deployments/sagemaker-async-app-1.0.0.jar"

echo "📦 Uploading JAR to S3..."
aws s3 cp $JAR_FILE s3://$S3_BUCKET/$S3_KEY --region $REGION

# Deploy via SSM
echo "🔧 Deploying to EC2 via SSM..."
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunShellScript" \
    --region $REGION \
    --parameters 'commands=[
        "sudo mkdir -p '$APP_DIR'",
        "cd '$APP_DIR'",
        "aws s3 cp s3://'$S3_BUCKET'/'$S3_KEY' . --region '$REGION'",
        "sudo pkill -f sagemaker-async-app || true",
        "sleep 2",
        "nohup java -jar sagemaker-async-app-1.0.0.jar > app.log 2>&1 &",
        "sleep 5",
        "curl -f http://localhost:8080/api/sagemaker/health || echo \"Health check failed\"",
        "echo \"✅ Deployment completed\""
    ]' \
    --output text

echo "✅ Deployment command sent to EC2 instance $INSTANCE_ID"
echo "🔍 To check status: aws ssm list-command-invocations --instance-id $INSTANCE_ID --region $REGION"
echo "🌐 Test endpoint: curl http://[EC2-PUBLIC-IP]:8080/api/sagemaker/test"

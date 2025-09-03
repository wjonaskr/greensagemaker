#!/bin/bash

# EC2 Instance ID from the documentation
INSTANCE_ID="i-05d1c3de1532a30e7"
REGION="ap-northeast-2"

echo "🔗 Connecting to EC2 instance via SSM..."
echo "Instance ID: $INSTANCE_ID"
echo "Region: $REGION"

# Start SSM session
aws ssm start-session --target $INSTANCE_ID --region $REGION

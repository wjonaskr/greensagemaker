#!/bin/bash

# Test script for SageMaker Async Endpoint
EC2_IP="[EC2-PUBLIC-IP]"  # Replace with actual EC2 public IP
PORT="8080"

echo "🧪 Testing SageMaker Async Endpoint Application"
echo "Target: http://$EC2_IP:$PORT"
echo ""

# Health Check
echo "1. Health Check:"
curl -s http://$EC2_IP:$PORT/api/sagemaker/health
echo -e "\n"

# Test Async Endpoint
echo "2. Async Endpoint Test (test-async-endpoint3):"
curl -s -X POST http://$EC2_IP:$PORT/api/sagemaker/test | jq .
echo -e "\n"

# Manual invoke test
echo "3. Manual Invoke Test:"
curl -s -X POST "http://$EC2_IP:$PORT/api/sagemaker/invoke?endpointName=test-async-endpoint3" \
  -H "Content-Type: application/json" \
  -d '{"instances": [[1.0, 2.0, 3.0, 4.0]]}' | jq .
echo -e "\n"

echo "✅ Test completed"

#!/bin/bash

# SageMaker Async Endpoint 설치 스크립트
echo "🚀 SageMaker Async Endpoint 설치를 시작합니다..."

# 환경 변수 설정
read -p "AWS 리전을 입력하세요 (예: ap-northeast-2): " AWS_REGION
read -p "S3 버킷 이름을 입력하세요 (고유한 이름): " BUCKET_NAME
read -p "AWS 계정 ID를 입력하세요: " ACCOUNT_ID

export AWS_DEFAULT_REGION=$AWS_REGION

echo "📦 AWS 리소스를 생성합니다..."

# S3 버킷 생성
echo "S3 버킷 생성 중..."
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION

# SNS 토픽 생성
echo "SNS 토픽 생성 중..."
SNS_ARN=$(aws sns create-topic --name sagemaker-async-notifications --region $AWS_REGION --query 'TopicArn' --output text)
echo "SNS 토픽 ARN: $SNS_ARN"

# SQS 큐 생성
echo "SQS 큐 생성 중..."
QUEUE_URL=$(aws sqs create-queue --queue-name sagemaker-inference-results --region $AWS_REGION --query 'QueueUrl' --output text)
QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names QueueArn --region $AWS_REGION --query 'Attributes.QueueArn' --output text)
echo "SQS 큐 URL: $QUEUE_URL"
echo "SQS 큐 ARN: $QUEUE_ARN"

# SNS-SQS 구독
echo "SNS-SQS 구독 설정 중..."
aws sns subscribe --topic-arn $SNS_ARN --protocol sqs --notification-endpoint $QUEUE_ARN --region $AWS_REGION

# SQS 정책 설정
echo "SQS 정책 설정 중..."
POLICY="{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"sns.amazonaws.com\"},\"Action\":\"sqs:SendMessage\",\"Resource\":\"$QUEUE_ARN\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"$SNS_ARN\"}}}]}"
aws sqs set-queue-attributes --queue-url $QUEUE_URL --attributes "{\"Policy\":\"$POLICY\"}" --region $AWS_REGION

echo "✅ AWS 리소스 생성 완료!"
echo ""
echo "📝 다음 값들을 애플리케이션 설정에 사용하세요:"
echo "AWS_REGION: $AWS_REGION"
echo "BUCKET_NAME: $BUCKET_NAME"
echo "SNS_TOPIC_ARN: $SNS_ARN"
echo "SQS_QUEUE_URL: $QUEUE_URL"
echo ""
echo "🔧 이제 PORTING_GUIDE.md의 5단계부터 진행하세요!"

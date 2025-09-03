#!/bin/bash

# SageMaker Async Endpoint 자동 설치 스크립트
echo "🚀 SageMaker Async Endpoint 설치를 시작합니다..."

# 환경 변수 설정
read -p "AWS 리전을 입력하세요 (예: ap-northeast-2): " AWS_REGION
read -p "프로젝트 이름을 입력하세요 (기본값: sagemaker-async-app): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-sagemaker-async-app}

export AWS_REGION=$AWS_REGION
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export BUCKET_NAME=${PROJECT_NAME}-bucket-$(date +%s)
export PROJECT_NAME=$PROJECT_NAME

echo "📋 설정 정보:"
echo "  - AWS 리전: $AWS_REGION"
echo "  - AWS 계정 ID: $AWS_ACCOUNT_ID"
echo "  - S3 버킷: $BUCKET_NAME"
echo "  - 프로젝트 이름: $PROJECT_NAME"
echo ""

read -p "계속 진행하시겠습니까? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "설치가 취소되었습니다."
    exit 1
fi

echo "📦 AWS 리소스를 생성합니다..."

# S3 버킷 생성
echo "S3 버킷 생성 중..."
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION
aws s3api put-object --bucket $BUCKET_NAME --key async-inference-input/
aws s3api put-object --bucket $BUCKET_NAME --key async-inference/output/
aws s3api put-object --bucket $BUCKET_NAME --key deployments/

# SNS 토픽 생성
echo "SNS 토픽 생성 중..."
SNS_TOPIC_ARN=$(aws sns create-topic --name ${PROJECT_NAME}-async-notifications --region $AWS_REGION --query 'TopicArn' --output text)
echo "SNS 토픽 ARN: $SNS_TOPIC_ARN"

# SQS 큐 생성
echo "SQS 큐 생성 중..."
SQS_QUEUE_URL=$(aws sqs create-queue --queue-name ${PROJECT_NAME}-inference-results --region $AWS_REGION --query 'QueueUrl' --output text)
SQS_QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url $SQS_QUEUE_URL --attribute-names QueueArn --region $AWS_REGION --query 'Attributes.QueueArn' --output text)
echo "SQS 큐 URL: $SQS_QUEUE_URL"
echo "SQS 큐 ARN: $SQS_QUEUE_ARN"

# SNS-SQS 구독
echo "SNS-SQS 구독 설정 중..."
SUBSCRIPTION_ARN=$(aws sns subscribe --topic-arn $SNS_TOPIC_ARN --protocol sqs --notification-endpoint $SQS_QUEUE_ARN --region $AWS_REGION --query 'SubscriptionArn' --output text)

# SQS 정책 설정
echo "SQS 정책 설정 중..."
POLICY="{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"sns.amazonaws.com\"},\"Action\":\"sqs:SendMessage\",\"Resource\":\"$SQS_QUEUE_ARN\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"$SNS_TOPIC_ARN\"}}}]}"
aws sqs set-queue-attributes --queue-url $SQS_QUEUE_URL --attributes "{\"Policy\":\"$POLICY\"}" --region $AWS_REGION

# IAM 역할 생성 (SageMaker용)
echo "SageMaker IAM 역할 생성 중..."
cat > sagemaker-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sagemaker.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name ${PROJECT_NAME}-sagemaker-role --assume-role-policy-document file://sagemaker-trust-policy.json 2>/dev/null || echo "역할이 이미 존재합니다."
aws iam attach-role-policy --role-name ${PROJECT_NAME}-sagemaker-role --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess 2>/dev/null

# 추가 정책 생성
cat > sagemaker-additional-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${SNS_TOPIC_ARN}"
    }
  ]
}
EOF

aws iam create-policy --policy-name ${PROJECT_NAME}-additional-policy --policy-document file://sagemaker-additional-policy.json 2>/dev/null || echo "정책이 이미 존재합니다."
aws iam attach-role-policy --role-name ${PROJECT_NAME}-sagemaker-role --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-additional-policy 2>/dev/null

# 설정 파일 생성
cat > aws-resources.env << EOF
# AWS 리소스 정보 - 애플리케이션 설정에 사용하세요
export AWS_REGION=${AWS_REGION}
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
export BUCKET_NAME=${BUCKET_NAME}
export SNS_TOPIC_ARN=${SNS_TOPIC_ARN}
export SQS_QUEUE_URL=${SQS_QUEUE_URL}
export SQS_QUEUE_ARN=${SQS_QUEUE_ARN}
export SAGEMAKER_ROLE_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-sagemaker-role
export PROJECT_NAME=${PROJECT_NAME}
EOF

# 임시 파일 정리
rm -f sagemaker-trust-policy.json sagemaker-additional-policy.json

echo "✅ AWS 리소스 생성 완료!"
echo ""
echo "📝 생성된 리소스 정보:"
echo "  - S3 버킷: $BUCKET_NAME"
echo "  - SNS 토픽: $SNS_TOPIC_ARN"
echo "  - SQS 큐: $SQS_QUEUE_URL"
echo "  - SageMaker 역할: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-sagemaker-role"
echo ""
echo "🔧 다음 단계:"
echo "1. aws-resources.env 파일의 값들을 확인하세요"
echo "2. PORTING_GUIDE.md의 5단계부터 진행하세요"
echo "3. SageMaker 모델 및 엔드포인트를 생성하세요"
echo ""
echo "💡 리소스 정리가 필요하면 다음 명령어를 실행하세요:"
echo "   source aws-resources.env && aws s3 rm s3://\$BUCKET_NAME --recursive && aws s3 rb s3://\$BUCKET_NAME"

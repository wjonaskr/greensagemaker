#!/bin/bash
# cleanup-resources.sh - 생성된 모든 AWS 리소스 삭제

# 환경 변수 로드
if [ -f "aws-resources.env" ]; then
    source aws-resources.env
else
    echo "❌ aws-resources.env 파일을 찾을 수 없습니다."
    echo "수동으로 환경 변수를 설정하거나 setup.sh를 먼저 실행하세요."
    exit 1
fi

echo "🗑️  AWS 리소스 정리를 시작합니다..."
echo "프로젝트: $PROJECT_NAME"
echo "리전: $AWS_REGION"
echo ""

read -p "정말로 모든 리소스를 삭제하시겠습니까? (y/N): " confirm
if [[ $confirm != [yY] ]]; then
    echo "정리가 취소되었습니다."
    exit 1
fi

# SageMaker 엔드포인트 삭제 (있는 경우)
echo "SageMaker 엔드포인트 확인 중..."
ENDPOINTS=$(aws sagemaker list-endpoints --query 'Endpoints[?contains(EndpointName, `async`) || contains(EndpointName, `'$PROJECT_NAME'`)].EndpointName' --output text 2>/dev/null)
for endpoint in $ENDPOINTS; do
  echo "엔드포인트 삭제 중: $endpoint"
  aws sagemaker delete-endpoint --endpoint-name $endpoint 2>/dev/null
  aws sagemaker delete-endpoint-config --endpoint-config-name $endpoint 2>/dev/null
done

# SNS 구독 삭제
echo "SNS 구독 삭제 중..."
if [ ! -z "$SNS_TOPIC_ARN" ]; then
    SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC_ARN --query 'Subscriptions[].SubscriptionArn' --output text 2>/dev/null)
    for sub in $SUBSCRIPTIONS; do
        if [ "$sub" != "None" ]; then
            aws sns unsubscribe --subscription-arn $sub 2>/dev/null
        fi
    done
    
    # SNS 토픽 삭제
    echo "SNS 토픽 삭제 중..."
    aws sns delete-topic --topic-arn $SNS_TOPIC_ARN 2>/dev/null
fi

# SQS 큐 삭제
echo "SQS 큐 삭제 중..."
if [ ! -z "$SQS_QUEUE_URL" ]; then
    aws sqs delete-queue --queue-url $SQS_QUEUE_URL 2>/dev/null
fi

# S3 버킷 비우기 및 삭제
echo "S3 버킷 정리 중..."
if [ ! -z "$BUCKET_NAME" ]; then
    aws s3 rm s3://$BUCKET_NAME --recursive 2>/dev/null
    aws s3 rb s3://$BUCKET_NAME 2>/dev/null
fi

# IAM 정책 및 역할 삭제
echo "IAM 리소스 삭제 중..."
if [ ! -z "$PROJECT_NAME" ]; then
    # SageMaker 역할 정리
    aws iam detach-role-policy --role-name ${PROJECT_NAME}-sagemaker-role --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess 2>/dev/null
    aws iam detach-role-policy --role-name ${PROJECT_NAME}-sagemaker-role --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-additional-policy 2>/dev/null
    aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-additional-policy 2>/dev/null
    aws iam delete-role --role-name ${PROJECT_NAME}-sagemaker-role 2>/dev/null
    
    # EC2 역할 정리 (있는 경우)
    aws iam remove-role-from-instance-profile --instance-profile-name ${PROJECT_NAME}-ec2-profile --role-name ${PROJECT_NAME}-ec2-role 2>/dev/null
    aws iam delete-instance-profile --instance-profile-name ${PROJECT_NAME}-ec2-profile 2>/dev/null
    aws iam detach-role-policy --role-name ${PROJECT_NAME}-ec2-role --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-ec2-app-policy 2>/dev/null
    aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-ec2-app-policy 2>/dev/null
    aws iam delete-role --role-name ${PROJECT_NAME}-ec2-role 2>/dev/null
fi

# 보안 그룹 삭제 (있는 경우)
if [ ! -z "$SECURITY_GROUP_ID" ]; then
    echo "보안 그룹 삭제 중..."
    aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID 2>/dev/null
fi

# 임시 파일 정리
echo "임시 파일 정리 중..."
rm -f *-policy.json aws-resources.env

echo "✅ 모든 리소스가 정리되었습니다!"
echo ""
echo "💡 참고: 일부 리소스는 AWS에서 완전히 삭제되는데 시간이 걸릴 수 있습니다."

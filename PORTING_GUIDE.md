# 🚀 SageMaker Async Endpoint 포팅 가이드

## 📋 개요
이 가이드는 SageMaker 비동기 추론 Spring Boot 애플리케이션을 다른 AWS 환경으로 포팅하는 방법을 설명합니다.

## 📁 프로젝트 구조
```
GreenHackerthon/
├── src/main/java/com/example/sagemaker/
│   ├── SageMakerAsyncApplication.java      # Spring Boot 메인 클래스
│   ├── SageMakerAsyncService.java          # SageMaker 비동기 추론 서비스
│   ├── SageMakerController.java            # REST API 컨트롤러
│   └── SnsNotificationService.java         # SNS/SQS 알림 처리 서비스
├── pom.xml                                 # Maven 의존성 설정
├── README.md                               # 프로젝트 설명서
├── PORTING_GUIDE.md                        # 이 문서
└── archived/                               # 이전 버전 파일들
```

## 🔧 사전 요구사항

### 1. 개발 환경
- **Java**: 17 이상
- **Maven**: 3.6 이상
- **AWS CLI**: 2.x 버전
- **Git**: 최신 버전

### 2. AWS 권한
포팅할 AWS 계정에서 다음 권한이 필요합니다:
- SageMaker 엔드포인트 호출 권한
- S3 버킷 읽기/쓰기 권한
- SNS 토픽 생성/구독 권한
- SQS 큐 생성/관리 권한
- EC2 인스턴스 관리 권한 (배포 시)

## 🛠️ 포팅 단계

### 1단계: 프로젝트 클론 및 설정

```bash
# 프로젝트 클론
git clone https://github.com/wjonaskr/greensagemaker.git
cd greensagemaker

# Java 및 Maven 버전 확인
java -version
mvn -version
```

### 2단계: AWS 환경 설정

```bash
# AWS CLI 설정
aws configure
# Access Key ID, Secret Access Key, Region, Output format 입력

# 기본 리전 설정 (예: us-east-1, ap-northeast-2 등)
export AWS_DEFAULT_REGION=your-region
```

### 3단계: AWS 리소스 생성

#### 3.1 환경 변수 설정
```bash
# 환경 변수 설정 (실제 값으로 변경)
export AWS_REGION=ap-northeast-2
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export BUCKET_NAME=your-unique-bucket-name-$(date +%s)
export PROJECT_NAME=sagemaker-async-app
```

#### 3.2 IAM 역할 생성

##### SageMaker 실행 역할
```bash
# SageMaker 실행 역할 생성
cat > sagemaker-execution-role-trust-policy.json << EOF
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

aws iam create-role \
  --role-name ${PROJECT_NAME}-sagemaker-execution-role \
  --assume-role-policy-document file://sagemaker-execution-role-trust-policy.json

# SageMaker 실행 정책 연결
aws iam attach-role-policy \
  --role-name ${PROJECT_NAME}-sagemaker-execution-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess

# S3 및 SNS 접근 정책 생성
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
      "Resource": "arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PROJECT_NAME}-async-notifications"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ${PROJECT_NAME}-sagemaker-additional-policy \
  --policy-document file://sagemaker-additional-policy.json

aws iam attach-role-policy \
  --role-name ${PROJECT_NAME}-sagemaker-execution-role \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-sagemaker-additional-policy
```

##### EC2/애플리케이션 실행 역할 (EC2 배포 시)
```bash
# EC2 신뢰 정책
cat > ec2-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name ${PROJECT_NAME}-ec2-role \
  --assume-role-policy-document file://ec2-trust-policy.json

# EC2 애플리케이션 정책
cat > ec2-app-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sagemaker:InvokeEndpointAsync",
        "sagemaker:DescribeEndpoint"
      ],
      "Resource": "arn:aws:sagemaker:${AWS_REGION}:${AWS_ACCOUNT_ID}:endpoint/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
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
        "sns:Subscribe",
        "sns:Unsubscribe",
        "sns:GetTopicAttributes"
      ],
      "Resource": "arn:aws:sns:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PROJECT_NAME}-async-notifications"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:${AWS_REGION}:${AWS_ACCOUNT_ID}:${PROJECT_NAME}-inference-results"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name ${PROJECT_NAME}-ec2-app-policy \
  --policy-document file://ec2-app-policy.json

aws iam attach-role-policy \
  --role-name ${PROJECT_NAME}-ec2-role \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-ec2-app-policy

# EC2 인스턴스 프로파일 생성
aws iam create-instance-profile --instance-profile-name ${PROJECT_NAME}-ec2-profile
aws iam add-role-to-instance-profile \
  --instance-profile-name ${PROJECT_NAME}-ec2-profile \
  --role-name ${PROJECT_NAME}-ec2-role
```

#### 3.3 S3 버킷 생성
```bash
# S3 버킷 생성
aws s3 mb s3://${BUCKET_NAME} --region ${AWS_REGION}

# 버킷 정책 설정 (SageMaker 접근 허용)
cat > s3-bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-sagemaker-execution-role"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    },
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-sagemaker-execution-role"
      },
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket ${BUCKET_NAME} \
  --policy file://s3-bucket-policy.json

# 필요한 폴더 구조 생성
aws s3api put-object --bucket ${BUCKET_NAME} --key async-inference-input/
aws s3api put-object --bucket ${BUCKET_NAME} --key async-inference/output/
aws s3api put-object --bucket ${BUCKET_NAME} --key deployments/
```

#### 3.4 SNS 토픽 생성
```bash
# SNS 토픽 생성
SNS_TOPIC_ARN=$(aws sns create-topic \
  --name ${PROJECT_NAME}-async-notifications \
  --region ${AWS_REGION} \
  --query 'TopicArn' \
  --output text)

echo "SNS Topic ARN: $SNS_TOPIC_ARN"

# SNS 토픽 정책 설정 (SageMaker가 발행할 수 있도록)
cat > sns-topic-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sagemaker.amazonaws.com"
      },
      "Action": "sns:Publish",
      "Resource": "${SNS_TOPIC_ARN}",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "${AWS_ACCOUNT_ID}"
        }
      }
    }
  ]
}
EOF

aws sns set-topic-attributes \
  --topic-arn ${SNS_TOPIC_ARN} \
  --attribute-name Policy \
  --attribute-value file://sns-topic-policy.json
```

#### 3.5 SQS 큐 생성
```bash
# SQS 큐 생성
SQS_QUEUE_URL=$(aws sqs create-queue \
  --queue-name ${PROJECT_NAME}-inference-results \
  --region ${AWS_REGION} \
  --query 'QueueUrl' \
  --output text)

# SQS 큐 ARN 가져오기
SQS_QUEUE_ARN=$(aws sqs get-queue-attributes \
  --queue-url ${SQS_QUEUE_URL} \
  --attribute-names QueueArn \
  --region ${AWS_REGION} \
  --query 'Attributes.QueueArn' \
  --output text)

echo "SQS Queue URL: $SQS_QUEUE_URL"
echo "SQS Queue ARN: $SQS_QUEUE_ARN"

# SQS 큐 정책 설정 (SNS가 메시지를 보낼 수 있도록)
cat > sqs-queue-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${SQS_QUEUE_ARN}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${SNS_TOPIC_ARN}"
        }
      }
    }
  ]
}
EOF

aws sqs set-queue-attributes \
  --queue-url ${SQS_QUEUE_URL} \
  --attributes "{\"Policy\":\"$(cat sqs-queue-policy.json | tr -d '\n' | sed 's/"/\\"/g')\"}" \
  --region ${AWS_REGION}
```

#### 3.6 SNS-SQS 구독 연결
```bash
# SNS 토픽을 SQS 큐에 구독
SUBSCRIPTION_ARN=$(aws sns subscribe \
  --topic-arn ${SNS_TOPIC_ARN} \
  --protocol sqs \
  --notification-endpoint ${SQS_QUEUE_ARN} \
  --region ${AWS_REGION} \
  --query 'SubscriptionArn' \
  --output text)

echo "Subscription ARN: $SUBSCRIPTION_ARN"
```

#### 3.7 보안 그룹 생성 (EC2 배포 시)
```bash
# 기본 VPC ID 가져오기
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)

# 보안 그룹 생성
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name ${PROJECT_NAME}-sg \
  --description "Security group for ${PROJECT_NAME}" \
  --vpc-id ${VPC_ID} \
  --query 'GroupId' \
  --output text)

# HTTP 트래픽 허용 (포트 8080)
aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port 8080 \
  --cidr 0.0.0.0/0

# SSH 접근 허용 (포트 22)
aws ec2 authorize-security-group-ingress \
  --group-id ${SECURITY_GROUP_ID} \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

echo "Security Group ID: $SECURITY_GROUP_ID"
```

#### 3.8 리소스 정보 요약
```bash
# 생성된 리소스 정보 출력
echo "=== 생성된 AWS 리소스 정보 ==="
echo "AWS Region: ${AWS_REGION}"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "SNS Topic ARN: ${SNS_TOPIC_ARN}"
echo "SQS Queue URL: ${SQS_QUEUE_URL}"
echo "SQS Queue ARN: ${SQS_QUEUE_ARN}"
echo "SageMaker Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-sagemaker-execution-role"
echo "EC2 Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-ec2-role"
echo "Security Group ID: ${SECURITY_GROUP_ID}"
echo "================================"

# 설정 파일 생성
cat > aws-resources.env << EOF
# AWS 리소스 정보
export AWS_REGION=${AWS_REGION}
export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
export BUCKET_NAME=${BUCKET_NAME}
export SNS_TOPIC_ARN=${SNS_TOPIC_ARN}
export SQS_QUEUE_URL=${SQS_QUEUE_URL}
export SQS_QUEUE_ARN=${SQS_QUEUE_ARN}
export SAGEMAKER_ROLE_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-sagemaker-execution-role
export EC2_ROLE_ARN=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${PROJECT_NAME}-ec2-role
export SECURITY_GROUP_ID=${SECURITY_GROUP_ID}
EOF

echo "리소스 정보가 aws-resources.env 파일에 저장되었습니다."
```

### 4단계: SageMaker 모델 및 엔드포인트 생성

#### 4.1 모델 생성 (예: LinearRegression)
```python
# Python 스크립트로 모델 생성 및 배포
import boto3
import sagemaker
from sagemaker.sklearn.estimator import SKLearn

# SageMaker 세션 생성
sagemaker_session = sagemaker.Session()
role = sagemaker.get_execution_role()  # 또는 직접 IAM 역할 ARN 지정

# 모델 훈련 및 배포 (예시)
# 실제 모델에 맞게 수정 필요
```

#### 4.2 비동기 엔드포인트 설정
```python
# 비동기 추론 설정
from sagemaker.async_inference import AsyncInferenceConfig

async_config = AsyncInferenceConfig(
    output_path=f"s3://your-unique-bucket-name/async-inference/output/",
    max_concurrent_invocations_per_instance=4,
    notification_config={
        "SuccessTopic": "arn:aws:sns:your-region:your-account-id:sagemaker-async-notifications",
        "ErrorTopic": "arn:aws:sns:your-region:your-account-id:sagemaker-async-notifications"
    }
)

# 엔드포인트 배포
predictor = model.deploy(
    initial_instance_count=1,
    instance_type='ml.m5.large',
    async_inference_config=async_config,
    endpoint_name='your-async-endpoint-name'
)
```

### 5단계: 애플리케이션 설정 수정

#### 5.1 SnsNotificationService.java 수정
```java
// 다음 값들을 새 환경에 맞게 수정
private final String topicArn = "arn:aws:sns:your-region:your-account-id:sagemaker-async-notifications";
private final String queueUrl = "https://sqs.your-region.amazonaws.com/your-account-id/sagemaker-inference-results";
```

#### 5.2 SageMakerAsyncService.java 수정
```java
// S3 버킷 이름 수정
private final String bucketName = "your-unique-bucket-name";

// 리전 설정 확인
.region(Region.YOUR_REGION)
```

#### 5.3 SageMakerController.java 수정
```java
// 테스트 엔드포인트 이름 수정
String endpointName = "your-async-endpoint-name";
```

### 6단계: 빌드 및 테스트

```bash
# 애플리케이션 빌드
mvn clean package

# 로컬 실행
java -jar target/sagemaker-async-app-1.0.0.jar

# 테스트
curl -X POST http://localhost:8080/api/sagemaker/test
curl -X GET http://localhost:8080/api/sagemaker/notifications/check
```

### 7단계: EC2 배포 (선택사항)

#### 7.1 EC2 인스턴스 생성
```bash
# EC2 인스턴스 생성 (Amazon Linux 2)
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --count 1 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids sg-your-security-group \
  --subnet-id subnet-your-subnet \
  --region your-region
```

#### 7.2 애플리케이션 배포
```bash
# JAR 파일을 S3에 업로드
aws s3 cp target/sagemaker-async-app-1.0.0.jar s3://your-unique-bucket-name/deployments/

# EC2에서 애플리케이션 실행
ssh -i your-key.pem ec2-user@your-ec2-ip
sudo yum update -y
sudo yum install -y java-17-amazon-corretto
aws s3 cp s3://your-unique-bucket-name/deployments/sagemaker-async-app-1.0.0.jar .
nohup java -jar sagemaker-async-app-1.0.0.jar > app.log 2>&1 &
```

## 🔍 환경별 설정 체크리스트

### ✅ 개발 환경
- [ ] Java 17+ 설치
- [ ] Maven 설치
- [ ] AWS CLI 설정
- [ ] 로컬 테스트 완료

### ✅ AWS 리소스
- [ ] S3 버킷 생성
- [ ] SNS 토픽 생성
- [ ] SQS 큐 생성
- [ ] SNS-SQS 구독 설정
- [ ] SageMaker 엔드포인트 배포

### ✅ 애플리케이션 설정
- [ ] 리전 설정 수정
- [ ] S3 버킷 이름 수정
- [ ] SNS 토픽 ARN 수정
- [ ] SQS 큐 URL 수정
- [ ] 엔드포인트 이름 수정

### ✅ 보안 설정
- [ ] IAM 역할 및 정책 설정
- [ ] 보안 그룹 설정
- [ ] VPC 설정 (필요시)

## 🧹 리소스 정리

### 전체 리소스 삭제 스크립트
```bash
#!/bin/bash
# cleanup-resources.sh - 생성된 모든 AWS 리소스 삭제

# 환경 변수 로드
source aws-resources.env

echo "🗑️  AWS 리소스 정리를 시작합니다..."

# SageMaker 엔드포인트 삭제 (있는 경우)
echo "SageMaker 엔드포인트 확인 중..."
ENDPOINTS=$(aws sagemaker list-endpoints --query 'Endpoints[?contains(EndpointName, `async`)].EndpointName' --output text)
for endpoint in $ENDPOINTS; do
  echo "엔드포인트 삭제 중: $endpoint"
  aws sagemaker delete-endpoint --endpoint-name $endpoint
  aws sagemaker delete-endpoint-config --endpoint-config-name $endpoint
done

# SNS 구독 삭제
echo "SNS 구독 삭제 중..."
SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC_ARN --query 'Subscriptions[].SubscriptionArn' --output text)
for sub in $SUBSCRIPTIONS; do
  aws sns unsubscribe --subscription-arn $sub
done

# SNS 토픽 삭제
echo "SNS 토픽 삭제 중..."
aws sns delete-topic --topic-arn $SNS_TOPIC_ARN

# SQS 큐 삭제
echo "SQS 큐 삭제 중..."
aws sqs delete-queue --queue-url $SQS_QUEUE_URL

# S3 버킷 비우기 및 삭제
echo "S3 버킷 정리 중..."
aws s3 rm s3://$BUCKET_NAME --recursive
aws s3 rb s3://$BUCKET_NAME

# IAM 정책 및 역할 삭제
echo "IAM 리소스 삭제 중..."
aws iam detach-role-policy --role-name ${PROJECT_NAME}-sagemaker-execution-role --policy-arn arn:aws:iam::aws:policy/AmazonSageMakerFullAccess
aws iam detach-role-policy --role-name ${PROJECT_NAME}-sagemaker-execution-role --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-sagemaker-additional-policy
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-sagemaker-additional-policy
aws iam delete-role --role-name ${PROJECT_NAME}-sagemaker-execution-role

aws iam remove-role-from-instance-profile --instance-profile-name ${PROJECT_NAME}-ec2-profile --role-name ${PROJECT_NAME}-ec2-role
aws iam delete-instance-profile --instance-profile-name ${PROJECT_NAME}-ec2-profile
aws iam detach-role-policy --role-name ${PROJECT_NAME}-ec2-role --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-ec2-app-policy
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${PROJECT_NAME}-ec2-app-policy
aws iam delete-role --role-name ${PROJECT_NAME}-ec2-role

# 보안 그룹 삭제
echo "보안 그룹 삭제 중..."
aws ec2 delete-security-group --group-id $SECURITY_GROUP_ID

# 임시 파일 정리
rm -f *-policy.json aws-resources.env

echo "✅ 모든 리소스가 정리되었습니다!"
```

### 개별 리소스 확인
```bash
# 생성된 리소스 상태 확인
aws s3 ls | grep $BUCKET_NAME
aws sns list-topics | grep $PROJECT_NAME
aws sqs list-queues | grep $PROJECT_NAME
aws iam list-roles | grep $PROJECT_NAME
aws ec2 describe-security-groups --group-ids $SECURITY_GROUP_ID
```

## 🆘 문제 해결

### 일반적인 오류
1. **권한 오류**: IAM 역할 및 정책 확인
2. **네트워크 오류**: 보안 그룹 및 VPC 설정 확인
3. **엔드포인트 오류**: SageMaker 엔드포인트 상태 확인
4. **SNS/SQS 오류**: 구독 설정 및 정책 확인

### 로그 확인
```bash
# 애플리케이션 로그
tail -f app.log

# AWS CloudWatch 로그
aws logs describe-log-groups --region your-region
```

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. AWS 서비스 상태 페이지
2. CloudWatch 로그
3. 애플리케이션 로그
4. AWS CLI 명령어 결과

---
**성공적인 포팅을 위해 단계별로 차근차근 진행하세요! 🎉**

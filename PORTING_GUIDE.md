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

#### 3.1 S3 버킷 생성
```bash
# 고유한 버킷 이름으로 변경
aws s3 mb s3://your-unique-bucket-name --region your-region
```

#### 3.2 SNS 토픽 생성
```bash
# SNS 토픽 생성
aws sns create-topic --name sagemaker-async-notifications --region your-region

# 토픽 ARN 확인 (출력값 기록)
aws sns list-topics --region your-region
```

#### 3.3 SQS 큐 생성
```bash
# SQS 큐 생성
aws sqs create-queue --queue-name sagemaker-inference-results --region your-region

# 큐 URL 및 ARN 확인
aws sqs get-queue-attributes --queue-url https://sqs.your-region.amazonaws.com/your-account-id/sagemaker-inference-results --attribute-names QueueArn --region your-region
```

#### 3.4 SNS-SQS 연결
```bash
# SNS 토픽을 SQS 큐에 구독
aws sns subscribe \
  --topic-arn arn:aws:sns:your-region:your-account-id:sagemaker-async-notifications \
  --protocol sqs \
  --notification-endpoint arn:aws:sqs:your-region:your-account-id:sagemaker-inference-results \
  --region your-region

# SQS 큐 정책 설정 (SNS가 메시지를 보낼 수 있도록)
aws sqs set-queue-attributes \
  --queue-url https://sqs.your-region.amazonaws.com/your-account-id/sagemaker-inference-results \
  --attributes '{
    "Policy": "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"sns.amazonaws.com\"},\"Action\":\"sqs:SendMessage\",\"Resource\":\"arn:aws:sqs:your-region:your-account-id:sagemaker-inference-results\",\"Condition\":{\"ArnEquals\":{\"aws:SourceArn\":\"arn:aws:sns:your-region:your-account-id:sagemaker-async-notifications\"}}}]}"
  }' \
  --region your-region
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

## 🚨 주의사항

1. **리전 일관성**: 모든 AWS 리소스를 동일한 리전에 생성
2. **버킷 이름**: S3 버킷 이름은 전역적으로 고유해야 함
3. **권한 설정**: 최소 권한 원칙 적용
4. **비용 관리**: 사용하지 않는 리소스는 삭제
5. **보안**: 민감한 정보는 환경변수나 AWS Secrets Manager 사용

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

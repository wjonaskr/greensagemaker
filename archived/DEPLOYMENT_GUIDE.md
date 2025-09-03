# EC2 배포 가이드

## 1. 현재 상태
✅ JAR 파일 빌드 완료: `target/sagemaker-async-app-1.0.0.jar`
✅ Endpoint 설정: `test-async-endpoint3`
✅ ARN: `arn:aws:sagemaker:ap-northeast-2:154126116352:endpoint/test-async-endpoint3`

## 2. EC2 정보
- Instance ID: `i-05d1c3de1532a30e7`
- Region: `ap-northeast-2`
- S3 Bucket: `greenenergy-ai-app-d-an2-s3-gem`

## 3. 배포 단계

### Step 1: AWS 콘솔에서 SSM 접속
1. AWS 콘솔 → EC2 → Instances
2. Instance ID: `i-05d1c3de1532a30e7` 선택
3. "Connect" → "Session Manager" → "Connect"

### Step 2: EC2에서 환경 설정
```bash
# Java 설치 확인
java -version

# 애플리케이션 디렉토리 생성
sudo mkdir -p /home/ec2-user/sagemaker-async-app
cd /home/ec2-user/sagemaker-async-app

# S3에서 JAR 파일 다운로드
aws s3 cp s3://greenenergy-ai-app-d-an2-s3-gem/deployments/sagemaker-async-app-1.0.0.jar . --region ap-northeast-2
```

### Step 3: 애플리케이션 실행
```bash
# 기존 프로세스 종료
sudo pkill -f sagemaker-async-app || true

# 애플리케이션 실행
nohup java -jar sagemaker-async-app-1.0.0.jar > app.log 2>&1 &

# 로그 확인
tail -f app.log
```

### Step 4: 테스트
```bash
# Health check
curl http://localhost:8080/api/sagemaker/health

# Async endpoint 테스트
curl -X POST http://localhost:8080/api/sagemaker/test
```

## 4. 로컬에서 S3 업로드 (수동)
```bash
# 로컬에서 실행
aws s3 cp target/sagemaker-async-app-1.0.0.jar s3://greenenergy-ai-app-d-an2-s3-gem/deployments/ --region ap-northeast-2
```

## 5. 트러블슈팅
- 포트 8080이 열려있는지 확인
- Security Group에서 8080 포트 허용 확인
- IAM Role에 SageMaker 권한 확인
- S3 접근 권한 확인

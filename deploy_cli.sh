#!/bin/bash

# 새 엔드포인트 이름 생성
TIMESTAMP=$(date +%Y%m%d%H%M%S)
ENDPOINT_NAME="test-async-endpoint-v${TIMESTAMP}"
MODEL_NAME="async-model-${TIMESTAMP}"

echo "🚀 새 엔드포인트 배포: ${ENDPOINT_NAME}"

# 모델 생성
aws sagemaker create-model \
  --model-name ${MODEL_NAME} \
  --primary-container Image=763104351884.dkr.ecr.ap-northeast-2.amazonaws.com/sklearn-inference:1.2-1-cpu-py3,ModelDataUrl=s3://greenenergy-ai-app-d-an2-s3-gem/sagemaker-models/async-20250729100023/model.tar.gz \
  --execution-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/service-role/AmazonSageMaker-ExecutionRole-20250729T100023 \
  --region ap-northeast-2

# 엔드포인트 설정 생성
aws sagemaker create-endpoint-config \
  --endpoint-config-name ${ENDPOINT_NAME}-config \
  --production-variants VariantName=AllTraffic,ModelName=${MODEL_NAME},InitialInstanceCount=1,InstanceType=ml.m5.large \
  --async-inference-config OutputConfig='{S3OutputPath=s3://greenenergy-ai-app-d-an2-s3-gem/async-inference/output/,S3FailurePath=s3://greenenergy-ai-app-d-an2-s3-gem/async-inference/error/}',ClientConfig='{MaxConcurrentInvocationsPerInstance=4}' \
  --region ap-northeast-2

# 엔드포인트 생성
aws sagemaker create-endpoint \
  --endpoint-name ${ENDPOINT_NAME} \
  --endpoint-config-name ${ENDPOINT_NAME}-config \
  --region ap-northeast-2

echo "✅ 배포 시작됨: ${ENDPOINT_NAME}"
echo "📍 상태 확인: aws sagemaker describe-endpoint --endpoint-name ${ENDPOINT_NAME} --region ap-northeast-2"

import boto3
import sagemaker
from sagemaker.model import Model
from sagemaker.async_inference import AsyncInferenceConfig
from datetime import datetime

# 설정
sagemaker_session = sagemaker.Session()
role = sagemaker.get_execution_role()
timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
endpoint_name = f"test-async-endpoint-v{timestamp}"

# 기존 모델 아티팩트 사용
model_data = "s3://greenenergy-ai-app-d-an2-s3-gem/sagemaker-models/async-20250729100023/model.tar.gz"

# 모델 생성
model = Model(
    image_uri="763104351884.dkr.ecr.ap-northeast-2.amazonaws.com/sklearn-inference:1.2-1-cpu-py3",
    model_data=model_data,
    role=role,
    sagemaker_session=sagemaker_session
)

# Async 설정
async_config = AsyncInferenceConfig(
    output_path="s3://greenenergy-ai-app-d-an2-s3-gem/async-inference/output/",
    max_concurrent_invocations_per_instance=4,
    failure_path="s3://greenenergy-ai-app-d-an2-s3-gem/async-inference/error/"
)

print(f"🚀 배포 시작: {endpoint_name}")

# 배포
predictor = model.deploy(
    initial_instance_count=1,
    instance_type="ml.m5.large",
    endpoint_name=endpoint_name,
    async_inference_config=async_config
)

print(f"✅ 배포 완료: {endpoint_name}")
print(f"📍 엔드포인트: {predictor.endpoint_name}")

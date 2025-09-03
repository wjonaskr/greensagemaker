import boto3
import json
import time

def test_new_endpoint(endpoint_name):
    runtime = boto3.client('sagemaker-runtime')
    s3 = boto3.client('s3')
    
    # 테스트 데이터
    test_data = {"instances": [[1.5, 2.5, 3.5, 4.5]]}
    input_key = f"async-inference/input/test-{int(time.time())}.json"
    
    # S3에 입력 데이터 업로드
    s3.put_object(
        Bucket="greenenergy-ai-app-d-an2-s3-gem",
        Key=input_key,
        Body=json.dumps(test_data)
    )
    
    input_location = f"s3://greenenergy-ai-app-d-an2-s3-gem/{input_key}"
    
    try:
        # Async 추론 시작
        response = runtime.invoke_endpoint_async(
            EndpointName=endpoint_name,
            ContentType='application/json',
            InputLocation=input_location
        )
        
        output_location = response['OutputLocation']
        print(f"✅ 추론 시작됨")
        print(f"📥 입력: {input_location}")
        print(f"📤 출력: {output_location}")
        
        # 결과 대기
        bucket = "greenenergy-ai-app-d-an2-s3-gem"
        output_key = output_location.split(f"s3://{bucket}/")[1]
        
        for i in range(20):
            try:
                result = s3.get_object(Bucket=bucket, Key=output_key)
                prediction = json.loads(result['Body'].read())
                print(f"🎯 결과: {prediction}")
                return prediction
            except s3.exceptions.NoSuchKey:
                print(f"⏳ 대기 중... ({i+1}/20)")
                time.sleep(15)
        
        print("❌ 타임아웃")
        return None
        
    except Exception as e:
        print(f"❌ 오류: {e}")
        return None

if __name__ == "__main__":
    # 최신 엔드포인트 이름을 여기에 입력
    endpoint_name = input("엔드포인트 이름을 입력하세요: ")
    test_new_endpoint(endpoint_name)

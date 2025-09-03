#!/bin/bash

echo "🚀 SageMaker Async 추론 테스트 시작"

# 새 추론 시작
echo "📤 추론 요청 중..."
RESULT=$(curl -s -X POST "http://15.165.190.78:8080/api/sagemaker/invoke?endpointName=test-async-endpoint2" \
  -H "Content-Type: application/json" \
  -d '{"instances": [[1.5, 2.5, 3.5, 4.5]]}')

echo "응답: $RESULT"

# outputLocation 추출
OUTPUT_LOCATION=$(echo $RESULT | grep -o 's3://[^"]*')
echo "📍 출력 위치: $OUTPUT_LOCATION"

if [ -z "$OUTPUT_LOCATION" ]; then
    echo "❌ 출력 위치를 찾을 수 없습니다"
    exit 1
fi

# 5분간 모니터링 (30초마다 체크)
echo "⏳ 결과 대기 중... (최대 5분)"
for i in {1..10}; do
    echo "체크 $i/10 ($(date '+%H:%M:%S'))"
    
    RESULT_CHECK=$(curl -s -G "http://15.165.190.78:8080/api/sagemaker/result" \
      --data-urlencode "outputLocation=$OUTPUT_LOCATION")
    
    if [[ $RESULT_CHECK == *"predictions"* ]]; then
        echo "✅ 결과 준비됨!"
        echo "$RESULT_CHECK"
        exit 0
    elif [[ $RESULT_CHECK == *"error"* ]]; then
        echo "⏳ 아직 준비 안됨..."
    else
        echo "응답: $RESULT_CHECK"
    fi
    
    sleep 30
done

echo "⏰ 타임아웃 - 추론이 완료되지 않았습니다"

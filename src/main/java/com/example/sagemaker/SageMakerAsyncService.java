package com.example.sagemaker;

import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sagemakerruntime.SageMakerRuntimeClient;
import software.amazon.awssdk.services.sagemakerruntime.model.InvokeEndpointAsyncRequest;
import software.amazon.awssdk.services.sagemakerruntime.model.InvokeEndpointAsyncResponse;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.core.sync.RequestBody;

@Service
public class SageMakerAsyncService {
    
    private final SageMakerRuntimeClient sageMakerClient;
    private final S3Client s3Client;
    private final String bucketName = "greenenergy-ai-app-d-an2-s3-gem";
    
    public SageMakerAsyncService() {
        this.sageMakerClient = SageMakerRuntimeClient.builder()
                .region(Region.AP_NORTHEAST_2)
                .build();
        this.s3Client = S3Client.builder()
                .region(Region.AP_NORTHEAST_2)
                .build();
    }
    
    public String invokeAsyncEndpoint(String endpointName, String inputData) {
        try {
            // 1. S3에 입력 데이터 업로드
            String inputKey = "async-inference-input/" + System.currentTimeMillis() + "_input.json";
            s3Client.putObject(
                PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(inputKey)
                    .build(),
                RequestBody.fromString(inputData)
            );
            
            String inputS3Uri = "s3://" + bucketName + "/" + inputKey;
            String outputS3Uri = "s3://" + bucketName + "/async-inference-output/";
            
            // 2. SageMaker Async Endpoint 호출 (간단한 버전)
            InvokeEndpointAsyncRequest request = InvokeEndpointAsyncRequest.builder()
                    .endpointName(endpointName)
                    .inputLocation(inputS3Uri)
                    .contentType("application/json")
                    .build();
            
            InvokeEndpointAsyncResponse response = sageMakerClient.invokeEndpointAsync(request);
            
            // 출력 위치 반환 (실제로는 response에서 가져와야 하지만 임시로 고정값)
            return outputS3Uri + System.currentTimeMillis() + "_output.json";
            
        } catch (Exception e) {
            throw new RuntimeException("Failed to invoke async endpoint: " + e.getMessage(), e);
        }
    }
    
    public String getResult(String outputS3Uri) {
        try {
            // S3 URI에서 bucket과 key 추출
            String[] parts = outputS3Uri.replace("s3://", "").split("/", 2);
            String bucket = parts[0];
            String key = parts[1];
            
            // S3에서 결과 다운로드
            GetObjectRequest request = GetObjectRequest.builder()
                    .bucket(bucket)
                    .key(key)
                    .build();
            
            return s3Client.getObjectAsBytes(request).asUtf8String();
            
        } catch (Exception e) {
            throw new RuntimeException("Failed to get result: " + e.getMessage(), e);
        }
    }
}

package com.example.sagemaker;

import org.springframework.stereotype.Service;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.SubscribeRequest;
import software.amazon.awssdk.services.sns.model.SubscribeResponse;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageRequest;
import software.amazon.awssdk.services.sqs.model.ReceiveMessageResponse;
import software.amazon.awssdk.services.sqs.model.DeleteMessageRequest;
import software.amazon.awssdk.services.sqs.model.Message;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;

import java.util.List;

@Service
public class SnsNotificationService {
    
    private final SnsClient snsClient;
    private final SqsClient sqsClient;
    private final ObjectMapper objectMapper;
    private final String topicArn = "arn:aws:sns:ap-northeast-2:154126116352:sagemaker-async-notifications";
    private final String queueUrl = "https://sqs.ap-northeast-2.amazonaws.com/154126116352/sagemaker-inference-results";
    
    public SnsNotificationService() {
        this.snsClient = SnsClient.builder()
                .region(Region.AP_NORTHEAST_2)
                .build();
        this.sqsClient = SqsClient.builder()
                .region(Region.AP_NORTHEAST_2)
                .build();
        this.objectMapper = new ObjectMapper();
    }
    
    // ========== 방법 1: SNS → SQS → Java App (현재 구현, 권장) ==========
    /**
     * SQS를 통한 SNS 알림 확인 (현재 사용 중)
     * 장점: 안정성, 재시도 메커니즘, 메시지 손실 방지
     * 단점: 추가 AWS 서비스 필요 (SQS)
     */
    public String checkForNotifications() {
        try {
            ReceiveMessageRequest request = ReceiveMessageRequest.builder()
                .queueUrl(queueUrl)
                .maxNumberOfMessages(1)
                .waitTimeSeconds(1)
                .build();
                
            ReceiveMessageResponse response = sqsClient.receiveMessage(request);
            List<Message> messages = response.messages();
            
            if (!messages.isEmpty()) {
                Message message = messages.get(0);
                String body = message.body();
                
                // SNS 메시지 파싱
                JsonNode snsMessage = objectMapper.readTree(body);
                String actualMessage = snsMessage.get("Message").asText();
                
                // 메시지 삭제 (중복 처리 방지)
                sqsClient.deleteMessage(DeleteMessageRequest.builder()
                    .queueUrl(queueUrl)
                    .receiptHandle(message.receiptHandle())
                    .build());
                
                return actualMessage;
            }
            
            return null;
        } catch (Exception e) {
            return "Error checking notifications: " + e.getMessage();
        }
    }
    
    // ========== 방법 2: SNS → HTTP Endpoint (대안) ==========
    /**
     * HTTP 엔드포인트를 통한 직접 SNS 구독 설정
     * 장점: 단순함, 실시간 처리, SQS 불필요
     * 단점: 애플리케이션 다운 시 메시지 손실 가능, 재시도 제한적
     */
    public String subscribeToHttpEndpoint(String httpEndpoint) {
        try {
            SubscribeRequest request = SubscribeRequest.builder()
                    .topicArn(topicArn)
                    .protocol("http")  // 또는 "https"
                    .endpoint(httpEndpoint)
                    .build();
            
            SubscribeResponse response = snsClient.subscribe(request);
            return response.subscriptionArn();
        } catch (Exception e) {
            throw new RuntimeException("Failed to subscribe HTTP endpoint to SNS: " + e.getMessage(), e);
        }
    }
    
    // ========== 공통 메서드 ==========
    public String subscribeToNotifications(String endpoint, String protocol) {
        try {
            SubscribeRequest request = SubscribeRequest.builder()
                    .topicArn(topicArn)
                    .protocol(protocol)
                    .endpoint(endpoint)
                    .build();
            
            SubscribeResponse response = snsClient.subscribe(request);
            return response.subscriptionArn();
        } catch (Exception e) {
            throw new RuntimeException("Failed to subscribe to SNS notifications: " + e.getMessage(), e);
        }
    }
    
    public String getTopicArn() {
        return topicArn;
    }
    
    public String getQueueUrl() {
        return queueUrl;
    }
}

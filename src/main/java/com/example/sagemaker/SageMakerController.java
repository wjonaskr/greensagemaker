package com.example.sagemaker;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/sagemaker")
public class SageMakerController {
    
    @Autowired
    private SageMakerAsyncService sageMakerService;
    
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("SageMaker Async Service is running");
    }
    
    @PostMapping("/invoke")
    public ResponseEntity<Map<String, String>> invokeEndpoint(
            @RequestParam String endpointName,
            @RequestBody String inputData) {
        
        try {
            String outputLocation = sageMakerService.invokeAsyncEndpoint(endpointName, inputData);
            return ResponseEntity.ok(Map.of(
                "status", "success",
                "outputLocation", outputLocation,
                "message", "Async inference started"
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "status", "error",
                "message", e.getMessage()
            ));
        }
    }
    
    @GetMapping("/result")
    public ResponseEntity<Map<String, String>> getResult(@RequestParam String outputLocation) {
        try {
            String result = sageMakerService.getResult(outputLocation);
            return ResponseEntity.ok(Map.of(
                "status", "success",
                "result", result
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "status", "error",
                "message", e.getMessage()
            ));
        }
    }
    
    @PostMapping("/test")
    public ResponseEntity<Map<String, String>> testRegression() {
        // 실제 SageMaker Async Endpoint 테스트
        String endpointName = "test-async-endpoint2";
        String testData = "{\"instances\": [[1.0, 2.0], [3.0, -1.0], [-0.5, 1.5]]}";
        
        try {
            String outputLocation = sageMakerService.invokeAsyncEndpoint(endpointName, testData);
            return ResponseEntity.ok(Map.of(
                "status", "success",
                "endpointName", endpointName,
                "testData", testData,
                "outputLocation", outputLocation,
                "message", "Async inference started successfully"
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "status", "error",
                "endpointName", endpointName,
                "message", e.getMessage()
            ));
        }
    }
    
    @PostMapping("/test-real")
    public ResponseEntity<Map<String, String>> testRealEndpoint() {
        // 실제 엔드포인트로 테스트
        String endpointName = "test-async-endpoint2";
        String testData = "{\"instances\": [[1.0, 2.0], [3.0, -1.0], [-0.5, 1.5], [2.5, 0.8], [-1.2, 3.4]]}";
        
        try {
            String outputLocation = sageMakerService.invokeAsyncEndpoint(endpointName, testData);
            return ResponseEntity.ok(Map.of(
                "status", "success",
                "endpointName", endpointName,
                "testData", testData,
                "outputLocation", outputLocation,
                "timestamp", String.valueOf(System.currentTimeMillis())
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "status", "error",
                "endpointName", endpointName,
                "message", e.getMessage(),
                "timestamp", String.valueOf(System.currentTimeMillis())
            ));
        }
    }
}

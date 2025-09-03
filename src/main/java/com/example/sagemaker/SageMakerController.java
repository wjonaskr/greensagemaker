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
        // 간단한 regression 테스트 데이터
        String testData = "{\"instances\": [[1.0, 2.0, 3.0, 4.0]]}";
        
        try {
            String outputLocation = sageMakerService.invokeAsyncEndpoint("your-endpoint-name", testData);
            return ResponseEntity.ok(Map.of(
                "status", "success",
                "testData", testData,
                "outputLocation", outputLocation
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "status", "error",
                "message", e.getMessage()
            ));
        }
    }
}

import requests
import json
import time

# 기존 Spring Boot 앱을 통해 테스트
BASE_URL = "http://15.165.190.78:8080/api/sagemaker"

def test_existing_endpoint():
    try:
        # Health check
        response = requests.get(f"{BASE_URL}/health")
        print(f"Health: {response.text}")
        
        # Test async inference
        response = requests.post(f"{BASE_URL}/test")
        result = response.json()
        print(f"Test result: {result}")
        
        if 'outputLocation' in result:
            # Wait and check result
            time.sleep(60)  # Wait 1 minute
            output_url = result['outputLocation']
            check_response = requests.get(f"{BASE_URL}/result", 
                                        params={'outputLocation': output_url})
            print(f"Final result: {check_response.text}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_existing_endpoint()

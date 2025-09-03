import boto3
import json
import time

def test_with_boto3(endpoint_name):
    """Test async inference using boto3 directly"""
    runtime = boto3.client('sagemaker-runtime')
    
    # Test data
    test_data = {"instances": [[1.0, 2.0, 3.0, 4.0]]}
    
    try:
        response = runtime.invoke_endpoint_async(
            EndpointName=endpoint_name,
            ContentType='application/json',
            InputLocation=f's3://greenenergy-ai-app-d-an2-s3-gem/async-inference/input/test-{int(time.time())}.json',
            Body=json.dumps(test_data)
        )
        
        output_location = response['OutputLocation']
        print(f"✅ Async inference started")
        print(f"📍 Output location: {output_location}")
        return output_location
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def check_result(output_location):
    """Check if result is ready in S3"""
    s3 = boto3.client('s3')
    
    # Parse S3 location
    bucket = output_location.split('/')[2]
    key = '/'.join(output_location.split('/')[3:])
    
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        result = json.loads(response['Body'].read())
        print(f"✅ Result ready: {result}")
        return result
    except s3.exceptions.NoSuchKey:
        print("⏳ Result not ready yet")
        return None
    except Exception as e:
        print(f"❌ Error checking result: {e}")
        return None

# Test the endpoint
if __name__ == "__main__":
    endpoint_name = "test-async-endpoint2"
    
    # Start async inference
    output_location = test_with_boto3(endpoint_name)
    
    if output_location:
        # Wait and check result
        print("Waiting for result...")
        for i in range(10):  # Check for up to 10 times
            time.sleep(30)  # Wait 30 seconds between checks
            result = check_result(output_location)
            if result:
                break
            print(f"Check {i+1}/10 - still waiting...")

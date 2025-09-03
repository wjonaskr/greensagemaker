# Fix for the notebook predictor issue
from sagemaker.predictor import Predictor
import sagemaker

# Create predictor for existing endpoint
sagemaker_session = sagemaker.Session()

predictor = Predictor(
    endpoint_name="test-async-endpoint2",
    sagemaker_session=sagemaker_session,
    serializer=sagemaker.serializers.JSONSerializer(),
    deserializer=sagemaker.deserializers.JSONDeserializer()
)

print("✅ Predictor created successfully")
print(f"Endpoint: {predictor.endpoint_name}")

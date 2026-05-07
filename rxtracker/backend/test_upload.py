import httpx
import json

url = "http://127.0.0.1:8000/api/prescriptions/scan"
files = {'file': ('test.jpg', open('test.jpg', 'rb'), 'image/jpeg')}

try:
    response = httpx.post(url, files=files, timeout=30.0)
    print("Status:", response.status_code)
    print("Response:", json.dumps(response.json(), indent=2))
except Exception as e:
    print("Error:", e)

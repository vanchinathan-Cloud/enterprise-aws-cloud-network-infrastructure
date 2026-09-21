# Full Walkthrough — Zero Trust Internal API

This is the detailed, console-click-by-console-click version of the build. See the main [README](./README.md) for the summarized version.

**Scenario:** an internal inventory API that must never trust a caller just because the caller is "inside" the network. Every request — even from an EC2 instance in the same VPC — has to be cryptographically signed and independently authorized before it reaches application code.

## 1. Network placement

Created a VPC with a public subnet to host the test client. This is deliberately *not* a private/isolated subnet — the point of the exercise is that network isolation isn't what's protecting the API. The IAM authorization layer is.

## 2. DynamoDB — the data being protected

**DynamoDB → Tables → Create table**
- Table name: `InternalInventory`
- Partition key: `item_id` (String)
- Table settings: Default

Added a test item via **Explore table items → Create item**:
- `item_id`: `gadget_001`
- `status`: `Top Secret`

## 3. IAM — two roles, two trust boundaries

**Role 1 — `iam_role_zero_trust_lambda`**
- Trusted entity: AWS service → Lambda
- Attached policies: `AmazonDynamoDBReadOnlyAccess`, `AWSLambdaBasicExecutionRole`

**Role 2 — `iam_role_zero_trust_ec2_client`**
- Trusted entity: AWS service → EC2
- Scoped to allow only what's needed to call the API (not broad EC2 permissions)

These are separate roles with separate trust policies on purpose — the Lambda role has no reason to trust EC2, and the EC2 client role has no reason to touch DynamoDB directly. Verified both roles' trust relationships tab shows the correct service principal before moving on.

## 4. Lambda — the request handler

Created a Lambda function attached to `iam_role_zero_trust_lambda`, with handler code that:
1. Receives the API Gateway event
2. Scans/queries `InternalInventory`
3. Returns the result as a JSON body with a `data` key

## 5. API Gateway — the enforcement point

**API Gateway → Create API → REST API**
- Name: `InternalSecureAPI`
- Created a resource/method (`GET /inventory`) integrated with the Lambda function
- **Method Request → Authorization: AWS_IAM** — this is the actual Zero Trust enforcement point. Without a valid SigV4 signature tied to an authorized IAM identity, API Gateway rejects the request before Lambda ever executes.
- Deployed to a `prod` stage, copied the Invoke URL (`https://<api-id>.execute-api.us-east-1.amazonaws.com/prod`)

## 6. EC2 — the test client

Launched an EC2 instance (`ZeroTrust-Client`) in the public subnet:
- Attached `iam_role_zero_trust_ec2_client` as the instance profile — no access keys stored anywhere on the box
- Connected via EC2 Instance Connect (no SSH key needed for this step)

## 7. Writing and running the SigV4-signed test

Installed dependencies:
```bash
sudo yum update -y
sudo yum install -y python3 python3-pip
pip3 install boto3 requests
```

Wrote a test script that manually signs the request using the instance's assumed-role credentials — this is the part that makes it a genuine Zero Trust test rather than just an API key check:

```python
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import json

API_URL = "https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/inventory"

session = boto3.Session()
credentials = session.get_credentials()
region = 'us-east-1'
service = 'execute-api'

request = AWSRequest(method='GET', url=API_URL)
SigV4Auth(credentials, service, region).add_auth(request)

response = requests.get(API_URL, headers=dict(request.headers))

print(f"Status Code: {response.status_code}")
print(f"Response: {response.text}")

if response.status_code == 200:
    data = response.json()
    if 'data' in data and len(data['data']) > 0:
        print("\n✅ ZERO TRUST API TEST PASSED!")
        print(f"Found {len(data['data'])} items in inventory")
    else:
        print("\n❌ No items found in inventory")
else:
    print(f"\n❌ API call failed with status {response.status_code}")
```

Ran it:
```bash
python3 test_zero_trust_api.py
```

Result: `Status Code: 200` with the inventory data returned, confirming the full chain — EC2 assumed-role credentials → SigV4 signature → API Gateway IAM check → Lambda → DynamoDB → response — worked end to end.

## What proves this is Zero Trust, not just "an API with a role attached"

The meaningful test isn't that the signed request succeeded — it's that an **unsigned** request to the same URL (e.g., from a browser, or `curl` without SigV4 headers) gets rejected by API Gateway before Lambda even runs. Being on the same network, in the same account, or hitting the same URL grants nothing. Only a valid signature tied to an authorized role does.

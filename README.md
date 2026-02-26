# Asset Monitoring Platform

Serverless IoT platform for real-time asset health monitoring and predictive maintenance built with Terraform.

## 🏗️ Architecture

```
IoT Devices (MQTT) → AWS IoT Core → IoT Rule → SQS → Lambda → S3 + DynamoDB
                                                                      ↓
                                                          API Gateway → Lambda → DynamoDB
```

## 📊 Deployed Infrastructure

### Phase 1: Read API

**API Gateway HTTP API**
- Endpoint: `GET /assets/{asset_id}/health`
- Returns latest device telemetry and status

**Lambda Function: get_asset_health**
- Runtime: Python 3.11
- Memory: 256 MB
- Timeout: 10 seconds
- Permissions: DynamoDB read (latest_readings)

**DynamoDB Table: latest_readings**
- Partition Key: `asset_id` (String)
- Billing: Pay-per-request
- Encryption: Server-side (AES-256)

---

### Phase 2: Ingestion Pipeline

**AWS IoT Core**
- MQTT endpoint for device connections
- mTLS authentication required
- Topic pattern: `telemetry/#`

**IoT Rule: telemetry_rule**
- SQL: `SELECT * FROM 'telemetry/#'`
- Action: Route to SQS

**SQS Queue: telemetry_queue**
- Batch size: 100 messages
- Batching window: 5 seconds
- Dead Letter Queue: Enabled (4-day retention)

**Lambda Function: process_telemetry**
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 60 seconds
- Batch processing: 100 messages per invocation
- Permissions: SQS read/delete, S3 write, DynamoDB write

**S3 Bucket: raw-telemetry**
- Compressed archive (gzip)
- Partitioned: `raw/iot/year=/month=/day=/hour=/`
- Lifecycle: 90 days → Glacier, 365 days → Delete
- Encryption: AES-256
- Versioning: Enabled

**DynamoDB Tables**
- `latest_readings`: Current device state
- `alerts`: Historical alert records (temp ≥ 80°C or vib ≥ 3.0 Hz)

---

### Phase 3: IoT Devices

**IoT Thing Type: motor**
- Description: Industrial motor sensors
- Searchable attributes: manufacturer, model, location

**IoT Things**
- `asset-monitoring-platform-device-1-dev`
- `asset-monitoring-platform-device-2-dev`
- `asset-monitoring-platform-device-3-dev`

**IoT Policy: device-policy**
- Connect: Allowed for `asset-monitoring-platform-*` clients
- Publish: Allowed to `telemetry/*` topics
- Subscribe/Receive: Allowed on `telemetry/*` topics

**Device Certificates**
- ⚠️ **Not managed by Terraform** (security best practice)
- Managed manually via AWS Console or CLI
- X.509 certificates with mTLS authentication

---

## 🛠️ Technology Stack

- **IaC**: Terraform 1.10+
- **Cloud**: AWS (us-west-2)
- **Compute**: AWS Lambda (Python 3.11)
- **API**: API Gateway HTTP API
- **Database**: DynamoDB (Pay-per-request)
- **Storage**: S3 (Standard + Glacier)
- **Messaging**: SQS
- **IoT**: AWS IoT Core

## 🚀 Deployment

### Prerequisites

- AWS CLI configured with credentials
- Terraform 1.10+
- AWS account with appropriate permissions
- Default region set to `us-west-2`

```bash
# Configure AWS CLI default region
aws configure set region us-west-2

# Verify configuration
aws configure list
```

---

### Step 1: Bootstrap Terraform Backend

```bash
# Navigate to bootstrap directory
cd bootstrap

# Initialize and apply
terraform init
terraform apply

# Note the backend bucket name
terraform output state_bucket_name

# Return to root
cd ..
```

---

### Step 2: Configure Backend

Update `backend.tf` with your backend bucket name from Step 1:

```hcl
terraform {
  backend "s3" {
    bucket         = "asset-monitoring-platform-tfstate-XXXXXXXX"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

---

### Step 3: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Save outputs
terraform output > outputs.txt
```

---

### Step 4: Set Up Device Certificates

**⚠️ Device certificates are managed outside Terraform for security.**

```bash
# Create directory for certificates
mkdir -p certs/device-1

# Create certificate for device-1
aws iot create-keys-and-certificate \
  --set-as-active \
  --certificate-pem-outfile certs/device-1/device.cert.pem \
  --public-key-outfile certs/device-1/device.public.key \
  --private-key-outfile certs/device-1/device.private.key

# Save certificate ARN from output
CERT_ARN="arn:aws:iot:us-west-2:ACCOUNT_ID:cert/CERT_ID"

# Download Amazon Root CA
curl -o certs/device-1/AmazonRootCA1.pem \
  https://www.amazontrust.com/repository/AmazonRootCA1.pem

# Attach policy to certificate
aws iot attach-policy \
  --policy-name asset-monitoring-platform-device-policy-dev \
  --target $CERT_ARN

# Attach certificate to thing
aws iot attach-thing-principal \
  --thing-name asset-monitoring-platform-device-1-dev \
  --principal $CERT_ARN

# Set secure permissions
chmod 600 certs/device-1/device.private.key
chmod 644 certs/device-1/*.pem

# Repeat for device-2 and device-3
```

---

## 🧪 Testing

### Test 1: Publish Test Message via AWS CLI

```bash
# Get IoT endpoint
IOT_ENDPOINT=$(terraform output -raw iot_endpoint)

# Publish test message
aws iot-data publish \
  --topic "telemetry/device-1" \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "asset_id": "motor-1",
    "device_id": "device-1",
    "timestamp": "2026-02-26T12:00:00Z",
    "temperature": 75.0,
    "vibration": 2.5,
    "current": 15.0
  }'

# Wait 10 seconds for processing
sleep 10

# Verify data in DynamoDB
aws dynamodb get-item \
  --table-name asset-monitoring-platform-latest-readings-dev \
  --key '{"asset_id": {"S": "motor-1"}}'
```

---

### Test 2: Query via API Gateway

```bash
# Get API endpoint
API_ENDPOINT=$(terraform output -raw api_endpoint)

# Query device health
curl $API_ENDPOINT/assets/motor-1/health

# Expected response:
# {
#   "asset_id": "motor-1",
#   "device_id": "device-1",
#   "temperature": 75.0,
#   "vibration": 2.5,
#   "current": 15.0,
#   "status": "NORMAL",
#   "ts": "2026-02-26T12:00:00Z"
# }
```

---

### Test 3: Publish with MQTT Client (Using Certificates)

```bash
# Install mosquitto MQTT client
# macOS: brew install mosquitto
# Ubuntu: sudo apt install mosquitto-clients

# Get IoT endpoint
IOT_ENDPOINT=$(terraform output -raw iot_endpoint)

# Publish using device certificate
mosquitto_pub \
  --cafile certs/device-1/AmazonRootCA1.pem \
  --cert certs/device-1/device.cert.pem \
  --key certs/device-1/device.private.key \
  -h $IOT_ENDPOINT \
  -p 8883 \
  -q 1 \
  -t "telemetry/device-1" \
  -m '{
    "asset_id": "motor-1",
    "device_id": "device-1",
    "timestamp": "2026-02-26T13:00:00Z",
    "temperature": 85.0,
    "vibration": 4.5,
    "current": 19.0
  }'
```

**Note:** This message should trigger an alert (temp ≥ 80°C)

---

## 📈 Monitoring

### CloudWatch Logs

```bash
# Lambda: get_asset_health
aws logs tail /aws/lambda/asset-monitoring-platform-get-asset-health-dev --follow

# Lambda: process_telemetry
aws logs tail /aws/lambda/asset-monitoring-platform-process-telemetry-dev --follow

# API Gateway
aws logs tail /aws/apigateway/asset-monitoring-platform-api-dev --follow
```

---

### Verify S3 Archive

```bash
# List recent files
aws s3 ls s3://asset-monitoring-platform-raw-telemetry-dev/raw/iot/ --recursive | tail -10

# Download and inspect a batch file
aws s3 cp s3://asset-monitoring-platform-raw-telemetry-dev/raw/iot/year=2026/month=02/day=26/hour=12/batch-XXXXX.json.gz .

# Decompress and view
gunzip -c batch-XXXXX.json.gz | jq .
```

---

### Check DynamoDB Data

```bash
# Scan latest readings
aws dynamodb scan \
  --table-name asset-monitoring-platform-latest-readings-dev \
  --query 'Items[*].{asset:asset_id.S,temp:temperature.N,status:status.S}' \
  --output table

# Query alerts for specific asset
aws dynamodb query \
  --table-name asset-monitoring-platform-alerts-dev \
  --key-condition-expression "asset_id = :asset" \
  --expression-attribute-values '{":asset": {"S": "motor-2"}}' \
  --query 'Items[*].{time:ts.S,severity:severity.S,message:message.S}' \
  --output table
```

---

## 🔐 Security

### IAM Roles (Least Privilege)

**get_asset_health Lambda:**
- DynamoDB: `GetItem`, `Query` on `latest_readings` only
- CloudWatch: Create logs for this function only

**process_telemetry Lambda:**
- SQS: `ReceiveMessage`, `DeleteMessage` on `telemetry_queue` only
- S3: `PutObject` on `raw-telemetry` bucket only
- DynamoDB: `PutItem`, `UpdateItem` on `latest_readings` and `alerts` only
- CloudWatch: Create logs for this function only

**IoT Rule:**
- SQS: `SendMessage` on `telemetry_queue` only

---

### Encryption

- **S3**: AES-256 encryption at rest
- **DynamoDB**: Server-side encryption enabled
- **Terraform State**: Encrypted in S3 backend
- **MQTT**: TLS 1.2+ with mutual authentication (mTLS)

---

### Best Practices

✅ **Device Certificates:** Managed outside Terraform (not in state)  
✅ **State File:** Remote backend with encryption and locking  
✅ **API Gateway:** No authentication (add API keys or Cognito for production)  
✅ **VPC:** Lambdas run in AWS-managed VPC (add custom VPC for production)  
✅ **Secrets:** No hardcoded credentials  
✅ **Monitoring:** CloudWatch logs with 7-day retention  

---

### Security Recommendations for Production

1. **Add API Authentication:**
   - API Gateway API Keys
   - AWS Cognito User Pools
   - IAM authorization

2. **Device Certificate Rotation:**
   - Implement certificate lifecycle management
   - Store certificates in AWS Secrets Manager
   - Automate rotation with Lambda

3. **Network Security:**
   - Deploy Lambdas in VPC
   - Use VPC endpoints for AWS services
   - Enable VPC Flow Logs

4. **Monitoring & Alerting:**
   - CloudWatch Alarms for Lambda errors
   - SNS notifications for critical alerts
   - AWS X-Ray for distributed tracing

---

## 💰 Cost Estimate

**Monthly cost (10 devices, 24/7 operation, 5-second intervals):**

| Service | Usage | Cost/Month |
|---------|-------|------------|
| IoT Core | 5.2M messages | $40 |
| SQS | 5.2M requests | $2 |
| Lambda (process_telemetry) | 52K invocations | $0 (free tier) |
| Lambda (get_asset_health) | Varies | $0 (free tier) |
| S3 Storage | ~15 GB | $0.35 |
| S3 PUT (optimized) | 86K requests | $430 |
| S3 GET | 1M requests | $0.40 |
| DynamoDB Writes | 5.2M | $6.50 |
| DynamoDB Reads | 1M | $0.25 |
| API Gateway | Varies | ~$1/million |
| **TOTAL** | | **~$480/month** |

**Cost Optimization:**
- ✅ S3 batching: 98% reduction (from $25,910 to $430)
- ✅ Pay-per-request DynamoDB: No wasted capacity
- ✅ HTTP API (not REST API): 70% cheaper
- ✅ Lifecycle policies: 90-day → Glacier, 365-day → Delete

---

## 📚 API Reference

### GET /assets/{asset_id}/health

**Request:**
```bash
curl https://YOUR_API_ENDPOINT/assets/motor-1/health
```

**Response (200 OK):**
```json
{
  "asset_id": "motor-1",
  "device_id": "device-1",
  "ts": "2026-02-26T12:00:00Z",
  "temperature": 75.0,
  "vibration": 2.5,
  "current": 15.0,
  "status": "NORMAL",
  "ingested_at": "2026-02-26T12:00:01Z",
  "raw_s3_key": "raw/iot/year=2026/month=02/day=26/hour=12/batch-xyz.json.gz"
}
```

**Response (404 Not Found):**
```json
{
  "error": "Asset motor-999 not found"
}
```

---

## 📊 Data Schema

### DynamoDB: latest_readings

```
{
  "asset_id": "motor-1",           // PK (String)
  "device_id": "device-1",         // String
  "ts": "2026-02-26T12:00:00Z",    // String (ISO 8601)
  "temperature": 75.0,             // Number
  "vibration": 2.5,                // Number
  "current": 15.0,                 // Number
  "status": "NORMAL",              // String (NORMAL|WARN|CRITICAL)
  "raw_s3_key": "...",             // String
  "ingested_at": "..."             // String (ISO 8601)
}
```

### DynamoDB: alerts

```
{
  "asset_id": "motor-2",           // PK (String)
  "ts": "2026-02-26T12:05:00Z",    // SK (String, ISO 8601)
  "alert_id": "uuid",              // String
  "device_id": "device-2",         // String
  "severity": "WARN",              // String (WARN|CRITICAL)
  "type": "THRESHOLD",             // String
  "message": "temperature 85.0 >= 80.0; vibration 4.5 >= 3.0",
  "temperature": 85.0,             // Number
  "vibration": 4.5,                // Number
  "current": 19.2,                 // Number
  "device_ts": "...",              // String
  "raw_s3_key": "..."              // String
}
```

---

## 🗑️ Cleanup

### Destroy Infrastructure

```bash
# Destroy all resources
terraform destroy

# Confirm with 'yes'
```

**Note:** S3 bucket with versioning enabled may need manual cleanup:

```bash
# Delete all versions
aws s3api delete-objects \
  --bucket asset-monitoring-platform-raw-telemetry-dev \
  --delete "$(aws s3api list-object-versions \
    --bucket asset-monitoring-platform-raw-telemetry-dev \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)"

# Then destroy
terraform destroy
```

## 🤝 Contributing

For issues or improvements, contact the maintainer.

## 👤 Maintainer

- **Project:** asset-monitoring-platform
- **Environment:** dev
- **Owner:** luisgarmir
- **Region:** us-west-2
- **Managed by:** Terraform

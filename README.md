# Asset Monitoring Platform

Serverless IoT platform for real-time asset health monitoring and predictive maintenance.

## 🏗️ Architecture

```
Devices (MQTT) → AWS IoT Core → IoT Rule → SQS → Lambda (process_telemetry) → S3 + DynamoDB
                                                                                      ↓
                                                                          API Gateway → Lambda (get_asset_health)
```

## 📊 Current Infrastructure Status

### ✅ Phase 1: Read API (DEPLOYED)
- **API Gateway HTTP API**: `https://c3hjhpx465.execute-api.us-west-2.amazonaws.com`
- **Lambda Function**: `get_asset_health` - Retrieves latest asset health data
- **DynamoDB Table**: `latest_readings` - Stores latest device readings
- **IAM Role**: Least-privilege access (DynamoDB read + CloudWatch logs)

**Endpoint:**
```
GET /assets/{asset_id}/health
```

**Example:**
```bash
curl https://c3hjhpx465.execute-api.us-west-2.amazonaws.com/assets/motor-1/health
```

**Response:**
```json
{
  "asset_id": "motor-1",
  "device_id": "motor-1-dev-1",
  "ts": "2026-02-26T10:00:00Z",
  "temperature": 75.5,
  "vibration": 4.2,
  "current": 18.1,
  "status": "WARN"
}
```

### ✅ Supporting Resources (DEPLOYED)
- **SQS Queue**: `telemetry_queue` - Message buffering with batch processing
- **SQS DLQ**: `telemetry_dlq` - Dead letter queue for failed messages
- **CloudWatch Logs**: 7-day retention for Lambda and API Gateway

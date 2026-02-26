#!/bin/bash

echo "🚀 Publishing test message..."
aws iot-data publish \
  --topic "telemetry/test-device-1" \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "asset_id": "motor-test",
    "device_id": "test-device-1",
    "timestamp": "2026-02-26T12:00:00Z",
    "temperature": 85.5,
    "vibration": 4.5,
    "current": 19.2
  }'

echo "⏳ Waiting 10 seconds for processing..."
sleep 10

echo ""
echo "📊 Checking DynamoDB latest_readings..."
aws dynamodb get-item \
  --table-name asset-monitoring-platform-latest-readings-dev \
  --key '{"asset_id": {"S": "motor-test"}}' \
  --query 'Item.{asset_id:asset_id.S,temperature:temperature.N,vibration:vibration.N,status:status.S}'

echo ""
echo "🚨 Checking alerts..."
aws dynamodb query \
  --table-name asset-monitoring-platform-alerts-dev \
  --key-condition-expression "asset_id = :asset" \
  --expression-attribute-values '{":asset": {"S": "motor-test"}}' \
  --query 'Count'

echo ""
echo "🌐 Testing API..."
curl -s https://c3hjhpx465.execute-api.us-west-2.amazonaws.com/assets/motor-test/health | jq .

echo ""
echo "📦 Checking S3..."
aws s3 ls s3://asset-monitoring-platform-raw-telemetry-dev/raw/iot/ --recursive | tail -3

echo ""
echo "✅ Test complete!"
import json
import boto3
import os
import uuid
import gzip
from datetime import datetime, timezone
from decimal import Decimal

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Environment variables
S3_BUCKET = os.environ['S3_BUCKET']
LATEST_TABLE = os.environ['LATEST_TABLE']
ALERTS_TABLE = os.environ['ALERTS_TABLE']
TEMP_THRESHOLD = Decimal(os.environ.get('TEMP_THRESHOLD', '80.0'))
VIB_THRESHOLD = Decimal(os.environ.get('VIB_THRESHOLD', '3.0'))

latest_tbl = dynamodb.Table(LATEST_TABLE)
alerts_tbl = dynamodb.Table(ALERTS_TABLE)

def _to_decimal(x):
    """Convert to Decimal for DynamoDB"""
    return Decimal(str(x))

def lambda_handler(event, context):
    """
    Process batch of telemetry messages from SQS.
    Optimized with S3 batching (1 file per batch).
    """
    
    # Collect all messages for batch S3 write
    batch_messages = []
    batch_metadata = []
    
    now = datetime.now(timezone.utc)
    batch_id = str(uuid.uuid4())
    
    # Process all records in batch
    for record in event.get('Records', []):
        try:
            # Parse message
            body = json.loads(record['body'])
            
            # Validate required fields
            required = ['asset_id', 'device_id', 'timestamp', 'temperature', 'vibration', 'current']
            if not all(field in body for field in required):
                print(f"Missing fields in message: {body}")
                continue
            
            asset_id = str(body['asset_id'])
            device_id = str(body['device_id'])
            device_ts = str(body['timestamp'])
            temperature = _to_decimal(body['temperature'])
            vibration = _to_decimal(body['vibration'])
            current = _to_decimal(body['current'])
            
            ingested_at = datetime.now(timezone.utc).isoformat()
            
            # Store for batch S3 write
            batch_messages.append(body)
            
            # Store metadata for DynamoDB writes
            batch_metadata.append({
                'asset_id': asset_id,
                'device_id': device_id,
                'device_ts': device_ts,
                'temperature': temperature,
                'vibration': vibration,
                'current': current,
                'ingested_at': ingested_at,
            })
            
        except Exception as e:
            print(f"Error processing record: {e}")
            continue
    
    if not batch_messages:
        return {'statusCode': 200, 'processed': 0}
    
    # ========================================
    # WRITE ONE S3 FILE FOR ENTIRE BATCH
    # ========================================
    
    s3_key = (
        f"raw/iot/year={now:%Y}/month={now:%m}/day={now:%d}/hour={now:%H}/"
        f"batch-{batch_id}.json.gz"
    )
    
    # Compress batch
    batch_json = json.dumps(batch_messages, default=str)
    compressed = gzip.compress(batch_json.encode('utf-8'))
    
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=s3_key,
        Body=compressed,
        ContentType='application/json',
        ContentEncoding='gzip',
    )
    
    print(f"✅ Wrote {len(batch_messages)} messages to s3://{S3_BUCKET}/{s3_key}")
    
    # ========================================
    # PROCESS EACH MESSAGE FOR DYNAMODB
    # ========================================
    
    for meta in batch_metadata:
        asset_id = meta['asset_id']
        device_id = meta['device_id']
        device_ts = meta['device_ts']
        temperature = meta['temperature']
        vibration = meta['vibration']
        current = meta['current']
        ingested_at = meta['ingested_at']
        
        # Determine status
        status = 'NORMAL'
        reasons = []
        
        if vibration >= VIB_THRESHOLD:
            status = 'WARN'
            reasons.append(f"vibration {vibration} >= {VIB_THRESHOLD}")
        
        if temperature >= TEMP_THRESHOLD:
            status = 'WARN'
            reasons.append(f"temperature {temperature} >= {TEMP_THRESHOLD}")
        
        # Update latest reading
        latest_tbl.put_item(
            Item={
                'asset_id': asset_id,
                'device_id': device_id,
                'ts': device_ts,
                'temperature': temperature,
                'vibration': vibration,
                'current': current,
                'status': status,
                'raw_s3_key': s3_key,
                'ingested_at': ingested_at,
            }
        )
        
        # Create alert if threshold exceeded
        if status != 'NORMAL':
            alert_id = str(uuid.uuid4())
            
            alerts_tbl.put_item(
                Item={
                    'asset_id': asset_id,
                    'ts': ingested_at,
                    'alert_id': alert_id,
                    'device_id': device_id,
                    'severity': status,
                    'type': 'THRESHOLD',
                    'message': '; '.join(reasons),
                    'temperature': temperature,
                    'vibration': vibration,
                    'current': current,
                    'device_ts': device_ts,
                    'raw_s3_key': s3_key,
                }
            )
    
    return {
        'statusCode': 200,
        'processed': len(batch_messages),
        's3_key': s3_key
    }
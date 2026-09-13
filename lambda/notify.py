import json
import boto3
import os

sns = boto3.client('sns')
TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    body = json.loads(event['body'])
    
    alerts = body.get('alerts', [])
    for alert in alerts:
        status = alert.get('status', 'unknown')
        alertname = alert.get('labels', {}).get('alertname', 'UnknownAlert')
        summary = alert.get('annotations', {}).get('summary', 'No summary provided')
        
        message = f"[{status.upper()}] {alertname}: {summary}"
        
        sns.publish(
            TopicArn=TOPIC_ARN,
            Subject=f"Cluster Alert: {alertname}",
            Message=message
        )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processed'})
    }
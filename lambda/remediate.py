import json
import boto3
import os

ssm = boto3.client('ssm')
sns = boto3.client('sns')

INSTANCE_ID = os.environ['INSTANCE_ID']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

REMEDIATION_COMMANDS = {
    'PodCrashLooping': 'export KUBECONFIG=/home/ec2-user/.kube/config && kubectl rollout restart deployment/healthcheck-app -n default'
}

def lambda_handler(event, context):
    body = json.loads(event['body'])
    alerts = body.get('alerts', [])

    for alert in alerts:
        status = alert.get('status', 'unknown')
        alertname = alert.get('labels', {}).get('alertname', 'UnknownAlert')

        if status != 'firing':
            continue

        command = REMEDIATION_COMMANDS.get(alertname)
        if not command:
            continue

        response = ssm.send_command(
            InstanceIds=[INSTANCE_ID],
            DocumentName='AWS-RunShellScript',
            Parameters={'commands': [command]}
        )

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"Auto-remediation triggered: {alertname}",
            Message=f"Detected {alertname} firing. Triggered remediation command via SSM. Command ID: {response['Command']['CommandId']}"
        )

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processed'})
    }
import json
import os
import boto3
import logging
from boto3.dynamodb.conditions import Key

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    # Log the incoming event
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Get table name from environment variable
        table_name = os.environ.get('FEEDBACK_TABLE_NAME')
        table = dynamodb.Table(table_name)
        logger.info(f"Using DynamoDB table: {table_name}")
        
        # Get query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        conversation_id = query_params.get('conversation_id')
        feedback_type = query_params.get('feedback_type')
        
        logger.info(f"Query parameters - conversation_id: {conversation_id}, feedback_type: {feedback_type}")
        
        # If conversation_id is provided, get feedback for that conversation
        if conversation_id:
            logger.info(f"Querying feedback for conversation: {conversation_id}")
            response = table.query(
                KeyConditionExpression=Key('conversation_id').eq(conversation_id)
            )
            items = response.get('Items', [])
        # If feedback_type is provided, scan for that type
        elif feedback_type:
            logger.info(f"Scanning feedback for type: {feedback_type}")
            response = table.scan(
                FilterExpression=Key('feedback_type').eq(feedback_type)
            )
            items = response.get('Items', [])
        # Otherwise, get all feedback (with limit)
        else:
            logger.info("Scanning all feedback (limit 100)")
            response = table.scan(Limit=100)
            items = response.get('Items', [])
        
        logger.info(f"Retrieved {len(items)} feedback items")
        
        # Return successful response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET'
            },
            'body': json.dumps({
                'feedback_count': len(items),
                'feedback_items': items
            })
        }
        
    except Exception as e:
        logger.error(f"Error reading feedback: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,GET'
            },
            'body': json.dumps({'error': f"Error reading feedback: {str(e)}"})
        }
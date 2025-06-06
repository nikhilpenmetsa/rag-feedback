import json
import os
import boto3
import uuid
import logging
import jwt
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')

def extract_user_from_token(event):
    """Extract user information from JWT token"""
    try:
        # Get the Authorization header
        auth_header = event.get('headers', {}).get('Authorization')
        if not auth_header:
            logger.warning("No Authorization header found")
            return None
        
        # Extract the token (remove 'Bearer ' prefix)
        token = auth_header.replace('Bearer ', '')
        
        # Decode the token (without verification for now - AWS API Gateway already verified it)
        # In production, you should verify the token signature
        decoded = jwt.decode(token, options={"verify_signature": False})
        
        # Extract user information
        user_id = decoded.get('email') or decoded.get('cognito:username')
        is_reviewer = decoded.get('custom:is_reviewer', 'false').lower() == 'true'
        
        logger.info(f"Extracted user_id: {user_id}, is_reviewer: {is_reviewer}")
        return {
            'user_id': user_id,
            'is_reviewer': is_reviewer
        }
    except Exception as e:
        logger.error(f"Error extracting user from token: {str(e)}", exc_info=True)
        return None

def lambda_handler(event, context):
    # Log the incoming event
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract user information from JWT token
        user_info = extract_user_from_token(event)
        user_id = user_info.get('user_id', 'anonymous') if user_info else 'anonymous'
        
        # Get request body from API Gateway event
        body = json.loads(event.get('body', '{}'))
        logger.info(f"Request body: {json.dumps(body)}")
        
        # Extract feedback data
        conversation_id = body.get('conversation_id', str(uuid.uuid4()))
        feedback_type = body.get('feedback_type', 'neutral')  # positive, negative, neutral
        feedback_text = body.get('feedback_text', '')
        original_query = body.get('original_query', '')
        llm_response = body.get('llm_response', '')
        
        logger.info(f"Processing feedback for conversation: {conversation_id}, type: {feedback_type}")
        
        # Validate feedback_type
        if feedback_type not in ['positive', 'negative', 'neutral']:
            logger.warning(f"Invalid feedback type: {feedback_type}")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'error': 'Invalid feedback_type. Must be positive, negative, or neutral'})
            }
        
        # Get table name from environment variable
        table_name = os.environ.get('FEEDBACK_TABLE_NAME')
        table = dynamodb.Table(table_name)
        logger.info(f"Using DynamoDB table: {table_name}")
        
        # Create timestamp
        timestamp = datetime.utcnow().isoformat()
        
        # Create item to store in DynamoDB
        item = {
            'id': str(uuid.uuid4()),
            'conversation_id': conversation_id,
            'feedback_type': feedback_type,
            'feedback_text': feedback_text,
            'original_query': original_query,
            'llm_response': llm_response,
            'timestamp': timestamp,
            'user_id': user_id,
            'reviewed': False,
            'reviewer_comments': '',
            'reviewer_id': ''
        }
        
        # Store in DynamoDB
        logger.info(f"Storing feedback with ID: {item['id']}")
        table.put_item(Item=item)
        logger.info("Feedback stored successfully")
        
        # Return successful response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({
                'message': 'Feedback stored successfully',
                'feedback_id': item['id']
            })
        }
        
    except Exception as e:
        logger.error(f"Error storing feedback: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'error': f"Error storing feedback: {str(e)}"})
        }
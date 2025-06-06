import json
import os
import boto3
import logging
import jwt
from boto3.dynamodb.conditions import Key

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
cognito = boto3.client('cognito-idp')

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
        is_reviewer = user_info.get('is_reviewer', False) if user_info else False
        
        # Get table name from environment variable
        table_name = os.environ.get('FEEDBACK_TABLE_NAME')
        table = dynamodb.Table(table_name)
        logger.info(f"Using DynamoDB table: {table_name}")
        
        # Get query parameters
        query_params = event.get('queryStringParameters', {}) or {}
        conversation_id = query_params.get('conversation_id')
        feedback_type = query_params.get('feedback_type')
        
        logger.info(f"Query parameters - conversation_id: {conversation_id}, feedback_type: {feedback_type}")
        
        # If the user is not a reviewer, they can only see their own feedback
        if not is_reviewer:
            logger.info(f"Regular user {user_id} can only see their own feedback")
            
            # If conversation_id is provided, get feedback for that conversation and user
            if conversation_id:
                logger.info(f"Querying feedback for conversation: {conversation_id} and user: {user_id}")
                response = table.query(
                    IndexName="ConversationIndex",
                    KeyConditionExpression=Key('conversation_id').eq(conversation_id),
                    FilterExpression=Key('user_id').eq(user_id)
                )
                items = response.get('Items', [])
            # Otherwise, get all feedback for this user
            else:
                logger.info(f"Querying all feedback for user: {user_id}")
                response = table.query(
                    IndexName="UserIndex",
                    KeyConditionExpression=Key('user_id').eq(user_id)
                )
                items = response.get('Items', [])
        
        # If the user is a reviewer, they can see all feedback
        else:
            logger.info(f"Reviewer {user_id} can see all feedback")
            
            # If conversation_id is provided, get feedback for that conversation
            if conversation_id:
                logger.info(f"Querying feedback for conversation: {conversation_id}")
                response = table.query(
                    IndexName="ConversationIndex",
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
                'feedback_items': items,
                'is_reviewer': is_reviewer
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
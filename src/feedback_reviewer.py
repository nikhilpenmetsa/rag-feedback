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
        
        # Get request body from API Gateway event
        body = json.loads(event.get('body', '{}'))
        logger.info(f"Request body: {json.dumps(body)}")
        
        # Extract review data
        feedback_id = body.get('feedback_id')
        reviewer_comments = body.get('reviewer_comments', '')
        
        # Validate required fields
        if not feedback_id:
            logger.warning("Missing required field: feedback_id")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'error': 'Missing required field: feedback_id'})
            }
        
        # Get table name from environment variable
        table_name = os.environ.get('FEEDBACK_TABLE_NAME')
        table = dynamodb.Table(table_name)
        logger.info(f"Using DynamoDB table: {table_name}")
        
        # Check if user has reviewer permissions
        if not is_reviewer:
            logger.warning(f"User {user_id} does not have reviewer permissions")
            return {
                'statusCode': 403,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'error': 'User does not have reviewer permissions'})
            }
        
        # Update the feedback item with review information
        response = table.update_item(
            Key={'id': feedback_id},
            UpdateExpression="set reviewed = :r, reviewer_comments = :c, reviewer_id = :i",
            ExpressionAttributeValues={
                ':r': True,
                ':c': reviewer_comments,
                ':i': user_id
            },
            ReturnValues="UPDATED_NEW"
        )
        
        logger.info(f"Updated feedback item: {json.dumps(response.get('Attributes', {}))}")
        
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
                'message': 'Feedback reviewed successfully',
                'feedback_id': feedback_id
            })
        }
        
    except Exception as e:
        logger.error(f"Error reviewing feedback: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'error': f"Error reviewing feedback: {str(e)}"})
        }
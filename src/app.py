import json
import os
import boto3
import logging
import uuid
import base64
import jwt

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Bedrock client
bedrock = boto3.client('bedrock-runtime')

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
        message = body.get('message', '')
        
        if not message:
            logger.warning("No message provided in request")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'error': 'No message provided'})
            }
        
        # Get model ID from environment variable
        model_id = os.environ.get('MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        logger.info(f"Using model: {model_id}")
        
        # Create a conversation ID
        conversation_id = str(uuid.uuid4())
        logger.info(f"Generated conversation ID: {conversation_id}")
        
        # Call Bedrock to converse with Claude
        response = bedrock.converse(
            modelId=model_id,
            messages=[
                {
                    'role': 'user',
                    'content': [
                        {
                            'text': message
                        }
                    ]
                }
            ]
        )
        
        # Extract response from Claude
        claude_response = response['output']['message']['content'][0]['text']
        logger.info(f"Generated response of length: {len(claude_response)}")
        
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
                'conversation_id': conversation_id,
                'response': claude_response,
                'user_id': user_id
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing conversation: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'error': f"Error processing conversation: {str(e)}"})
        }
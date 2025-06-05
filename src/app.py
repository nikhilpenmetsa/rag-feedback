import json
import os
import boto3
import uuid
import logging
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize Bedrock client
bedrock_runtime = boto3.client('bedrock-runtime')

def lambda_handler(event, context):
    # Log the incoming event
    logger.info(f"Received event: {json.dumps(event)}")
    
    try:
        # Get request body from API Gateway event
        body = json.loads(event.get('body', '{}'))
        logger.info(f"Request body: {json.dumps(body)}")
        
        # Extract message from request
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
                'body': json.dumps({'error': 'Message is required'})
            }
        
        # Generate a conversation ID if not provided
        conversation_id = body.get('conversation_id', str(uuid.uuid4()))
        logger.info(f"Conversation ID: {conversation_id}")
        
        # Get model ID from environment variable or use default
        model_id = os.environ.get('MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        logger.info(f"Using model: {model_id}")
        
        # Prepare request for Bedrock Converse API
        logger.info("Calling Bedrock Converse API")
        response = bedrock_runtime.converse(
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
        logger.info(f"Received response from Bedrock (length: {len(claude_response)})")
        
        # Return successful response with conversation ID
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
                'original_query': message
            })
        }
        
    except ClientError as e:
        logger.error(f"Error calling Bedrock: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'error': f"Error calling Bedrock: {str(e)}"})
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'error': f"Unexpected error: {str(e)}"})
        }
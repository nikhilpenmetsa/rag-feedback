import boto3
import json
import os
import sys

def get_stack_outputs(stack_name):
    """Get the outputs from a CloudFormation stack"""
    cfn = boto3.client('cloudformation')
    
    try:
        response = cfn.describe_stacks(StackName=stack_name)
        outputs = response['Stacks'][0]['Outputs']
        
        # Convert to dictionary
        output_dict = {}
        for output in outputs:
            output_dict[output['OutputKey']] = output['OutputValue']
            
        return output_dict
    except Exception as e:
        print(f"Error getting stack outputs: {str(e)}")
        return None

def update_config_file(config_path, backend_stack_name='feedback-stack'):
    """Update the config.js file with values from CloudFormation stack outputs"""
    # Get stack outputs
    outputs = get_stack_outputs(backend_stack_name)
    if not outputs:
        print("Failed to get stack outputs")
        return False
    
    # Read the current config file
    try:
        with open(config_path, 'r') as f:
            config_content = f.read()
    except Exception as e:
        print(f"Error reading config file: {str(e)}")
        return False
    
    # Update API endpoints
    config_content = config_content.replace(
        'https://your-api-id.execute-api.your-region.amazonaws.com/prod/conversation',
        outputs.get('ConversationApiEndpoint', 'https://your-api-id.execute-api.your-region.amazonaws.com/prod/conversation')
    )
    
    config_content = config_content.replace(
        'https://your-api-id.execute-api.your-region.amazonaws.com/prod/submit-feedback',
        outputs.get('WriteFeedbackApiEndpoint', 'https://your-api-id.execute-api.your-region.amazonaws.com/prod/submit-feedback')
    )
    
    config_content = config_content.replace(
        'https://your-api-id.execute-api.your-region.amazonaws.com/prod/feedback-data',
        outputs.get('ReadFeedbackApiEndpoint', 'https://your-api-id.execute-api.your-region.amazonaws.com/prod/feedback-data')
    )
    
    config_content = config_content.replace(
        'https://your-api-id.execute-api.your-region.amazonaws.com/prod/review-feedback',
        outputs.get('ReviewFeedbackApiEndpoint', 'https://your-api-id.execute-api.your-region.amazonaws.com/prod/review-feedback')
    )
    
    # Update Cognito configuration
    config_content = config_content.replace(
        'your-region_your-user-pool-id',
        outputs.get('UserPoolId', 'your-region_your-user-pool-id')
    )
    
    config_content = config_content.replace(
        'your-client-id',
        outputs.get('UserPoolClientId', 'your-client-id')
    )
    
    # Write the updated config file
    try:
        with open(config_path, 'w') as f:
            f.write(config_content)
        print(f"Updated {config_path} with stack outputs")
        return True
    except Exception as e:
        print(f"Error writing config file: {str(e)}")
        return False

def main():
    # Get the script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Get the SPA directory
    spa_dir = os.path.dirname(script_dir)
    
    # Get the config file path
    config_path = os.path.join(spa_dir, 'public', 'config.js')
    
    # Get the stack name from command line arguments or use default
    stack_name = sys.argv[1] if len(sys.argv) > 1 else 'feedback-stack'
    
    # Update the config file
    success = update_config_file(config_path, stack_name)
    
    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()
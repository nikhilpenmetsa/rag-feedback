import boto3
import argparse
import json
import sys
import time
import getpass

def create_user(cognito_client, user_pool_id, email, name, password, is_reviewer=False):
    """
    Create a user in the Cognito User Pool
    """
    try:
        # Create the user
        response = cognito_client.admin_create_user(
            UserPoolId=user_pool_id,
            Username=email,
            UserAttributes=[
                {
                    'Name': 'email',
                    'Value': email
                },
                {
                    'Name': 'email_verified',
                    'Value': 'true'
                },
                {
                    'Name': 'name',
                    'Value': name
                },
                {
                    'Name': 'custom:is_reviewer',
                    'Value': 'true' if is_reviewer else 'false'
                }
            ],
            TemporaryPassword=password,
            MessageAction='SUPPRESS'
        )
        
        # Set the user's password permanently (skip the force change password step)
        cognito_client.admin_set_user_password(
            UserPoolId=user_pool_id,
            Username=email,
            Password=password,
            Permanent=True
        )
        
        print(f"Created user: {email} (Reviewer: {is_reviewer})")
        return response
    except Exception as e:
        print(f"Error creating user {email}: {str(e)}")
        return None

def main():
    parser = argparse.ArgumentParser(description='Create users in Cognito User Pool')
    parser.add_argument('--user-pool-id', required=True, help='Cognito User Pool ID')
    parser.add_argument('--region', default='us-east-1', help='AWS region')
    parser.add_argument('--users-file', help='JSON file with user data')
    parser.add_argument('--interactive', action='store_true', help='Create users interactively')
    
    args = parser.parse_args()
    
    # Initialize Cognito client
    cognito_client = boto3.client('cognito-idp', region_name=args.region)
    
    if args.users_file:
        # Create users from file
        try:
            with open(args.users_file, 'r') as f:
                users = json.load(f)
            
            for user in users:
                create_user(
                    cognito_client,
                    args.user_pool_id,
                    user['email'],
                    user['name'],
                    user['password'],
                    user.get('is_reviewer', False)
                )
                # Small delay to avoid throttling
                time.sleep(0.5)
                
        except Exception as e:
            print(f"Error creating users from file: {str(e)}")
            sys.exit(1)
    
    elif args.interactive:
        # Create users interactively
        while True:
            email = input("Enter user email (or 'q' to quit): ")
            if email.lower() == 'q':
                break
                
            name = input("Enter user name: ")
            password = getpass.getpass("Enter password (min 8 chars, uppercase, lowercase, number): ")
            is_reviewer = input("Is this user a reviewer? (y/n): ").lower() == 'y'
            
            create_user(
                cognito_client,
                args.user_pool_id,
                email,
                name,
                password,
                is_reviewer
            )
    
    else:
        # Create default users
        default_password = "Password123!"
        
        # Create regular users
        for i in range(1, 4):
            create_user(
                cognito_client,
                args.user_pool_id,
                f"user{i}@example.com",
                f"Regular User {i}",
                default_password,
                False
            )
            time.sleep(0.5)
        
        # Create reviewer users
        for i in range(1, 3):
            create_user(
                cognito_client,
                args.user_pool_id,
                f"reviewer{i}@example.com",
                f"Reviewer {i}",
                default_password,
                True
            )
            time.sleep(0.5)
    
    print("User creation completed.")

if __name__ == "__main__":
    main()
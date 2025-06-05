#!/bin/bash
# Update the config.js file with values from CloudFormation stack outputs

STACK_NAME=${1:-feedback-stack}

# Run the Python script
python update_config.py $STACK_NAME

if [ $? -ne 0 ]; then
    echo "Failed to update config.js"
    exit 1
fi

echo "Successfully updated config.js with stack outputs"
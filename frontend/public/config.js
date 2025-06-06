// Configuration file for the SPA
// Updated from CloudFormation stack outputs

const CONFIG = {
    // API Endpoints
    API_ENDPOINTS: {
        CONVERSATION: 'https://6wql43dake.execute-api.us-east-1.amazonaws.com/prod/conversation',
        SUBMIT_FEEDBACK: 'https://6wql43dake.execute-api.us-east-1.amazonaws.com/prod/submit-feedback',
        FEEDBACK_DATA: 'https://6wql43dake.execute-api.us-east-1.amazonaws.com/prod/feedback-data',
        REVIEW_FEEDBACK: 'https://6wql43dake.execute-api.us-east-1.amazonaws.com/prod/review-feedback'
    },
    
    // Cognito Configuration
    COGNITO: {
        USER_POOL_ID: 'us-east-1_L24JDh1uQ',
        CLIENT_ID: '6hou9r0rr1flsmsmngjnn1a021'
    }
};

// Export the configuration
window.CONFIG = CONFIG;

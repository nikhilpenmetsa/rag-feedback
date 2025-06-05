// Configuration file for the SPA
// Replace these values with the actual values from your CloudFormation stack outputs

const CONFIG = {
    // API Endpoints
    API_ENDPOINTS: {
        CONVERSATION: 'https://sz84wiarb4.execute-api.us-east-1.amazonaws.com/prod/conversation',
        SUBMIT_FEEDBACK: 'https://sz84wiarb4.execute-api.us-east-1.amazonaws.com/prod/submit-feedback',
        FEEDBACK_DATA: 'https://sz84wiarb4.execute-api.us-east-1.amazonaws.com/prod/feedback-data',
        REVIEW_FEEDBACK: 'https://sz84wiarb4.execute-api.us-east-1.amazonaws.com/prod/review-feedback'
    },
    
    // Cognito Configuration
    COGNITO: {
        USER_POOL_ID: 'us-east-1_IblxgL8oS',
        CLIENT_ID: '1id0saf4lp7ct55l84pcfkd57p'
    }
};

// Export the configuration
window.CONFIG = CONFIG;
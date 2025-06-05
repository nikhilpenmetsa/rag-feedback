// Configuration
const API_ENDPOINT = 'https://sz84wiarb4.execute-api.us-east-1.amazonaws.com/prod/conversation';
const FEEDBACK_API_ENDPOINT = 'https://sz84wiarb4.execute-api.us-east-1.amazonaws.com/prod/submit-feedback';

// DOM Elements
const chatMessages = document.getElementById('chat-messages');
const userInput = document.getElementById('user-input');
const sendButton = document.getElementById('send-button');

// State
let conversationId = null;
let lastQuery = '';
let lastResponse = '';

// Event Listeners
sendButton.addEventListener('click', sendMessage);
userInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
    }
});

// Functions
async function sendMessage() {
    const message = userInput.value.trim();
    if (!message) return;

    // Save the query for feedback
    lastQuery = message;
    
    // Clear input
    userInput.value = '';

    // Add user message to chat
    addMessage(message, 'user');

    // Show loading indicator
    const loadingElement = addLoadingIndicator();

    try {
        // Send message to API
        const response = await fetch(API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ message })
        });

        if (!response.ok) {
            throw new Error(`API responded with status: ${response.status}`);
        }

        const data = await response.json();
        
        // Save conversation ID and response
        conversationId = data.conversation_id;
        lastResponse = data.response;
        
        // Remove loading indicator
        loadingElement.remove();
        
        // Add assistant response to chat with feedback buttons
        addMessageWithFeedback(data.response, data.conversation_id);
    } catch (error) {
        console.error('Error sending message:', error);
        
        // Remove loading indicator
        loadingElement.remove();
        
        // Add error message
        addMessage('Sorry, there was an error processing your request. Please try again.', 'system');
    }
}

function addMessage(text, sender) {
    const messageElement = document.createElement('div');
    messageElement.classList.add('message', sender);
    messageElement.textContent = text;
    
    chatMessages.appendChild(messageElement);
    
    // Scroll to bottom
    chatMessages.scrollTop = chatMessages.scrollHeight;
    
    return messageElement;
}

function addMessageWithFeedback(text, msgConversationId) {
    // Create message container
    const container = document.createElement('div');
    container.classList.add('message-container');
    
    // Create message element
    const messageElement = document.createElement('div');
    messageElement.classList.add('message', 'assistant');
    messageElement.textContent = text;
    container.appendChild(messageElement);
    
    // Create feedback container
    const feedbackContainer = document.createElement('div');
    feedbackContainer.classList.add('feedback-container');
    
    // Create feedback buttons
    const thumbsUpButton = document.createElement('button');
    thumbsUpButton.classList.add('feedback-button');
    thumbsUpButton.innerHTML = '👍';
    thumbsUpButton.title = 'Helpful';
    
    const thumbsDownButton = document.createElement('button');
    thumbsDownButton.classList.add('feedback-button');
    thumbsDownButton.innerHTML = '👎';
    thumbsDownButton.title = 'Not helpful';
    
    // Add event listeners to feedback buttons
    thumbsUpButton.addEventListener('click', () => {
        showFeedbackForm(container, 'positive', msgConversationId);
        thumbsUpButton.classList.add('active');
        thumbsDownButton.classList.remove('active');
    });
    
    thumbsDownButton.addEventListener('click', () => {
        showFeedbackForm(container, 'negative', msgConversationId);
        thumbsDownButton.classList.add('active');
        thumbsUpButton.classList.remove('active');
    });
    
    // Add buttons to feedback container
    feedbackContainer.appendChild(thumbsUpButton);
    feedbackContainer.appendChild(thumbsDownButton);
    
    // Add feedback container to message container
    container.appendChild(feedbackContainer);
    
    // Add to chat
    chatMessages.appendChild(container);
    
    // Scroll to bottom
    chatMessages.scrollTop = chatMessages.scrollHeight;
    
    return container;
}

function showFeedbackForm(container, feedbackType, msgConversationId) {
    // Remove existing feedback form if any
    const existingForm = container.querySelector('.feedback-form');
    if (existingForm) {
        existingForm.remove();
    }
    
    // Create feedback form
    const feedbackForm = document.createElement('div');
    feedbackForm.classList.add('feedback-form');
    
    // Create textarea
    const textarea = document.createElement('textarea');
    textarea.placeholder = feedbackType === 'positive' 
        ? 'What was helpful about this response?' 
        : 'What was not helpful about this response?';
    textarea.rows = 2;
    
    // Create submit button
    const submitButton = document.createElement('button');
    submitButton.textContent = 'Submit Feedback';
    submitButton.addEventListener('click', () => {
        submitFeedback(feedbackType, textarea.value, msgConversationId);
        feedbackForm.innerHTML = '<div class="feedback-thanks">Thank you for your feedback!</div>';
        setTimeout(() => {
            feedbackForm.remove();
        }, 3000);
    });
    
    // Add elements to form
    feedbackForm.appendChild(textarea);
    feedbackForm.appendChild(submitButton);
    
    // Add form to container
    container.appendChild(feedbackForm);
}

async function submitFeedback(feedbackType, feedbackText, msgConversationId) {
    try {
        const response = await fetch(FEEDBACK_API_ENDPOINT, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                conversation_id: msgConversationId,
                feedback_type: feedbackType,
                feedback_text: feedbackText,
                original_query: lastQuery,
                llm_response: lastResponse
            })
        });
        
        if (!response.ok) {
            throw new Error(`API responded with status: ${response.status}`);
        }
        
        console.log('Feedback submitted successfully');
    } catch (error) {
        console.error('Error submitting feedback:', error);
    }
}

function addLoadingIndicator() {
    const loadingElement = document.createElement('div');
    loadingElement.classList.add('message', 'assistant', 'loading');
    
    for (let i = 0; i < 3; i++) {
        const dot = document.createElement('div');
        dot.classList.add('loading-dot');
        loadingElement.appendChild(dot);
    }
    
    chatMessages.appendChild(loadingElement);
    chatMessages.scrollTop = chatMessages.scrollHeight;
    
    return loadingElement;
}

// Initialize the app
function init() {
    // Focus on input
    userInput.focus();
}

// Start the app
init();
// DOM Elements
const backButton = document.getElementById('back-button');
const feedbackItems = document.getElementById('feedback-items');
const typeFilter = document.getElementById('type-filter');
const reviewFilter = document.getElementById('review-filter');
const userNameElement = document.getElementById('user-name');

// Event Listeners
backButton.addEventListener('click', () => {
    window.location.href = 'chat.html';
});

typeFilter.addEventListener('change', filterFeedback);
reviewFilter.addEventListener('change', filterFeedback);

// State
let allFeedbackItems = [];
let isReviewer = false;

// Functions
async function fetchFeedbackData() {
    try {
        // Get the authentication token
        const token = window.auth.getCurrentUserToken();
        if (!token) {
            throw new Error('Not authenticated');
        }

        // Check if user is a reviewer
        isReviewer = window.auth.isUserReviewer();
        
        // Update user name display
        if (userNameElement) {
            userNameElement.textContent = window.auth.getUserName();
        }
        
        // Fetch feedback data
        const response = await fetch(window.CONFIG.API_ENDPOINTS.FEEDBACK_DATA, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!response.ok) {
            throw new Error(`API responded with status: ${response.status}`);
        }

        const data = await response.json();
        allFeedbackItems = data.feedback_items || [];
        
        // Display feedback
        displayFeedback(allFeedbackItems);
    } catch (error) {
        console.error('Error fetching feedback data:', error);
        
        if (error.message === 'Not authenticated') {
            // Redirect to login page
            window.location.href = 'login.html';
        } else {
            // Show error message
            feedbackItems.innerHTML = `
                <div class="no-feedback">
                    Error loading feedback data. Please try again later.
                </div>
            `;
        }
    }
}

function displayFeedback(items) {
    if (items.length === 0) {
        feedbackItems.innerHTML = `
            <div class="no-feedback">
                No feedback items found.
            </div>
        `;
        return;
    }

    // Sort items by timestamp (newest first)
    items.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    
    // Generate HTML for each feedback item
    const html = items.map(item => {
        const date = new Date(item.timestamp).toLocaleString();
        const reviewSection = isReviewer ? generateReviewSection(item) : '';
        
        return `
            <div class="feedback-item" data-id="${item.id}" data-type="${item.feedback_type}" data-reviewed="${item.reviewed}">
                <div class="feedback-item-header">
                    <span>
                        <span class="feedback-type ${item.feedback_type}">${capitalizeFirst(item.feedback_type)}</span>
                        • ${date}
                    </span>
                    <span>User: ${item.user_id}</span>
                </div>
                <div class="conversation">
                    <div class="query">
                        <strong>User Query:</strong>
                        ${escapeHtml(item.original_query)}
                    </div>
                    <div class="response">
                        <strong>AI Response:</strong>
                        ${escapeHtml(item.llm_response)}
                    </div>
                </div>
                ${item.feedback_text ? `
                    <div class="feedback-text">
                        "${escapeHtml(item.feedback_text)}"
                    </div>
                ` : ''}
                ${reviewSection}
            </div>
        `;
    }).join('');
    
    feedbackItems.innerHTML = html;
    
    // Add event listeners to review forms
    if (isReviewer) {
        document.querySelectorAll('.review-form').forEach(form => {
            form.addEventListener('submit', handleReviewSubmit);
        });
    }
}

function generateReviewSection(item) {
    if (item.reviewed) {
        return `
            <div class="review-section">
                <div class="reviewer-comments">
                    ${escapeHtml(item.reviewer_comments)}
                    <div class="reviewer-info">
                        Reviewed by ${item.reviewer_id}
                    </div>
                </div>
            </div>
        `;
    } else {
        return `
            <div class="review-section">
                <form class="review-form" data-id="${item.id}">
                    <textarea placeholder="Add your review comments here..." required></textarea>
                    <button type="submit">Submit Review</button>
                </form>
            </div>
        `;
    }
}

async function handleReviewSubmit(event) {
    event.preventDefault();
    
    const form = event.target;
    const feedbackId = form.dataset.id;
    const reviewerComments = form.querySelector('textarea').value;
    
    try {
        // Get the authentication token
        const token = window.auth.getCurrentUserToken();
        if (!token) {
            throw new Error('Not authenticated');
        }

        // Submit review
        const response = await fetch(window.CONFIG.API_ENDPOINTS.REVIEW_FEEDBACK, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({
                feedback_id: feedbackId,
                reviewer_comments: reviewerComments
            })
        });

        if (!response.ok) {
            throw new Error(`API responded with status: ${response.status}`);
        }

        // Update the UI
        const feedbackItem = document.querySelector(`.feedback-item[data-id="${feedbackId}"]`);
        const reviewSection = feedbackItem.querySelector('.review-section');
        
        // Get reviewer ID (email)
        const reviewerId = JSON.parse(atob(token.split('.')[1])).email;
        
        reviewSection.innerHTML = `
            <div class="reviewer-comments">
                ${escapeHtml(reviewerComments)}
                <div class="reviewer-info">
                    Reviewed by ${reviewerId}
                </div>
            </div>
        `;
        
        // Update the data attribute
        feedbackItem.dataset.reviewed = 'true';
        
        // Update the item in the allFeedbackItems array
        const itemIndex = allFeedbackItems.findIndex(item => item.id === feedbackId);
        if (itemIndex !== -1) {
            allFeedbackItems[itemIndex].reviewed = true;
            allFeedbackItems[itemIndex].reviewer_comments = reviewerComments;
            allFeedbackItems[itemIndex].reviewer_id = reviewerId;
        }
    } catch (error) {
        console.error('Error submitting review:', error);
        alert('Error submitting review. Please try again.');
    }
}

function filterFeedback() {
    const typeValue = typeFilter.value;
    const reviewValue = reviewFilter.value;
    
    let filteredItems = [...allFeedbackItems];
    
    // Filter by type
    if (typeValue !== 'all') {
        filteredItems = filteredItems.filter(item => item.feedback_type === typeValue);
    }
    
    // Filter by review status
    if (reviewValue === 'reviewed') {
        filteredItems = filteredItems.filter(item => item.reviewed);
    } else if (reviewValue === 'unreviewed') {
        filteredItems = filteredItems.filter(item => !item.reviewed);
    }
    
    // Display filtered items
    displayFeedback(filteredItems);
}

// Helper functions
function capitalizeFirst(str) {
    return str.charAt(0).toUpperCase() + str.slice(1);
}

function escapeHtml(unsafe) {
    return unsafe
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Check authentication
    if (!window.auth) {
        console.error('Auth module not loaded');
        return;
    }
    
    // Fetch feedback data
    fetchFeedbackData();
});
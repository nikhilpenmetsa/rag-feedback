// Initialize Cognito
const poolData = {
    UserPoolId: window.CONFIG.COGNITO.USER_POOL_ID,
    ClientId: window.CONFIG.COGNITO.CLIENT_ID
};

const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
const REDIRECT_URL = 'chat.html';

// Get user name from token
function getUserName() {
    const token = getCurrentUserToken();
    if (!token) return 'User';
    
    try {
        // Decode the token (JWT)
        const payload = JSON.parse(atob(token.split('.')[1]));
        return payload.name || payload.email || 'User';
    } catch (error) {
        console.error('Error decoding token:', error);
        return 'User';
    }
}

// Check if user is already authenticated
function checkAuthentication() {
    const cognitoUser = userPool.getCurrentUser();
    
    if (cognitoUser != null) {
        cognitoUser.getSession((err, session) => {
            if (err) {
                console.error('Error getting session:', err);
                return;
            }
            
            if (session.isValid()) {
                // If on login page, redirect to chat page
                if (window.location.pathname.includes('login.html')) {
                    window.location.href = REDIRECT_URL;
                } else {
                    // Update UI with user name
                    updateUserDisplay();
                }
            } else {
                // If not on login page, redirect to login
                if (!window.location.pathname.includes('login.html')) {
                    window.location.href = 'login.html';
                }
            }
        });
    } else {
        // If not on login page, redirect to login
        if (!window.location.pathname.includes('login.html')) {
            window.location.href = 'login.html';
        }
    }
}

// Update UI with user information
function updateUserDisplay() {
    const userNameElement = document.getElementById('user-name');
    if (userNameElement) {
        userNameElement.textContent = getUserName();
    }
}

// Handle login form submission
function setupLoginForm() {
    const loginForm = document.getElementById('login-form');
    if (!loginForm) return;
    
    loginForm.addEventListener('submit', (e) => {
        e.preventDefault();
        
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        const errorMessage = document.getElementById('error-message');
        
        // Hide any previous error messages
        errorMessage.style.display = 'none';
        
        // Set up authentication data
        const authenticationData = {
            Username: email,
            Password: password
        };
        
        const authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails(authenticationData);
        
        const userData = {
            Username: email,
            Pool: userPool
        };
        
        const cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);
        
        // Authenticate user
        cognitoUser.authenticateUser(authenticationDetails, {
            onSuccess: (result) => {
                // Get the ID token
                const idToken = result.getIdToken().getJwtToken();
                
                // Store the token in localStorage
                localStorage.setItem('idToken', idToken);
                
                // Redirect to chat page
                window.location.href = REDIRECT_URL;
            },
            onFailure: (err) => {
                console.error('Authentication failed:', err);
                errorMessage.style.display = 'block';
            }
        });
    });
}

// Get the current user's token
function getCurrentUserToken() {
    return localStorage.getItem('idToken');
}

// Check if the user is a reviewer
function isUserReviewer() {
    const token = getCurrentUserToken();
    if (!token) return false;
    
    try {
        // Decode the token (JWT)
        const payload = JSON.parse(atob(token.split('.')[1]));
        return payload['custom:is_reviewer'] === 'true';
    } catch (error) {
        console.error('Error decoding token:', error);
        return false;
    }
}

// Logout function
function logout() {
    const cognitoUser = userPool.getCurrentUser();
    if (cognitoUser) {
        cognitoUser.signOut();
        localStorage.removeItem('idToken');
        window.location.href = 'login.html';
    }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuthentication();
    setupLoginForm();
});

// Export functions for use in other scripts
window.auth = {
    getCurrentUserToken,
    getUserName,
    isUserReviewer,
    logout
};
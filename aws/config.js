// API Configuration
// Replace this URL with your actual API Gateway URL after deployment
const API_CONFIG = {
    // Get this URL from running the deploy.sh script
    BASE_URL: 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/prod',
    
    // API Endpoints
    ENDPOINTS: {
        storeReading: '/readings',
        getReadings: '/readings',
        listSessions: '/sessions'
    },
    
    // Request configuration
    REQUEST_TIMEOUT: 10000, // 10 seconds
    
    // Retry configuration
    MAX_RETRIES: 3,
    RETRY_DELAY: 1000, // 1 second
    
    // Cache configuration
    ENABLE_CACHE: true,
    CACHE_DURATION: 5 * 60 * 1000 // 5 minutes
};

// Security Configuration
const SECURITY_CONFIG = {
    // Enable/disable API key authentication (if using API Gateway API keys)
    USE_API_KEY: false,
    API_KEY: '', // Set this if USE_API_KEY is true
    
    // CORS configuration
    ALLOWED_ORIGINS: ['*'], // Restrict in production
    
    // Data validation
    MAX_TEMPERATURE: 1000,
    MIN_TEMPERATURE: -273.15,
    MAX_SENSOR_NAME_LENGTH: 50,
    MAX_SESSION_NAME_LENGTH: 100
};

// Feature flags
const FEATURE_FLAGS = {
    ENABLE_OFFLINE_MODE: true,
    ENABLE_AUTO_BACKUP: true,
    ENABLE_REAL_TIME_UPDATES: false, // For future WebSocket implementation
    ENABLE_EXPORT_TO_S3: false // For future S3 integration
};

// Export configuration (for use in HTML file)
if (typeof window !== 'undefined') {
    window.API_CONFIG = API_CONFIG;
    window.SECURITY_CONFIG = SECURITY_CONFIG;
    window.FEATURE_FLAGS = FEATURE_FLAGS;
}
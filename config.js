// Secure configuration for Temperature Monitor
// This file is safe to commit - it only reads from environment variables

const CONFIG = {
    // API Configuration
    API_KEY: process.env.TEMPERATURE_MONITOR_API_KEY || '',
    API_BASE_URL: process.env.TEMPERATURE_MONITOR_API_URL || 'https://pnx7qs4uve.execute-api.us-east-1.amazonaws.com/prod',
    
    // Environment
    ENVIRONMENT: process.env.NODE_ENV || 'development',
    
    // Security settings
    ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['localhost', '127.0.0.1'],
    
    // Request settings
    REQUEST_TIMEOUT: parseInt(process.env.REQUEST_TIMEOUT) || 10000,
    MAX_RETRIES: parseInt(process.env.MAX_RETRIES) || 3
};

// Validate required configuration
if (!CONFIG.API_KEY) {
    console.warn('WARNING: TEMPERATURE_MONITOR_API_KEY environment variable not set');
}

// Export for different environments
if (typeof module !== 'undefined' && module.exports) {
    // Node.js environment
    module.exports = CONFIG;
} else if (typeof window !== 'undefined') {
    // Browser environment
    window.TEMPERATURE_CONFIG = CONFIG;
}
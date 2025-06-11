// Simple local server for secure API key management
// Run with: node server.js

const http = require('http');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const PORT = process.env.PORT || 3000;
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS ? 
    process.env.ALLOWED_ORIGINS.split(',') : ['localhost', '127.0.0.1'];

// MIME types for static files
const mimeTypes = {
    '.html': 'text/html',
    '.js': 'text/javascript',
    '.css': 'text/css',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.wav': 'audio/wav',
    '.mp4': 'video/mp4',
    '.woff': 'application/font-woff',
    '.ttf': 'application/font-ttf',
    '.eot': 'application/vnd.ms-fontobject',
    '.otf': 'application/font-otf',
    '.wasm': 'application/wasm'
};

function corsHeaders(req, res) {
    const origin = req.headers.origin;
    const host = req.headers.host;
    
    // Check if origin is allowed
    const isAllowed = ALLOWED_ORIGINS.some(allowed => 
        origin && (origin.includes(allowed) || host.includes(allowed))
    ) || !origin; // Allow requests without origin (direct file access)
    
    if (isAllowed) {
        res.setHeader('Access-Control-Allow-Origin', origin || '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-API-Key');
        res.setHeader('Access-Control-Allow-Credentials', 'true');
    }
    
    return isAllowed;
}

function serveStaticFile(filePath, res) {
    const extname = String(path.extname(filePath)).toLowerCase();
    const contentType = mimeTypes[extname] || 'application/octet-stream';

    fs.readFile(filePath, (error, content) => {
        if (error) {
            if (error.code == 'ENOENT') {
                res.writeHead(404, { 'Content-Type': 'text/html' });
                res.end('<h1>404 Not Found</h1>', 'utf-8');
            } else {
                res.writeHead(500);
                res.end(`Server Error: ${error.code}`, 'utf-8');
            }
        } else {
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content, 'utf-8');
        }
    });
}

const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    
    // Set CORS headers
    if (!corsHeaders(req, res)) {
        res.writeHead(403, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Origin not allowed' }));
        return;
    }
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    // API endpoint for secure configuration
    if (url.pathname === '/api/config' && req.method === 'GET') {
        const config = {
            apiKey: process.env.TEMPERATURE_MONITOR_API_KEY,
            apiUrl: process.env.TEMPERATURE_MONITOR_API_URL || 
                   'https://pnx7qs4uve.execute-api.us-east-1.amazonaws.com/prod'
        };
        
        if (!config.apiKey) {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ 
                error: 'API key not configured. Set TEMPERATURE_MONITOR_API_KEY environment variable.' 
            }));
            return;
        }
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(config));
        return;
    }
    
    // Serve static files
    let filePath = '.' + url.pathname;
    if (filePath === './') {
        filePath = './temperature-monitor.html';
    }
    
    serveStaticFile(filePath, res);
});

server.listen(PORT, () => {
    console.log(`Temperature Monitor Server running at http://localhost:${PORT}/`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`API Key configured: ${!!process.env.TEMPERATURE_MONITOR_API_KEY}`);
    console.log(`Allowed origins: ${ALLOWED_ORIGINS.join(', ')}`);
    
    if (!process.env.TEMPERATURE_MONITOR_API_KEY) {
        console.warn('⚠️  WARNING: TEMPERATURE_MONITOR_API_KEY not set!');
        console.warn('   Copy .env.example to .env and configure your API key');
    }
});
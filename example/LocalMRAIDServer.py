#!/usr/bin/env python3
"""
Simple HTTP server to host MRAID test ads locally.
Run this script and access http://localhost:8080/MRAIDTestAd.html
"""

import http.server
import socketserver
import os
import sys

PORT = 8080

class MRAIDHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers for local testing
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def do_GET(self):
        # Log requests
        print(f"GET request for: {self.path}")
        super().do_GET()

def start_server():
    """Start the MRAID test server"""
    print(f"Starting MRAID test server on port {PORT}")
    print(f"Access your MRAID test ad at: http://localhost:{PORT}/MRAIDTestAd.html")
    print("Press Ctrl+C to stop the server")
    
    with socketserver.TCPServer(("", PORT), MRAIDHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")
            httpd.shutdown()

if __name__ == "__main__":
    # Check if MRAIDTestAd.html exists
    if not os.path.exists("MRAIDTestAd.html"):
        print("Error: MRAIDTestAd.html not found in current directory")
        print("Make sure you're running this from the directory containing the MRAID test ad")
        sys.exit(1)
    
    start_server() 
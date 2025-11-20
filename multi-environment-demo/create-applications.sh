#!/bin/bash

echo "🚀 Creating application..."
echo ""

# Create application and capture response
RESPONSE=$(curl --location 'https://localhost:8090/applications' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--insecure \
--silent \
--data '{
    "name": "First Test App", 
    "description": "First application for testing ZIP export", 
    "url": "https://localhost:3001",
    "auth_flow_graph_id": "auth_flow_config_basic",
    "registration_flow_graph_id": "registration_flow_config_basic",
    "is_registration_flow_enabled": true,
    "inbound_auth_config": [{
        "type": "oauth2",
        "config": {
            "client_id": "first_app_client", 
            "client_secret": "first_app_secret", 
            "redirect_uris": ["https://openidconnect.net/callback"],
            "grant_types": ["authorization_code"],                 
            "response_types": ["code"]
        }
    }]
}')

echo ""

# Extract the application ID from the response
APP_ID=$(echo $RESPONSE | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$APP_ID" ]; then
    echo "❌ Failed to extract application ID from response"
    exit 1
fi

echo "✅ Application created with ID: $APP_ID"

# Update runtime-dev.json with the application ID
RUNTIME_FILE="environments/runtime-dev.json"

if [ -f "$RUNTIME_FILE" ]; then
    # Use sed to replace the applicationID value
    sed -i.bak "s/\"applicationID\": \".*\"/\"applicationID\": \"$APP_ID\"/" "$RUNTIME_FILE"
    rm -f "${RUNTIME_FILE}.bak"
    echo "✅ Updated $RUNTIME_FILE with application ID: $APP_ID"
    
    # Store APP_ID in a temporary file for export script
    echo "$APP_ID" > /tmp/thunder_app_id.txt
else
    echo "❌ File $RUNTIME_FILE not found"
    exit 1
fi

# Update runtime-prod.json with the application ID
RUNTIME_FILE="environments/runtime-prod.json"

if [ -f "$RUNTIME_FILE" ]; then
    # Use sed to replace the applicationID value
    sed -i.bak "s/\"applicationID\": \".*\"/\"applicationID\": \"$APP_ID\"/" "$RUNTIME_FILE"
    rm -f "${RUNTIME_FILE}.bak"
    echo "✅ Updated $RUNTIME_FILE with application ID: $APP_ID"
    
    # Store APP_ID in a temporary file for export script
    echo "$APP_ID" > /tmp/thunder_app_id.txt
else
    echo "❌ File $RUNTIME_FILE not found"
    exit 1
fi




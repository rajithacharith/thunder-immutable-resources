#!/bin/bash

# Enable Client Credentials Grant for Application
# This script updates the application configuration to add client_credentials grant type
# Usage: ./enable-client-credentials.sh

set -e

# Dev environment only - read application ID from runtime-dev.json
THUNDER_URL="https://localhost:8090"
RUNTIME_FILE="environments/runtime-dev.json"

if [ ! -f "$RUNTIME_FILE" ]; then
  echo "❌ Error: $RUNTIME_FILE not found"
  exit 1
fi

APP_ID=$(grep -o '"applicationID": "[^"]*"' "$RUNTIME_FILE" | cut -d'"' -f4)

if [ -z "$APP_ID" ]; then
  echo "❌ Error: Could not extract application ID from $RUNTIME_FILE"
  exit 1
fi

CLIENT_ID="first_app_client"
CLIENT_SECRET="first_app_secret"
REDIRECT_URI="https://openidconnect.net/callback"

echo "🌍 Environment: DEVELOPMENT"
echo "🔧 Enabling client_credentials grant type..."
echo "Thunder URL: ${THUNDER_URL}"
echo "Application ID: ${APP_ID}"
echo ""

# Update the application to add client_credentials grant type
RESPONSE=$(curl -k -s -X PUT "${THUNDER_URL}/applications/${APP_ID}" \
  --header 'Content-Type: application/json' \
  --header 'Accept: application/json' \
  --data "{
    \"name\": \"First Test App\", 
    \"description\": \"First application for testing ZIP export\", 
    \"url\": \"https://localhost:3001\",
    \"auth_flow_graph_id\": \"auth_flow_config_basic\",
    \"registration_flow_graph_id\": \"registration_flow_config_basic\",
    \"is_registration_flow_enabled\": true,
    \"inbound_auth_config\": [{
        \"type\": \"oauth2\",
        \"config\": {
            \"client_id\": \"${CLIENT_ID}\", 
            \"client_secret\": \"${CLIENT_SECRET}\", 
            \"redirect_uris\": [\"${REDIRECT_URI}\"],
            \"grant_types\": [\"authorization_code\", \"client_credentials\"],                 
            \"response_types\": [\"code\"]
        }
    }]
}")

# Check if request was successful
if echo "$RESPONSE" | jq -e '.code' > /dev/null 2>&1; then
  ERROR_CODE=$(echo "$RESPONSE" | jq -r '.code')
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.message // .error')"
  echo ""
  echo "Full response:"
  echo "$RESPONSE" | jq '.'
  exit 1
else
  echo "✅ Application updated successfully!"
  echo ""
  echo "Verifying grant types..."
  sleep 2
  
  # Verify the update
  VERIFY=$(curl -k -s "${THUNDER_URL}/applications/${APP_ID}")
  GRANT_TYPES=$(echo "$VERIFY" | jq -r '.inbound_auth_config[0].config.grant_types[]' 2>/dev/null)
  
  if echo "$GRANT_TYPES" | grep -q "client_credentials"; then
    echo "✅ client_credentials grant type enabled!"
    echo ""
    echo "Enabled grant types:"
    echo "$GRANT_TYPES" | sed 's/^/  - /'
    echo ""
    echo "You can now test with:"
    echo "  ./call-client-credentials-grant.sh"
  else
    echo "⚠️  Update succeeded but grant types may not have changed"
    echo "Current grant types:"
    echo "$GRANT_TYPES" | sed 's/^/  - /'
  fi
fi

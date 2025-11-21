#!/bin/bash

# Client Credentials Grant Token Request
# This script requests an access token using the client credentials grant type
# Usage: ./call-client-credentials-grant.sh [dev|prod]

set -e

# Get environment from argument, default to dev
ENV=${1:-dev}
ENV=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')

# Configuration based on environment
if [ "$ENV" = "prod" ]; then
  THUNDER_URL="https://localhost:8091"
  CLIENT_ID="prod-first-test-app-uvwxy"
  CLIENT_SECRET="prod-first-test-secret-SECURE-KEY-lmn"
  ENV_NAME="PRODUCTION"
elif [ "$ENV" = "dev" ]; then
  THUNDER_URL="https://localhost:8090"
  CLIENT_ID="first_app_client"
  CLIENT_SECRET="first_app_secret"
  ENV_NAME="DEVELOPMENT"
else
  echo "❌ Error: Invalid environment '${1}'"
  echo "Usage: $0 [dev|prod]"
  echo ""
  echo "Examples:"
  echo "  $0 dev   # Use development environment (port 8090)"
  echo "  $0 prod  # Use production environment (port 8091)"
  exit 1
fi

echo "🌍 Environment: ${ENV_NAME}"
echo "🔐 Requesting access token using client credentials grant..."
echo "Thunder URL: ${THUNDER_URL}"
echo "Client ID: ${CLIENT_ID}"
echo ""

# Make the token request
RESPONSE=$(curl -k -s -X POST "${THUNDER_URL}/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

# Check if request was successful
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
  echo "❌ Error: $(echo "$RESPONSE" | jq -r '.error_description // .error')"
  echo ""
  echo "Full response:"
  echo "$RESPONSE" | jq '.'
  exit 1
else
  echo "✅ Token received successfully!"
  echo ""
  echo "Access Token:"
  echo "$RESPONSE" | jq -r '.access_token'
  echo ""
  echo "Full response:"
  echo "$RESPONSE" | jq '.'
fi

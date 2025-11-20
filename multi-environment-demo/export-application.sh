#!/bin/bash

# Read the application ID from runtime-dev.json
RUNTIME_FILE="environments/runtime-dev.json"

if [ ! -f "$RUNTIME_FILE" ]; then
    echo "❌ File $RUNTIME_FILE not found"
    exit 1
fi

# Extract APP_ID from runtime-dev.json
APP_ID=$(grep -o '"applicationID": *"[^"]*"' "$RUNTIME_FILE" | cut -d'"' -f4)

if [ -z "$APP_ID" ] || [ "$APP_ID" = "\${APP_ID}" ]; then
    echo "❌ No valid application ID found in $RUNTIME_FILE"
    echo "💡 Please run create-applications.sh first to create an application"
    exit 1
fi

echo "📦 Exporting application with ID: $APP_ID"
echo ""

# Export the application and capture response
RESPONSE=$(curl --location 'https://localhost:8090/export' -k \
--header 'Content-Type: application/json' \
--header 'Accept: application/yaml' \
--silent \
--data "{
    \"applications\": [
        \"$APP_ID\"
    ],
    \"options\": {
        \"include_metadata\": true,
        \"format\": \"yaml\",
        \"folder_structure\": {
            \"group_by_type\": true,
            \"file_naming_pattern\": \"\${name}_\${id}\"
        }
    }
}")

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    # Extract the filename from the response (first line after # File:)
    FILENAME=$(echo "$RESPONSE" | grep "# File:" | head -1 | sed 's/# File: //')
    
    # If no filename found, generate one
    if [ -z "$FILENAME" ]; then
        FILENAME="application_${APP_ID}.yaml"
    fi
    
    # Save the response to the file
    OUTPUT_FILE="configs/applications/$FILENAME"
    echo "$RESPONSE" > "$OUTPUT_FILE"
    
    echo "✅ Application exported successfully to: $OUTPUT_FILE"
    echo ""
    echo "📋 File contents preview:"
    echo "========================="
    head -20 "$OUTPUT_FILE"
    echo ""
    echo "💡 Full file saved at: $OUTPUT_FILE"
else
    echo ""
    echo "❌ Failed to export application"
    exit 1
fi

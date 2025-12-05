#!/bin/zsh

# Exit on error
set -e

# --- CONFIGURATION ---

# Paths (update these as needed)
PRODUCT_REPO_PATH="$PWD"
TEMP_DIR="$PRODUCT_REPO_PATH/wso2-setup-temp"
CONFIG_REPO_PATH="$TEMP_DIR"
THUNDER_API_BASE="https://localhost:8090"
ZIP_URL="https://github.com/rajithacharith/thunder-immutable-resources/releases/download/v0.0.2/wso2-cloud-setup-resources.zip"

# Required environment variables
export GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-<your-google-client-id>}"
export GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-<your-google-client-secret>}"
export ALLOWED_USER_TYPE="${ALLOWED_USER_TYPE:-Customer}"

# --- CREATE TEMP DIRECTORY ---
echo "Creating temporary directory..."
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# --- DOWNLOAD ZIP FILE ---
ZIP_FILE="$TEMP_DIR/wso2-cloud-setup-resources.zip"
if [ -f "$ZIP_FILE" ]; then
    echo "Found existing wso2-cloud-setup-resources.zip, skipping download..."
else
    echo "Downloading wso2-cloud-setup-resources.zip..."
    curl -L "$ZIP_URL" -o "$ZIP_FILE"
fi

# --- UNZIP FILES ---
# Check if resources are already extracted
if [ -d "$CONFIG_REPO_PATH/immutable_resources" ] && [ -d "$CONFIG_REPO_PATH/graphs" ]; then
    echo "Resources already extracted, skipping unzip..."
else
    echo "Unzipping resources..."
    unzip -o "$ZIP_FILE"
fi

# --- REMOVE EXISTING DIRECTORIES ---
echo "Removing existing immutable_resources directory..."
rm -rf "$PRODUCT_REPO_PATH/backend/cmd/server/repository/conf/immutable_resources"

echo "Removing existing graphs directory..."
rm -rf "$PRODUCT_REPO_PATH/backend/cmd/server/repository/resources/graphs"

# --- COPY FILES ---
echo "Copying immutable resources..."
mkdir -p "$PRODUCT_REPO_PATH/backend/cmd/server/repository/conf"
if [ -d "$CONFIG_REPO_PATH/immutable_resources" ]; then
    cp -r "$CONFIG_REPO_PATH/immutable_resources" "$PRODUCT_REPO_PATH/backend/cmd/server/repository/conf/"
else
    echo "Warning: immutable_resources directory not found in $CONFIG_REPO_PATH"
fi

echo "Copying graphs..."
mkdir -p "$PRODUCT_REPO_PATH/backend/cmd/server/repository/resources"
if [ -d "$CONFIG_REPO_PATH/graphs" ]; then
    cp -r "$CONFIG_REPO_PATH/graphs" "$PRODUCT_REPO_PATH/backend/cmd/server/repository/resources/"
else
    echo "Warning: graphs directory not found in $CONFIG_REPO_PATH"
fi

echo "Copying Makefile and build.sh..."
if [ -f "$CONFIG_REPO_PATH/Makefile" ]; then
    cp "$CONFIG_REPO_PATH/Makefile" "$PRODUCT_REPO_PATH/"
fi
if [ -f "$CONFIG_REPO_PATH/build.sh" ]; then
    cp "$CONFIG_REPO_PATH/build.sh" "$PRODUCT_REPO_PATH/"
fi

# --- RUN PRODUCT WITHOUT DEPLOYMENT.TOML ---
echo "Running Thunder with THUNDER_SKIP_SECURITY=true (no deployment.toml)..."
cd "$PRODUCT_REPO_PATH"
export THUNDER_SKIP_SECURITY=true
make run_backend &

THUNDER_PID=$!
sleep 10 # Wait for Thunder to start

# --- CREATE OR GET DEFAULT ORGANIZATION UNIT ---
thunder_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local url="${THUNDER_API_BASE}${endpoint}"

    if [ -z "$data" ]; then
        curl -k -s -w "\n%{http_code}" -X "$method" \
            "$url" \
            -H "Content-Type: application/json" 2>/dev/null || echo "000"
    else
        curl -k -s -w "\n%{http_code}" -X "$method" \
            "$url" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null || echo "000"
    fi
}

echo "Creating or getting default organization unit..."
RESPONSE=$(thunder_api_call POST "/organization-units" '{"handle": "default", "name": "Default", "description": "Default organization unit"}')
HTTP_CODE="${RESPONSE: -3}"
BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]]; then
    DEFAULT_OU_ID=$(echo "$BODY" | grep -o '"id":"[^\"]*"' | head -1 | cut -d'"' -f4)
elif [[ "$HTTP_CODE" == "409" ]]; then
    RESPONSE=$(thunder_api_call GET "/organization-units")
    BODY="${RESPONSE%???}"
    DEFAULT_OU_ID=$(echo "$BODY" | grep -o '"id":"[^\"]*"' | head -1 | cut -d'"' -f4)
else
    echo "Failed to create or get organization unit (HTTP $HTTP_CODE)"
    kill $THUNDER_PID
    exit 1
fi

echo "Default OU ID: $DEFAULT_OU_ID"

# --- CREATE USER SCHEMA ---
echo "Creating user schema..."
SCHEMA_RESPONSE=$(curl -k -s -w "\n%{http_code}" --location "$THUNDER_API_BASE/user-schemas" \
--header 'Content-Type: application/json' \
--data '{
    "name": "Customer",
    "ouId": "'"$DEFAULT_OU_ID"'",
    "allowSelfRegistration": true,
    "schema": {
        "sub": { "type": "string", "required": true, "unique": true },
        "username": { "type": "string", "required": false, "unique": false },
        "email": { "type": "string", "required": false, "unique": false }
    }
}')

SCHEMA_HTTP_CODE="${SCHEMA_RESPONSE: -3}"
if [[ "$SCHEMA_HTTP_CODE" != "201" ]] && [[ "$SCHEMA_HTTP_CODE" != "200" ]] && [[ "$SCHEMA_HTTP_CODE" != "409" ]]; then
    echo "Failed to create user schema (HTTP $SCHEMA_HTTP_CODE)"
    kill $THUNDER_PID
    exit 1
fi
echo "User schema created successfully"

# --- STOP THUNDER ---
echo "Stopping Thunder..."
kill $THUNDER_PID
sleep 5

echo "Copying deployment.yaml..."
mkdir -p "$PRODUCT_REPO_PATH/backend/cmd/server/repository/conf"
if [ -f "$CONFIG_REPO_PATH/deployment.yaml" ]; then
    cp "$CONFIG_REPO_PATH/deployment.yaml" "$PRODUCT_REPO_PATH/backend/cmd/server/repository/conf/"
else
    echo "Warning: deployment.yaml not found in $CONFIG_REPO_PATH"
fi


# --- RUN PRODUCT WITH DEPLOYMENT.TOML AND SKIP DEFAULT RESOURCES ---
echo "Running Thunder with SKIP_DEFAULT_RESOURCES=true..."
export SKIP_DEFAULT_RESOURCES=true
make run

# --- CLEANUP ---
echo "Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

echo "Setup and test complete."

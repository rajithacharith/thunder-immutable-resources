#!/bin/zsh

# Exit on error
set -e

# --- CONFIGURATION ---

# Paths (update these as needed)
PRODUCT_REPO_PATH="$PWD"
TEMP_DIR="$PRODUCT_REPO_PATH/wso2-setup-temp"
CONFIG_REPO_PATH="$TEMP_DIR"
THUNDER_API_BASE="https://localhost:8090"
ZIP_URL="https://github.com/rajithacharith/thunder-immutable-resources/releases/download/v0.0.5/wso2-cloud-setup-resources.zip"

# Required environment variables
export GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID:-<your-google-client-id>}"
export GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET:-<your-google-client-secret>}"
export ALLOWED_USER_TYPE="${ALLOWED_USER_TYPE:-Customer}"
export GOOGLE_REDIRECT_URI="${GOOGLE_REDIRECT_URI:-https://localhost:5190/gate/signin}"
export GITHUB_CLIENT_ID="${GITHUB_CLIENT_ID:-<your-github-client-id>}"
export GITHUB_CLIENT_SECRET="${GITHUB_CLIENT_SECRET:-<your-github-client-secret>}"
export GITHUB_REDIRECT_URI="${GITHUB_REDIRECT_URI:-https://localhost:8090/gate/signin}"

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
rm -rf "$PRODUCT_REPO_PATH/repository/conf/immutable_resources"

echo "Removing existing graphs directory..."
rm -rf "$PRODUCT_REPO_PATH/repository/resources/graphs"

# --- COPY FILES ---
echo "Copying graphs..."

echo "Updating immutable_resources and graphs from config repo (zip)..."
if [ -d "$CONFIG_REPO_PATH/immutable_resources" ]; then
    rm -rf "$PRODUCT_REPO_PATH/repository/conf/immutable_resources"
    mkdir -p "$PRODUCT_REPO_PATH/repository/conf"
    cp -r "$CONFIG_REPO_PATH/immutable_resources" "$PRODUCT_REPO_PATH/repository/conf/"
else
    echo "Warning: immutable_resources directory not found in $CONFIG_REPO_PATH"
fi
if [ -d "$CONFIG_REPO_PATH/graphs" ]; then
    rm -rf "$PRODUCT_REPO_PATH/repository/resources/graphs"
    mkdir -p "$PRODUCT_REPO_PATH/repository/resources"
    cp -r "$CONFIG_REPO_PATH/graphs" "$PRODUCT_REPO_PATH/repository/resources/"
else
    echo "Warning: graphs directory not found in $CONFIG_REPO_PATH"
fi

# --- RUN PRODUCT WITHOUT DEPLOYMENT.TOML ---
echo "Running Thunder with THUNDER_SKIP_SECURITY=true (no deployment.toml)..."
cd "$PRODUCT_REPO_PATH"

export THUNDER_SKIP_SECURITY=true
./start.sh &

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

# --- UPDATE USER SCHEMA WITH DEFAULT OU ID ---
echo "Updating user schema with default OU ID..."
if [ -f "$PRODUCT_REPO_PATH/repository/conf/immutable_resources/user_schemas/customer.yaml" ]; then
    sed -i.bak "s/organization_unit_id: .*/organization_unit_id: $DEFAULT_OU_ID/" "$PRODUCT_REPO_PATH/repository/conf/immutable_resources/user_schemas/customer.yaml"
    rm -f "$PRODUCT_REPO_PATH/repository/conf/immutable_resources/user_schemas/customer.yaml.bak"
    echo "User schema updated with OU ID: $DEFAULT_OU_ID"
else
    echo "Warning: customer.yaml not found"
fi

# --- STOP THUNDER ---
echo "Stopping Thunder..."
echo "Killing Thunder process with PID $THUNDER_PID"
kill $THUNDER_PID
sleep 10

echo "Overwriting deployment.yaml with zip version if present..."
if [ -f "$CONFIG_REPO_PATH/deployment.yaml" ]; then
    cp "$CONFIG_REPO_PATH/deployment.yaml" "$PRODUCT_REPO_PATH/repository/conf/deployment.yaml"
    echo "deployment.yaml updated from config repo."
else
    echo "Warning: deployment.yaml not found in config repo."
fi

# --- KILL PROCESSES ON PORTS 8090, 5190, 5191 ---
echo "Checking and killing processes on ports 8090, 5190, 5191..."
for port in 8090 5190 5191; do
    PID=$(lsof -ti:$port 2>/dev/null || true)
    if [ -n "$PID" ]; then
        echo "Killing process on port $port (PID: $PID)"
        kill $PID 2>/dev/null || true
        sleep 2
    else
        echo "No process found on port $port"
    fi
done

# --- RUN PRODUCT WITH DEPLOYMENT.TOML AND SKIP DEFAULT RESOURCES ---
echo "Running Thunder"
./start.sh 

# --- CLEANUP ---
echo "Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

echo "Setup and test complete."

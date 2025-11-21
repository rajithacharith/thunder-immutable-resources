#!/bin/bash

# Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com).
#
# WSO2 LLC. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1"
}

thunder_api_call() {
    local METHOD=$1
    local ENDPOINT=$2
    local DATA=${3:-""}
    
    if [[ -z "$DATA" ]]; then
        curl -k -s -w "\n%{http_code}" -X "$METHOD" \
            "https://localhost:8090${ENDPOINT}" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json"
    else
        curl -k -s -w "\n%{http_code}" -X "$METHOD" \
            "https://localhost:8090${ENDPOINT}" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "$DATA"
    fi
}

# ============================================================================
# Start Development Environment
# ============================================================================

echo "🚀 Starting Development Environment..."
echo ""

# Track if containers are being restarted (to skip resource creation)
IS_RESTART=false

# Check if prod containers are running and stop them
if docker ps | grep -q "thunder-prod\|sample-app-prod"; then
    echo "⚠️  Production containers are running. Stopping them first..."
    ENV=prod docker-compose --profile prod down
    echo "✅ Production containers stopped"
    echo ""
fi

# Check if dev containers are already running
if docker ps | grep -q "thunder-dev\|sample-app-dev"; then
    echo "⚠️  Development containers are already running"
    echo ""
    docker ps --filter "name=thunder-dev" --filter "name=sample-app-dev" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    read -p "Do you want to restart them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled. Containers remain running."
        exit 0
    fi
    echo "🔄 Restarting development environment..."
    IS_RESTART=true
fi

# Start dev environment
ENV=dev docker-compose -p thunder-dev --profile dev up -d

# Check health
echo ""
echo "🏥 Checking service health..."
if curl -k -sf https://localhost:8090/health/readiness > /dev/null 2>&1; then
    echo "✅ Thunder Server is healthy"
else
    echo "❌ Thunder Server is not responding"
fi

sleep 5

if curl -k -sf https://localhost:3000 > /dev/null 2>&1; then
    echo "✅ Sample App is healthy"
else
    echo "❌ Sample App is not responding"
fi

echo ""

# Only create resources if this is a fresh start (not a restart)
if [ "$IS_RESTART" = false ]; then

# ============================================================================
# Create Default Organization Unit
# ============================================================================

log_info "Creating default organization unit..."

RESPONSE=$(thunder_api_call POST "/organization-units" '{
  "handle": "default",
  "name": "Default",
  "description": "Default organization unit"
}')

HTTP_CODE="${RESPONSE: -3}"
BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]]; then
    log_success "Organization unit created successfully"
    DEFAULT_OU_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [[ -n "$DEFAULT_OU_ID" ]]; then
        log_info "Default OU ID: $DEFAULT_OU_ID"
    else
        log_error "Could not extract OU ID from response"
        exit 1
    fi
elif [[ "$HTTP_CODE" == "409" ]]; then
    log_warning "Organization unit already exists, retrieving OU ID..."
    # Get existing OU ID
    RESPONSE=$(thunder_api_call GET "/organization-units")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" == "200" ]]; then
        DEFAULT_OU_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [[ -n "$DEFAULT_OU_ID" ]]; then
            log_success "Found OU ID: $DEFAULT_OU_ID"
        else
            log_error "Could not find OU ID in response"
            exit 1
        fi
    else
        log_error "Failed to fetch organization units (HTTP $HTTP_CODE)"
        exit 1
    fi
else
    log_error "Failed to create organization unit (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
fi

echo ""

# ============================================================================
# Create User Schema
# ============================================================================

log_info "Creating user schema 'Person'..."

RESPONSE=$(thunder_api_call POST "/user-schemas" '{
  "name": "Person",
  "ouId": "'${DEFAULT_OU_ID}'",
  "schema": {
    "username": {
      "type": "string",
      "required": true,
      "unique": true
    },
    "email": {
      "type": "string",
      "required": true,
      "unique": true
    },
    "email_verified": {
      "type": "boolean",
      "required": false
    },
    "given_name": {
      "type": "string",
      "required": false
    },
    "family_name": {
      "type": "string",
      "required": false
    },
    "phone_number": {
      "type": "string",
      "required": false
    },
    "phone_number_verified": {
      "type": "boolean",
      "required": false
    }
  }
}')

HTTP_CODE="${RESPONSE: -3}"

if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]]; then
    log_success "User schema created successfully"
elif [[ "$HTTP_CODE" == "409" ]]; then
    log_warning "User schema already exists, skipping"
else
    log_error "Failed to create user schema (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""

# ============================================================================
# Create Admin User
# ============================================================================

log_info "Creating admin user..."

RESPONSE=$(thunder_api_call POST "/users" '{
  "type": "Person",
  "organizationUnit": "'${DEFAULT_OU_ID}'",
  "attributes": {
    "username": "admin",
    "password": "admin",
    "sub": "admin",
    "email": "admin@thunder.dev",
    "email_verified": true,
    "name": "Administrator",
    "given_name": "Admin",
    "family_name": "User",
    "picture": "https://example.com/avatar.jpg",
    "phone_number": "+12345678920",
    "phone_number_verified": true
  }
}')

HTTP_CODE="${RESPONSE: -3}"
BODY="${RESPONSE%???}"

if [[ "$HTTP_CODE" == "201" ]] || [[ "$HTTP_CODE" == "200" ]]; then
    log_success "Admin user created successfully"
    log_info "Username: admin"
    log_info "Password: admin"

    # Extract admin user ID
    ADMIN_USER_ID=$(echo "$BODY" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [[ -z "$ADMIN_USER_ID" ]]; then
        log_warning "Could not extract admin user ID from response"
    else
        log_info "Admin user ID: $ADMIN_USER_ID"
    fi
elif [[ "$HTTP_CODE" == "409" ]]; then
    log_warning "Admin user already exists, retrieving user ID..."

    # Get existing admin user ID
    RESPONSE=$(thunder_api_call GET "/users")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"

    if [[ "$HTTP_CODE" == "200" ]]; then
        # Parse JSON to find admin user
        ADMIN_USER_ID=$(echo "$BODY" | grep -o '"id":"[^"]*","[^"]*":"[^"]*","attributes":{[^}]*"username":"admin"' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

        # Fallback parsing
        if [[ -z "$ADMIN_USER_ID" ]]; then
            ADMIN_USER_ID=$(echo "$BODY" | sed 's/},{/}\n{/g' | grep '"username":"admin"' | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        fi

        if [[ -n "$ADMIN_USER_ID" ]]; then
            log_success "Found admin user ID: $ADMIN_USER_ID"
        else
            log_error "Could not find admin user in response"
            exit 1
        fi
    else
        log_error "Failed to fetch users (HTTP $HTTP_CODE)"
        exit 1
    fi
else
    log_error "Failed to create admin user (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
fi

echo ""

else
    log_info "Skipping resource creation (containers restarted)"
    echo ""
fi

echo "🎉 Development environment is ready!"
echo ""
echo "📍 Access points:"
echo "   - Thunder Server: http://localhost:8090"
echo "   - Sample App:     https://localhost:3000"
echo ""
echo "📚 Next steps:"
echo "   1. Create an application: curl -X POST http://localhost:8090/applications -H 'Content-Type: application/json' -d @configs/applications/web-app.yaml"
echo "   2. Open sample app: open https://localhost:3000"
echo ""
echo "🛑 To stop: ENV=dev docker-compose -p thunder-dev --profile dev down"

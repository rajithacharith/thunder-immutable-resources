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

echo "🚀 Starting Production Environment..."
echo ""

# Load environment variables from prod.env
source environments/prod.env

# Check if dev containers are running and stop them
if docker ps | grep -q "thunder-dev\|sample-app-dev"; then
    echo "⚠️  Development containers are running. Stopping them first..."
    ENV=dev docker-compose --profile dev down
    echo "✅ Development containers stopped"
    echo ""
fi

# Check if prod containers are already running
if docker ps | grep -q "thunder-prod\|sample-app-prod"; then
    echo "⚠️  Production containers are already running"
    echo ""
    docker ps --filter "name=thunder-prod" --filter "name=sample-app-prod" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    read -p "Do you want to restart them? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled. Containers remain running."
        exit 0
    fi
    echo "🔄 Restarting production environment..."
fi

# Start prod environment
ENV=prod PORT=8091 SAMPLE_APP_PORT=3001 docker-compose -p thunder-prod --profile prod up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 15

# Check health
echo ""
echo "🏥 Checking service health..."
if curl -sf http://localhost:8091/health/readiness > /dev/null 2>&1; then
    echo "✅ Thunder Server is healthy"
else
    echo "❌ Thunder Server is not responding"
fi

if curl -sf http://localhost:3001 > /dev/null 2>&1; then
    echo "✅ Sample App is healthy"
else
    echo "❌ Sample App is not responding"
fi

echo ""
echo "🎉 Production environment is ready!"
echo ""
echo "📍 Access points:"
echo "   - Thunder Server: http://localhost:8091"
echo "   - Sample App:     https://localhost:3001"
echo ""
echo "📚 Verify immutable configuration:"
echo "   curl http://localhost:8091/applications | jq"
echo ""
echo "🛑 To stop: ENV=prod docker-compose -p thunder-prod --profile prod down"

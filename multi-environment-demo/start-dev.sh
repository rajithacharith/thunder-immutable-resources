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

echo "🚀 Starting Development Environment..."
echo ""

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
fi

# Start dev environment
ENV=dev docker-compose -p thunder-dev --profile dev up -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 15

# Check health
echo ""
echo "🏥 Checking service health..."
if curl -k -sf https://localhost:8090/health/readiness > /dev/null 2>&1; then
    echo "✅ Thunder Server is healthy"
else
    echo "❌ Thunder Server is not responding"
fi

if curl -k -sf https://localhost:3000 > /dev/null 2>&1; then
    echo "✅ Sample App is healthy"
else
    echo "❌ Sample App is not responding"
fi

echo ""
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
echo "🛑 To stop: ENV=dev docker-compose --profile dev down"

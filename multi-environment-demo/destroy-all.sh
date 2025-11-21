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

echo "🛑 Stopping All Environments..."
echo ""

# Check if any containers are running
RUNNING_CONTAINERS=$(docker ps --filter "name=thunder" --filter "name=sample-app" --format "{{.Names}}")

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo "ℹ️  No Thunder or Sample App containers are running"
    exit 0
fi

echo "📋 Running containers:"
docker ps --filter "name=thunder" --filter "name=sample-app" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

read -p "⚠️  Do you want to stop all containers? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled. Containers remain running."
    exit 0
fi

echo ""
echo "🔄 Stopping environments..."
echo ""

# Stop dev environment
if docker ps | grep -q "thunder-dev\|sample-app-dev"; then
    echo "Stopping development environment..."
    ENV=dev docker-compose -p thunder-dev --profile dev down
    echo "✅ Development environment stopped"
    echo ""
fi

# Stop prod environment
if docker ps | grep -q "thunder-prod\|sample-app-prod"; then
    echo "Stopping production environment..."
    ENV=prod docker-compose -p thunder-prod --profile prod down
    echo "✅ Production environment stopped"
    echo ""
fi

echo "🎉 All environments stopped successfully!"
echo ""
echo "💡 To start environments:"
echo "   Development: bash start-dev.sh"
echo "   Production:  bash start-prod.sh"

#!/bin/bash

echo "🔄 Restarting Sample App Container..."
echo ""

# Recreate only the sample-app service using docker-compose
ENV=dev docker-compose -p thunder-dev up -d sample-app

echo ""
echo "⏳ Waiting for container to start..."
sleep 5

echo ""
echo "📋 Container Logs:"
echo "=================="
docker logs sample-app-dev

echo ""
echo "🏥 Checking container health..."
if docker ps | grep -q sample-app-dev; then
    echo "✅ Sample app container is running"
    
    # Check if the app is responding
    if curl -k -sf https://localhost:3000 > /dev/null 2>&1; then
        echo "✅ Sample app is healthy and responding"
    else
        echo "⚠️  Sample app container is running but not responding yet"
    fi
else
    echo "❌ Sample app container is not running"
fi

echo ""
echo "📍 Sample App: https://localhost:3000"
echo ""
echo "💡 To view live logs: docker logs -f sample-app-dev"

# Multi-Environment Demo

This directory contains a complete working example of Thunder's multi-environment configuration management workflow.

## Directory Structure

```
multi-environment-demo/
├── configs/                    # Immutable configuration files (for production)
│   └── applications/
│       └── web-app.yaml       # Web application configuration (exported from dev)
├── environments/              # Environment-specific variables
│   ├── dev.env               # Development environment variables
│   └── prod.env              # Production environment variables
├── deployment.yaml           # Thunder deployment configuration
├── docker-compose.yaml       # Docker Compose setup for both environments
└── README.md                 # This file
```

## Quick Start

### Development Environment (Database Mode)

```bash
# Start development environment
ENV=dev PORT=8090 IMMUTABLE_ENABLED=false docker-compose up -d

# Wait for Thunder to be ready
sleep 10
curl http://localhost:8090/healthz

# Create application via API
curl -X POST http://localhost:8090/applications \
  -H "Content-Type: application/json" \
  -d @- << 'EOF'
{
  "name": "Web Application",
  "description": "Main web application for end users",
  "url": "http://localhost:3000",
  "auth_flow_graph_id": "auth_flow_config_basic",
  "inbound_auth_config": [
    {
      "type": "oauth2",
      "config": {
        "redirect_uris": [
          "http://localhost:3000/callback",
          "http://localhost:3000/silent-callback"
        ],
        "grant_types": [
          "authorization_code",
          "refresh_token"
        ],
        "response_types": [
          "code"
        ],
        "token_endpoint_auth_method": "client_secret_basic",
        "scopes": [
          "openid",
          "profile",
          "email"
        ],
        "pkce_required": true,
        "public_client": false
      }
    }
  ]
}
EOF

# Save the application ID
APP_ID=$(curl -s http://localhost:8090/applications | jq -r '.applications[0].id')
echo "Application ID: $APP_ID"
```

### Production Environment (Immutable Mode)

```bash
# Start production environment
ENV=prod PORT=8091 IMMUTABLE_ENABLED=true IMMUTABLE_APPS_PATH=/app/repository/conf/immutable_resources/applications docker-compose -p thunder-prod up -d

# Wait for Thunder to be ready
sleep 10
curl http://localhost:8091/healthz

# Verify application is loaded from YAML
curl http://localhost:8091/applications/web-application | jq

# Verify it's immutable
curl http://localhost:8091/applications/web-application | jq '.is_immutable'
```

## Workflow

### 1. Develop in Dev
- Create and modify applications via API
- Test OAuth flows
- Iterate rapidly

### 2. Export Configuration
```bash
# Export application to YAML
curl -X POST http://localhost:8090/export \
  -H "Content-Type: application/json" \
  -H "Accept: application/yaml" \
  -d '{"applications": ["'$APP_ID'"]}' > configs/applications/web-app.yaml
```

### 3. Deploy to Production
- Update `environments/prod.env` with production values
- Restart production environment
- Configuration is loaded from YAML (immutable)

## Testing

### Test Authorization Code Flow
```bash
# Get authorization URL
curl -X GET "http://localhost:8090/oauth2/authorize?client_id=dev-web-app-12345&redirect_uri=http://localhost:3000/callback&response_type=code&scope=openid%20profile"
```

### Test Client Credentials Flow
```bash
# Get access token
curl -X POST http://localhost:8090/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "dev-web-app-12345:dev-web-secret-abcdef" \
  -d "grant_type=client_credentials&scope=api.read api.write"
```

## Cleanup

```bash
# Stop dev environment
docker-compose down

# Stop prod environment
docker-compose -p thunder-prod down

# Remove volumes (warning: deletes all data)
docker volume rm thunder-data-dev thunder-data-prod
```

## Related Documentation

- [Multi-Environment Demo Guide](../docs/guides/immutable-configurations/multi-environment-demo.md)
- [Immutable Configuration Guide](../docs/guides/immutable-configurations/immutable-configuration.md)
- [Export Configurations Guide](../docs/guides/immutable-configurations/export-configurations.md)

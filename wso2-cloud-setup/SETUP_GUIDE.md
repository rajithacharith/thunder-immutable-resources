# Setup Guide

## Prerequisites

- Make sure you have the product repository cloned locally
- Ensure `make` is installed on your system

## Setup Steps

### 1. Download Required Files

Download the following from your configuration repository:
- `graphs/` directory
- `immutable_resources/` directory  
- `deployment.yaml` file

You can download the zip with this : https://github.com/rajithacharith/thunder-immutable-resources/releases/download/v0.0.1/wso2-cloud-setup-resources.zip

### 2. Copy Files to Product Repository

Navigate to your product repository and copy the downloaded files to the appropriate locations:

#### Copy Immutable Resources
```bash
cp -r immutable_resources/ cmd/server/repository/conf/
```

#### Copy Deployment Configuration
```bash
cp deployment.yaml cmd/server/repository/conf/
```

#### Copy Graphs
```bash
cp -r graphs/ cmd/server/repository/resources/
```

#### Copy Makefile and build.sh
Replace existing Makefile and build.sh. This is to avoid creating default resources during the initialization with a flag.

### Export following environment variables
- GOOGLE_CLIENT_ID
- GOOGLE_CLIENT_SECRET
- ALLOWED_USER_TYPE

Run the product without these changes and create a userschema with sub attribute for the ALLOWED_USER_TYPE.

```
curl --location 'https://localhost:8090/user-schemas' \
--header 'Content-Type: application/json' \
--data '{
    "name": "Customer",
    "ouId": "<OU ID>",
    "allowSelfRegistration": true,
    "schema": {
        "sub": {
            "type": "string",
            "required": true,
            "unique": true
        },
        "username": {
            "type": "string",
            "required": false,
            "unique": false
        },
        "email": {
            "type": "string",
            "required": false,
            "unique": false
        }
    }
}'
```

```
export GOOGLE_CLIENT_ID=<your-google-client-id>
export GOOGLE_CLIENT_SECRET=<your-google-client-secret>
export ALLOWED_USER_TYPE=Customer
```

### 3. Run the Product

Execute the following command from the root of the product repository:

```bash
SKIP_DEFAULT_RESOURCES=true make run
```

## Directory Structure

After copying the files, your product repository should have the following structure:

```
cmd/server/repository/
├── conf/
│   ├── immutable_resources/
│   └── deployment.yaml
└── resources/
    └── graphs/
```

## Troubleshooting

- Ensure all paths exist before copying files
- Verify you have appropriate permissions to write to the target directories
- Check that the `make run` command completes without errors




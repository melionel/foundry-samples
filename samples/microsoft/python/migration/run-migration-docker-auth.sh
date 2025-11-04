#!/bin/bash
# Docker migration runner with automatic token authentication (Unix/Linux/macOS)
# This script handles token generation and Docker execution automatically

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🐳 Running v1 to v2 assistant migration in DOCKER with automatic authentication${NC}"
echo "======================================================================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Check if Azure CLI is available and authenticated
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found. Install from https://docs.microsoft.com/cli/azure/${NC}"
    exit 1
fi

# Check Azure CLI authentication
if ! az account show > /dev/null 2>&1; then
    echo -e "${RED}❌ Azure CLI not authenticated. Run 'az login' first.${NC}"
    exit 1
fi

ACCOUNT_INFO=$(az account show --query "user.name" -o tsv 2>/dev/null)
echo -e "${GREEN}✅ Azure CLI authenticated as: ${ACCOUNT_INFO}${NC}"

# Generate fresh token
echo -e "${BLUE}🔑 Generating fresh Azure AI token...${NC}"
TOKEN=$(az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$TOKEN" ] || [ ${#TOKEN} -lt 100 ]; then
    echo -e "${RED}❌ Failed to generate token or token is invalid${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Token generated successfully (length: ${#TOKEN})${NC}"

# Check if image exists
if ! docker image inspect v1-to-v2-migration > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Docker image 'v1-to-v2-migration' not found.${NC}"
    echo -e "${BLUE}🔨 Building Docker image...${NC}"
    docker build -t v1-to-v2-migration .
fi

# Load environment variables from .env if it exists
if [ -f .env ]; then
    echo -e "${GREEN}✅ Loading environment variables from .env file${NC}"
    export $(cat .env | grep -v '^#' | grep -v '^$' | xargs)
else
    echo -e "${YELLOW}⚠️  No .env file found. Using environment variables or defaults.${NC}"
fi

# Run the container with token authentication
echo -e "${GREEN}🏃 Running migration in Docker container with token authentication...${NC}"
echo -e "${YELLOW}Arguments: $@${NC}"
echo ""

# Execute Docker command
docker run --rm -it \
    --network host \
    -e DOCKER_CONTAINER=true \
    -e AZ_TOKEN="$TOKEN" \
    -e LOCAL_HOST=host.docker.internal:5001 \
    -e COSMOS_DB_CONNECTION_STRING="$COSMOS_DB_CONNECTION_STRING" \
    -e COSMOS_DB_DATABASE_NAME="$COSMOS_DB_DATABASE_NAME" \
    -e COSMOS_DB_CONTAINER_NAME="$COSMOS_DB_CONTAINER_NAME" \
    -e ASSISTANT_API_BASE="$ASSISTANT_API_BASE" \
    -e ASSISTANT_API_VERSION="$ASSISTANT_API_VERSION" \
    -e ASSISTANT_API_KEY="$ASSISTANT_API_KEY" \
    -e PROJECT_ENDPOINT_URL="$PROJECT_ENDPOINT_URL" \
    -e PROJECT_CONNECTION_STRING="$PROJECT_CONNECTION_STRING" \
    -e V2_API_BASE="$V2_API_BASE" \
    -e V2_API_VERSION="$V2_API_VERSION" \
    -e V2_API_KEY="$V2_API_KEY" \
    -e AZURE_TENANT_ID="$AZURE_TENANT_ID" \
    -e AZURE_CLIENT_ID="$AZURE_CLIENT_ID" \
    -e AZURE_CLIENT_SECRET="$AZURE_CLIENT_SECRET" \
    -e AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID" \
    -e AZURE_RESOURCE_GROUP="$AZURE_RESOURCE_GROUP" \
    -e AZURE_PROJECT_NAME="$AZURE_PROJECT_NAME" \
    -v "$HOME/.azure:/home/migration/.azure" \
    v1-to-v2-migration \
    "$@"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Migration completed successfully!${NC}"
else
    echo ""
    echo -e "${RED}❌ Migration failed with exit code: $EXIT_CODE${NC}"
fi

exit $EXIT_CODE
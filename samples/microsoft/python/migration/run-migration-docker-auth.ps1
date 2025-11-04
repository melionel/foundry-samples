#!/usr/bin/env pwsh
# Docker migration runner with automatic token authentication
# This script handles token generation and Docker execution automatically

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Arguments
)

# Colors for output
$Green = "`e[32m"
$Blue = "`e[34m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

Write-Host "${Blue}🐳 Running v1 to v2 assistant migration in DOCKER with automatic authentication${Reset}"
Write-Host "======================================================================================"

# Check if Docker is running
try {
    docker info | Out-Null
    Write-Host "${Green}✅ Docker is running${Reset}"
} catch {
    Write-Host "${Red}❌ Docker is not running. Please start Docker Desktop and try again.${Reset}"
    exit 1
}

# Check if Azure CLI is available and authenticated
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if ($account) {
        Write-Host "${Green}✅ Azure CLI authenticated as: $($account.user.name)${Reset}"
    } else {
        Write-Host "${Red}❌ Azure CLI not authenticated. Run 'az login' first.${Reset}"
        exit 1
    }
} catch {
    Write-Host "${Red}❌ Azure CLI not found. Install from https://docs.microsoft.com/cli/azure/${Reset}"
    exit 1
}

# Generate fresh token
Write-Host "${Blue}🔑 Generating fresh Azure AI token...${Reset}"
try {
    $token = az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv
    if ($token -and $token.Length -gt 100) {
        Write-Host "${Green}✅ Token generated successfully (length: $($token.Length))${Reset}"
    } else {
        Write-Host "${Red}❌ Failed to generate token or token is invalid${Reset}"
        exit 1
    }
} catch {
    Write-Host "${Red}❌ Failed to generate Azure token: $_${Reset}"
    exit 1
}

# Check if image exists
if (!(docker image inspect v1-to-v2-migration 2>$null)) {
    Write-Host "${Yellow}⚠️  Docker image 'v1-to-v2-migration' not found.${Reset}"
    Write-Host "${Blue}🔨 Building Docker image...${Reset}"
    docker build -t v1-to-v2-migration .
}

# Load environment variables from .env if it exists
if (Test-Path ".env") {
    Write-Host "${Green}✅ Loading environment variables from .env file${Reset}"
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.*)$") {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
} else {
    Write-Host "${Yellow}⚠️  No .env file found. Using environment variables or defaults.${Reset}"
}

# Run the container with token authentication
Write-Host "${Green}🏃 Running migration in Docker container with token authentication...${Reset}"
Write-Host "${Yellow}Arguments: $Arguments${Reset}"
Write-Host ""

try {
    docker run --rm -it `
        --network host `
        -e DOCKER_CONTAINER=true `
        -e AZ_TOKEN="$token" `
        -e COSMOS_DB_CONNECTION_STRING="$env:COSMOS_DB_CONNECTION_STRING" `
        -e COSMOS_DB_DATABASE_NAME="$env:COSMOS_DB_DATABASE_NAME" `
        -e COSMOS_DB_CONTAINER_NAME="$env:COSMOS_DB_CONTAINER_NAME" `
        -e ASSISTANT_API_BASE="$env:ASSISTANT_API_BASE" `
        -e ASSISTANT_API_VERSION="$env:ASSISTANT_API_VERSION" `
        -e ASSISTANT_API_KEY="$env:ASSISTANT_API_KEY" `
        -e PROJECT_ENDPOINT_URL="$env:PROJECT_ENDPOINT_URL" `
        -e PROJECT_CONNECTION_STRING="$env:PROJECT_CONNECTION_STRING" `
        -e V2_API_BASE="$env:V2_API_BASE" `
        -e V2_API_VERSION="$env:V2_API_VERSION" `
        -e V2_API_KEY="$env:V2_API_KEY" `
        -e AZURE_TENANT_ID="$env:AZURE_TENANT_ID" `
        -e AZURE_CLIENT_ID="$env:AZURE_CLIENT_ID" `
        -e AZURE_CLIENT_SECRET="$env:AZURE_CLIENT_SECRET" `
        -e AZURE_SUBSCRIPTION_ID="$env:AZURE_SUBSCRIPTION_ID" `
        -e AZURE_RESOURCE_GROUP="$env:AZURE_RESOURCE_GROUP" `
        -e AZURE_PROJECT_NAME="$env:AZURE_PROJECT_NAME" `
        -v "$env:USERPROFILE\.azure:/home/migration/.azure" `
        v1-to-v2-migration `
        @Arguments
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "${Green}✅ Migration completed successfully!${Reset}"
    } else {
        Write-Host ""
        Write-Host "${Red}❌ Migration failed with exit code: $exitCode${Reset}"
    }
    
    exit $exitCode
} catch {
    Write-Host "${Red}❌ Failed to run Docker container: $_${Reset}"
    exit 1
}
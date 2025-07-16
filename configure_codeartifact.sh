#!/bin/bash

# Usage:
# ./configure_codeartifact.sh

# === FIXED CONFIGURATION ===
AWS_REGION="eu-west-1"
DOMAIN="qoro-quantum"
REPOSITORY="divi"
ACCOUNT_ID="982534369690"

# === CHECK FOR VALID AWS CREDENTIALS ===
echo "🔍 Checking AWS credentials..."

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured or invalid."
    echo "Please run 'aws configure' first and try again."
    exit 1
fi

echo "✅ AWS credentials are valid."

# === GET AUTH TOKEN ===
echo "🔐 Retrieving CodeArtifact auth token..."
export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
  --domain "$DOMAIN" \
  --domain-owner "$ACCOUNT_ID" \
  --query authorizationToken \
  --output text)

if [[ -z "$CODEARTIFACT_AUTH_TOKEN" ]]; then
    echo "❌ Failed to retrieve authorization token."
    exit 1
fi

echo "🔑 Authorization token retrieved."

# === LOGIN TO PIP (For tools that may use pip under the hood) ===
if command -v pip &> /dev/null; then
    echo "🔌 Logging in to pip..."
    if ! aws codeartifact login --tool pip --domain "$DOMAIN" --repository "$REPOSITORY" --domain-owner "$ACCOUNT_ID"; then
        echo "⚠️  Warning: pip login failed. Proceeding anyway for poetry/uv/pipenv users."
    else
        echo "✅ pip login successful."
    fi
else
    echo "⚠️  pip not found. Skipping pip login."
fi
# === SET REPO URL ===
export CODEARTIFACT_REPO_URL="https://$DOMAIN-$ACCOUNT_ID.d.codeartifact.$AWS_REGION.amazonaws.com/pypi/$REPOSITORY/simple/"

echo "📦 CodeArtifact repository URL: $CODEARTIFACT_REPO_URL"

if command -v poetry &> /dev/null; then
    export POETRY_HTTP_BASIC_CODEARTIFACT_USERNAME=aws
    export POETRY_HTTP_BASIC_CODEARTIFACT_PASSWORD="$CODEARTIFACT_AUTH_TOKEN"
    poetry source add codeartifact $CODEARTIFACT_REPO_URL --priority primary
    echo "✅ poetry credentials set up successfully."
fi

if command -v uv &> /dev/null; then
    export UV_INDEX_CODEARTIFACT_USERNAME=aws
    export UV_INDEX_CODEARTIFACT_PASSWORD="$CODEARTIFACT_AUTH_TOKEN"
    
    # Create authenticated URL for uv
    export UV_AUTHENTICATED_URL="https://aws:$CODEARTIFACT_AUTH_TOKEN@$DOMAIN-$ACCOUNT_ID.d.codeartifact.$AWS_REGION.amazonaws.com/pypi/$REPOSITORY/simple/"
    
    echo "✅ uv credentials set up successfully."
fi

# === DISPLAY INSTALLATION COMMANDS ===
echo ""
echo "🛠️  Detected tools and install instructions:"

if command -v pip &> /dev/null; then
    echo ""
    echo "📌 pip:"
    echo "   pip install --index-url \$CODEARTIFACT_REPO_URL divi"
fi

if command -v poetry &> /dev/null; then
    echo ""
    echo "📌 poetry:"
    echo "   poetry add --source codeartifact divi"
fi

if command -v uv &> /dev/null; then
    echo ""
    echo "📌 uv:"
    echo "   uv add --default-index \$UV_AUTHENTICATED_URL divi"
fi

if command -v pipenv &> /dev/null; then
    echo ""
    echo "📌 pipenv:"
    echo "   PIP_INDEX_URL=\$CODEARTIFACT_REPO_URL pipenv install divi"
fi

echo ""
echo "⚠️  Note: The auth token is valid for 12 hours. Re-run this script if authentication expires."

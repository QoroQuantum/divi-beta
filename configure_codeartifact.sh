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

echo "🔑 Authorization token retrieved."
echo "📦 CodeArtifact repository URL: $CODEARTIFACT_REPO_URL"

# === DISPLAY INSTALLATION COMMANDS ===
echo ""
echo "📥 CodeArtifact repository configured successfully!"
echo ""
echo "🛠️  Detected tools and install instructions:"

if command -v pip &> /dev/null; then
    echo ""
    echo "📌 pip:"
    echo "   pip install divi  # (already configured via aws codeartifact login)"
    echo "   # If the above fails, try:"
    echo "   pip install --extra-index-url $CODEARTIFACT_REPO_URL --extra-index-url https://pypi.org/simple/ divi"
fi

if command -v poetry &> /dev/null; then
    echo ""
    echo "📌 poetry:"
    echo "   poetry source add codeartifact $CODEARTIFACT_REPO_URL || true"
    echo "   poetry add divi"
fi

if command -v uv &> /dev/null; then
    echo ""
    echo "📌 uv:"
    echo "   uv add --extra-index-url $CODEARTIFACT_REPO_URL --extra-index-url https://pypi.org/simple/ divi"
fi

if command -v pipenv &> /dev/null; then
    echo ""
    echo "📌 pipenv:"
    echo "   pipenv install --extra-index-url $CODEARTIFACT_REPO_URL --extra-index-url https://pypi.org/simple/ divi"
fi

if command -v conda &> /dev/null || command -v mamba &> /dev/null; then
    echo ""
    echo "📌 conda/mamba (via pip fallback):"
    echo "   pip install --extra-index-url $CODEARTIFACT_REPO_URL --extra-index-url https://pypi.org/simple/ divi"
fi

echo ""
echo "⚠️  Note: The auth token is valid for 12 hours. Re-run this script if authentication expires."

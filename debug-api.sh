#!/bin/bash

# GitHub API Debug Script
# Tests various endpoints to diagnose billing API issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  GitHub API Debug Script                                   ║${NC}"
echo -e "${BLUE}║  Diagnose Copilot billing API issues                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Load token from .env file
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
    echo -e "${GREEN}✓ Loaded .env file${NC}"
else
    echo -e "${RED}✗ No .env file found${NC}"
    echo ""
    echo "Create a .env file with:"
    echo "  GITHUB_TOKEN=your_token_here"
    echo "  GITHUB_USERNAME=your_username"
    echo ""
    exit 1
fi

# Validate required variables
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}✗ GITHUB_TOKEN not set in .env${NC}"
    exit 1
fi

if [ -z "$GITHUB_USERNAME" ]; then
    echo -e "${RED}✗ GITHUB_USERNAME not set in .env${NC}"
    exit 1
fi

echo -e "${CYAN}Username: ${GITHUB_USERNAME}${NC}"
echo -e "${CYAN}Token: ${GITHUB_TOKEN:0:10}...${NC}"
echo ""

# Common headers
AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
ACCEPT_HEADER="Accept: application/vnd.github+json"
API_VERSION="X-GitHub-Api-Version: 2022-11-28"

# Function to make API call and display results
api_call() {
    local description="$1"
    local endpoint="$2"
    local expected_status="${3:-200}"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}TEST: ${description}${NC}"
    echo -e "${CYAN}GET ${endpoint}${NC}"
    echo ""
    
    # Make the request and capture response + status code
    HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        -H "$API_VERSION" \
        "https://api.github.com${endpoint}")
    
    HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')
    HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n 1)
    
    # Display status
    if [ "$HTTP_STATUS" = "$expected_status" ] || [ "$HTTP_STATUS" = "200" ]; then
        echo -e "${GREEN}✓ Status: ${HTTP_STATUS}${NC}"
    else
        echo -e "${RED}✗ Status: ${HTTP_STATUS} (expected ${expected_status})${NC}"
    fi
    
    # Pretty print JSON if jq is available
    if command -v jq &> /dev/null; then
        echo "$HTTP_BODY" | jq '.' 2>/dev/null || echo "$HTTP_BODY"
    else
        echo "$HTTP_BODY"
    fi
    echo ""
}

# Function to check token scopes
check_token_scopes() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}TEST: Check Token Scopes & Permissions${NC}"
    echo ""
    
    # Make request and capture headers
    HEADERS=$(curl -s -I \
        -H "$AUTH_HEADER" \
        -H "$ACCEPT_HEADER" \
        -H "$API_VERSION" \
        "https://api.github.com/user")
    
    # Extract relevant headers
    SCOPES=$(echo "$HEADERS" | grep -i "x-oauth-scopes:" | cut -d: -f2- | tr -d '\r')
    RATE_LIMIT=$(echo "$HEADERS" | grep -i "x-ratelimit-limit:" | cut -d: -f2- | tr -d '\r')
    TOKEN_TYPE=$(echo "$HEADERS" | grep -i "x-github-authentication-token-type:" | cut -d: -f2- | tr -d '\r')
    
    echo -e "${CYAN}Token Type:${NC}$TOKEN_TYPE"
    echo -e "${CYAN}OAuth Scopes:${NC}$SCOPES"
    echo -e "${CYAN}Rate Limit:${NC}$RATE_LIMIT"
    
    if [ -z "$SCOPES" ] || [ "$SCOPES" = " " ]; then
        echo -e "${YELLOW}Note: No scopes shown - this is normal for Fine-grained tokens${NC}"
        echo -e "${YELLOW}Fine-grained tokens use permissions instead of scopes${NC}"
    fi
    echo ""
}

echo ""
echo -e "${BLUE}Starting API tests...${NC}"
echo ""

# Test 1: Verify token works - get authenticated user
api_call "Verify Token - Get Authenticated User" "/user"

# Test 2: Check token scopes/permissions
check_token_scopes

# Test 3: Get user's Copilot subscription status
api_call "Copilot Subscription Status (user)" "/user/copilot_seat"

# Test 4: The main billing endpoint we're trying to use
api_call "Premium Request Usage (user)" "/users/${GITHUB_USERNAME}/settings/billing/premium_request/usage"

# Test 5: Try the general billing usage endpoint
api_call "General Billing Usage (user)" "/users/${GITHUB_USERNAME}/settings/billing/usage"

# Test 6: Try the billing usage summary endpoint
api_call "Billing Usage Summary (user)" "/users/${GITHUB_USERNAME}/settings/billing/usage/summary"

# Test 7: List user's organizations (to check if Copilot might be org-managed)
api_call "List User Organizations" "/user/orgs"

# Test 8: Get user's Copilot settings/status
api_call "User Copilot Settings" "/user/copilot"

# Test 9: Check if user has access to Copilot (alternative endpoint)
api_call "User GitHub Copilot Info" "/users/${GITHUB_USERNAME}/settings/copilot"

# Test 10: List billing settings
api_call "User Settings" "/users/${GITHUB_USERNAME}/settings"

# Test 11: Check rate limit status (useful for debugging)
api_call "Rate Limit Status" "/rate_limit"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "If most endpoints return 404, the issue is likely:"
echo "  1. The billing API requires specific account access"
echo "  2. Your Copilot might be through an organization"
echo "  3. The premium_request endpoint might not be available for your plan"
echo ""
echo "If you see organization data, try the org billing endpoint:"
echo "  GET /organizations/{org}/settings/billing/premium_request/usage"
echo ""
echo -e "${YELLOW}Share the output above to help diagnose the issue!${NC}"
echo ""

#!/bin/bash
#
# Test script for WhatsApp Self-Registration feature
# Usage: ./test-registration.sh [base_url] [api_key]
#
# Examples:
#   ./test-registration.sh  # Uses emulator defaults
#   ./test-registration.sh "https://api.praticos.app" "your-api-key"
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${1:-http://localhost:5001/praticos/southamerica-east1/api}"
API_KEY="${2:-test-api-key}"
# Generate a unique test phone number
TEST_PHONE="+5511$(date +%s | tail -c 10)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  WhatsApp Self-Registration Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Base URL: ${YELLOW}$BASE_URL${NC}"
echo -e "API Key:  ${YELLOW}${API_KEY:0:10}...${NC}"
echo -e "Test Phone: ${YELLOW}$TEST_PHONE${NC}"
echo ""

# Helper function to make API calls
api_call() {
  local method=$1
  local endpoint=$2
  local data=$3

  local url="$BASE_URL$endpoint"
  local headers="-H 'X-API-Key: $API_KEY' -H 'X-WhatsApp-Number: $TEST_PHONE' -H 'Content-Type: application/json'"

  if [ -n "$data" ]; then
    eval "curl -s -X $method $headers -d '$data' '$url'"
  else
    eval "curl -s -X $method $headers '$url'"
  fi
}

# Helper function to check response
check_response() {
  local response=$1
  local expected_success=$2
  local step_name=$3

  local success=$(echo "$response" | jq -r '.success')

  if [ "$success" == "$expected_success" ]; then
    echo -e "${GREEN}✓ $step_name${NC}"
    return 0
  else
    echo -e "${RED}✗ $step_name${NC}"
    echo -e "${RED}Response: $response${NC}"
    return 1
  fi
}

# Helper function to extract value from JSON
get_value() {
  local json=$1
  local path=$2
  echo "$json" | jq -r "$path"
}

echo -e "${YELLOW}Step 0: Check initial context${NC}"
echo "----------------------------------------"
RESPONSE=$(api_call "GET" "/bot/link/context")
echo "$RESPONSE" | jq .
LINKED=$(get_value "$RESPONSE" '.data.linked')
if [ "$LINKED" == "false" ]; then
  echo -e "${GREEN}✓ Phone is not linked (as expected)${NC}"
else
  echo -e "${RED}✗ Phone is already linked! Use a different test phone.${NC}"
  exit 1
fi
echo ""

echo -e "${YELLOW}Step 1: Start registration${NC}"
echo "----------------------------------------"
RESPONSE=$(api_call "POST" "/bot/registration/start" '{"locale":"pt-BR"}')
echo "$RESPONSE" | jq .
check_response "$RESPONSE" "true" "Registration started"
TOKEN=$(get_value "$RESPONSE" '.data.token')
STATE=$(get_value "$RESPONSE" '.data.state')
SEGMENTS_COUNT=$(get_value "$RESPONSE" '.data.segments | length')
echo -e "Token: ${BLUE}$TOKEN${NC}"
echo -e "State: ${BLUE}$STATE${NC}"
echo -e "Segments available: ${BLUE}$SEGMENTS_COUNT${NC}"

# Get first segment ID for testing
FIRST_SEGMENT_ID=$(get_value "$RESPONSE" '.data.segments[0].id')
FIRST_SEGMENT_NAME=$(get_value "$RESPONSE" '.data.segments[0].name')
HAS_SUBSPECIALTIES=$(get_value "$RESPONSE" '.data.segments[0].hasSubspecialties')
echo -e "First segment: ${BLUE}$FIRST_SEGMENT_NAME ($FIRST_SEGMENT_ID)${NC}"
echo ""

echo -e "${YELLOW}Step 2: Set company name${NC}"
echo "----------------------------------------"
COMPANY_NAME="Empresa Teste $(date +%H%M%S)"
RESPONSE=$(api_call "POST" "/bot/registration/update" "{\"companyName\":\"$COMPANY_NAME\"}")
echo "$RESPONSE" | jq .
check_response "$RESPONSE" "true" "Company name set"
STATE=$(get_value "$RESPONSE" '.data.state')
echo -e "New state: ${BLUE}$STATE${NC}"
echo ""

echo -e "${YELLOW}Step 3: Select segment${NC}"
echo "----------------------------------------"
RESPONSE=$(api_call "POST" "/bot/registration/update" "{\"segmentId\":\"$FIRST_SEGMENT_ID\"}")
echo "$RESPONSE" | jq .
check_response "$RESPONSE" "true" "Segment selected"
STATE=$(get_value "$RESPONSE" '.data.state')
echo -e "New state: ${BLUE}$STATE${NC}"

# Check if we need to handle subspecialties
if [ "$STATE" == "awaiting_subspecialties" ]; then
  echo ""
  echo -e "${YELLOW}Step 3.1: Select subspecialties${NC}"
  echo "----------------------------------------"
  # Get first subspecialty ID
  FIRST_SUBSPECIALTY=$(get_value "$RESPONSE" '.data.subspecialties[0].id')
  if [ "$FIRST_SUBSPECIALTY" != "null" ] && [ -n "$FIRST_SUBSPECIALTY" ]; then
    RESPONSE=$(api_call "POST" "/bot/registration/update" "{\"subspecialties\":[\"$FIRST_SUBSPECIALTY\"]}")
  else
    RESPONSE=$(api_call "POST" "/bot/registration/update" '{"subspecialties":[]}')
  fi
  echo "$RESPONSE" | jq .
  check_response "$RESPONSE" "true" "Subspecialties selected"
  STATE=$(get_value "$RESPONSE" '.data.state')
  echo -e "New state: ${BLUE}$STATE${NC}"
fi
echo ""

echo -e "${YELLOW}Step 4: Choose bootstrap option${NC}"
echo "----------------------------------------"
RESPONSE=$(api_call "POST" "/bot/registration/update" '{"includeBootstrap":true}')
echo "$RESPONSE" | jq .
check_response "$RESPONSE" "true" "Bootstrap option set"
STATE=$(get_value "$RESPONSE" '.data.state')
echo -e "New state: ${BLUE}$STATE${NC}"

# Show summary
SUMMARY=$(get_value "$RESPONSE" '.data.summary')
echo -e "Summary: ${BLUE}$SUMMARY${NC}"
echo ""

echo -e "${YELLOW}Step 5: Check status before completing${NC}"
echo "----------------------------------------"
RESPONSE=$(api_call "GET" "/bot/registration/status")
echo "$RESPONSE" | jq .
check_response "$RESPONSE" "true" "Status retrieved"
echo ""

echo -e "${YELLOW}Step 6: Complete registration${NC}"
echo "----------------------------------------"
RESPONSE=$(api_call "POST" "/bot/registration/complete")
echo "$RESPONSE" | jq .

SUCCESS=$(get_value "$RESPONSE" '.success')
if [ "$SUCCESS" == "true" ]; then
  echo -e "${GREEN}✓ Registration completed successfully!${NC}"
  USER_ID=$(get_value "$RESPONSE" '.data.userId')
  COMPANY_ID=$(get_value "$RESPONSE" '.data.companyId')
  BOOTSTRAP_SERVICES=$(get_value "$RESPONSE" '.data.bootstrapResult.servicesCreated // 0')
  BOOTSTRAP_PRODUCTS=$(get_value "$RESPONSE" '.data.bootstrapResult.productsCreated // 0')
  BOOTSTRAP_CUSTOMERS=$(get_value "$RESPONSE" '.data.bootstrapResult.customersCreated // 0')

  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}  Registration Summary${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo -e "User ID:      ${BLUE}$USER_ID${NC}"
  echo -e "Company ID:   ${BLUE}$COMPANY_ID${NC}"
  echo -e "Company Name: ${BLUE}$COMPANY_NAME${NC}"
  echo -e "Services:     ${BLUE}$BOOTSTRAP_SERVICES created${NC}"
  echo -e "Products:     ${BLUE}$BOOTSTRAP_PRODUCTS created${NC}"
  echo -e "Customers:    ${BLUE}$BOOTSTRAP_CUSTOMERS created${NC}"
else
  echo -e "${RED}✗ Registration failed${NC}"
  ERROR_CODE=$(get_value "$RESPONSE" '.error.code')
  ERROR_MSG=$(get_value "$RESPONSE" '.error.message')
  echo -e "Error: ${RED}$ERROR_CODE - $ERROR_MSG${NC}"
  exit 1
fi
echo ""

echo -e "${YELLOW}Step 7: Verify context after registration${NC}"
echo "----------------------------------------"
RESPONSE=$(api_call "GET" "/bot/link/context")
echo "$RESPONSE" | jq .
LINKED=$(get_value "$RESPONSE" '.data.linked')
if [ "$LINKED" == "true" ]; then
  echo -e "${GREEN}✓ Phone is now linked!${NC}"
  LINKED_USER=$(get_value "$RESPONSE" '.data.userName')
  LINKED_COMPANY=$(get_value "$RESPONSE" '.data.companyName')
  LINKED_ROLE=$(get_value "$RESPONSE" '.data.role')
  echo -e "User: ${BLUE}$LINKED_USER${NC}"
  echo -e "Company: ${BLUE}$LINKED_COMPANY${NC}"
  echo -e "Role: ${BLUE}$LINKED_ROLE${NC}"
else
  echo -e "${RED}✗ Phone is not linked after registration!${NC}"
  exit 1
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  All tests passed! ✓${NC}"
echo -e "${GREEN}========================================${NC}"

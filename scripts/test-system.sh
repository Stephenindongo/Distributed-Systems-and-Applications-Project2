#!/bin/bash

# Windhoek Transport System - Complete System Test
# This script performs end-to-end testing of the entire system

echo "🧪 Windhoek Transport System - Complete Test Suite"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_status="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to test API endpoint
test_api() {
    local service_name="$1"
    local endpoint="$2"
    local method="${3:-GET}"
    local data="$4"
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "$data" "$endpoint" > /dev/null
    else
        curl -s -f "$endpoint" > /dev/null
    fi
}

echo ""
echo "🔍 Infrastructure Tests"
echo "----------------------"

# Test Docker containers
run_test "Docker containers running" "docker-compose ps | grep -q 'Up'"

# Test database connection
run_test "MySQL database accessible" "docker exec mysql mysql -u transport_user -ptransport_password -e 'SELECT 1;'"

# Test Kafka
run_test "Kafka broker accessible" "docker exec kafka kafka-topics --list --bootstrap-server localhost:9092"

echo ""
echo "🚌 Microservices Tests"
echo "----------------------"

# Test Passenger Service
run_test "Passenger Service - Routes endpoint" "test_api 'Passenger Service' 'http://localhost:8081/api/v1/passengers'"

# Test Transport Service
run_test "Transport Service - Routes endpoint" "test_api 'Transport Service' 'http://localhost:8082/api/v1/transport/routes'"
run_test "Transport Service - Trips endpoint" "test_api 'Transport Service' 'http://localhost:8082/api/v1/transport/trips'"
run_test "Transport Service - Search endpoint" "test_api 'Transport Service' 'http://localhost:8082/api/v1/transport/search?query=Katutura'"

# Test Ticketing Service
run_test "Ticketing Service - Endpoint accessible" "test_api 'Ticketing Service' 'http://localhost:8083/api/v1/tickets'"

# Test Payment Service
run_test "Payment Service - Endpoint accessible" "test_api 'Payment Service' 'http://localhost:8084/api/v1/payments'"

# Test Notification Service
run_test "Notification Service - Endpoint accessible" "test_api 'Notification Service' 'http://localhost:8085/api/v1/notifications'"

# Test Admin Service
run_test "Admin Service - Endpoint accessible" "test_api 'Admin Service' 'http://localhost:8086/api/v1/admin'"

echo ""
echo "👤 User Journey Tests"
echo "-------------------"

# Test user registration
echo "Testing user registration..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/passengers/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "password123",
    "firstName": "Test",
    "lastName": "User",
    "phone": "+264811234567"
  }')

if echo "$REGISTER_RESPONSE" | grep -q "registered successfully"; then
    echo -e "User Registration: ${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "User Registration: ${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Test user login
echo "Testing user login..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/passengers/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "password123"
  }')

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
    echo -e "User Login: ${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Extract token for further tests
    TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
else
    echo -e "User Login: ${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Test route search
echo "Testing route search..."
ROUTE_RESPONSE=$(curl -s "http://localhost:8082/api/v1/transport/routes")

if echo "$ROUTE_RESPONSE" | grep -q "routes"; then
    echo -e "Route Search: ${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "Route Search: ${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Test trip search
echo "Testing trip search..."
TRIP_RESPONSE=$(curl -s "http://localhost:8082/api/v1/transport/trips")

if echo "$TRIP_RESPONSE" | grep -q "trips"; then
    echo -e "Trip Search: ${GREEN}✅ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "Trip Search: ${RED}❌ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Test ticket creation (if we have a token)
if [ -n "$TOKEN" ]; then
    echo "Testing ticket creation..."
    TICKET_RESPONSE=$(curl -s -X POST http://localhost:8083/api/v1/tickets/ \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d '{
        "tripId": 1,
        "ticketType": "SINGLE_RIDE"
      }')
    
    if echo "$TICKET_RESPONSE" | grep -q "created successfully"; then
        echo -e "Ticket Creation: ${GREEN}✅ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "Ticket Creation: ${RED}❌ FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

echo ""
echo "📊 Database Tests"
echo "----------------"

# Test database tables
run_test "Users table exists" "docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e 'SELECT COUNT(*) FROM users;'"
run_test "Routes table exists" "docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e 'SELECT COUNT(*) FROM routes;'"
run_test "Trips table exists" "docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e 'SELECT COUNT(*) FROM trips;'"
run_test "Tickets table exists" "docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e 'SELECT COUNT(*) FROM tickets;'"
run_test "Payments table exists" "docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e 'SELECT COUNT(*) FROM payments;'"

echo ""
echo "📨 Kafka Tests"
echo "-------------"

# Test Kafka topics
run_test "Kafka topics exist" "docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 | grep -q user-registration"
run_test "Kafka topics exist" "docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 | grep -q ticket-created"
run_test "Kafka topics exist" "docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 | grep -q payment-completed"

echo ""
echo "🔧 Performance Tests"
echo "--------------------"

# Test response times
echo "Testing response times..."

# Test transport service response time
TRANSPORT_TIME=$(curl -s -w "%{time_total}" -o /dev/null "http://localhost:8082/api/v1/transport/routes")
if (( $(echo "$TRANSPORT_TIME < 2.0" | bc -l) )); then
    echo -e "Transport Service Response Time (${TRANSPORT_TIME}s): ${GREEN}✅ GOOD${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "Transport Service Response Time (${TRANSPORT_TIME}s): ${YELLOW}⚠️  SLOW${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Test passenger service response time
PASSENGER_TIME=$(curl -s -w "%{time_total}" -o /dev/null "http://localhost:8081/api/v1/passengers")
if (( $(echo "$PASSENGER_TIME < 2.0" | bc -l) )); then
    echo -e "Passenger Service Response Time (${PASSENGER_TIME}s): ${GREEN}✅ GOOD${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "Passenger Service Response Time (${PASSENGER_TIME}s): ${YELLOW}⚠️  SLOW${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""
echo "📈 System Statistics"
echo "--------------------"

echo "📦 Container Status:"
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "💾 Database Statistics:"
docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e "
SELECT 
    'Users' as table_name, COUNT(*) as count FROM users
UNION ALL
SELECT 
    'Routes' as table_name, COUNT(*) as count FROM routes  
UNION ALL
SELECT 
    'Trips' as table_name, COUNT(*) as count FROM trips
UNION ALL
SELECT 
    'Tickets' as table_name, COUNT(*) as count FROM tickets
UNION ALL
SELECT 
    'Payments' as table_name, COUNT(*) as count FROM payments;
"

echo ""
echo "📨 Kafka Topics:"
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

echo ""
echo "🏥 Test Results Summary"
echo "======================"
echo "Total Tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! System is fully operational.${NC}"
    exit 0
elif [ $TESTS_PASSED -gt $TESTS_FAILED ]; then
    echo -e "${YELLOW}⚠️  Most tests passed. Some issues detected.${NC}"
    exit 1
else
    echo -e "${RED}🚨 Many tests failed. System needs attention.${NC}"
    exit 2
fi

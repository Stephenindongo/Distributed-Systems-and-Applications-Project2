#!/bin/bash

# Windhoek Transport System - Quick Start Script
# This script provides a one-click setup for the entire system

echo "🚀 Windhoek Transport System - Quick Start"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print step
print_step() {
    echo -e "${BLUE}Step $1: $2${NC}"
}

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
    else
        echo -e "${RED}❌ FAILED${NC}"
        exit 1
    fi
}

echo ""
echo "🏗️  System Architecture Overview"
echo "================================="
echo "• 6 Microservices (Ballerina)"
echo "• MySQL Database"
echo "• Apache Kafka (10 topics)"
echo "• Docker & Docker Compose"
echo "• JWT Authentication"
echo "• Comprehensive Monitoring"
echo ""

echo "📋 Prerequisites Check"
echo "====================="

# Check Docker
print_step "1" "Checking Docker installation..."
if command -v docker > /dev/null 2>&1; then
    echo -e "Docker: ${GREEN}✅ INSTALLED${NC}"
else
    echo -e "Docker: ${RED}❌ NOT FOUND${NC}"
    echo "Please install Docker Desktop for Windows"
    exit 1
fi

# Check Docker Compose
print_step "2" "Checking Docker Compose..."
if command -v docker-compose > /dev/null 2>&1; then
    echo -e "Docker Compose: ${GREEN}✅ INSTALLED${NC}"
else
    echo -e "Docker Compose: ${RED}❌ NOT FOUND${NC}"
    echo "Please install Docker Compose"
    exit 1
fi

# Check if Docker is running
print_step "3" "Checking Docker daemon..."
if docker info > /dev/null 2>&1; then
    echo -e "Docker daemon: ${GREEN}✅ RUNNING${NC}"
else
    echo -e "Docker daemon: ${RED}❌ NOT RUNNING${NC}"
    echo "Please start Docker Desktop"
    exit 1
fi

echo ""
echo "🚀 Starting Infrastructure"
echo "============================"

# Start infrastructure services
print_step "1" "Starting MySQL database..."
docker-compose up -d mysql
check_success

print_step "2" "Starting Kafka and Zookeeper..."
docker-compose up -d zookeeper kafka
check_success

# Wait for services to be ready
print_step "3" "Waiting for services to initialize..."
echo "⏳ This may take 2-3 minutes..."
sleep 120

# Check if services are ready
print_step "4" "Verifying infrastructure services..."
if docker exec mysql mysql -u transport_user -ptransport_password -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "MySQL: ${GREEN}✅ READY${NC}"
else
    echo -e "MySQL: ${RED}❌ NOT READY${NC}"
    echo "Please wait a bit longer and try again"
    exit 1
fi

if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > /dev/null 2>&1; then
    echo -e "Kafka: ${GREEN}✅ READY${NC}"
else
    echo -e "Kafka: ${RED}❌ NOT READY${NC}"
    echo "Please wait a bit longer and try again"
    exit 1
fi

echo ""
echo "📨 Setting up Kafka Topics"
echo "==========================="

print_step "1" "Creating Kafka topics..."
if [ -f "./kafka-topics.sh" ]; then
    chmod +x ./kafka-topics.sh
    ./kafka-topics.sh
    check_success
else
    echo "Creating topics manually..."
    docker exec kafka kafka-topics --create --topic user-registration --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic user-login --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic ticket-created --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic ticket-validated --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic ticket-cancelled --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic payment-completed --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic payment-failed --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic payment-refunded --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic trip-status-update --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    docker exec kafka kafka-topics --create --topic service-disruption --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
    check_success
fi

echo ""
echo "🚌 Starting Microservices"
echo "========================="

print_step "1" "Starting Passenger Service (Port 8081)..."
docker-compose up -d passenger-service
check_success

print_step "2" "Starting Transport Service (Port 8082)..."
docker-compose up -d transport-service
check_success

print_step "3" "Starting Ticketing Service (Port 8083)..."
docker-compose up -d ticketing-service
check_success

print_step "4" "Starting Payment Service (Port 8084)..."
docker-compose up -d payment-service
check_success

print_step "5" "Starting Notification Service (Port 8085)..."
docker-compose up -d notification-service
check_success

print_step "6" "Starting Admin Service (Port 8086)..."
docker-compose up -d admin-service
check_success

# Wait for services to be ready
print_step "7" "Waiting for services to initialize..."
echo "⏳ This may take 3-5 minutes..."
sleep 180

echo ""
echo "🔍 System Health Check"
echo "====================="

print_step "1" "Checking all services..."
SERVICES_RUNNING=$(docker-compose ps --services --filter "status=running" | wc -l)
TOTAL_SERVICES=$(docker-compose ps --services | wc -l)

echo "Services running: $SERVICES_RUNNING/$TOTAL_SERVICES"

if [ $SERVICES_RUNNING -eq $TOTAL_SERVICES ]; then
    echo -e "Service status: ${GREEN}✅ ALL RUNNING${NC}"
else
    echo -e "Service status: ${YELLOW}⚠️  SOME SERVICES DOWN${NC}"
    echo "Please check: docker-compose ps"
fi

print_step "2" "Testing API endpoints..."

# Test transport service
if curl -s -f "http://localhost:8082/api/v1/transport/routes" > /dev/null 2>&1; then
    echo -e "Transport Service: ${GREEN}✅ HEALTHY${NC}"
else
    echo -e "Transport Service: ${RED}❌ UNHEALTHY${NC}"
fi

# Test passenger service
if curl -s -f "http://localhost:8081/api/v1/passengers" > /dev/null 2>&1; then
    echo -e "Passenger Service: ${GREEN}✅ HEALTHY${NC}"
else
    echo -e "Passenger Service: ${RED}❌ UNHEALTHY${NC}"
fi

print_step "3" "Verifying database..."
if docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e "SELECT COUNT(*) FROM routes;" > /dev/null 2>&1; then
    echo -e "Database: ${GREEN}✅ HEALTHY${NC}"
else
    echo -e "Database: ${RED}❌ UNHEALTHY${NC}"
fi

echo ""
echo "📊 System Overview"
echo "================="

echo "📦 Container Status:"
docker-compose ps

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
echo "🎯 Quick Test Commands"
echo "===================="

echo "Test Transport Service:"
echo "curl http://localhost:8082/api/v1/transport/routes"
echo ""

echo "Test Passenger Service:"
echo "curl http://localhost:8081/api/v1/passengers"
echo ""

echo "Register a user:"
echo "curl -X POST http://localhost:8081/api/v1/passengers/register \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"email\":\"test@example.com\",\"password\":\"password123\",\"firstName\":\"John\",\"lastName\":\"Doe\",\"phone\":\"+264811234567\"}'"
echo ""

echo "Login user:"
echo "curl -X POST http://localhost:8081/api/v1/passengers/login \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"email\":\"test@example.com\",\"password\":\"password123\"}'"
echo ""

echo "🔧 Useful Commands"
echo "================="

echo "View logs:"
echo "docker-compose logs -f"
echo ""

echo "Check service health:"
echo "./scripts/health-check.sh"
echo ""

echo "Run system tests:"
echo "./scripts/test-system.sh"
echo ""

echo "Start monitoring:"
echo "./start-monitoring.sh"
echo ""

echo "Stop system:"
echo "docker-compose down"
echo ""

echo "🎉 System Ready!"
echo "==============="

echo -e "${GREEN}🎉 Windhoek Transport System is now running!${NC}"
echo ""
echo "🌐 Access URLs:"
echo "  • Passenger Service: http://localhost:8081"
echo "  • Transport Service: http://localhost:8082"
echo "  • Ticketing Service: http://localhost:8083"
echo "  • Payment Service: http://localhost:8084"
echo "  • Notification Service: http://localhost:8085"
echo "  • Admin Service: http://localhost:8086"
echo ""
echo "📚 Documentation:"
echo "  • README.md - Complete system overview"
echo "  • SETUP_GUIDE.md - Detailed setup instructions"
echo "  • COMMANDS.md - Command reference"
echo "  • PROJECT_SUMMARY.md - Project summary"
echo ""
echo "🚀 Next Steps:"
echo "  1. Test the system with the commands above"
echo "  2. Register a user and explore the APIs"
echo "  3. Start monitoring for production use"
echo "  4. Check the documentation for advanced features"
echo ""
echo -e "${PURPLE}Happy coding with Windhoek Transport System! 🚌✨${NC}"

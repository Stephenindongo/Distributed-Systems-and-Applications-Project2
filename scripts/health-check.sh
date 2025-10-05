#!/bin/bash

# Windhoek Transport System - Health Check Script
# This script checks the health of all services in the system

echo "🏥 Windhoek Transport System Health Check"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check service health
check_service() {
    local service_name=$1
    local port=$2
    local endpoint=$3
    
    echo -n "Checking $service_name on port $port... "
    
    if curl -s -f "http://localhost:$port$endpoint" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}❌ UNHEALTHY${NC}"
        return 1
    fi
}

# Function to check database connection
check_database() {
    echo -n "Checking MySQL database... "
    
    if docker exec mysql mysql -u transport_user -ptransport_password -e "SELECT 1;" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}❌ UNHEALTHY${NC}"
        return 1
    fi
}

# Function to check Kafka
check_kafka() {
    echo -n "Checking Kafka broker... "
    
    if docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}❌ UNHEALTHY${NC}"
        return 1
    fi
}

# Function to check Docker containers
check_containers() {
    echo -n "Checking Docker containers... "
    
    local unhealthy_containers=$(docker-compose ps --services --filter "status=unhealthy" | wc -l)
    
    if [ $unhealthy_containers -eq 0 ]; then
        echo -e "${GREEN}✅ ALL HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}❌ $unhealthy_containers UNHEALTHY${NC}"
        return 1
    fi
}

# Main health check
echo ""
echo "🔍 Infrastructure Health Check"
echo "------------------------------"

# Check Docker containers
check_containers

# Check database
check_database

# Check Kafka
check_kafka

echo ""
echo "🚌 Microservices Health Check"
echo "-----------------------------"

# Check each microservice
check_service "Passenger Service" 8081 "/api/v1/passengers/routes" || check_service "Passenger Service" 8081 "/api/v1/passengers"
check_service "Transport Service" 8082 "/api/v1/transport/routes"
check_service "Ticketing Service" 8083 "/api/v1/tickets"
check_service "Payment Service" 8084 "/api/v1/payments"
check_service "Notification Service" 8085 "/api/v1/notifications"
check_service "Admin Service" 8086 "/api/v1/admin"

echo ""
echo "📊 System Statistics"
echo "--------------------"

# Get container stats
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
echo "🔗 Network Connectivity:"
echo -n "Testing localhost connectivity... "
if ping -c 1 localhost > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
fi

echo ""
echo "📈 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo ""
echo "🏥 Health Check Summary"
echo "======================="

# Count healthy services
healthy_count=0
total_services=6

if check_service "Passenger Service" 8081 "/api/v1/passengers" > /dev/null 2>&1; then ((healthy_count++)); fi
if check_service "Transport Service" 8082 "/api/v1/transport/routes" > /dev/null 2>&1; then ((healthy_count++)); fi
if check_service "Ticketing Service" 8083 "/api/v1/tickets" > /dev/null 2>&1; then ((healthy_count++)); fi
if check_service "Payment Service" 8084 "/api/v1/payments" > /dev/null 2>&1; then ((healthy_count++)); fi
if check_service "Notification Service" 8085 "/api/v1/notifications" > /dev/null 2>&1; then ((healthy_count++)); fi
if check_service "Admin Service" 8086 "/api/v1/admin" > /dev/null 2>&1; then ((healthy_count++)); fi

echo "Services Healthy: $healthy_count/$total_services"

if [ $healthy_count -eq $total_services ]; then
    echo -e "${GREEN}🎉 All systems operational!${NC}"
    exit 0
elif [ $healthy_count -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some services are down. Check logs for details.${NC}"
    exit 1
else
    echo -e "${RED}🚨 System is down! Please check Docker and restart services.${NC}"
    exit 2
fi

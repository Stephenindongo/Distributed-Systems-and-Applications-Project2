#!/bin/bash

# Windhoek Transport System - Restore Script
# This script restores the system from a backup

echo "🔄 Windhoek Transport System - Restore Script"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if backup file is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    echo "Example: $0 backups/windhoek_transport_backup_20240115_143022.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo "📁 Restore Configuration:"
echo "  Backup File: $BACKUP_FILE"
echo "  Current Directory: $(pwd)"
echo ""

# Extract backup
echo "📦 Extracting Backup"
echo "--------------------"

BACKUP_DIR="./restore_temp"
mkdir -p "$BACKUP_DIR"

echo "Extracting backup archive..."
if tar -xzf "$BACKUP_FILE" -C "$BACKUP_DIR"; then
    echo -e "Extraction: ${GREEN}✅ SUCCESS${NC}"
else
    echo -e "Extraction: ${RED}❌ FAILED${NC}"
    exit 1
fi

# Find the extracted directory
EXTRACTED_DIR=$(find "$BACKUP_DIR" -type d -name "windhoek_transport_backup_*" | head -1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}❌ Could not find extracted backup directory${NC}"
    exit 1
fi

echo "Found backup directory: $EXTRACTED_DIR"

echo ""
echo "🛑 Stopping Current System"
echo "--------------------------"

# Stop current system
echo "Stopping current services..."
docker-compose down

echo ""
echo "🗄️  Database Restore"
echo "-------------------"

# Start infrastructure services first
echo "Starting infrastructure services..."
docker-compose up -d mysql kafka

# Wait for services to be ready
echo "Waiting for services to be ready..."
sleep 30

# Check if database is accessible
echo "Checking database connectivity..."
if docker exec mysql mysql -u transport_user -ptransport_password -e "SELECT 1;" > /dev/null 2>&1; then
    echo -e "Database connectivity: ${GREEN}✅ SUCCESS${NC}"
else
    echo -e "Database connectivity: ${RED}❌ FAILED${NC}"
    echo "Please ensure MySQL is running and accessible"
    exit 1
fi

# Restore database
echo "Restoring database..."
if docker exec -i mysql mysql -u transport_user -ptransport_password transport_ticketing < "$EXTRACTED_DIR/database.sql"; then
    echo -e "Database restore: ${GREEN}✅ SUCCESS${NC}"
else
    echo -e "Database restore: ${RED}❌ FAILED${NC}"
    echo "Please check the database backup file"
    exit 1
fi

echo ""
echo "📦 Container Restore"
echo "-------------------"

# Restore Docker Compose configuration if different
if [ -f "$EXTRACTED_DIR/docker-compose.yml" ]; then
    echo "Restoring Docker Compose configuration..."
    cp "$EXTRACTED_DIR/docker-compose.yml" ./docker-compose.yml
    echo -e "Docker Compose config: ${GREEN}✅ SUCCESS${NC}"
fi

# Restore container images if available
if [ -f "$EXTRACTED_DIR/container_images.tar" ]; then
    echo "Restoring container images..."
    if docker load -i "$EXTRACTED_DIR/container_images.tar"; then
        echo -e "Container images: ${GREEN}✅ SUCCESS${NC}"
    else
        echo -e "Container images: ${YELLOW}⚠️  PARTIAL${NC}"
    fi
fi

echo ""
echo "📁 Application Code Restore"
echo "--------------------------"

# Restore application code
echo "Restoring application code..."
if [ -d "$EXTRACTED_DIR/services" ]; then
    cp -r "$EXTRACTED_DIR/services" ./
    echo -e "Application code: ${GREEN}✅ SUCCESS${NC}"
fi

# Restore monitoring configuration
if [ -d "$EXTRACTED_DIR/monitoring" ]; then
    cp -r "$EXTRACTED_DIR/monitoring" ./
    echo -e "Monitoring config: ${GREEN}✅ SUCCESS${NC}"
fi

# Restore scripts
if [ -d "$EXTRACTED_DIR/scripts" ]; then
    cp -r "$EXTRACTED_DIR/scripts" ./
    echo -e "Scripts: ${GREEN}✅ SUCCESS${NC}"
fi

# Restore database initialization
if [ -d "$EXTRACTED_DIR/database" ]; then
    cp -r "$EXTRACTED_DIR/database" ./
    echo -e "Database init: ${GREEN}✅ SUCCESS${NC}"
fi

# Restore configuration files
for file in kafka-topics.sh start-monitoring.sh; do
    if [ -f "$EXTRACTED_DIR/$file" ]; then
        cp "$EXTRACTED_DIR/$file" ./
        chmod +x "$file"
    fi
done

echo ""
echo "🚀 Starting Services"
echo "-------------------"

# Start all services
echo "Starting all services..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 60

echo ""
echo "📨 Kafka Topics Restore"
echo "----------------------"

# Create Kafka topics
echo "Creating Kafka topics..."
if [ -f "./kafka-topics.sh" ]; then
    chmod +x ./kafka-topics.sh
    ./kafka-topics.sh
    echo -e "Kafka topics: ${GREEN}✅ SUCCESS${NC}"
else
    echo -e "Kafka topics: ${YELLOW}⚠️  MANUAL SETUP REQUIRED${NC}"
fi

echo ""
echo "🔍 System Verification"
echo "--------------------"

# Verify system health
echo "Verifying system health..."

# Check if all services are running
SERVICES_RUNNING=$(docker-compose ps --services --filter "status=running" | wc -l)
TOTAL_SERVICES=$(docker-compose ps --services | wc -l)

echo "Services running: $SERVICES_RUNNING/$TOTAL_SERVICES"

if [ $SERVICES_RUNNING -eq $TOTAL_SERVICES ]; then
    echo -e "Service status: ${GREEN}✅ ALL RUNNING${NC}"
else
    echo -e "Service status: ${YELLOW}⚠️  SOME SERVICES DOWN${NC}"
fi

# Test API endpoints
echo "Testing API endpoints..."

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

# Test database
echo "Testing database..."
if docker exec mysql mysql -u transport_user -ptransport_password transport_ticketing -e "SELECT COUNT(*) FROM users;" > /dev/null 2>&1; then
    echo -e "Database: ${GREEN}✅ HEALTHY${NC}"
else
    echo -e "Database: ${RED}❌ UNHEALTHY${NC}"
fi

echo ""
echo "📊 Restore Summary"
echo "=================="

# Display system information
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
echo "🧹 Cleanup"
echo "---------"

# Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf "$BACKUP_DIR"

echo ""
echo "🎯 Next Steps"
echo "============="

echo "1. Run health check: ./scripts/health-check.sh"
echo "2. Run system test: ./scripts/test-system.sh"
echo "3. Start monitoring: ./start-monitoring.sh"
echo "4. Test user journey:"
echo "   - Register user: curl -X POST http://localhost:8081/api/v1/passengers/register"
echo "   - Login: curl -X POST http://localhost:8081/api/v1/passengers/login"
echo "   - Browse routes: curl http://localhost:8082/api/v1/transport/routes"

echo ""
echo -e "${GREEN}🎉 System restore completed successfully!${NC}"
echo "Your Windhoek Transport System has been restored from backup."

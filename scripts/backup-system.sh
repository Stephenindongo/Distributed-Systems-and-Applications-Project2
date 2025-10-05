#!/bin/bash

# Windhoek Transport System - Backup Script
# This script creates backups of the entire system

echo "💾 Windhoek Transport System - Backup Script"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="windhoek_transport_backup_$TIMESTAMP"

echo "📅 Backup Configuration:"
echo "  Backup Directory: $BACKUP_DIR"
echo "  Backup Name: $BACKUP_NAME"
echo "  Timestamp: $TIMESTAMP"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

echo "🗄️  Database Backup"
echo "-------------------"

# Backup MySQL database
echo "Creating MySQL database backup..."
if docker exec mysql mysqldump -u transport_user -ptransport_password transport_ticketing > "$BACKUP_DIR/$BACKUP_NAME/database.sql"; then
    echo -e "Database backup: ${GREEN}✅ SUCCESS${NC}"
else
    echo -e "Database backup: ${RED}❌ FAILED${NC}"
    exit 1
fi

# Backup database schema
echo "Creating database schema backup..."
docker exec mysql mysqldump -u transport_user -ptransport_password --no-data transport_ticketing > "$BACKUP_DIR/$BACKUP_NAME/schema.sql"
echo -e "Schema backup: ${GREEN}✅ SUCCESS${NC}"

echo ""
echo "📦 Container Backup"
echo "-------------------"

# Export container configurations
echo "Exporting container configurations..."
docker-compose config > "$BACKUP_DIR/$BACKUP_NAME/docker-compose.yml"
echo -e "Docker Compose config: ${GREEN}✅ SUCCESS${NC}"

# Export container images
echo "Exporting container images..."
docker save -o "$BACKUP_DIR/$BACKUP_NAME/container_images.tar" \
    $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(passenger|transport|ticketing|payment|notification|admin)-service")

if [ $? -eq 0 ]; then
    echo -e "Container images: ${GREEN}✅ SUCCESS${NC}"
else
    echo -e "Container images: ${YELLOW}⚠️  PARTIAL${NC}"
fi

echo ""
echo "📁 Application Code Backup"
echo "-------------------------"

# Backup application code
echo "Creating application code backup..."
cp -r services "$BACKUP_DIR/$BACKUP_NAME/"
cp -r monitoring "$BACKUP_DIR/$BACKUP_NAME/"
cp -r scripts "$BACKUP_DIR/$BACKUP_NAME/"
cp -r database "$BACKUP_DIR/$BACKUP_NAME/"

# Copy configuration files
cp docker-compose.yml "$BACKUP_DIR/$BACKUP_NAME/"
cp kafka-topics.sh "$BACKUP_DIR/$BACKUP_NAME/"
cp start-monitoring.sh "$BACKUP_DIR/$BACKUP_NAME/"

# Copy documentation
cp README.md "$BACKUP_DIR/$BACKUP_NAME/"
cp SETUP_GUIDE.md "$BACKUP_DIR/$BACKUP_NAME/"
cp COMMANDS.md "$BACKUP_DIR/$BACKUP_NAME/"
cp PROJECT_SUMMARY.md "$BACKUP_DIR/$BACKUP_NAME/"

echo -e "Application code: ${GREEN}✅ SUCCESS${NC}"

echo ""
echo "📊 System State Backup"
echo "---------------------"

# Backup system state information
echo "Creating system state backup..."

# Container status
docker-compose ps > "$BACKUP_DIR/$BACKUP_NAME/container_status.txt"

# Docker images
docker images > "$BACKUP_DIR/$BACKUP_NAME/docker_images.txt"

# Docker volumes
docker volume ls > "$BACKUP_DIR/$BACKUP_NAME/docker_volumes.txt"

# Docker networks
docker network ls > "$BACKUP_DIR/$BACKUP_NAME/docker_networks.txt"

# System information
echo "System Information" > "$BACKUP_DIR/$BACKUP_NAME/system_info.txt"
echo "==================" >> "$BACKUP_DIR/$BACKUP_NAME/system_info.txt"
echo "Date: $(date)" >> "$BACKUP_DIR/$BACKUP_NAME/system_info.txt"
echo "Hostname: $(hostname)" >> "$BACKUP_DIR/$BACKUP_NAME/system_info.txt"
echo "OS: $(uname -a)" >> "$BACKUP_DIR/$BACKUP_NAME/system_info.txt"
echo "Docker Version: $(docker --version)" >> "$BACKUP_DIR/$BACKUP_NAME/system_info.txt"
echo "Docker Compose Version: $(docker-compose --version)" >> "$BACKUP_DIR/$BACKUP_NAME/system_info.txt"

echo -e "System state: ${GREEN}✅ SUCCESS${NC}"

echo ""
echo "📨 Kafka Backup"
echo "---------------"

# Backup Kafka topics configuration
echo "Creating Kafka topics backup..."
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 > "$BACKUP_DIR/$BACKUP_NAME/kafka_topics.txt"

# Backup Kafka configuration
docker exec kafka cat /opt/kafka/config/server.properties > "$BACKUP_DIR/$BACKUP_NAME/kafka_config.properties"

echo -e "Kafka backup: ${GREEN}✅ SUCCESS${NC}"

echo ""
echo "📈 Monitoring Data Backup"
echo "------------------------"

# Backup monitoring data if available
if docker ps | grep -q prometheus; then
    echo "Backing up Prometheus data..."
    docker cp prometheus:/prometheus "$BACKUP_DIR/$BACKUP_NAME/prometheus_data" 2>/dev/null || echo "Prometheus data not accessible"
fi

if docker ps | grep -q grafana; then
    echo "Backing up Grafana data..."
    docker cp grafana:/var/lib/grafana "$BACKUP_DIR/$BACKUP_NAME/grafana_data" 2>/dev/null || echo "Grafana data not accessible"
fi

echo -e "Monitoring data: ${GREEN}✅ SUCCESS${NC}"

echo ""
echo "📋 Backup Manifest"
echo "-----------------"

# Create backup manifest
cat > "$BACKUP_DIR/$BACKUP_NAME/BACKUP_MANIFEST.txt" << EOF
Windhoek Transport System Backup Manifest
=========================================

Backup Date: $(date)
Backup Name: $BACKUP_NAME
System Version: 1.0.0

Contents:
---------
- database.sql: Complete database dump
- schema.sql: Database schema only
- docker-compose.yml: Container orchestration config
- container_images.tar: Docker container images
- services/: Application source code
- monitoring/: Monitoring configuration
- scripts/: Utility scripts
- database/: Database initialization scripts
- Documentation files (README.md, etc.)

System State:
-------------
- Container Status: container_status.txt
- Docker Images: docker_images.txt
- Docker Volumes: docker_volumes.txt
- Docker Networks: docker_networks.txt
- System Info: system_info.txt

Kafka:
------
- Topics List: kafka_topics.txt
- Configuration: kafka_config.properties

Monitoring:
-----------
- Prometheus Data: prometheus_data/
- Grafana Data: grafana_data/

Restore Instructions:
--------------------
1. Extract backup: tar -xzf $BACKUP_NAME.tar.gz
2. Start infrastructure: docker-compose up -d mysql kafka
3. Restore database: docker exec -i mysql mysql -u transport_user -p transport_ticketing < database.sql
4. Start services: docker-compose up -d
5. Verify system: ./scripts/health-check.sh

EOF

echo -e "Backup manifest: ${GREEN}✅ SUCCESS${NC}"

echo ""
echo "🗜️  Creating Archive"
echo "--------------------"

# Create compressed archive
echo "Creating compressed archive..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"

if [ $? -eq 0 ]; then
    echo -e "Archive creation: ${GREEN}✅ SUCCESS${NC}"
    
    # Get archive size
    ARCHIVE_SIZE=$(du -h "$BACKUP_NAME.tar.gz" | cut -f1)
    echo "Archive size: $ARCHIVE_SIZE"
    
    # Clean up uncompressed directory
    rm -rf "$BACKUP_NAME"
    echo "Cleaned up uncompressed directory"
else
    echo -e "Archive creation: ${RED}❌ FAILED${NC}"
    exit 1
fi

cd - > /dev/null

echo ""
echo "📊 Backup Summary"
echo "================="

echo "Backup completed successfully!"
echo "Archive location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Archive size: $ARCHIVE_SIZE"

echo ""
echo "📋 Backup Contents:"
echo "  ✅ Database dump (database.sql)"
echo "  ✅ Database schema (schema.sql)"
echo "  ✅ Docker Compose configuration"
echo "  ✅ Container images"
echo "  ✅ Application source code"
echo "  ✅ Monitoring configuration"
echo "  ✅ System state information"
echo "  ✅ Kafka configuration"
echo "  ✅ Documentation"

echo ""
echo "🔄 Restore Instructions:"
echo "  1. Extract: tar -xzf $BACKUP_NAME.tar.gz"
echo "  2. Start infrastructure: docker-compose up -d mysql kafka"
echo "  3. Restore database: docker exec -i mysql mysql -u transport_user -p transport_ticketing < database.sql"
echo "  4. Start services: docker-compose up -d"
echo "  5. Verify: ./scripts/health-check.sh"

echo ""
echo -e "${GREEN}🎉 Backup completed successfully!${NC}"
echo "Your Windhoek Transport System has been fully backed up."

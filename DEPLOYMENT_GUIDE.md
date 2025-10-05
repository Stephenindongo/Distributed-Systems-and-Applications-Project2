# Windhoek Transport System - Deployment Guide

## 🚀 Complete Deployment Instructions

This guide provides comprehensive instructions for deploying the Windhoek Transport System in various environments.

## 📋 Prerequisites

### System Requirements
- **OS**: Windows 11 (as specified)
- **RAM**: Minimum 8GB (16GB recommended)
- **Storage**: 20GB free space
- **CPU**: 4 cores minimum

### Software Requirements
- **Docker Desktop**: Latest version
- **Git**: For version control
- **PowerShell**: For Windows commands
- **Git Bash** (optional): For Unix-like commands

## 🏗️ Deployment Options

### Option 1: Quick Start (Recommended)
```bash
# One-click setup
./scripts/quick-start.sh
```

### Option 2: Manual Setup
```bash
# 1. Start infrastructure
docker-compose up -d mysql kafka

# 2. Create Kafka topics
./kafka-topics.sh

# 3. Start all services
docker-compose up -d

# 4. Verify system
./scripts/health-check.sh
```

### Option 3: Development Mode
```bash
# Start with logs
docker-compose up

# Or start specific service
docker-compose up passenger-service transport-service
```

## 🔧 Environment Configuration

### Production Environment
```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  mysql:
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./backups:/backups
```

### Development Environment
```yaml
# docker-compose.dev.yml
version: '3.8'
services:
  passenger-service:
    volumes:
      - ./services/passenger-service:/app
    environment:
      - DEBUG=true
      - LOG_LEVEL=debug
```

## 📊 Monitoring Setup

### Basic Monitoring
```bash
# Start monitoring stack
./start-monitoring.sh

# Access monitoring tools
# Grafana: http://localhost:3000 (admin/admin123)
# Prometheus: http://localhost:9090
# Jaeger: http://localhost:16686
```

### Advanced Monitoring
```bash
# Start with custom configuration
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# Configure alerts
cp monitoring/alert_rules.yml /etc/prometheus/
```

## 🔒 Security Configuration

### JWT Configuration
```bash
# Set secure JWT secret
export JWT_SECRET="your-secure-secret-key-here"

# Update in docker-compose.yml
environment:
  - JWT_SECRET=${JWT_SECRET}
```

### Database Security
```sql
-- Create secure user
CREATE USER 'transport_user'@'%' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON transport_ticketing.* TO 'transport_user'@'%';
FLUSH PRIVILEGES;
```

### Network Security
```yaml
# docker-compose.yml
networks:
  transport_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## 📈 Scaling Configuration

### Horizontal Scaling
```yaml
# docker-compose.scale.yml
services:
  passenger-service:
    deploy:
      replicas: 3
  transport-service:
    deploy:
      replicas: 2
  ticketing-service:
    deploy:
      replicas: 3
```

### Load Balancing
```yaml
# nginx.conf
upstream passenger_service {
    server passenger-service-1:8081;
    server passenger-service-2:8081;
    server passenger-service-3:8081;
}

server {
    listen 80;
    location /api/v1/passengers/ {
        proxy_pass http://passenger_service;
    }
}
```

## 🗄️ Database Management

### Backup Strategy
```bash
# Automated backup
./scripts/backup-system.sh

# Manual backup
docker exec mysql mysqldump -u transport_user -p transport_ticketing > backup.sql

# Scheduled backup (cron)
0 2 * * * /path/to/backup-system.sh
```

### Restore Strategy
```bash
# Restore from backup
./scripts/restore-system.sh backup_file.tar.gz

# Manual restore
docker exec -i mysql mysql -u transport_user -p transport_ticketing < backup.sql
```

### Database Optimization
```sql
-- Add indexes for performance
CREATE INDEX idx_tickets_passenger_status ON tickets(passenger_id, status);
CREATE INDEX idx_trips_route_date ON trips(route_id, trip_date);
CREATE INDEX idx_payments_ticket_status ON payments(ticket_id, status);

-- Optimize tables
OPTIMIZE TABLE users, routes, trips, tickets, payments;
```

## 📨 Kafka Configuration

### Topic Management
```bash
# Create topics with custom configuration
docker exec kafka kafka-topics --create \
  --topic user-registration \
  --bootstrap-server localhost:9092 \
  --partitions 6 \
  --replication-factor 2 \
  --config retention.ms=604800000

# Monitor topic metrics
docker exec kafka kafka-topics --describe \
  --bootstrap-server localhost:9092
```

### Consumer Groups
```bash
# List consumer groups
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --list

# Check consumer lag
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group notification-service \
  --describe
```

## 🔄 CI/CD Pipeline

### GitHub Actions
```yaml
# .github/workflows/deploy.yml
name: Deploy Windhoek Transport System

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to production
        run: |
          docker-compose -f docker-compose.prod.yml up -d
          ./scripts/health-check.sh
```

### Docker Registry
```bash
# Build and push images
docker build -t windhoek/transport-system:latest .
docker push windhoek/transport-system:latest

# Deploy from registry
docker-compose -f docker-compose.prod.yml up -d
```

## 🧪 Testing Strategy

### Unit Testing
```bash
# Test individual services
cd services/passenger-service
bal test

# Test all services
for service in services/*; do
  cd $service
  bal test
  cd ../..
done
```

### Integration Testing
```bash
# Run complete test suite
./scripts/test-system.sh

# Load testing
./scripts/load-test.sh

# Performance testing
ab -n 1000 -c 10 http://localhost:8082/api/v1/transport/routes
```

### End-to-End Testing
```bash
# Test complete user journey
curl -X POST http://localhost:8081/api/v1/passengers/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","firstName":"John","lastName":"Doe"}'

curl -X POST http://localhost:8081/api/v1/passengers/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

## 📊 Performance Optimization

### Database Optimization
```sql
-- Query optimization
EXPLAIN SELECT * FROM tickets WHERE passenger_id = 1 AND status = 'VALIDATED';

-- Connection pooling
SET GLOBAL max_connections = 1000;
SET GLOBAL innodb_buffer_pool_size = 1G;
```

### Application Optimization
```yaml
# docker-compose.yml
services:
  passenger-service:
    environment:
      - DATABASE_POOL_SIZE=20
      - KAFKA_BATCH_SIZE=1000
      - CACHE_TTL=300
```

### Monitoring Optimization
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

## 🚨 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check logs
docker-compose logs passenger-service

# Restart service
docker-compose restart passenger-service

# Rebuild service
docker-compose up -d --build passenger-service
```

#### Database Connection Issues
```bash
# Check database status
docker exec mysql mysql -u transport_user -p -e "SHOW PROCESSLIST;"

# Check connection limits
docker exec mysql mysql -u root -p -e "SHOW VARIABLES LIKE 'max_connections';"
```

#### Kafka Issues
```bash
# Check Kafka status
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

# Check consumer lag
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Check database performance
docker exec mysql mysql -u transport_user -p -e "SHOW PROCESSLIST;"

# Check network connectivity
telnet localhost 8081
telnet localhost 3306
telnet localhost 9092
```

## 📋 Maintenance Tasks

### Daily Tasks
```bash
# Health check
./scripts/health-check.sh

# Log rotation
docker system prune -f

# Database backup
./scripts/backup-system.sh
```

### Weekly Tasks
```bash
# System test
./scripts/test-system.sh

# Performance monitoring
./scripts/load-test.sh

# Security audit
docker exec mysql mysql -u transport_user -p -e "SHOW GRANTS;"
```

### Monthly Tasks
```bash
# Full system backup
./scripts/backup-system.sh

# Database optimization
docker exec mysql mysql -u transport_user -p transport_ticketing -e "OPTIMIZE TABLE users, routes, trips, tickets, payments;"

# Security updates
docker-compose pull
docker-compose up -d
```

## 🎯 Production Checklist

### Pre-Deployment
- [ ] All services tested
- [ ] Database backed up
- [ ] Security configured
- [ ] Monitoring setup
- [ ] Load testing completed

### Deployment
- [ ] Infrastructure started
- [ ] Services deployed
- [ ] Health checks passed
- [ ] Monitoring active
- [ ] Documentation updated

### Post-Deployment
- [ ] System monitoring
- [ ] Performance tracking
- [ ] User feedback collection
- [ ] Issue tracking
- [ ] Regular backups

## 📞 Support

### Emergency Contacts
- **System Administrator**: admin@windhoek.gov.na
- **Technical Support**: support@windhoek.gov.na
- **Emergency Hotline**: +264 61 290 2000

### Documentation
- **API Documentation**: http://localhost:8081/docs
- **System Monitoring**: http://localhost:3000
- **Logs**: http://localhost:5601

---

**🎉 Deployment Complete!**

Your Windhoek Transport System is now ready for production use. Follow the maintenance tasks and monitoring guidelines to ensure optimal performance.

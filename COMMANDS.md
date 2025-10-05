# Windhoek Transport Ticketing System - Commands Reference

## 🚀 Quick Start Commands

### Start the System
```bash
# Start all services
docker-compose up -d

# Start with logs
docker-compose up

# Start specific services
docker-compose up -d mysql kafka passenger-service
```

### Stop the System
```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: Deletes all data)
docker-compose down -v

# Stop specific service
docker-compose stop passenger-service
```

## 🐳 Docker Commands

### Container Management
```bash
# List all containers
docker ps -a

# List running containers
docker ps

# Stop all containers
docker stop $(docker ps -q)

# Remove all containers
docker rm $(docker ps -aq)

# Remove all images
docker rmi $(docker images -q)

# Clean up system
docker system prune -a
```

### Service-Specific Commands
```bash
# View logs for specific service
docker-compose logs passenger-service
docker-compose logs transport-service
docker-compose logs ticketing-service
docker-compose logs payment-service
docker-compose logs notification-service
docker-compose logs admin-service

# Restart specific service
docker-compose restart passenger-service

# Rebuild specific service
docker-compose build passenger-service

# Execute commands in running container
docker exec -it passenger-service bash
docker exec -it mysql mysql -u transport_user -p transport_ticketing
```

## 🗄️ Database Commands

### MySQL Access
```bash
# Connect to MySQL
docker exec -it mysql mysql -u transport_user -p transport_ticketing
# Password: transport_password

# Connect as root
docker exec -it mysql mysql -u root -p
# Password: rootpassword
```

### Database Operations
```sql
-- Show all tables
SHOW TABLES;

-- Check users
SELECT * FROM users;

-- Check routes
SELECT * FROM routes;

-- Check trips
SELECT * FROM trips;

-- Check tickets
SELECT * FROM tickets;

-- Check payments
SELECT * FROM payments;

-- Check notifications
SELECT * FROM notifications;

-- Check service disruptions
SELECT * FROM service_disruptions;

-- Get user count
SELECT COUNT(*) FROM users;

-- Get ticket statistics
SELECT 
    status,
    COUNT(*) as count
FROM tickets 
GROUP BY status;

-- Get payment statistics
SELECT 
    status,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM payments 
GROUP BY status;
```

## 📨 Kafka Commands

### Topic Management
```bash
# List all topics
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092

# Create a topic
docker exec -it kafka kafka-topics --create --topic test-topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1

# Delete a topic
docker exec -it kafka kafka-topics --delete --topic test-topic --bootstrap-server localhost:9092

# Describe a topic
docker exec -it kafka kafka-topics --describe --topic user-registration --bootstrap-server localhost:9092
```

### Message Monitoring
```bash
# Consume messages from a topic
docker exec -it kafka kafka-console-consumer --topic user-registration --bootstrap-server localhost:9092 --from-beginning

# Produce a test message
docker exec -it kafka kafka-console-producer --topic user-registration --bootstrap-server localhost:9092

# Monitor all topics
docker exec -it kafka kafka-console-consumer --topic ".*" --bootstrap-server localhost:9092 --from-beginning
```

## 🌐 API Testing Commands

### Passenger Service (Port 8081)
```bash
# Register user
curl -X POST http://localhost:8081/api/v1/passengers/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+264811234567"
  }'

# Login user
curl -X POST http://localhost:8081/api/v1/passengers/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# Get user profile (replace TOKEN with actual JWT)
curl -X GET http://localhost:8081/api/v1/passengers/profile \
  -H "Authorization: Bearer TOKEN"

# Get user tickets
curl -X GET http://localhost:8081/api/v1/passengers/tickets \
  -H "Authorization: Bearer TOKEN"
```

### Transport Service (Port 8082)
```bash
# Get all routes
curl -X GET http://localhost:8082/api/v1/transport/routes

# Get route by ID
curl -X GET http://localhost:8082/api/v1/transport/routes/1

# Get trips for route
curl -X GET http://localhost:8082/api/v1/transport/routes/1/trips

# Get all trips
curl -X GET http://localhost:8082/api/v1/transport/trips

# Search routes
curl -X GET "http://localhost:8082/api/v1/transport/search?query=Katutura&transportType=BUS"

# Get service disruptions
curl -X GET http://localhost:8082/api/v1/transport/disruptions
```

### Ticketing Service (Port 8083)
```bash
# Create ticket (replace TOKEN with actual JWT)
curl -X POST http://localhost:8083/api/v1/tickets/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{
    "tripId": 1,
    "ticketType": "SINGLE_RIDE"
  }'

# Get ticket by code
curl -X GET http://localhost:8083/api/v1/tickets/ABC12345

# Validate ticket
curl -X POST http://localhost:8083/api/v1/tickets/validate \
  -H "Content-Type: application/json" \
  -d '{
    "ticketCode": "ABC12345",
    "tripId": 1
  }'

# Cancel ticket
curl -X PUT http://localhost:8083/api/v1/tickets/ABC12345/cancel
```

### Payment Service (Port 8084)
```bash
# Process payment
curl -X POST http://localhost:8084/api/v1/payments/process \
  -H "Content-Type: application/json" \
  -d '{
    "ticketId": 1,
    "paymentMethod": "CARD",
    "amount": 5.00,
    "currency": "NAD"
  }'

# Get payment by transaction ID
curl -X GET http://localhost:8084/api/v1/payments/transaction/TXN_ABC123

# Get payment statistics
curl -X GET http://localhost:8084/api/v1/payments/statistics

# Process refund
curl -X POST http://localhost:8084/api/v1/payments/refund \
  -H "Content-Type: application/json" \
  -d '{
    "paymentId": 1,
    "reason": "Customer request"
  }'
```

### Notification Service (Port 8085)
```bash
# Send notification
curl -X POST http://localhost:8085/api/v1/notifications/send \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "notificationType": "TRIP_UPDATE",
    "title": "Trip Update",
    "message": "Your trip has been delayed by 15 minutes"
  }'

# Get user notifications
curl -X GET http://localhost:8085/api/v1/notifications/user/1

# Mark notification as read
curl -X PUT http://localhost:8085/api/v1/notifications/1/read

# Get notification statistics
curl -X GET http://localhost:8085/api/v1/notifications/statistics
```

### Admin Service (Port 8086)
```bash
# Create route (replace TOKEN with admin JWT)
curl -X POST http://localhost:8086/api/v1/admin/routes \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{
    "routeNumber": "B004",
    "routeName": "CBD to Eros",
    "transportType": "BUS",
    "startLocation": "Windhoek CBD",
    "endLocation": "Eros Airport",
    "distanceKm": 12.5,
    "estimatedDurationMinutes": 30
  }'

# Create trip
curl -X POST http://localhost:8086/api/v1/admin/trips \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{
    "routeId": 1,
    "tripNumber": "B001-004",
    "departureTime": "09:00:00",
    "arrivalTime": "09:25:00",
    "tripDate": "2024-01-15"
  }'

# Get dashboard statistics
curl -X GET http://localhost:8086/api/v1/admin/dashboard \
  -H "Authorization: Bearer TOKEN"

# Get route statistics
curl -X GET http://localhost:8086/api/v1/admin/routes/statistics \
  -H "Authorization: Bearer TOKEN"

# Get all users
curl -X GET http://localhost:8086/api/v1/admin/users \
  -H "Authorization: Bearer TOKEN"
```

## 🔧 Development Commands

### Ballerina Development
```bash
# Navigate to service directory
cd services/passenger-service

# Build service
bal build

# Run service
bal run

# Test service
bal test

# Format code
bal format

# Check code style
bal check
```

### Service-Specific Development
```bash
# Build all services
for service in passenger-service transport-service ticketing-service payment-service notification-service admin-service; do
  cd services/$service
  bal build
  cd ../..
done

# Run specific service in development mode
cd services/passenger-service
bal run --debug
```

## 📊 Monitoring Commands

### System Health Check
```bash
# Check all services status
docker-compose ps

# Check service health
curl -f http://localhost:8081/health || echo "Passenger service down"
curl -f http://localhost:8082/health || echo "Transport service down"
curl -f http://localhost:8083/health || echo "Ticketing service down"
curl -f http://localhost:8084/health || echo "Payment service down"
curl -f http://localhost:8085/health || echo "Notification service down"
curl -f http://localhost:8086/health || echo "Admin service down"
```

### Resource Usage
```bash
# Check Docker resource usage
docker stats

# Check specific container resources
docker stats passenger-service

# Check disk usage
docker system df

# Check container logs size
docker-compose logs --tail=100 passenger-service
```

### Database Monitoring
```sql
-- Check database size
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'transport_ticketing'
GROUP BY table_schema;

-- Check table sizes
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'transport_ticketing'
ORDER BY (data_length + index_length) DESC;

-- Check slow queries
SHOW PROCESSLIST;
```

## 🧪 Testing Commands

### Load Testing
```bash
# Install Apache Bench (if available)
# Test passenger registration
ab -n 100 -c 10 -p register.json -T application/json http://localhost:8081/api/v1/passengers/register

# Test route search
ab -n 50 -c 5 http://localhost:8082/api/v1/transport/routes
```

### Integration Testing
```bash
# Test complete user journey
# 1. Register user
# 2. Login
# 3. Search routes
# 4. Create ticket
# 5. Process payment
# 6. Validate ticket

# Create test script
cat > test-journey.sh << 'EOF'
#!/bin/bash
echo "Testing complete user journey..."

# Register user
echo "1. Registering user..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/passengers/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","firstName":"John","lastName":"Doe","phone":"+264811234567"}')
echo "Registration: $REGISTER_RESPONSE"

# Login
echo "2. Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/v1/passengers/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}')
echo "Login: $LOGIN_RESPONSE"

# Extract token (you'll need to parse JSON)
# TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')

# Search routes
echo "3. Searching routes..."
curl -s -X GET http://localhost:8082/api/v1/transport/routes

echo "Test journey completed!"
EOF

chmod +x test-journey.sh
./test-journey.sh
```

## 🚨 Troubleshooting Commands

### Service Debugging
```bash
# Check service logs with timestamps
docker-compose logs -t passenger-service

# Follow logs in real-time
docker-compose logs -f passenger-service

# Check service configuration
docker-compose config

# Validate docker-compose file
docker-compose config --quiet
```

### Network Debugging
```bash
# Check port usage
netstat -ano | findstr :8081
netstat -ano | findstr :3306
netstat -ano | findstr :9092

# Test connectivity
telnet localhost 8081
telnet localhost 3306
telnet localhost 9092

# Check Docker network
docker network ls
docker network inspect distributed-systems-and-applications-project2_default
```

### Database Debugging
```bash
# Check MySQL process list
docker exec -it mysql mysql -u root -p -e "SHOW PROCESSLIST;"

# Check MySQL variables
docker exec -it mysql mysql -u root -p -e "SHOW VARIABLES LIKE '%timeout%';"

# Check database connections
docker exec -it mysql mysql -u root -p -e "SHOW STATUS LIKE 'Connections';"
```

## 🔄 Maintenance Commands

### Backup Database
```bash
# Create database backup
docker exec mysql mysqldump -u transport_user -p transport_ticketing > backup.sql

# Restore database
docker exec -i mysql mysql -u transport_user -p transport_ticketing < backup.sql
```

### Update Services
```bash
# Pull latest images
docker-compose pull

# Rebuild services
docker-compose build --no-cache

# Restart services
docker-compose restart
```

### Clean Up
```bash
# Remove unused containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Clean everything
docker system prune -a
```

## 📝 Log Management

### Log Rotation
```bash
# Check log sizes
docker system df

# Clean up logs
docker system prune

# View specific log entries
docker-compose logs --tail=50 passenger-service | grep ERROR
docker-compose logs --tail=50 passenger-service | grep WARN
```

### Log Analysis
```bash
# Count error logs
docker-compose logs passenger-service | grep -c ERROR

# Find specific errors
docker-compose logs passenger-service | grep "Database error"

# Monitor real-time errors
docker-compose logs -f passenger-service | grep ERROR
```

---

**💡 Pro Tips:**
- Use `docker-compose logs -f` to follow logs in real-time
- Use `docker-compose exec` to run commands in running containers
- Use `docker system df` to check disk usage
- Use `docker stats` to monitor resource usage
- Always backup your database before major changes
- Use `docker-compose config` to validate your configuration

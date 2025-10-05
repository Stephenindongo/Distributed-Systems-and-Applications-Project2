# Windhoek Transport Ticketing System - Setup Guide

## 🚀 Complete Setup Instructions for Windows 11

This guide will walk you through setting up the complete Windhoek Transport Ticketing System on Windows 11.

## 📋 Prerequisites

### 1. Install Docker Desktop for Windows

1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop/
2. Install Docker Desktop
3. Start Docker Desktop
4. Verify installation:
   ```cmd
   docker --version
   docker-compose --version
   ```

### 2. Install Git (if not already installed)

1. Download Git from: https://git-scm.com/download/win
2. Install Git with default settings
3. Verify installation:
   ```cmd
   git --version
   ```

## 🏗️ Project Setup

### Step 1: Clone or Download the Project

If you have the project files, navigate to the project directory:
```cmd
cd C:\Dev\Distributed-Systems-and-Applications-Project2
```

### Step 2: Verify Project Structure

Ensure you have the following structure:
```
Distributed-Systems-and-Applications-Project2/
├── docker-compose.yml
├── database/
│   └── init.sql
├── services/
│   ├── passenger-service/
│   ├── transport-service/
│   ├── ticketing-service/
│   ├── payment-service/
│   ├── notification-service/
│   └── admin-service/
├── kafka-topics.sh
├── README.md
└── SETUP_GUIDE.md
```

## 🐳 Docker Setup

### Step 1: Start the Infrastructure Services

Open Command Prompt or PowerShell as Administrator and run:

```cmd
# Navigate to project directory
cd C:\Dev\Distributed-Systems-and-Applications-Project2

# Start infrastructure services first
docker-compose up -d mysql zookeeper kafka
```

Wait for these services to be ready (about 2-3 minutes).

### Step 2: Create Kafka Topics

```cmd
# Make the script executable (if using Git Bash)
chmod +x kafka-topics.sh

# Run the Kafka topics creation script
./kafka-topics.sh
```

**Alternative method using Docker:**
```cmd
# Create topics manually
docker exec -it kafka kafka-topics --create --topic user-registration --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic user-login --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic ticket-created --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic ticket-validated --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic ticket-cancelled --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic payment-completed --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic payment-failed --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic payment-refunded --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic trip-status-update --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
docker exec -it kafka kafka-topics --create --topic service-disruption --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
```

### Step 3: Start All Microservices

```cmd
# Start all services
docker-compose up -d
```

### Step 4: Verify All Services Are Running

```cmd
# Check service status
docker-compose ps
```

You should see all services with "Up" status:
- mysql
- zookeeper
- kafka
- passenger-service
- transport-service
- ticketing-service
- payment-service
- notification-service
- admin-service

## 🧪 Testing the System

### Step 1: Test Database Connection

```cmd
# Connect to MySQL database
docker exec -it mysql mysql -u transport_user -p transport_ticketing
# Password: transport_password
```

### Step 2: Test API Endpoints

#### Test Passenger Registration

```cmd
curl -X POST http://localhost:8081/api/v1/passengers/register ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"test@example.com\",\"password\":\"password123\",\"firstName\":\"John\",\"lastName\":\"Doe\",\"phone\":\"+264811234567\"}"
```

#### Test User Login

```cmd
curl -X POST http://localhost:8081/api/v1/passengers/login ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"test@example.com\",\"password\":\"password123\"}"
```

#### Test Routes

```cmd
curl -X GET http://localhost:8082/api/v1/transport/routes
```

#### Test Trips

```cmd
curl -X GET http://localhost:8082/api/v1/transport/trips
```

### Step 3: Test Complete User Journey

1. **Register a user**
2. **Login and get JWT token**
3. **Search for routes**
4. **Create a ticket**
5. **Process payment**
6. **Validate ticket**

## 📊 Monitoring and Logs

### View Service Logs

```cmd
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs passenger-service
docker-compose logs transport-service
docker-compose logs ticketing-service
docker-compose logs payment-service
docker-compose logs notification-service
docker-compose logs admin-service
```

### Monitor Kafka Topics

```cmd
# List all topics
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092

# Monitor a specific topic
docker exec -it kafka kafka-console-consumer --topic user-registration --bootstrap-server localhost:9092 --from-beginning
```

### Check Database

```cmd
# Connect to database
docker exec -it mysql mysql -u transport_user -p transport_ticketing

# View tables
SHOW TABLES;

# Check users
SELECT * FROM users;

# Check routes
SELECT * FROM routes;

# Check tickets
SELECT * FROM tickets;
```

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Services Not Starting

**Problem**: Services fail to start or show "Exit" status.

**Solution**:
```cmd
# Check logs for specific service
docker-compose logs passenger-service

# Restart specific service
docker-compose restart passenger-service

# Rebuild and restart
docker-compose up -d --build passenger-service
```

#### 2. Database Connection Issues

**Problem**: Services can't connect to MySQL.

**Solution**:
```cmd
# Check if MySQL is running
docker-compose ps mysql

# Restart MySQL
docker-compose restart mysql

# Check MySQL logs
docker-compose logs mysql
```

#### 3. Kafka Connection Issues

**Problem**: Services can't connect to Kafka.

**Solution**:
```cmd
# Check Kafka status
docker-compose ps kafka

# Restart Kafka
docker-compose restart kafka

# Check if topics exist
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092
```

#### 4. Port Conflicts

**Problem**: Ports 8081-8086, 3306, 9092 are already in use.

**Solution**:
```cmd
# Check what's using the ports
netstat -ano | findstr :8081
netstat -ano | findstr :3306
netstat -ano | findstr :9092

# Stop conflicting services or change ports in docker-compose.yml
```

#### 5. Ballerina Build Issues

**Problem**: Ballerina services fail to build.

**Solution**:
```cmd
# Check Ballerina installation in container
docker exec -it passenger-service bal version

# Rebuild services
docker-compose build --no-cache
```

### Reset Everything

If you need to start completely fresh:

```cmd
# Stop all services
docker-compose down

# Remove all containers and volumes
docker-compose down -v

# Remove all images
docker system prune -a

# Start fresh
docker-compose up -d
```

## 📱 Using the System

### 1. User Registration and Login

1. Register a new user via the Passenger Service
2. Login to get a JWT token
3. Use the token for authenticated requests

### 2. Browse Routes and Trips

1. Use the Transport Service to search routes
2. View available trips for specific dates
3. Check for service disruptions

### 3. Purchase Tickets

1. Create a ticket via the Ticketing Service
2. Process payment via the Payment Service
3. Receive confirmation notifications

### 4. Validate Tickets

1. Use the ticket code to validate on boarding
2. Check ticket status and remaining validations

### 5. Admin Functions

1. Create routes and trips
2. Monitor system statistics
3. Manage service disruptions
4. View user and payment reports

## 🔍 API Testing with Postman

### Import Collection

Create a Postman collection with the following requests:

1. **POST** `http://localhost:8081/api/v1/passengers/register`
2. **POST** `http://localhost:8081/api/v1/passengers/login`
3. **GET** `http://localhost:8082/api/v1/transport/routes`
4. **POST** `http://localhost:8083/api/v1/tickets/`
5. **POST** `http://localhost:8084/api/v1/payments/process`

### Environment Variables

Create a Postman environment with:
- `base_url`: `http://localhost`
- `jwt_token`: (set after login)

## 📈 Performance Testing

### Load Testing

Use tools like Apache Bench or JMeter to test the system:

```cmd
# Install Apache Bench (if not available)
# Test passenger registration endpoint
ab -n 100 -c 10 -p register.json -T application/json http://localhost:8081/api/v1/passengers/register
```

### Database Performance

```cmd
# Connect to MySQL and check performance
docker exec -it mysql mysql -u transport_user -p transport_ticketing

# Check query performance
EXPLAIN SELECT * FROM tickets WHERE passenger_id = 1;
```

## 🎯 Next Steps

1. **Frontend Development**: Create a web or mobile frontend
2. **Security Hardening**: Implement additional security measures
3. **Monitoring**: Add application performance monitoring
4. **Scaling**: Implement horizontal scaling strategies
5. **CI/CD**: Set up continuous integration and deployment

## 📞 Support

If you encounter issues:

1. Check the logs: `docker-compose logs`
2. Verify all services are running: `docker-compose ps`
3. Test database connectivity
4. Check Kafka topics
5. Review the troubleshooting section above

## 🎉 Success!

If all services are running and you can make API calls successfully, your Windhoek Transport Ticketing System is ready for use!

The system provides:
- ✅ User registration and authentication
- ✅ Route and trip management
- ✅ Ticket creation and validation
- ✅ Payment processing
- ✅ Real-time notifications
- ✅ Administrative functions
- ✅ Event-driven architecture
- ✅ Scalable microservices design

**Happy coding! 🚌✨**

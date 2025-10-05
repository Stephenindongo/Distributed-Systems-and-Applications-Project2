# Windhoek Transport Ticketing System

A distributed smart public transport ticketing system for Windhoek City, Namibia. Built with microservices architecture using Ballerina, Kafka, MySQL, and Docker.

## 🚌 Overview

This system provides a modern, distributed ticketing platform for buses and trains in Windhoek City. It supports different user roles (passengers, administrators, validators) and provides a seamless experience across devices with real-time updates and notifications.

## 🏗️ Architecture

The system is built using microservices architecture with the following components:

- **Passenger Service** (Port 8081): User registration, login, profile management
- **Transport Service** (Port 8082): Routes, trips, schedules, disruptions
- **Ticketing Service** (Port 8083): Ticket creation, validation, lifecycle management
- **Payment Service** (Port 8084): Payment processing, refunds, transaction management
- **Notification Service** (Port 8085): Real-time notifications, event handling
- **Admin Service** (Port 8086): Administrative functions, reporting, analytics

## 🛠️ Technology Stack

- **Language**: Ballerina 2201.8.5
- **Message Broker**: Apache Kafka
- **Database**: MySQL 8.0
- **Containerization**: Docker & Docker Compose
- **Authentication**: JWT tokens
- **Event-Driven**: Kafka topics for inter-service communication

## 📋 Prerequisites

- Docker and Docker Compose
- Git
- Windows 11 (as specified)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Distributed-Systems-and-Applications-Project2
```

### 2. Start the System

```bash
# Start all services
docker-compose up -d

# Wait for services to be ready (about 2-3 minutes)
docker-compose logs -f
```

### 3. Create Kafka Topics

```bash
# Make the script executable and run it
chmod +x kafka-topics.sh
./kafka-topics.sh
```

### 4. Verify Services

Check that all services are running:

```bash
# Check service status
docker-compose ps

# Check logs
docker-compose logs passenger-service
docker-compose logs transport-service
docker-compose logs ticketing-service
docker-compose logs payment-service
docker-compose logs notification-service
docker-compose logs admin-service
```

## 📡 API Endpoints

### Passenger Service (Port 8081)
- `POST /api/v1/passengers/register` - Register new passenger
- `POST /api/v1/passengers/login` - Login passenger
- `GET /api/v1/passengers/profile` - Get user profile
- `GET /api/v1/passengers/tickets` - Get user tickets
- `PUT /api/v1/passengers/profile` - Update profile

### Transport Service (Port 8082)
- `GET /api/v1/transport/routes` - Get all routes
- `GET /api/v1/transport/routes/{id}` - Get route by ID
- `GET /api/v1/transport/routes/{id}/trips` - Get trips for route
- `GET /api/v1/transport/trips` - Get all trips
- `GET /api/v1/transport/trips/{id}` - Get trip by ID
- `PUT /api/v1/transport/trips/{id}/status` - Update trip status
- `GET /api/v1/transport/disruptions` - Get service disruptions
- `GET /api/v1/transport/search` - Search routes

### Ticketing Service (Port 8083)
- `POST /api/v1/tickets/` - Create new ticket
- `GET /api/v1/tickets/{code}` - Get ticket by code
- `POST /api/v1/tickets/validate` - Validate ticket
- `GET /api/v1/tickets/passenger/{id}` - Get passenger tickets
- `PUT /api/v1/tickets/{code}/cancel` - Cancel ticket

### Payment Service (Port 8084)
- `POST /api/v1/payments/process` - Process payment
- `GET /api/v1/payments/transaction/{id}` - Get payment by transaction ID
- `GET /api/v1/payments/ticket/{id}` - Get payments for ticket
- `POST /api/v1/payments/refund` - Process refund
- `GET /api/v1/payments/statistics` - Get payment statistics

### Notification Service (Port 8085)
- `POST /api/v1/notifications/send` - Send notification
- `GET /api/v1/notifications/user/{id}` - Get user notifications
- `PUT /api/v1/notifications/{id}/read` - Mark notification as read
- `PUT /api/v1/notifications/user/{id}/read-all` - Mark all as read
- `DELETE /api/v1/notifications/{id}` - Delete notification
- `GET /api/v1/notifications/statistics` - Get notification statistics
- `POST /api/v1/notifications/bulk` - Send bulk notification

### Admin Service (Port 8086)
- `POST /api/v1/admin/routes` - Create route
- `POST /api/v1/admin/trips` - Create trip
- `POST /api/v1/admin/disruptions` - Create service disruption
- `GET /api/v1/admin/dashboard` - Get dashboard statistics
- `GET /api/v1/admin/routes/statistics` - Get route statistics
- `GET /api/v1/admin/trips/statistics` - Get trip statistics
- `PUT /api/v1/admin/trips/{id}/status` - Update trip status
- `GET /api/v1/admin/users` - Get all users

## 🎫 Ticket Types

- **Single Ride**: One-time use ticket (5 NAD)
- **Multiple Rides**: Multi-use ticket with 20% discount
- **Weekly Pass**: 7-day unlimited travel (50 NAD)
- **Monthly Pass**: 30-day unlimited travel (150 NAD)

## 🚌 Sample Routes (Windhoek)

- **B001**: CBD to Katutura (8.5 km, 25 minutes)
- **B002**: CBD to Khomasdal (6.2 km, 20 minutes)
- **B003**: CBD to Eros Airport (12.3 km, 35 minutes)
- **T001**: Windhoek to Okahandja (45 km, 60 minutes)
- **T002**: Windhoek to Rehoboth (85 km, 90 minutes)

## 🔧 Development

### Building Individual Services

```bash
# Navigate to service directory
cd services/passenger-service

# Build the service
bal build

# Run the service
bal run
```

### Database Schema

The system uses MySQL with the following main tables:
- `users` - User accounts and profiles
- `routes` - Bus and train routes
- `stops` - Route stops and locations
- `trips` - Scheduled trips
- `tickets` - Ticket records and status
- `payments` - Payment transactions
- `notifications` - User notifications
- `service_disruptions` - Service disruption announcements

### Kafka Topics

- `user-registration` - User registration events
- `user-login` - User login events
- `ticket-created` - Ticket creation events
- `ticket-validated` - Ticket validation events
- `ticket-cancelled` - Ticket cancellation events
- `payment-completed` - Successful payment events
- `payment-failed` - Failed payment events
- `payment-refunded` - Refund events
- `trip-status-update` - Trip status changes
- `service-disruption` - Service disruption announcements

## 🧪 Testing

### Test User Registration

```bash
curl -X POST http://localhost:8081/api/v1/passengers/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+264811234567"
  }'
```

### Test User Login

```bash
curl -X POST http://localhost:8081/api/v1/passengers/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Test Route Search

```bash
curl -X GET "http://localhost:8082/api/v1/transport/search?query=Katutura&transportType=BUS"
```

### Test Ticket Creation

```bash
curl -X POST http://localhost:8083/api/v1/tickets/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "tripId": 1,
    "ticketType": "SINGLE_RIDE"
  }'
```

## 📊 Monitoring

### Check Service Health

```bash
# Check all services
docker-compose ps

# Check specific service logs
docker-compose logs passenger-service
docker-compose logs transport-service
```

### Database Connection

```bash
# Connect to MySQL
docker exec -it mysql mysql -u transport_user -p transport_ticketing
```

### Kafka Topics

```bash
# List Kafka topics
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092

# Check topic messages
docker exec -it kafka kafka-console-consumer --topic user-registration --bootstrap-server localhost:9092 --from-beginning
```

## 🛠️ Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker logs with `docker-compose logs`
2. **Database connection issues**: Ensure MySQL is running and accessible
3. **Kafka connection issues**: Verify Kafka is running and topics are created
4. **Port conflicts**: Ensure ports 8081-8086, 3306, 9092 are available

### Reset System

```bash
# Stop all services
docker-compose down

# Remove volumes (WARNING: This deletes all data)
docker-compose down -v

# Start fresh
docker-compose up -d
```

## 📝 API Documentation

### Authentication

Most endpoints require JWT authentication. Include the token in the Authorization header:

```
Authorization: Bearer YOUR_JWT_TOKEN
```

### Error Responses

All services return consistent error responses:

```json
{
  "message": "Error description"
}
```

### Success Responses

Successful operations return appropriate data:

```json
{
  "message": "Operation successful",
  "data": { ... }
}
```

## 🔒 Security

- JWT-based authentication
- Password hashing with SHA-256
- Input validation and sanitization
- SQL injection prevention
- CORS configuration for web clients

## 📈 Performance

- Microservices architecture for scalability
- Event-driven communication for loose coupling
- Database indexing for query optimization
- Connection pooling for database efficiency
- Kafka for high-throughput message processing

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the troubleshooting section

## 🎯 Future Enhancements

- Mobile app integration
- Real-time GPS tracking
- Advanced analytics dashboard
- Machine learning for demand prediction
- Integration with external payment gateways
- Multi-language support
- Accessibility improvements

---

**Built for Windhoek City Council** 🏛️  
**Distributed Systems and Applications Project 2** 📚

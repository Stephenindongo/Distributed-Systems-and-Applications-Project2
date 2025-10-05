# Windhoek Transport Ticketing System - Project Summary

## 🎯 Project Overview

A comprehensive distributed smart public transport ticketing system built for Windhoek City, Namibia. This system demonstrates real-world distributed systems skills including microservices architecture, event-driven communication, persistent storage, containerization, and orchestration.

## 🏗️ System Architecture

### Microservices (6 Services)
1. **Passenger Service** (Port 8081) - User management, authentication, profiles
2. **Transport Service** (Port 8082) - Routes, trips, schedules, disruptions
3. **Ticketing Service** (Port 8083) - Ticket lifecycle management, validation
4. **Payment Service** (Port 8084) - Payment processing, refunds, transactions
5. **Notification Service** (Port 8085) - Real-time notifications, event handling
6. **Admin Service** (Port 8086) - Administrative functions, reporting, analytics

### Infrastructure
- **Database**: MySQL 8.0 with comprehensive schema
- **Message Broker**: Apache Kafka with 10 topics
- **Containerization**: Docker & Docker Compose
- **Authentication**: JWT-based security
- **Monitoring**: Prometheus, Grafana, Jaeger, ELK Stack

## 🚀 Key Features Implemented

### For Passengers
- ✅ User registration and secure login
- ✅ Browse routes, trips, and schedules
- ✅ Purchase different ticket types (single-ride, multiple rides, passes)
- ✅ Ticket validation on boarding
- ✅ Real-time notifications for disruptions
- ✅ Profile management

### For Administrators
- ✅ Create and manage routes and trips
- ✅ Monitor ticket sales and passenger traffic
- ✅ Publish service disruptions and schedule changes
- ✅ Generate comprehensive reports and analytics
- ✅ User management and system oversight

### For System
- ✅ Scalable microservices architecture
- ✅ Event-driven communication via Kafka
- ✅ Persistent data storage with MySQL
- ✅ Containerized deployment with Docker
- ✅ Comprehensive monitoring and logging
- ✅ Fault-tolerant design

## 🛠️ Technology Stack

- **Language**: Ballerina 2201.8.5
- **Database**: MySQL 8.0
- **Message Broker**: Apache Kafka
- **Containerization**: Docker & Docker Compose
- **Authentication**: JWT tokens
- **Monitoring**: Prometheus, Grafana, Jaeger
- **Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)
- **Tracing**: Jaeger for distributed tracing

## 📊 Database Schema

### Core Tables
- `users` - User accounts and profiles
- `routes` - Bus and train routes
- `stops` - Route stops and locations
- `trips` - Scheduled trips
- `tickets` - Ticket records and status
- `payments` - Payment transactions
- `notifications` - User notifications
- `service_disruptions` - Service announcements

### Sample Data
- 5 pre-configured routes for Windhoek
- 7 sample stops across the city
- Multiple trip schedules
- Comprehensive indexes for performance

## 🔄 Event-Driven Architecture

### Kafka Topics (10 Topics)
- `user-registration` - New user events
- `user-login` - Authentication events
- `ticket-created` - Ticket creation events
- `ticket-validated` - Validation events
- `ticket-cancelled` - Cancellation events
- `payment-completed` - Successful payments
- `payment-failed` - Failed payments
- `payment-refunded` - Refund events
- `trip-status-update` - Trip changes
- `service-disruption` - Disruption announcements

## 🎫 Ticket System

### Ticket Types
- **Single Ride**: 5 NAD (one-time use)
- **Multiple Rides**: 20% discount for multi-use
- **Weekly Pass**: 50 NAD (7-day unlimited)
- **Monthly Pass**: 150 NAD (30-day unlimited)

### Ticket Lifecycle
1. **CREATED** - Ticket created, awaiting payment
2. **PAID** - Payment processed successfully
3. **VALIDATED** - Ticket used for travel
4. **EXPIRED** - Ticket past expiry date
5. **CANCELLED** - Ticket cancelled/refunded

## 🚌 Windhoek Routes

### Bus Routes
- **B001**: CBD to Katutura (8.5 km, 25 min)
- **B002**: CBD to Khomasdal (6.2 km, 20 min)
- **B003**: CBD to Eros Airport (12.3 km, 35 min)

### Train Routes
- **T001**: Windhoek to Okahandja (45 km, 60 min)
- **T002**: Windhoek to Rehoboth (85 km, 90 min)

## 📡 API Endpoints

### Passenger Service (8081)
- `POST /api/v1/passengers/register` - User registration
- `POST /api/v1/passengers/login` - User login
- `GET /api/v1/passengers/profile` - Get profile
- `GET /api/v1/passengers/tickets` - Get user tickets
- `PUT /api/v1/passengers/profile` - Update profile

### Transport Service (8082)
- `GET /api/v1/transport/routes` - Get all routes
- `GET /api/v1/transport/trips` - Get all trips
- `GET /api/v1/transport/search` - Search routes
- `GET /api/v1/transport/disruptions` - Get disruptions

### Ticketing Service (8083)
- `POST /api/v1/tickets/` - Create ticket
- `GET /api/v1/tickets/{code}` - Get ticket
- `POST /api/v1/tickets/validate` - Validate ticket
- `PUT /api/v1/tickets/{code}/cancel` - Cancel ticket

### Payment Service (8084)
- `POST /api/v1/payments/process` - Process payment
- `GET /api/v1/payments/statistics` - Get statistics
- `POST /api/v1/payments/refund` - Process refund

### Notification Service (8085)
- `GET /api/v1/notifications/user/{id}` - Get notifications
- `POST /api/v1/notifications/send` - Send notification
- `PUT /api/v1/notifications/{id}/read` - Mark as read

### Admin Service (8086)
- `GET /api/v1/admin/dashboard` - Dashboard stats
- `POST /api/v1/admin/routes` - Create route
- `GET /api/v1/admin/routes/statistics` - Route statistics

## 🔧 Setup Instructions

### Quick Start
```bash
# 1. Start the system
docker-compose up -d

# 2. Create Kafka topics
./kafka-topics.sh

# 3. Start monitoring (optional)
./start-monitoring.sh
```

### Verification
```bash
# Check services
docker-compose ps

# Test API
curl http://localhost:8082/api/v1/transport/routes
```

## 📊 Monitoring & Observability

### Metrics Collection
- **Prometheus**: System and application metrics
- **Grafana**: Visualization dashboards
- **Node Exporter**: System metrics
- **cAdvisor**: Container metrics
- **MySQL Exporter**: Database metrics
- **Kafka Exporter**: Message broker metrics

### Logging
- **ELK Stack**: Centralized logging
- **Fluentd**: Log collection
- **Logstash**: Log processing
- **Elasticsearch**: Log storage
- **Kibana**: Log visualization

### Tracing
- **Jaeger**: Distributed tracing
- **Request correlation**: End-to-end request tracking

## 🧪 Testing

### API Testing
- Complete user journey testing
- Load testing capabilities
- Integration testing scripts
- Health check endpoints

### Sample Test Flow
1. Register user → Get JWT token
2. Search routes → Select trip
3. Create ticket → Process payment
4. Validate ticket → Receive notifications

## 🔒 Security Features

- JWT-based authentication
- Password hashing (SHA-256)
- Input validation and sanitization
- SQL injection prevention
- Role-based access control
- Secure API endpoints

## 📈 Performance Features

- Microservices for horizontal scaling
- Event-driven architecture for loose coupling
- Database indexing for query optimization
- Connection pooling for efficiency
- Kafka for high-throughput messaging
- Container orchestration for deployment

## 🎯 Learning Outcomes Demonstrated

### Distributed Systems Concepts
- ✅ Microservices architecture
- ✅ Event-driven communication
- ✅ Service discovery and communication
- ✅ Data consistency and trade-offs
- ✅ Fault tolerance and resilience

### Technical Skills
- ✅ Containerization with Docker
- ✅ Orchestration with Docker Compose
- ✅ Message queuing with Kafka
- ✅ Database design and optimization
- ✅ API design and implementation
- ✅ Monitoring and observability

### Real-World Application
- ✅ Production-like environment
- ✅ Scalable architecture
- ✅ Comprehensive documentation
- ✅ Testing and validation
- ✅ Monitoring and maintenance

## 📁 Project Structure

```
Distributed-Systems-and-Applications-Project2/
├── docker-compose.yml                 # Main orchestration
├── database/init.sql                  # Database schema
├── services/                          # Microservices
│   ├── passenger-service/
│   ├── transport-service/
│   ├── ticketing-service/
│   ├── payment-service/
│   ├── notification-service/
│   └── admin-service/
├── monitoring/                        # Monitoring stack
├── kafka-topics.sh                   # Kafka setup
├── start-monitoring.sh               # Monitoring setup
├── README.md                         # Main documentation
├── SETUP_GUIDE.md                    # Setup instructions
├── COMMANDS.md                       # Command reference
└── PROJECT_SUMMARY.md               # This file
```

## 🎉 Success Metrics

### Functional Requirements ✅
- User registration and authentication
- Route and trip management
- Ticket creation and validation
- Payment processing
- Real-time notifications
- Administrative functions

### Non-Functional Requirements ✅
- Scalable microservices architecture
- Event-driven communication
- Persistent data storage
- Containerized deployment
- Comprehensive monitoring
- Fault tolerance

### Technical Excellence ✅
- Clean code architecture
- Comprehensive documentation
- Testing capabilities
- Monitoring and observability
- Security best practices
- Performance optimization

## 🚀 Future Enhancements

- Mobile application development
- Real-time GPS tracking
- Machine learning for demand prediction
- Advanced analytics dashboard
- Multi-language support
- Integration with external payment gateways
- Accessibility improvements

## 📞 Support & Maintenance

- Comprehensive documentation provided
- Setup guides and troubleshooting
- Command reference for operations
- Monitoring and alerting configured
- Logging and tracing implemented

---

**🎯 Project Status: COMPLETE** ✅

This distributed smart public transport ticketing system successfully demonstrates all required distributed systems concepts and provides a production-ready foundation for Windhoek City's transportation needs.

**Built with ❤️ for Windhoek City Council** 🏛️

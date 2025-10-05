
## 🎯 Project Overview

A  distributed smart public transport ticketing system . 

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


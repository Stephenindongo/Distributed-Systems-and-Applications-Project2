-- Windhoek Transport Ticketing System Database Schema
CREATE DATABASE IF NOT EXISTS transport_ticketing;

USE transport_ticketing;

-- Users table for passengers and administrators
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    user_type ENUM('PASSENGER', 'ADMIN', 'VALIDATOR') DEFAULT 'PASSENGER',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Routes table for bus and train routes
CREATE TABLE routes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    route_number VARCHAR(20) UNIQUE NOT NULL,
    route_name VARCHAR(255) NOT NULL,
    transport_type ENUM('BUS', 'TRAIN') NOT NULL,
    start_location VARCHAR(255) NOT NULL,
    end_location VARCHAR(255) NOT NULL,
    distance_km DECIMAL(8,2),
    estimated_duration_minutes INT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Stops table for route stops
CREATE TABLE stops (
    id INT AUTO_INCREMENT PRIMARY KEY,
    stop_name VARCHAR(255) NOT NULL,
    stop_code VARCHAR(20) UNIQUE NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Route stops mapping
CREATE TABLE route_stops (
    id INT AUTO_INCREMENT PRIMARY KEY,
    route_id INT NOT NULL,
    stop_id INT NOT NULL,
    sequence_order INT NOT NULL,
    estimated_arrival_time TIME,
    FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
    FOREIGN KEY (stop_id) REFERENCES stops(id) ON DELETE CASCADE,
    UNIQUE KEY unique_route_stop_sequence (route_id, sequence_order)
);

-- Trips table for scheduled trips
CREATE TABLE trips (
    id INT AUTO_INCREMENT PRIMARY KEY,
    route_id INT NOT NULL,
    trip_number VARCHAR(50) NOT NULL,
    departure_time TIME NOT NULL,
    arrival_time TIME NOT NULL,
    trip_date DATE NOT NULL,
    status ENUM('SCHEDULED', 'ON_TIME', 'DELAYED', 'CANCELLED') DEFAULT 'SCHEDULED',
    delay_minutes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE,
    UNIQUE KEY unique_trip (route_id, trip_number, trip_date)
);

-- Tickets table
CREATE TABLE tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ticket_code VARCHAR(50) UNIQUE NOT NULL,
    passenger_id INT NOT NULL,
    trip_id INT NOT NULL,
    ticket_type ENUM('SINGLE_RIDE', 'MULTIPLE_RIDES', 'WEEKLY_PASS', 'MONTHLY_PASS') NOT NULL,
    status ENUM('CREATED', 'PAID', 'VALIDATED', 'EXPIRED', 'CANCELLED') DEFAULT 'CREATED',
    price DECIMAL(10,2) NOT NULL,
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiry_date TIMESTAMP,
    validation_count INT DEFAULT 0,
    max_validations INT DEFAULT 1,
    validated_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (passenger_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
);

-- Payments table
CREATE TABLE payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ticket_id INT NOT NULL,
    payment_method ENUM('CASH', 'CARD', 'MOBILE_MONEY', 'BANK_TRANSFER') NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'NAD',
    status ENUM('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED') DEFAULT 'PENDING',
    transaction_id VARCHAR(100) UNIQUE,
    payment_reference VARCHAR(100),
    processed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE
);

-- Notifications table
CREATE TABLE notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    notification_type ENUM('TRIP_UPDATE', 'TICKET_VALIDATION', 'PAYMENT_CONFIRMATION', 'SERVICE_DISRUPTION') NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Service disruptions table
CREATE TABLE service_disruptions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    route_id INT,
    disruption_type ENUM('DELAY', 'CANCELLATION', 'DETOUR', 'MAINTENANCE') NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') DEFAULT 'MEDIUM',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (route_id) REFERENCES routes(id) ON DELETE CASCADE
);

-- Insert sample data for Windhoek routes
INSERT INTO routes (route_number, route_name, transport_type, start_location, end_location, distance_km, estimated_duration_minutes) VALUES
('B001', 'CBD to Katutura', 'BUS', 'Windhoek CBD', 'Katutura', 8.5, 25),
('B002', 'CBD to Khomasdal', 'BUS', 'Windhoek CBD', 'Khomasdal', 6.2, 20),
('B003', 'CBD to Eros Airport', 'BUS', 'Windhoek CBD', 'Eros Airport', 12.3, 35),
('T001', 'Windhoek to Okahandja', 'TRAIN', 'Windhoek Station', 'Okahandja Station', 45.0, 60),
('T002', 'Windhoek to Rehoboth', 'TRAIN', 'Windhoek Station', 'Rehoboth Station', 85.0, 90);

-- Insert sample stops
INSERT INTO stops (stop_name, stop_code, latitude, longitude, address) VALUES
('Windhoek CBD', 'CBD001', -22.5609, 17.0658, 'Independence Avenue, Windhoek'),
('Katutura Market', 'KAT001', -22.5200, 17.0800, 'Katutura Market, Windhoek'),
('Khomasdal Centre', 'KHO001', -22.6000, 17.1000, 'Khomasdal Shopping Centre'),
('Eros Airport', 'EROS001', -22.6119, 17.0806, 'Eros Airport, Windhoek'),
('Windhoek Station', 'WST001', -22.5700, 17.0800, 'Windhoek Railway Station'),
('Okahandja Station', 'OKA001', -21.9833, 16.9167, 'Okahandja Railway Station'),
('Rehoboth Station', 'REH001', -23.3167, 17.0833, 'Rehoboth Railway Station');

-- Insert sample trips
INSERT INTO trips (route_id, trip_number, departure_time, arrival_time, trip_date, status) VALUES
(1, 'B001-001', '06:00:00', '06:25:00', CURDATE(), 'SCHEDULED'),
(1, 'B001-002', '07:00:00', '07:25:00', CURDATE(), 'SCHEDULED'),
(1, 'B001-003', '08:00:00', '08:25:00', CURDATE(), 'SCHEDULED'),
(2, 'B002-001', '06:30:00', '06:50:00', CURDATE(), 'SCHEDULED'),
(2, 'B002-002', '07:30:00', '07:50:00', CURDATE(), 'SCHEDULED'),
(5, 'T001-001', '08:00:00', '09:00:00', CURDATE(), 'SCHEDULED'),
(5, 'T001-002', '14:00:00', '15:00:00', CURDATE(), 'SCHEDULED');

-- Create indexes for better performance
CREATE INDEX idx_tickets_passenger ON tickets(passenger_id);
CREATE INDEX idx_tickets_trip ON tickets(trip_id);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_code ON tickets(ticket_code);
CREATE INDEX idx_trips_route_date ON trips(route_id, trip_date);
CREATE INDEX idx_trips_status ON trips(status);
CREATE INDEX idx_payments_ticket ON payments(ticket_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(notification_type);

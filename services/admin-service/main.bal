import ballerina/http;
import ballerina/sql;
import ballerina/mysql;
import ballerina/log;
import ballerina/io;
import ballerina/time;
import ballerina/uuid;
import ballerina/jwt;
import ballerina/constraint;
import ballerina/regex;
import ballerina/kafka;

// Database configuration
configurable string databaseUrl = "jdbc:mysql://localhost:3306/transport_ticketing";
configurable string databaseUser = "root";
configurable string databasePassword = "password123";

// Kafka configuration
configurable string kafkaBrokers = "localhost:9092";

// JWT configuration
configurable string jwtSecret = "windhoek-transport-secret-key-2024";

// Database client
mysql:Client dbClient = check new (databaseUrl, databaseUser, databasePassword);

// Kafka producer
kafka:Producer kafkaProducer = check new (kafkaBrokers);

// Data types
public type RouteCreateRequest record {
    string routeNumber;
    string routeName;
    string transportType;
    string startLocation;
    string endLocation;
    decimal? distanceKm;
    int? estimatedDurationMinutes;
};

public type TripCreateRequest record {
    int routeId;
    string tripNumber;
    string departureTime;
    string arrivalTime;
    string tripDate;
};

public type ServiceDisruptionCreateRequest record {
    int? routeId;
    string disruptionType;
    string title;
    string description;
    string startTime;
    string? endTime;
    string severity;
};

public type DashboardStats record {
    int totalUsers;
    int totalRoutes;
    int totalTrips;
    int totalTickets;
    decimal totalRevenue;
    int activeDisruptions;
};

public type RouteStats record {
    int routeId;
    string routeNumber;
    string routeName;
    int totalTrips;
    int totalTickets;
    decimal totalRevenue;
    decimal averageOccupancy;
};

public type TripStats record {
    int tripId;
    string tripNumber;
    string routeName;
    string departureTime;
    string tripDate;
    int totalTickets;
    decimal revenue;
    string status;
};

// Utility functions
function validateAdminAccess(jwt:Payload payload) returns boolean {
    string userType = <string>payload["user_type"];
    return userType == "ADMIN";
}

function validateRouteNumber(string routeNumber) returns boolean {
    string pattern = "^[BT][0-9]{3}$";
    return regex:matches(routeNumber, pattern);
}

function validateTripNumber(string tripNumber) returns boolean {
    string pattern = "^[BT][0-9]{3}-[0-9]{3}$";
    return regex:matches(tripNumber, pattern);
}

// HTTP service
@http:ServiceConfig {
    basePath: "/api/v1/admin"
}
service / on new http:Listener(8086) {
    
    // Create route
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/routes"
    }
    resource function post createRoute(@http:Header string authorization, @http:Payload RouteCreateRequest routeRequest) 
            returns http:Created|http:Unauthorized|http:BadRequest|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        // Validate input
        if routeRequest.routeNumber == "" || routeRequest.routeName == "" {
            return <http:BadRequest>{
                body: {message: "Route number and name are required"}
            };
        }
        
        if !validateRouteNumber(routeRequest.routeNumber) {
            return <http:BadRequest>{
                body: {message: "Invalid route number format. Use B001, T001, etc."}
            };
        }
        
        if routeRequest.transportType != "BUS" && routeRequest.transportType != "TRAIN" {
            return <http:BadRequest>{
                body: {message: "Transport type must be BUS or TRAIN"}
            };
        }
        
        // Check if route number already exists
        stream<record {}, sql:Error?>|sql:Error existingRouteStream = 
            dbClient->query(`SELECT id FROM routes WHERE route_number = '${routeRequest.routeNumber}'`);
        
        record {}|sql:Error? existingRouteResult = existingRouteStream.next();
        if existingRouteResult is record {} {
            return <http:BadRequest>{
                body: {message: "Route number already exists"}
            };
        }
        
        // Create route
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
            INSERT INTO routes (route_number, route_name, transport_type, start_location, 
                              end_location, distance_km, estimated_duration_minutes)
            VALUES ('${routeRequest.routeNumber}', '${routeRequest.routeName}', 
                   '${routeRequest.transportType}', '${routeRequest.startLocation}', 
                   '${routeRequest.endLocation}', 
                   ${routeRequest.distanceKm is decimal ? routeRequest.distanceKm.toString() : "NULL"}, 
                   ${routeRequest.estimatedDurationMinutes is int ? routeRequest.estimatedDurationMinutes.toString() : "NULL"})
        `);
        
        if insertResult is sql:Error {
            log:printError("Failed to create route", 'error = insertResult);
            return <http:InternalServerError>{
                body: {message: "Failed to create route"}
            };
        }
        
        return <http:Created>{
            body: {message: "Route created successfully"}
        };
    }
    
    // Create trip
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/trips"
    }
    resource function post createTrip(@http:Header string authorization, @http:Payload TripCreateRequest tripRequest) 
            returns http:Created|http:Unauthorized|http:BadRequest|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        // Validate input
        if tripRequest.routeId <= 0 {
            return <http:BadRequest>{
                body: {message: "Valid route ID is required"}
            };
        }
        
        if tripRequest.tripNumber == "" {
            return <http:BadRequest>{
                body: {message: "Trip number is required"}
            };
        }
        
        if !validateTripNumber(tripRequest.tripNumber) {
            return <http:BadRequest>{
                body: {message: "Invalid trip number format. Use B001-001, T001-001, etc."}
            };
        }
        
        if tripRequest.departureTime == "" || tripRequest.arrivalTime == "" {
            return <http:BadRequest>{
                body: {message: "Departure and arrival times are required"}
            };
        }
        
        if tripRequest.tripDate == "" {
            return <http:BadRequest>{
                body: {message: "Trip date is required"}
            };
        }
        
        // Check if route exists
        stream<record {}, sql:Error?>|sql:Error routeStream = 
            dbClient->query(`SELECT id FROM routes WHERE id = ${tripRequest.routeId}`);
        
        record {}|sql:Error? routeResult = routeStream.next();
        if routeResult is () {
            return <http:BadRequest>{
                body: {message: "Route not found"}
            };
        }
        
        // Check if trip already exists
        stream<record {}, sql:Error?>|sql:Error existingTripStream = 
            dbClient->query(`SELECT id FROM trips WHERE route_id = ${tripRequest.routeId} AND trip_number = '${tripRequest.tripNumber}' AND trip_date = '${tripRequest.tripDate}'`);
        
        record {}|sql:Error? existingTripResult = existingTripStream.next();
        if existingTripResult is record {} {
            return <http:BadRequest>{
                body: {message: "Trip already exists for this route and date"}
            };
        }
        
        // Create trip
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
            INSERT INTO trips (route_id, trip_number, departure_time, arrival_time, trip_date)
            VALUES (${tripRequest.routeId}, '${tripRequest.tripNumber}', 
                   '${tripRequest.departureTime}', '${tripRequest.arrivalTime}', 
                   '${tripRequest.tripDate}')
        `);
        
        if insertResult is sql:Error {
            log:printError("Failed to create trip", 'error = insertResult);
            return <http:InternalServerError>{
                body: {message: "Failed to create trip"}
            };
        }
        
        return <http:Created>{
            body: {message: "Trip created successfully"}
        };
    }
    
    // Create service disruption
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/disruptions"
    }
    resource function post createDisruption(@http:Header string authorization, @http:Payload ServiceDisruptionCreateRequest disruptionRequest) 
            returns http:Created|http:Unauthorized|http:BadRequest|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        // Validate input
        if disruptionRequest.title == "" || disruptionRequest.description == "" {
            return <http:BadRequest>{
                body: {message: "Title and description are required"}
            };
        }
        
        if disruptionRequest.disruptionType == "" {
            return <http:BadRequest>{
                body: {message: "Disruption type is required"}
            };
        }
        
        if disruptionRequest.startTime == "" {
            return <http:BadRequest>{
                body: {message: "Start time is required"}
            };
        }
        
        // Create service disruption
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
            INSERT INTO service_disruptions (route_id, disruption_type, title, description, 
                                           start_time, end_time, severity)
            VALUES (${disruptionRequest.routeId is int ? disruptionRequest.routeId.toString() : "NULL"}, 
                   '${disruptionRequest.disruptionType}', '${disruptionRequest.title}', 
                   '${disruptionRequest.description}', '${disruptionRequest.startTime}', 
                   ${disruptionRequest.endTime is string ? "'" + disruptionRequest.endTime + "'" : "NULL"}, 
                   '${disruptionRequest.severity}')
        `);
        
        if insertResult is sql:Error {
            log:printError("Failed to create service disruption", 'error = insertResult);
            return <http:InternalServerError>{
                body: {message: "Failed to create service disruption"}
            };
        }
        
        // Send disruption event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "service-disruption",
            value: {
                disruptionType: disruptionRequest.disruptionType,
                title: disruptionRequest.title,
                description: disruptionRequest.description,
                routeId: disruptionRequest.routeId,
                severity: disruptionRequest.severity,
                timestamp: time:utcNow().toString()
            }.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send disruption event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Created>{
            body: {message: "Service disruption created successfully"}
        };
    }
    
    // Get dashboard statistics
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/dashboard"
    }
    resource function get dashboard(@http:Header string authorization) 
            returns http:Ok|http:Unauthorized|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        // Get dashboard statistics
        stream<record {}, sql:Error?>|sql:Error statsStream = 
            dbClient->query(`
                SELECT 
                    (SELECT COUNT(*) FROM users) as total_users,
                    (SELECT COUNT(*) FROM routes WHERE is_active = true) as total_routes,
                    (SELECT COUNT(*) FROM trips) as total_trips,
                    (SELECT COUNT(*) FROM tickets) as total_tickets,
                    (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'COMPLETED') as total_revenue,
                    (SELECT COUNT(*) FROM service_disruptions WHERE is_active = true) as active_disruptions
            `);
        
        record {}|sql:Error? statsResult = statsStream.next();
        if statsResult is sql:Error {
            log:printError("Database error retrieving dashboard statistics", 'error = statsResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve dashboard statistics"}
            };
        }
        
        DashboardStats stats = {
            totalUsers: <int>statsResult["total_users"],
            totalRoutes: <int>statsResult["total_routes"],
            totalTrips: <int>statsResult["total_trips"],
            totalTickets: <int>statsResult["total_tickets"],
            totalRevenue: <decimal>statsResult["total_revenue"],
            activeDisruptions: <int>statsResult["active_disruptions"]
        };
        
        return <http:Ok>{
            body: stats
        };
    }
    
    // Get route statistics
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/routes/statistics"
    }
    resource function get routeStatistics(@http:Header string authorization) 
            returns http:Ok|http:Unauthorized|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        stream<record {}, sql:Error?>|sql:Error routeStatsStream = 
            dbClient->query(`
                SELECT 
                    r.id as route_id,
                    r.route_number,
                    r.route_name,
                    COUNT(DISTINCT t.id) as total_trips,
                    COUNT(DISTINCT tk.id) as total_tickets,
                    COALESCE(SUM(p.amount), 0) as total_revenue,
                    COALESCE(AVG(tk.validation_count), 0) as average_occupancy
                FROM routes r
                LEFT JOIN trips t ON r.id = t.route_id
                LEFT JOIN tickets tk ON t.id = tk.trip_id
                LEFT JOIN payments p ON tk.id = p.ticket_id AND p.status = 'COMPLETED'
                WHERE r.is_active = true
                GROUP BY r.id, r.route_number, r.route_name
                ORDER BY total_revenue DESC
            `);
        
        RouteStats[] routeStats = [];
        record {}|sql:Error? routeStatResult = routeStatsStream.next();
        
        while routeStatResult is record {} {
            RouteStats routeStat = {
                routeId: <int>routeStatResult["route_id"],
                routeNumber: <string>routeStatResult["route_number"],
                routeName: <string>routeStatResult["route_name"],
                totalTrips: <int>routeStatResult["total_trips"],
                totalTickets: <int>routeStatResult["total_tickets"],
                totalRevenue: <decimal>routeStatResult["total_revenue"],
                averageOccupancy: <decimal>routeStatResult["average_occupancy"]
            };
            routeStats.push(routeStat);
            routeStatResult = routeStatsStream.next();
        }
        
        if routeStatResult is sql:Error {
            log:printError("Database error retrieving route statistics", 'error = routeStatResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve route statistics"}
            };
        }
        
        return <http:Ok>{
            body: {routeStats: routeStats}
        };
    }
    
    // Get trip statistics
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/trips/statistics"
    }
    resource function get tripStatistics(@http:Header string authorization, @http:Query string? date) 
            returns http:Ok|http:Unauthorized|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        string dateFilter = date is string ? `AND t.trip_date = '${date}'` : "";
        
        stream<record {}, sql:Error?>|sql:Error tripStatsStream = 
            dbClient->query(`
                SELECT 
                    t.id as trip_id,
                    t.trip_number,
                    r.route_name,
                    t.departure_time,
                    t.trip_date,
                    COUNT(tk.id) as total_tickets,
                    COALESCE(SUM(p.amount), 0) as revenue,
                    t.status
                FROM trips t
                JOIN routes r ON t.route_id = r.id
                LEFT JOIN tickets tk ON t.id = tk.trip_id
                LEFT JOIN payments p ON tk.id = p.ticket_id AND p.status = 'COMPLETED'
                WHERE 1=1 ${dateFilter}
                GROUP BY t.id, t.trip_number, r.route_name, t.departure_time, t.trip_date, t.status
                ORDER BY t.departure_time
            `);
        
        TripStats[] tripStats = [];
        record {}|sql:Error? tripStatResult = tripStatsStream.next();
        
        while tripStatResult is record {} {
            TripStats tripStat = {
                tripId: <int>tripStatResult["trip_id"],
                tripNumber: <string>tripStatResult["trip_number"],
                routeName: <string>tripStatResult["route_name"],
                departureTime: <string>tripStatResult["departure_time"],
                tripDate: <string>tripStatResult["trip_date"],
                totalTickets: <int>tripStatResult["total_tickets"],
                revenue: <decimal>tripStatResult["revenue"],
                status: <string>tripStatResult["status"]
            };
            tripStats.push(tripStat);
            tripStatResult = tripStatsStream.next();
        }
        
        if tripStatResult is sql:Error {
            log:printError("Database error retrieving trip statistics", 'error = tripStatResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve trip statistics"}
            };
        }
        
        return <http:Ok>{
            body: {tripStats: tripStats}
        };
    }
    
    // Update trip status
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/trips/{tripId}/status"
    }
    resource function put updateTripStatus(int tripId, @http:Header string authorization, @http:Payload record {
        string status;
        int? delayMinutes;
    } statusUpdate) returns http:Ok|http:Unauthorized|http:NotFound|http:BadRequest|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        if statusUpdate.status == "" {
            return <http:BadRequest>{
                body: {message: "Status is required"}
            };
        }
        
        string delayUpdate = statusUpdate.delayMinutes is int ? 
            `, delay_minutes = ${statusUpdate.delayMinutes}` : "";
        
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
            UPDATE trips 
            SET status = '${statusUpdate.status}'${delayUpdate}, updated_at = NOW()
            WHERE id = ${tripId}
        `);
        
        if updateResult is sql:Error {
            log:printError("Failed to update trip status", 'error = updateResult);
            return <http:InternalServerError>{
                body: {message: "Failed to update trip status"}
            };
        }
        
        if updateResult.affectedRowCount == 0 {
            return <http:NotFound>{
                body: {message: "Trip not found"}
            };
        }
        
        // Send trip update event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "trip-status-update",
            value: {
                tripId: tripId,
                status: statusUpdate.status,
                delayMinutes: statusUpdate.delayMinutes,
                timestamp: time:utcNow().toString()
            }.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send trip update event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Ok>{
            body: {message: "Trip status updated successfully"}
        };
    }
    
    // Get all users
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/users"
    }
    resource function get users(@http:Header string authorization, @http:Query int? page, @http:Query int? limit) 
            returns http:Ok|http:Unauthorized|http:InternalServerError {
        
        // Extract and validate JWT token
        if !authorization.startsWith("Bearer ") {
            return <http:Unauthorized>{
                body: {message: "Invalid authorization header"}
            };
        }
        
        string token = authorization.substring(7);
        jwt:Payload|jwt:Error payloadResult = jwt:validate(token, jwtSecret);
        
        if payloadResult is jwt:Error {
            return <http:Unauthorized>{
                body: {message: "Invalid token"}
            };
        }
        
        if !validateAdminAccess(payloadResult) {
            return <http:Unauthorized>{
                body: {message: "Admin access required"}
            };
        }
        
        int pageNum = page is int ? page : 1;
        int limitNum = limit is int ? limit : 20;
        int offset = (pageNum - 1) * limitNum;
        
        stream<record {}, sql:Error?>|sql:Error usersStream = 
            dbClient->query(`
                SELECT id, email, first_name, last_name, phone, user_type, is_active, created_at
                FROM users 
                ORDER BY created_at DESC 
                LIMIT ${limitNum} OFFSET ${offset}
            `);
        
        record {}[] users = [];
        record {}|sql:Error? userResult = usersStream.next();
        
        while userResult is record {} {
            users.push(userResult);
            userResult = usersStream.next();
        }
        
        if userResult is sql:Error {
            log:printError("Database error retrieving users", 'error = userResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve users"}
            };
        }
        
        return <http:Ok>{
            body: {users: users}
        };
    }
}

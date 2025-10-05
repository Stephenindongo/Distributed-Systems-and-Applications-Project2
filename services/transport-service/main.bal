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
configurable string databaseUser = "transport_user";
configurable string databasePassword = "transport_password";

// Kafka configuration
configurable string kafkaBrokers = "localhost:9092";

// JWT configuration
configurable string jwtSecret = "windhoek-transport-secret-key-2024";

// Database client
mysql:Client dbClient = check new (databaseUrl, databaseUser, databasePassword);

// Kafka producer
kafka:Producer kafkaProducer = check new (kafkaBrokers);

// Data types
public type Route record {
    int id?;
    string routeNumber;
    string routeName;
    string transportType;
    string startLocation;
    string endLocation;
    decimal? distanceKm;
    int? estimatedDurationMinutes;
    boolean isActive;
    string createdAt?;
    string updatedAt?;
};

public type Stop record {
    int id?;
    string stopName;
    string stopCode;
    decimal? latitude;
    decimal? longitude;
    string? address;
    boolean isActive;
    string createdAt?;
};

public type RouteStop record {
    int id?;
    int routeId;
    int stopId;
    int sequenceOrder;
    string? estimatedArrivalTime;
};

public type Trip record {
    int id?;
    int routeId;
    string tripNumber;
    string departureTime;
    string arrivalTime;
    string tripDate;
    string status;
    int delayMinutes;
    string createdAt?;
    string updatedAt?;
};

public type TripWithRoute record {
    int id;
    int routeId;
    string tripNumber;
    string departureTime;
    string arrivalTime;
    string tripDate;
    string status;
    int delayMinutes;
    string routeNumber;
    string routeName;
    string transportType;
    string startLocation;
    string endLocation;
};

public type ServiceDisruption record {
    int id?;
    int? routeId;
    string disruptionType;
    string title;
    string description;
    string startTime;
    string? endTime;
    string severity;
    boolean isActive;
    string createdAt?;
};

// HTTP service
@http:ServiceConfig {
    basePath: "/api/v1/transport"
}
service / on new http:Listener(8082) {
    
    // Get all routes
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/routes"
    }
    resource function get routes() returns http:Ok|http:InternalServerError {
        
        stream<record {}, sql:Error?>|sql:Error routesStream = 
            dbClient->query(`SELECT * FROM routes WHERE is_active = true ORDER BY route_number`);
        
        Route[] routes = [];
        record {}|sql:Error? routeResult = routesStream.next();
        
        while routeResult is record {} {
            Route route = {
                id: <int>routeResult["id"],
                routeNumber: <string>routeResult["route_number"],
                routeName: <string>routeResult["route_name"],
                transportType: <string>routeResult["transport_type"],
                startLocation: <string>routeResult["start_location"],
                endLocation: <string>routeResult["end_location"],
                distanceKm: <decimal?>routeResult["distance_km"],
                estimatedDurationMinutes: <int?>routeResult["estimated_duration_minutes"],
                isActive: <boolean>routeResult["is_active"],
                createdAt: <string>routeResult["created_at"],
                updatedAt: <string>routeResult["updated_at"]
            };
            routes.push(route);
            routeResult = routesStream.next();
        }
        
        if routeResult is sql:Error {
            log:printError("Database error retrieving routes", 'error = routeResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve routes"}
            };
        }
        
        return <http:Ok>{
            body: {routes: routes}
        };
    }
    
    // Get route by ID
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/routes/{routeId}"
    }
    resource function get route(int routeId) returns http:Ok|http:NotFound|http:InternalServerError {
        
        stream<record {}, sql:Error?>|sql:Error routeStream = 
            dbClient->query(`SELECT * FROM routes WHERE id = ${routeId} AND is_active = true`);
        
        record {}|sql:Error? routeResult = routeStream.next();
        if routeResult is sql:Error {
            log:printError("Database error retrieving route", 'error = routeResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve route"}
            };
        }
        
        if routeResult is () {
            return <http:NotFound>{
                body: {message: "Route not found"}
            };
        }
        
        Route route = {
            id: <int>routeResult["id"],
            routeNumber: <string>routeResult["route_number"],
            routeName: <string>routeResult["route_name"],
            transportType: <string>routeResult["transport_type"],
            startLocation: <string>routeResult["start_location"],
            endLocation: <string>routeResult["end_location"],
            distanceKm: <decimal?>routeResult["distance_km"],
            estimatedDurationMinutes: <int?>routeResult["estimated_duration_minutes"],
            isActive: <boolean>routeResult["is_active"],
            createdAt: <string>routeResult["created_at"],
            updatedAt: <string>routeResult["updated_at"]
        };
        
        return <http:Ok>{
            body: route
        };
    }
    
    // Get route stops
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/routes/{routeId}/stops"
    }
    resource function get routeStops(int routeId) returns http:Ok|http:NotFound|http:InternalServerError {
        
        stream<record {}, sql:Error?>|sql:Error stopsStream = 
            dbClient->query(`
                SELECT s.*, rs.sequence_order, rs.estimated_arrival_time 
                FROM stops s 
                JOIN route_stops rs ON s.id = rs.stop_id 
                WHERE rs.route_id = ${routeId} AND s.is_active = true 
                ORDER BY rs.sequence_order
            `);
        
        record {}[] stops = [];
        record {}|sql:Error? stopResult = stopsStream.next();
        
        while stopResult is record {} {
            stops.push(stopResult);
            stopResult = stopsStream.next();
        }
        
        if stopResult is sql:Error {
            log:printError("Database error retrieving route stops", 'error = stopResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve route stops"}
            };
        }
        
        return <http:Ok>{
            body: {stops: stops}
        };
    }
    
    // Get trips for a route
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/routes/{routeId}/trips"
    }
    resource function get routeTrips(int routeId, @http:Query string? date) returns http:Ok|http:InternalServerError {
        
        string tripDate = date is string ? date : time:utcNow().toString().substring(0, 10);
        
        stream<record {}, sql:Error?>|sql:Error tripsStream = 
            dbClient->query(`
                SELECT t.*, r.route_number, r.route_name, r.transport_type, r.start_location, r.end_location
                FROM trips t 
                JOIN routes r ON t.route_id = r.id 
                WHERE t.route_id = ${routeId} AND t.trip_date = '${tripDate}'
                ORDER BY t.departure_time
            `);
        
        TripWithRoute[] trips = [];
        record {}|sql:Error? tripResult = tripsStream.next();
        
        while tripResult is record {} {
            TripWithRoute trip = {
                id: <int>tripResult["id"],
                routeId: <int>tripResult["route_id"],
                tripNumber: <string>tripResult["trip_number"],
                departureTime: <string>tripResult["departure_time"],
                arrivalTime: <string>tripResult["arrival_time"],
                tripDate: <string>tripResult["trip_date"],
                status: <string>tripResult["status"],
                delayMinutes: <int>tripResult["delay_minutes"],
                routeNumber: <string>tripResult["route_number"],
                routeName: <string>tripResult["route_name"],
                transportType: <string>tripResult["transport_type"],
                startLocation: <string>tripResult["start_location"],
                endLocation: <string>tripResult["end_location"]
            };
            trips.push(trip);
            tripResult = tripsStream.next();
        }
        
        if tripResult is sql:Error {
            log:printError("Database error retrieving route trips", 'error = tripResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve trips"}
            };
        }
        
        return <http:Ok>{
            body: {trips: trips}
        };
    }
    
    // Get all trips for today
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/trips"
    }
    resource function get trips(@http:Query string? date, @http:Query string? transportType) returns http:Ok|http:InternalServerError {
        
        string tripDate = date is string ? date : time:utcNow().toString().substring(0, 10);
        string transportFilter = transportType is string ? `AND r.transport_type = '${transportType}'` : "";
        
        stream<record {}, sql:Error?>|sql:Error tripsStream = 
            dbClient->query(`
                SELECT t.*, r.route_number, r.route_name, r.transport_type, r.start_location, r.end_location
                FROM trips t 
                JOIN routes r ON t.route_id = r.id 
                WHERE t.trip_date = '${tripDate}' ${transportFilter}
                ORDER BY t.departure_time
            `);
        
        TripWithRoute[] trips = [];
        record {}|sql:Error? tripResult = tripsStream.next();
        
        while tripResult is record {} {
            TripWithRoute trip = {
                id: <int>tripResult["id"],
                routeId: <int>tripResult["route_id"],
                tripNumber: <string>tripResult["trip_number"],
                departureTime: <string>tripResult["departure_time"],
                arrivalTime: <string>tripResult["arrival_time"],
                tripDate: <string>tripResult["trip_date"],
                status: <string>tripResult["status"],
                delayMinutes: <int>tripResult["delay_minutes"],
                routeNumber: <string>tripResult["route_number"],
                routeName: <string>tripResult["route_name"],
                transportType: <string>tripResult["transport_type"],
                startLocation: <string>tripResult["start_location"],
                endLocation: <string>tripResult["end_location"]
            };
            trips.push(trip);
            tripResult = tripsStream.next();
        }
        
        if tripResult is sql:Error {
            log:printError("Database error retrieving trips", 'error = tripResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve trips"}
            };
        }
        
        return <http:Ok>{
            body: {trips: trips}
        };
    }
    
    // Get trip by ID
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/trips/{tripId}"
    }
    resource function get trip(int tripId) returns http:Ok|http:NotFound|http:InternalServerError {
        
        stream<record {}, sql:Error?>|sql:Error tripStream = 
            dbClient->query(`
                SELECT t.*, r.route_number, r.route_name, r.transport_type, r.start_location, r.end_location
                FROM trips t 
                JOIN routes r ON t.route_id = r.id 
                WHERE t.id = ${tripId}
            `);
        
        record {}|sql:Error? tripResult = tripStream.next();
        if tripResult is sql:Error {
            log:printError("Database error retrieving trip", 'error = tripResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve trip"}
            };
        }
        
        if tripResult is () {
            return <http:NotFound>{
                body: {message: "Trip not found"}
            };
        }
        
        TripWithRoute trip = {
            id: <int>tripResult["id"],
            routeId: <int>tripResult["route_id"],
            tripNumber: <string>tripResult["trip_number"],
            departureTime: <string>tripResult["departure_time"],
            arrivalTime: <string>tripResult["arrival_time"],
            tripDate: <string>tripResult["trip_date"],
            status: <string>tripResult["status"],
            delayMinutes: <int>tripResult["delay_minutes"],
            routeNumber: <string>tripResult["route_number"],
            routeName: <string>tripResult["route_name"],
            transportType: <string>tripResult["transport_type"],
            startLocation: <string>tripResult["start_location"],
            endLocation: <string>tripResult["end_location"]
        };
        
        return <http:Ok>{
            body: trip
        };
    }
    
    // Update trip status (for real-time updates)
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/trips/{tripId}/status"
    }
    resource function put updateTripStatus(int tripId, @http:Payload record {
        string status;
        int? delayMinutes;
    } statusUpdate) returns http:Ok|http:NotFound|http:BadRequest|http:InternalServerError {
        
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
    
    // Get service disruptions
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/disruptions"
    }
    resource function get disruptions(@http:Query int? routeId) returns http:Ok|http:InternalServerError {
        
        string routeFilter = routeId is int ? `AND route_id = ${routeId}` : "";
        
        stream<record {}, sql:Error?>|sql:Error disruptionsStream = 
            dbClient->query(`
                SELECT * FROM service_disruptions 
                WHERE is_active = true ${routeFilter}
                ORDER BY created_at DESC
            `);
        
        ServiceDisruption[] disruptions = [];
        record {}|sql:Error? disruptionResult = disruptionsStream.next();
        
        while disruptionResult is record {} {
            ServiceDisruption disruption = {
                id: <int>disruptionResult["id"],
                routeId: <int?>disruptionResult["route_id"],
                disruptionType: <string>disruptionResult["disruption_type"],
                title: <string>disruptionResult["title"],
                description: <string>disruptionResult["description"],
                startTime: <string>disruptionResult["start_time"],
                endTime: <string?>disruptionResult["end_time"],
                severity: <string>disruptionResult["severity"],
                isActive: <boolean>disruptionResult["is_active"],
                createdAt: <string>disruptionResult["created_at"]
            };
            disruptions.push(disruption);
            disruptionResult = disruptionsStream.next();
        }
        
        if disruptionResult is sql:Error {
            log:printError("Database error retrieving disruptions", 'error = disruptionResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve disruptions"}
            };
        }
        
        return <http:Ok>{
            body: {disruptions: disruptions}
        };
    }
    
    // Search routes
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/search"
    }
    resource function get search(@http:Query string? query, @http:Query string? transportType) returns http:Ok|http:InternalServerError {
        
        string searchQuery = query is string ? query : "";
        string transportFilter = transportType is string ? `AND transport_type = '${transportType}'` : "";
        
        if searchQuery == "" {
            return <http:Ok>{
                body: {routes: []}
            };
        }
        
        stream<record {}, sql:Error?>|sql:Error searchStream = 
            dbClient->query(`
                SELECT * FROM routes 
                WHERE is_active = true ${transportFilter}
                AND (route_name LIKE '%${searchQuery}%' 
                     OR start_location LIKE '%${searchQuery}%' 
                     OR end_location LIKE '%${searchQuery}%')
                ORDER BY route_name
            `);
        
        Route[] routes = [];
        record {}|sql:Error? routeResult = searchStream.next();
        
        while routeResult is record {} {
            Route route = {
                id: <int>routeResult["id"],
                routeNumber: <string>routeResult["route_number"],
                routeName: <string>routeResult["route_name"],
                transportType: <string>routeResult["transport_type"],
                startLocation: <string>routeResult["start_location"],
                endLocation: <string>routeResult["end_location"],
                distanceKm: <decimal?>routeResult["distance_km"],
                estimatedDurationMinutes: <int?>routeResult["estimated_duration_minutes"],
                isActive: <boolean>routeResult["is_active"],
                createdAt: <string>routeResult["created_at"],
                updatedAt: <string>routeResult["updated_at"]
            };
            routes.push(route);
            routeResult = searchStream.next();
        }
        
        if routeResult is sql:Error {
            log:printError("Database error searching routes", 'error = routeResult);
            return <http:InternalServerError>{
                body: {message: "Failed to search routes"}
            };
        }
        
        return <http:Ok>{
            body: {routes: routes}
        };
    }
}

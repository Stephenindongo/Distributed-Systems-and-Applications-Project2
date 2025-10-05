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
public type TicketRequest record {
    int tripId;
    string ticketType;
    int? maxValidations;
};

public type Ticket record {
    int id?;
    string ticketCode;
    int passengerId;
    int tripId;
    string ticketType;
    string status;
    decimal price;
    string purchaseDate?;
    string? expiryDate;
    int validationCount;
    int maxValidations;
    string? validatedAt;
    string createdAt?;
    string updatedAt?;
};

public type TicketWithDetails record {
    int id;
    string ticketCode;
    int passengerId;
    int tripId;
    string ticketType;
    string status;
    decimal price;
    string purchaseDate;
    string? expiryDate;
    int validationCount;
    int maxValidations;
    string? validatedAt;
    string routeNumber;
    string routeName;
    string transportType;
    string departureTime;
    string arrivalTime;
    string tripDate;
};

public type TicketValidation record {
    string ticketCode;
    int tripId;
    string validationLocation?;
};

public type TicketValidationResponse record {
    boolean isValid;
    string message;
    Ticket? ticket;
};

// Utility functions
function generateTicketCode() returns string {
    return uuid:createType4AsString().substring(0, 8).toUpperAscii();
}

function calculateTicketPrice(string ticketType, int? maxValidations) returns decimal {
    match ticketType {
        "SINGLE_RIDE" => return 5.00;
        "MULTIPLE_RIDES" => {
            int rides = maxValidations is int ? maxValidations : 5;
            return 5.00 * <decimal>rides * 0.8; // 20% discount for multiple rides
        }
        "WEEKLY_PASS" => return 50.00;
        "MONTHLY_PASS" => return 150.00;
        _ => return 5.00;
    }
}

function calculateExpiryDate(string ticketType) returns string {
    match ticketType {
        "SINGLE_RIDE" => return time:utcNow().add(24 * 60 * 60).toString(); // 24 hours
        "MULTIPLE_RIDES" => return time:utcNow().add(7 * 24 * 60 * 60).toString(); // 7 days
        "WEEKLY_PASS" => return time:utcNow().add(7 * 24 * 60 * 60).toString(); // 7 days
        "MONTHLY_PASS" => return time:utcNow().add(30 * 24 * 60 * 60).toString(); // 30 days
        _ => return time:utcNow().add(24 * 60 * 60).toString();
    }
}

function validateTicketCode(string ticketCode) returns boolean {
    string pattern = "^[A-F0-9]{8}$";
    return regex:matches(ticketCode, pattern);
}

// HTTP service
@http:ServiceConfig {
    basePath: "/api/v1/tickets"
}
service / on new http:Listener(8083) {
    
    // Create a new ticket
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/"
    }
    resource function post create(@http:Header string authorization, @http:Payload TicketRequest ticketRequest) 
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
        
        int passengerId = <int>payloadResult["user_id"];
        
        // Validate input
        if ticketRequest.tripId <= 0 {
            return <http:BadRequest>{
                body: {message: "Valid trip ID is required"}
            };
        }
        
        if ticketRequest.ticketType == "" {
            return <http:BadRequest>{
                body: {message: "Ticket type is required"}
            };
        }
        
        // Check if trip exists and is valid
        stream<record {}, sql:Error?>|sql:Error tripStream = 
            dbClient->query(`SELECT * FROM trips WHERE id = ${ticketRequest.tripId}`);
        
        record {}|sql:Error? tripResult = tripStream.next();
        if tripResult is sql:Error {
            log:printError("Database error checking trip", 'error = tripResult);
            return <http:InternalServerError>{
                body: {message: "Failed to validate trip"}
            };
        }
        
        if tripResult is () {
            return <http:BadRequest>{
                body: {message: "Trip not found"}
            };
        }
        
        // Check if trip is not cancelled
        if <string>tripResult["status"] == "CANCELLED" {
            return <http:BadRequest>{
                body: {message: "Cannot purchase ticket for cancelled trip"}
            };
        }
        
        // Generate ticket code
        string ticketCode = generateTicketCode();
        
        // Calculate price and expiry
        decimal price = calculateTicketPrice(ticketRequest.ticketType, ticketRequest.maxValidations);
        string expiryDate = calculateExpiryDate(ticketRequest.ticketType);
        int maxValidations = ticketRequest.maxValidations is int ? ticketRequest.maxValidations : 1;
        
        // Create ticket
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
            INSERT INTO tickets (ticket_code, passenger_id, trip_id, ticket_type, status, price, 
                               expiry_date, max_validations)
            VALUES ('${ticketCode}', ${passengerId}, ${ticketRequest.tripId}, 
                   '${ticketRequest.ticketType}', 'CREATED', ${price}, 
                   '${expiryDate}', ${maxValidations})
        `);
        
        if insertResult is sql:Error {
            log:printError("Failed to create ticket", 'error = insertResult);
            return <http:InternalServerError>{
                body: {message: "Failed to create ticket"}
            };
        }
        
        // Get created ticket
        stream<record {}, sql:Error?>|sql:Error ticketStream = 
            dbClient->query(`SELECT * FROM tickets WHERE ticket_code = '${ticketCode}'`);
        
        record {}|sql:Error? ticketResult = ticketStream.next();
        if ticketResult is sql:Error {
            log:printError("Failed to retrieve created ticket", 'error = ticketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve ticket"}
            };
        }
        
        Ticket ticket = {
            id: <int>ticketResult["id"],
            ticketCode: <string>ticketResult["ticket_code"],
            passengerId: <int>ticketResult["passenger_id"],
            tripId: <int>ticketResult["trip_id"],
            ticketType: <string>ticketResult["ticket_type"],
            status: <string>ticketResult["status"],
            price: <decimal>ticketResult["price"],
            purchaseDate: <string>ticketResult["purchase_date"],
            expiryDate: <string?>ticketResult["expiry_date"],
            validationCount: <int>ticketResult["validation_count"],
            maxValidations: <int>ticketResult["max_validations"],
            validatedAt: <string?>ticketResult["validated_at"],
            createdAt: <string>ticketResult["created_at"],
            updatedAt: <string>ticketResult["updated_at"]
        };
        
        // Send ticket creation event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "ticket-created",
            value: {
                ticketId: ticket.id,
                ticketCode: ticket.ticketCode,
                passengerId: ticket.passengerId,
                tripId: ticket.tripId,
                ticketType: ticket.ticketType,
                price: ticket.price,
                timestamp: time:utcNow().toString()
            }.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send ticket creation event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Created>{
            body: {
                message: "Ticket created successfully",
                ticket: ticket
            }
        };
    }
    
    // Get ticket by code
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/{ticketCode}"
    }
    resource function get ticket(string ticketCode) returns http:Ok|http:NotFound|http:BadRequest|http:InternalServerError {
        
        if !validateTicketCode(ticketCode) {
            return <http:BadRequest>{
                body: {message: "Invalid ticket code format"}
            };
        }
        
        stream<record {}, sql:Error?>|sql:Error ticketStream = 
            dbClient->query(`
                SELECT t.*, tr.route_number, tr.route_name, tr.transport_type, 
                       tr.departure_time, tr.arrival_time, tr.trip_date
                FROM tickets t 
                JOIN trips tr ON t.trip_id = tr.id 
                WHERE t.ticket_code = '${ticketCode}'
            `);
        
        record {}|sql:Error? ticketResult = ticketStream.next();
        if ticketResult is sql:Error {
            log:printError("Database error retrieving ticket", 'error = ticketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve ticket"}
            };
        }
        
        if ticketResult is () {
            return <http:NotFound>{
                body: {message: "Ticket not found"}
            };
        }
        
        TicketWithDetails ticket = {
            id: <int>ticketResult["id"],
            ticketCode: <string>ticketResult["ticket_code"],
            passengerId: <int>ticketResult["passenger_id"],
            tripId: <int>ticketResult["trip_id"],
            ticketType: <string>ticketResult["ticket_type"],
            status: <string>ticketResult["status"],
            price: <decimal>ticketResult["price"],
            purchaseDate: <string>ticketResult["purchase_date"],
            expiryDate: <string?>ticketResult["expiry_date"],
            validationCount: <int>ticketResult["validation_count"],
            maxValidations: <int>ticketResult["max_validations"],
            validatedAt: <string?>ticketResult["validated_at"],
            routeNumber: <string>ticketResult["route_number"],
            routeName: <string>ticketResult["route_name"],
            transportType: <string>ticketResult["transport_type"],
            departureTime: <string>ticketResult["departure_time"],
            arrivalTime: <string>ticketResult["arrival_time"],
            tripDate: <string>ticketResult["trip_date"]
        };
        
        return <http:Ok>{
            body: ticket
        };
    }
    
    // Validate ticket
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/validate"
    }
    resource function post validate(@http:Payload TicketValidation validation) 
            returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError {
        
        if validation.ticketCode == "" {
            return <http:BadRequest>{
                body: {message: "Ticket code is required"}
            };
        }
        
        if !validateTicketCode(validation.ticketCode) {
            return <http:BadRequest>{
                body: {message: "Invalid ticket code format"}
            };
        }
        
        // Get ticket details
        stream<record {}, sql:Error?>|sql:Error ticketStream = 
            dbClient->query(`
                SELECT t.*, tr.status as trip_status, tr.departure_time, tr.trip_date
                FROM tickets t 
                JOIN trips tr ON t.trip_id = tr.id 
                WHERE t.ticket_code = '${validation.ticketCode}'
            `);
        
        record {}|sql:Error? ticketResult = ticketStream.next();
        if ticketResult is sql:Error {
            log:printError("Database error retrieving ticket for validation", 'error = ticketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to validate ticket"}
            };
        }
        
        if ticketResult is () {
            return <http:NotFound>{
                body: {message: "Ticket not found"}
            };
        }
        
        string ticketStatus = <string>ticketResult["status"];
        string tripStatus = <string>ticketResult["trip_status"];
        int validationCount = <int>ticketResult["validation_count"];
        int maxValidations = <int>ticketResult["max_validations"];
        string expiryDate = <string>ticketResult["expiry_date"];
        
        // Check if ticket is expired
        if time:utcNow().toString() > expiryDate {
            // Update ticket status to expired
            dbClient->execute(`UPDATE tickets SET status = 'EXPIRED' WHERE ticket_code = '${validation.ticketCode}'`);
            
            return <http:Ok>{
                body: {
                    isValid: false,
                    message: "Ticket has expired",
                    ticket: ()
                }
            };
        }
        
        // Check if ticket is already validated and single-use
        if ticketStatus == "VALIDATED" && maxValidations == 1 {
            return <http:Ok>{
                body: {
                    isValid: false,
                    message: "Ticket has already been used",
                    ticket: ()
                }
            };
        }
        
        // Check if ticket has reached max validations
        if validationCount >= maxValidations {
            return <http:Ok>{
                body: {
                    isValid: false,
                    message: "Ticket has reached maximum validations",
                    ticket: ()
                }
            };
        }
        
        // Check if trip is cancelled
        if tripStatus == "CANCELLED" {
            return <http:Ok>{
                body: {
                    isValid: false,
                    message: "Trip has been cancelled",
                    ticket: ()
                }
            };
        }
        
        // Validate ticket
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
            UPDATE tickets 
            SET status = 'VALIDATED', 
                validation_count = validation_count + 1,
                validated_at = NOW()
            WHERE ticket_code = '${validation.ticketCode}'
        `);
        
        if updateResult is sql:Error {
            log:printError("Failed to validate ticket", 'error = updateResult);
            return <http:InternalServerError>{
                body: {message: "Failed to validate ticket"}
            };
        }
        
        // Get updated ticket
        stream<record {}, sql:Error?>|sql:Error updatedTicketStream = 
            dbClient->query(`SELECT * FROM tickets WHERE ticket_code = '${validation.ticketCode}'`);
        
        record {}|sql:Error? updatedTicketResult = updatedTicketStream.next();
        if updatedTicketResult is sql:Error {
            log:printError("Failed to retrieve updated ticket", 'error = updatedTicketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve updated ticket"}
            };
        }
        
        Ticket ticket = {
            id: <int>updatedTicketResult["id"],
            ticketCode: <string>updatedTicketResult["ticket_code"],
            passengerId: <int>updatedTicketResult["passenger_id"],
            tripId: <int>updatedTicketResult["trip_id"],
            ticketType: <string>updatedTicketResult["ticket_type"],
            status: <string>updatedTicketResult["status"],
            price: <decimal>updatedTicketResult["price"],
            purchaseDate: <string>updatedTicketResult["purchase_date"],
            expiryDate: <string?>updatedTicketResult["expiry_date"],
            validationCount: <int>updatedTicketResult["validation_count"],
            maxValidations: <int>updatedTicketResult["max_validations"],
            validatedAt: <string?>updatedTicketResult["validated_at"],
            createdAt: <string>updatedTicketResult["created_at"],
            updatedAt: <string>updatedTicketResult["updated_at"]
        };
        
        // Send ticket validation event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "ticket-validated",
            value: {
                ticketId: ticket.id,
                ticketCode: ticket.ticketCode,
                passengerId: ticket.passengerId,
                tripId: ticket.tripId,
                validationCount: ticket.validationCount,
                timestamp: time:utcNow().toString()
            }.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send ticket validation event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Ok>{
            body: {
                isValid: true,
                message: "Ticket validated successfully",
                ticket: ticket
            }
        };
    }
    
    // Get passenger tickets
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/passenger/{passengerId}"
    }
    resource function get passengerTickets(int passengerId) returns http:Ok|http:InternalServerError {
        
        stream<record {}, sql:Error?>|sql:Error ticketsStream = 
            dbClient->query(`
                SELECT t.*, tr.route_number, tr.route_name, tr.transport_type, 
                       tr.departure_time, tr.arrival_time, tr.trip_date
                FROM tickets t 
                JOIN trips tr ON t.trip_id = tr.id 
                WHERE t.passenger_id = ${passengerId}
                ORDER BY t.created_at DESC
            `);
        
        TicketWithDetails[] tickets = [];
        record {}|sql:Error? ticketResult = ticketsStream.next();
        
        while ticketResult is record {} {
            TicketWithDetails ticket = {
                id: <int>ticketResult["id"],
                ticketCode: <string>ticketResult["ticket_code"],
                passengerId: <int>ticketResult["passenger_id"],
                tripId: <int>ticketResult["trip_id"],
                ticketType: <string>ticketResult["ticket_type"],
                status: <string>ticketResult["status"],
                price: <decimal>ticketResult["price"],
                purchaseDate: <string>ticketResult["purchase_date"],
                expiryDate: <string?>ticketResult["expiry_date"],
                validationCount: <int>ticketResult["validation_count"],
                maxValidations: <int>ticketResult["max_validations"],
                validatedAt: <string?>ticketResult["validated_at"],
                routeNumber: <string>ticketResult["route_number"],
                routeName: <string>ticketResult["route_name"],
                transportType: <string>ticketResult["transport_type"],
                departureTime: <string>ticketResult["departure_time"],
                arrivalTime: <string>ticketResult["arrival_time"],
                tripDate: <string>ticketResult["trip_date"]
            };
            tickets.push(ticket);
            ticketResult = ticketsStream.next();
        }
        
        if ticketResult is sql:Error {
            log:printError("Database error retrieving passenger tickets", 'error = ticketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve tickets"}
            };
        }
        
        return <http:Ok>{
            body: {tickets: tickets}
        };
    }
    
    // Cancel ticket
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/{ticketCode}/cancel"
    }
    resource function put cancelTicket(string ticketCode) returns http:Ok|http:NotFound|http:BadRequest|http:InternalServerError {
        
        if !validateTicketCode(ticketCode) {
            return <http:BadRequest>{
                body: {message: "Invalid ticket code format"}
            };
        }
        
        // Check if ticket exists and can be cancelled
        stream<record {}, sql:Error?>|sql:Error ticketStream = 
            dbClient->query(`SELECT * FROM tickets WHERE ticket_code = '${ticketCode}'`);
        
        record {}|sql:Error? ticketResult = ticketStream.next();
        if ticketResult is sql:Error {
            log:printError("Database error retrieving ticket for cancellation", 'error = ticketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to cancel ticket"}
            };
        }
        
        if ticketResult is () {
            return <http:NotFound>{
                body: {message: "Ticket not found"}
            };
        }
        
        string ticketStatus = <string>ticketResult["status"];
        
        if ticketStatus == "VALIDATED" {
            return <http:BadRequest>{
                body: {message: "Cannot cancel already validated ticket"}
            };
        }
        
        if ticketStatus == "CANCELLED" {
            return <http:BadRequest>{
                body: {message: "Ticket is already cancelled"}
            };
        }
        
        // Cancel ticket
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
            UPDATE tickets SET status = 'CANCELLED' WHERE ticket_code = '${ticketCode}'
        `);
        
        if updateResult is sql:Error {
            log:printError("Failed to cancel ticket", 'error = updateResult);
            return <http:InternalServerError>{
                body: {message: "Failed to cancel ticket"}
            };
        }
        
        // Send ticket cancellation event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "ticket-cancelled",
            value: {
                ticketCode: ticketCode,
                timestamp: time:utcNow().toString()
            }.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send ticket cancellation event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Ok>{
            body: {message: "Ticket cancelled successfully"}
        };
    }
}

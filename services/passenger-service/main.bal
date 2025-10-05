import ballerina/http;
import ballerina/sql;
import ballerina/mysql;
import ballerina/log;
import ballerina/io;
import ballerina/time;
import ballerina/uuid;
import ballerina/crypto;
import ballerina/jwt;
import ballerina/constraint;
import ballerina/regex;
import ballerina/kafka;

// Database configuration
configurable string databaseUrl = "jdbc:mysql://localhost:3306/transport_ticketing";
configurable string databaseUser = "root";
configurable string databasePassword = "T1981@I29#sql";

// Kafka configuration
configurable string kafkaBrokers = "localhost:9092";

// JWT configuration
configurable string jwtSecret = "windhoek-transport-secret-key-2024";

// Database client
mysql:Client dbClient = check new (databaseUrl, databaseUser, databasePassword);

// Kafka producer
kafka:Producer kafkaProducer = check new (kafkaBrokers);

// User types
public type User record {
    int id?;
    string email;
    string firstName;
    string lastName;
    string? phone;
    string userType;
    boolean isActive;
    string createdAt?;
    string updatedAt?;
};

public type UserRegistration record {
    string email;
    string password;
    string firstName;
    string lastName;
    string? phone;
};

public type UserLogin record {
    string email;
    string password;
};

public type UserResponse record {
    int id;
    string email;
    string firstName;
    string lastName;
    string? phone;
    string userType;
    boolean isActive;
    string createdAt;
    string updatedAt;
};

public type LoginResponse record {
    string token;
    UserResponse user;
};

public type TicketInfo record {
    int id;
    string ticketCode;
    int tripId;
    string ticketType;
    string status;
    decimal price;
    string purchaseDate;
    string? expiryDate;
    int validationCount;
    int maxValidations;
    string? validatedAt;
};

// Utility functions
function hashPassword(string password) returns string {
    return crypto:hashSha256(password.toBytes());
}

function generateJwtToken(int userId, string email, string userType) returns string|error {
    jwt:Header header = {};
    jwt:Payload payload = {
        iss: "windhoek-transport",
        sub: userId.toString(),
        aud: ["passenger-service"],
        exp: time:utcNow().add(24 * 60 * 60), // 24 hours
        iat: time:utcNow(),
        jti: uuid:createType4AsString(),
        "user_id": userId,
        "email": email,
        "user_type": userType
    };
    
    return jwt:issue(header, payload, jwtSecret);
}

function validateEmail(string email) returns boolean {
    string emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$";
    return regex:matches(email, emailPattern);
}

// HTTP service
@http:ServiceConfig {
    basePath: "/api/v1/passengers"
}
service / on new http:Listener(8081) {
    
    // Register new passenger
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/register"
    }
    resource function post register(@http:Payload UserRegistration userData) 
            returns http:Created|http:BadRequest|http:InternalServerError {
        
        // Validate input
        if userData.email == "" || userData.password == "" || 
           userData.firstName == "" || userData.lastName == "" {
            return <http:BadRequest>{
                body: {message: "All required fields must be provided"}
            };
        }
        
        if !validateEmail(userData.email) {
            return <http:BadRequest>{
                body: {message: "Invalid email format"}
            };
        }
        
        if userData.password.length() < 6 {
            return <http:BadRequest>{
                body: {message: "Password must be at least 6 characters long"}
            };
        }
        
        // Check if user already exists
        stream<record {}, sql:Error?>|sql:Error userCheckStream = 
            dbClient->query(`SELECT id FROM users WHERE email = ${userData.email}`);
        
        record {}|sql:Error? userCheckResult = userCheckStream.next();
        if userCheckResult is record {} {
            return <http:BadRequest>{
                body: {message: "User with this email already exists"}
            };
        }
        
        // Hash password
        string hashedPassword = hashPassword(userData.password);
        
        // Insert new user
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
            INSERT INTO users (email, password_hash, first_name, last_name, phone, user_type)
            VALUES (${userData.email}, ${hashedPassword}, ${userData.firstName}, 
                   ${userData.lastName}, ${userData.phone}, 'PASSENGER')
        `);
        
        if insertResult is sql:Error {
            log:printError("Failed to register user", 'error = insertResult);
            return <http:InternalServerError>{
                body: {message: "Failed to register user"}
            };
        }
        
        // Get the created user
        stream<record {}, sql:Error?>|sql:Error userStream = 
            dbClient->query(`SELECT * FROM users WHERE email = ${userData.email}`);
        
        record {}|sql:Error? userResult = userStream.next();
        if userResult is sql:Error {
            log:printError("Failed to retrieve created user", 'error = userResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve user information"}
            };
        }
        
        UserResponse userResponse = {
            id: <int>userResult["id"],
            email: <string>userResult["email"],
            firstName: <string>userResult["first_name"],
            lastName: <string>userResult["last_name"],
            phone: <string?>userResult["phone"],
            userType: <string>userResult["user_type"],
            isActive: <boolean>userResult["is_active"],
            createdAt: <string>userResult["created_at"],
            updatedAt: <string>userResult["updated_at"]
        };
        
        // Send registration event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "user-registration",
            value: userResponse.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send registration event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Created>{
            body: {
                message: "User registered successfully",
                user: userResponse
            }
        };
    }
    
    // Login passenger
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/login"
    }
    resource function post login(@http:Payload UserLogin loginData) 
            returns http:Ok|http:Unauthorized|http:BadRequest|http:InternalServerError {
        
        if loginData.email == "" || loginData.password == "" {
            return <http:BadRequest>{
                body: {message: "Email and password are required"}
            };
        }
        
        // Get user from database
        stream<record {}, sql:Error?>|sql:Error userStream = 
            dbClient->query(`SELECT * FROM users WHERE email = ${loginData.email} AND is_active = true`);
        
        record {}|sql:Error? userResult = userStream.next();
        if userResult is sql:Error {
            log:printError("Database error during login", 'error = userResult);
            return <http:InternalServerError>{
                body: {message: "Login failed"}
            };
        }
        
        if userResult is () {
            return <http:Unauthorized>{
                body: {message: "Invalid email or password"}
            };
        }
        
        // Verify password
        string storedPassword = <string>userResult["password_hash"];
        string hashedInputPassword = hashPassword(loginData.password);
        
        if storedPassword != hashedInputPassword {
            return <http:Unauthorized>{
                body: {message: "Invalid email or password"}
            };
        }
        
        // Generate JWT token
        string|error tokenResult = generateJwtToken(
            <int>userResult["id"],
            <string>userResult["email"],
            <string>userResult["user_type"]
        );
        
        if tokenResult is error {
            log:printError("Failed to generate JWT token", 'error = tokenResult);
            return <http:InternalServerError>{
                body: {message: "Login failed"}
            };
        }
        
        UserResponse userResponse = {
            id: <int>userResult["id"],
            email: <string>userResult["email"],
            firstName: <string>userResult["first_name"],
            lastName: <string>userResult["last_name"],
            phone: <string?>userResult["phone"],
            userType: <string>userResult["user_type"],
            isActive: <boolean>userResult["is_active"],
            createdAt: <string>userResult["created_at"],
            updatedAt: <string>userResult["updated_at"]
        };
        
        LoginResponse loginResponse = {
            token: tokenResult,
            user: userResponse
        };
        
        // Send login event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "user-login",
            value: loginResponse.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send login event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Ok>{
            body: loginResponse
        };
    }
    
    // Get user profile
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/profile"
    }
    resource function get profile(@http:Header string authorization) 
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
        
        int userId = <int>payloadResult["user_id"];
        
        // Get user from database
        stream<record {}, sql:Error?>|sql:Error userStream = 
            dbClient->query(`SELECT * FROM users WHERE id = ${userId}`);
        
        record {}|sql:Error? userResult = userStream.next();
        if userResult is sql:Error {
            log:printError("Database error retrieving user profile", 'error = userResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve profile"}
            };
        }
        
        if userResult is () {
            return <http:Unauthorized>{
                body: {message: "User not found"}
            };
        }
        
        UserResponse userResponse = {
            id: <int>userResult["id"],
            email: <string>userResult["email"],
            firstName: <string>userResult["first_name"],
            lastName: <string>userResult["last_name"],
            phone: <string?>userResult["phone"],
            userType: <string>userResult["user_type"],
            isActive: <boolean>userResult["is_active"],
            createdAt: <string>userResult["created_at"],
            updatedAt: <string>userResult["updated_at"]
        };
        
        return <http:Ok>{
            body: userResponse
        };
    }
    
    // Get user tickets
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/tickets"
    }
    resource function get tickets(@http:Header string authorization) 
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
        
        int userId = <int>payloadResult["user_id"];
        
        // Get user tickets
        stream<record {}, sql:Error?>|sql:Error ticketsStream = 
            dbClient->query(`SELECT * FROM tickets WHERE passenger_id = ${userId} ORDER BY created_at DESC`);
        
        TicketInfo[] tickets = [];
        record {}|sql:Error? ticketResult = ticketsStream.next();
        
        while ticketResult is record {} {
            TicketInfo ticket = {
                id: <int>ticketResult["id"],
                ticketCode: <string>ticketResult["ticket_code"],
                tripId: <int>ticketResult["trip_id"],
                ticketType: <string>ticketResult["ticket_type"],
                status: <string>ticketResult["status"],
                price: <decimal>ticketResult["price"],
                purchaseDate: <string>ticketResult["purchase_date"],
                expiryDate: <string?>ticketResult["expiry_date"],
                validationCount: <int>ticketResult["validation_count"],
                maxValidations: <int>ticketResult["max_validations"],
                validatedAt: <string?>ticketResult["validated_at"]
            };
            tickets.push(ticket);
            ticketResult = ticketsStream.next();
        }
        
        if ticketResult is sql:Error {
            log:printError("Database error retrieving tickets", 'error = ticketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve tickets"}
            };
        }
        
        return <http:Ok>{
            body: {tickets: tickets}
        };
    }
    
    // Update user profile
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/profile"
    }
    resource function put updateProfile(@http:Header string authorization, 
                                      @http:Payload User userData) 
            returns http:Ok|http:Unauthorized|http:BadRequest|http:InternalServerError {
        
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
        
        int userId = <int>payloadResult["user_id"];
        
        // Validate input
        if userData.firstName == "" || userData.lastName == "" {
            return <http:BadRequest>{
                body: {message: "First name and last name are required"}
            };
        }
        
        if userData.phone is string && userData.phone != "" {
            string phonePattern = "^\\+264[0-9]{9}$";
            if !regex:matches(userData.phone, phonePattern) {
                return <http:BadRequest>{
                    body: {message: "Invalid phone number format. Use +264XXXXXXXXX"}
                };
            }
        }
        
        // Update user profile
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
            UPDATE users 
            SET first_name = ${userData.firstName}, 
                last_name = ${userData.lastName}, 
                phone = ${userData.phone}
            WHERE id = ${userId}
        `);
        
        if updateResult is sql:Error {
            log:printError("Failed to update user profile", 'error = updateResult);
            return <http:InternalServerError>{
                body: {message: "Failed to update profile"}
            };
        }
        
        // Get updated user
        stream<record {}, sql:Error?>|sql:Error userStream = 
            dbClient->query(`SELECT * FROM users WHERE id = ${userId}`);
        
        record {}|sql:Error? userResult = userStream.next();
        if userResult is sql:Error {
            log:printError("Database error retrieving updated user", 'error = userResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve updated profile"}
            };
        }
        
        UserResponse userResponse = {
            id: <int>userResult["id"],
            email: <string>userResult["email"],
            firstName: <string>userResult["first_name"],
            lastName: <string>userResult["last_name"],
            phone: <string?>userResult["phone"],
            userType: <string>userResult["user_type"],
            isActive: <boolean>userResult["is_active"],
            createdAt: <string>userResult["created_at"],
            updatedAt: <string>userResult["updated_at"]
        };
        
        return <http:Ok>{
            body: {
                message: "Profile updated successfully",
                user: userResponse
            }
        };
    }
}

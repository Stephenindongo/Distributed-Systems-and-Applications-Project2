import ballerina/http;
import ballerina/log;
import ballerina/uuid;
import ballerina/time;
import ballerina/io;

// Type definitions
public type Passenger record {
    string id;
    string email;
    string password;
    string firstName;
    string lastName;
    string phoneNumber;
    boolean isActive;
    time:Utc createdAt;
    time:Utc updatedAt;
};

public type PassengerRegistration record {
    string email;
    string password;
    string firstName;
    string lastName;
    string phoneNumber;
};

public type PassengerResponse record {
    string id;
    string email;
    string firstName;
    string lastName;
    string phoneNumber;
    time:Utc createdAt;
};

public type LoginRequest record {
    string email;
    string password;
};

public type LoginResponse record {
    string accessToken;
    string refreshToken;
    int expiresIn;
    PassengerSummary passenger;
};

public type PassengerSummary record {
    string id;
    string email;
    string firstName;
    string lastName;
};

// Configuration
configurable int servicePort = 8080;

// Storage configuration
configurable boolean persistToFile = true; // Set to true to persist data to JSON files
configurable string dataDir = "./data";

// In-memory storage with file persistence
map<Passenger> passengers = {};

// Initialize storage and load existing data
function initializeStorage() returns error? {
    if persistToFile {
        error? result = loadPassengersFromFile();
        if result is error {
            log:printWarn("Could not load existing passenger data: " + result.message());
        } else {
            log:printInfo("Loaded existing passenger data from file");
        }
    }
    log:printInfo("Passenger storage initialized");
}

// Load passengers from JSON file
function loadPassengersFromFile() returns error? {
    string filePath = dataDir + "/passengers.json";
    json|error fileContent = io:fileReadJson(filePath);
    if fileContent is json {
        if fileContent is json[] {
            foreach json passengerJson in fileContent {
                Passenger|error passenger = passengerJson.cloneWithType(Passenger);
                if passenger is Passenger {
                    passengers[passenger.id] = passenger;
                }
            }
        }
    }
}

// Save passengers to JSON file
function savePassengersToFile() returns error? {
    if persistToFile {
        string filePath = dataDir + "/passengers.json";

        Passenger[] passengerArray = passengers.toArray();
        json passengerJson = passengerArray.toJson();
        check io:fileWriteJson(filePath, passengerJson);
    }
}

// Storage helper functions
function savePassenger(Passenger passenger) returns error? {
    passengers[passenger.id] = passenger;
    return savePassengersToFile();
}

function getPassenger(string id) returns Passenger? {
    return passengers[id];
}

function getAllPassengers() returns Passenger[] {
    return passengers.toArray();
}

function findPassengerByEmail(string email) returns Passenger? {
    foreach Passenger passenger in passengers {
        if passenger.email == email {
            return passenger;
        }
    }
    return ();
}

// Simple password hashing (use proper hashing in production)
function hashPassword(string password) returns string {
    return password + "_hashed";
}

// Simple validation
function validateRegistration(PassengerRegistration registration) returns string? {
    if registration.email.trim().length() == 0 {
        return "Email is required";
    }
    if registration.password.length() < 8 {
        return "Password must be at least 8 characters long";
    }
    if registration.firstName.trim().length() == 0 {
        return "First name is required";
    }
    if registration.lastName.trim().length() == 0 {
        return "Last name is required";
    }
    if registration.phoneNumber.trim().length() == 0 {
        return "Phone number is required";
    }
    return ();
}

// HTTP service
@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allowHeaders: ["Content-Type", "Authorization"]
    }
}
service /api/v1/passengers on new http:Listener(servicePort) {

    // Initialize storage on service start
    function init() returns error? {
        return initializeStorage();
    }

    // Health check endpoint
    resource function get health() returns json {
        return {
            "status": "UP",
            "service": "passenger-service",
            "timestamp": time:utcNow(),
            "storage": persistToFile ? "file-persistent" : "in-memory"
        };
    }

    // Register new passenger
    resource function post register(@http:Payload PassengerRegistration registration) returns http:Response|error {
        log:printInfo("Registering new passenger: " + registration.email);
        
        http:Response response = new;
        
        // Validate input
        string? validationError = validateRegistration(registration);
        if validationError is string {
            response.statusCode = 400;
            response.setJsonPayload({
                "success": false,
                "error": {
                    "code": "VALIDATION_ERROR",
                    "message": validationError
                }
            });
            return response;
        }

        // Check if passenger already exists
        Passenger? existingPassenger = findPassengerByEmail(registration.email);
        if existingPassenger is Passenger {
            response.statusCode = 409;
            response.setJsonPayload({
                "success": false,
                "error": {
                    "code": "PASSENGER_EXISTS",
                    "message": "Passenger with this email already exists"
                }
            });
            return response;
        }

        // Create passenger record
        string passengerId = uuid:createType1AsString();
        Passenger newPassenger = {
            id: passengerId,
            email: registration.email,
            password: hashPassword(registration.password),
            firstName: registration.firstName,
            lastName: registration.lastName,
            phoneNumber: registration.phoneNumber,
            isActive: true,
            createdAt: time:utcNow(),
            updatedAt: time:utcNow()
        };

        // Store passenger
        error? saveResult = savePassenger(newPassenger);
        if saveResult is error {
            log:printError("Failed to save passenger: " + saveResult.message());
            response.statusCode = 500;
            response.setJsonPayload({
                "success": false,
                "error": {
                    "code": "STORAGE_ERROR",
                    "message": "Failed to save passenger data"
                }
            });
            return response;
        }

        // Return success response (without password)
        PassengerResponse passengerResponse = {
            id: newPassenger.id,
            email: newPassenger.email,
            firstName: newPassenger.firstName,
            lastName: newPassenger.lastName,
            phoneNumber: newPassenger.phoneNumber,
            createdAt: newPassenger.createdAt
        };

        response.statusCode = 201;
        response.setJsonPayload({
            "success": true,
            "data": passengerResponse.toJson(),
            "message": "Passenger registered successfully"
        });
        
        log:printInfo("Passenger registered successfully: " + newPassenger.id);
        return response;
    }

    // Passenger login
    resource function post login(@http:Payload LoginRequest loginRequest) returns http:Response|error {
        log:printInfo("Login attempt for: " + loginRequest.email);
        
        http:Response response = new;
        
        // Find passenger by email
        Passenger? passenger = findPassengerByEmail(loginRequest.email);
        if passenger is () {
            response.statusCode = 401;
            response.setJsonPayload({
                "success": false,
                "error": {
                    "code": "INVALID_CREDENTIALS",
                    "message": "Invalid email or password"
                }
            });
            return response;
        }

        // Verify password
        string hashedPassword = hashPassword(loginRequest.password);
        if passenger.password != hashedPassword {
            response.statusCode = 401;
            response.setJsonPayload({
                "success": false,
                "error": {
                    "code": "INVALID_CREDENTIALS",
                    "message": "Invalid email or password"
                }
            });
            return response;
        }

        // Check if passenger is active
        if !passenger.isActive {
            response.statusCode = 403;
            response.setJsonPayload({
                "success": false,
                "error": {
                    "code": "ACCOUNT_DISABLED",
                    "message": "Account is disabled"
                }
            });
            return response;
        }

        // Generate simple tokens (use proper JWT in production)
        string accessToken = "access_" + uuid:createType1AsString();
        string refreshToken = "refresh_" + uuid:createType1AsString();

        // Return login response
        LoginResponse loginResponse = {
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 3600,
            passenger: {
                id: passenger.id,
                email: passenger.email,
                firstName: passenger.firstName,
                lastName: passenger.lastName
            }
        };

        response.statusCode = 200;
        response.setJsonPayload({
            "success": true,
            "data": loginResponse.toJson(),
            "message": "Login successful"
        });
        
        log:printInfo("Login successful for passenger: " + passenger.id);
        return response;
    }

    // Get passenger profile
    resource function get [string passengerId]/profile() returns http:Response|error {
        log:printInfo("Getting profile for passenger: " + passengerId);
        
        http:Response response = new;
        
        // Find passenger by ID (simplified search)
        Passenger? foundPassenger = getPassenger(passengerId);

        if foundPassenger is () {
            response.statusCode = 404;
            response.setJsonPayload({
                "success": false,
                "error": {
                    "code": "PASSENGER_NOT_FOUND",
                    "message": "Passenger not found"
                }
            });
            return response;
        }

        // Return passenger profile (without password)
        PassengerResponse passengerResponse = {
            id: foundPassenger.id,
            email: foundPassenger.email,
            firstName: foundPassenger.firstName,
            lastName: foundPassenger.lastName,
            phoneNumber: foundPassenger.phoneNumber,
            createdAt: foundPassenger.createdAt
        };

        response.statusCode = 200;
        response.setJsonPayload({
            "success": true,
            "data": passengerResponse.toJson()
        });
        
        return response;
    }

    // Get all passengers (for testing)
    resource function get all() returns json {
        PassengerResponse[] allPassengers = [];

        Passenger[] allStoredPassengers = getAllPassengers();
        foreach Passenger passenger in allStoredPassengers {
            PassengerResponse passengerResponse = {
                id: passenger.id,
                email: passenger.email,
                firstName: passenger.firstName,
                lastName: passenger.lastName,
                phoneNumber: passenger.phoneNumber,
                createdAt: passenger.createdAt
            };
            allPassengers.push(passengerResponse);
        }

        return {
            "success": true,
            "data": allPassengers.toJson(),
            "count": allPassengers.length()
        };
    }
}

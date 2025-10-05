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

// Kafka producer and consumer
kafka:Producer kafkaProducer = check new (kafkaBrokers);
kafka:Consumer kafkaConsumer = check new (kafkaBrokers, ["user-registration", "user-login", "ticket-created", "ticket-validated", "ticket-cancelled", "payment-completed", "payment-failed", "payment-refunded", "trip-status-update"]);

// Data types
public type Notification record {
    int id?;
    int? userId;
    string notificationType;
    string title;
    string message;
    boolean isRead;
    string sentAt?;
};

public type NotificationRequest record {
    int? userId;
    string notificationType;
    string title;
    string message;
};

public type NotificationResponse record {
    int id;
    string notificationType;
    string title;
    string message;
    boolean isRead;
    string sentAt;
};

public type NotificationStats record {
    int totalNotifications;
    int unreadNotifications;
    int notificationsByType;
};

// Utility functions
function sendEmailNotification(string email, string title, string message) returns boolean {
    // In a real implementation, this would integrate with email service
    log:printInfo(`Email sent to ${email}: ${title} - ${message}`);
    return true;
}

function sendSMSNotification(string phone, string message) returns boolean {
    // In a real implementation, this would integrate with SMS service
    log:printInfo(`SMS sent to ${phone}: ${message}`);
    return true;
}

function sendPushNotification(int userId, string title, string message) returns boolean {
    // In a real implementation, this would integrate with push notification service
    log:printInfo(`Push notification sent to user ${userId}: ${title} - ${message}`);
    return true;
}

// Kafka consumer service
service kafka:Consumer kafkaConsumerService = new (kafkaConsumer);

@kafka:ServiceConfig {
    topics: ["user-registration", "user-login", "ticket-created", "ticket-validated", "ticket-cancelled", "payment-completed", "payment-failed", "payment-refunded", "trip-status-update"]
}
service kafka:Consumer on kafkaConsumerService {
    
    resource function onMessage(kafka:ConsumerRecord[] records) {
        foreach kafka:ConsumerRecord record in records {
            handleKafkaEvent(record);
        }
    }
}

function handleKafkaEvent(kafka:ConsumerRecord record) {
    string topic = record.topic;
    string value = record.value.toString();
    
    log:printInfo(`Processing Kafka event from topic: ${topic}`);
    
    match topic {
        "user-registration" => handleUserRegistration(value);
        "user-login" => handleUserLogin(value);
        "ticket-created" => handleTicketCreated(value);
        "ticket-validated" => handleTicketValidated(value);
        "ticket-cancelled" => handleTicketCancelled(value);
        "payment-completed" => handlePaymentCompleted(value);
        "payment-failed" => handlePaymentFailed(value);
        "payment-refunded" => handlePaymentRefunded(value);
        "trip-status-update" => handleTripStatusUpdate(value);
        _ => log:printWarn(`Unknown topic: ${topic}`);
    }
}

function handleUserRegistration(string eventData) {
    // Send welcome notification
    createNotification({
        userId: (),
        notificationType: "WELCOME",
        title: "Welcome to Windhoek Transport!",
        message: "Thank you for registering with Windhoek Transport. You can now purchase tickets and travel with us."
    });
}

function handleUserLogin(string eventData) {
    // Send login notification
    createNotification({
        userId: (),
        notificationType: "LOGIN",
        title: "Login Successful",
        message: "You have successfully logged into your Windhoek Transport account."
    });
}

function handleTicketCreated(string eventData) {
    // Send ticket purchase confirmation
    createNotification({
        userId: (),
        notificationType: "TICKET_PURCHASE",
        title: "Ticket Purchased Successfully",
        message: "Your ticket has been created and is ready for payment."
    });
}

function handleTicketValidated(string eventData) {
    // Send ticket validation confirmation
    createNotification({
        userId: (),
        notificationType: "TICKET_VALIDATION",
        title: "Ticket Validated",
        message: "Your ticket has been successfully validated. Have a safe journey!"
    });
}

function handleTicketCancelled(string eventData) {
    // Send ticket cancellation notification
    createNotification({
        userId: (),
        notificationType: "TICKET_CANCELLATION",
        title: "Ticket Cancelled",
        message: "Your ticket has been cancelled. If you have any questions, please contact support."
    });
}

function handlePaymentCompleted(string eventData) {
    // Send payment confirmation
    createNotification({
        userId: (),
        notificationType: "PAYMENT_CONFIRMATION",
        title: "Payment Successful",
        message: "Your payment has been processed successfully. Your ticket is now active."
    });
}

function handlePaymentFailed(string eventData) {
    // Send payment failure notification
    createNotification({
        userId: (),
        notificationType: "PAYMENT_FAILURE",
        title: "Payment Failed",
        message: "Your payment could not be processed. Please try again or contact support."
    });
}

function handlePaymentRefunded(string eventData) {
    // Send refund notification
    createNotification({
        userId: (),
        notificationType: "REFUND",
        title: "Refund Processed",
        message: "Your refund has been processed successfully. The amount will be credited to your account."
    });
}

function handleTripStatusUpdate(string eventData) {
    // Send trip update notification
    createNotification({
        userId: (),
        notificationType: "TRIP_UPDATE",
        title: "Trip Status Update",
        message: "There has been an update to your trip status. Please check the latest information."
    });
}

function createNotification(NotificationRequest notificationRequest) {
    sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
        INSERT INTO notifications (user_id, notification_type, title, message, is_read)
        VALUES (${notificationRequest.userId is int ? notificationRequest.userId.toString() : "NULL"}, 
               '${notificationRequest.notificationType}', 
               '${notificationRequest.title}', 
               '${notificationRequest.message}', 
               false)
    `);
    
    if insertResult is sql:Error {
        log:printError("Failed to create notification", 'error = insertResult);
    } else {
        log:printInfo("Notification created successfully");
    }
}

// HTTP service
@http:ServiceConfig {
    basePath: "/api/v1/notifications"
}
service / on new http:Listener(8085) {
    
    // Send notification
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/send"
    }
    resource function post send(@http:Payload NotificationRequest notificationRequest) 
            returns http:Created|http:BadRequest|http:InternalServerError {
        
        if notificationRequest.title == "" || notificationRequest.message == "" {
            return <http:BadRequest>{
                body: {message: "Title and message are required"}
            };
        }
        
        if notificationRequest.notificationType == "" {
            return <http:BadRequest>{
                body: {message: "Notification type is required"}
            };
        }
        
        createNotification(notificationRequest);
        
        return <http:Created>{
            body: {message: "Notification sent successfully"}
        };
    }
    
    // Get user notifications
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/user/{userId}"
    }
    resource function get userNotifications(int userId, @http:Query boolean? unreadOnly) returns http:Ok|http:InternalServerError {
        
        string filter = unreadOnly is boolean && unreadOnly ? "AND is_read = false" : "";
        
        stream<record {}, sql:Error?>|sql:Error notificationsStream = 
            dbClient->query(`
                SELECT * FROM notifications 
                WHERE user_id = ${userId} ${filter}
                ORDER BY sent_at DESC
            `);
        
        NotificationResponse[] notifications = [];
        record {}|sql:Error? notificationResult = notificationsStream.next();
        
        while notificationResult is record {} {
            NotificationResponse notification = {
                id: <int>notificationResult["id"],
                notificationType: <string>notificationResult["notification_type"],
                title: <string>notificationResult["title"],
                message: <string>notificationResult["message"],
                isRead: <boolean>notificationResult["is_read"],
                sentAt: <string>notificationResult["sent_at"]
            };
            notifications.push(notification);
            notificationResult = notificationsStream.next();
        }
        
        if notificationResult is sql:Error {
            log:printError("Database error retrieving notifications", 'error = notificationResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve notifications"}
            };
        }
        
        return <http:Ok>{
            body: {notifications: notifications}
        };
    }
    
    // Mark notification as read
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/{notificationId}/read"
    }
    resource function put markAsRead(int notificationId) returns http:Ok|http:NotFound|http:InternalServerError {
        
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
            UPDATE notifications SET is_read = true WHERE id = ${notificationId}
        `);
        
        if updateResult is sql:Error {
            log:printError("Failed to mark notification as read", 'error = updateResult);
            return <http:InternalServerError>{
                body: {message: "Failed to update notification"}
            };
        }
        
        if updateResult.affectedRowCount == 0 {
            return <http:NotFound>{
                body: {message: "Notification not found"}
            };
        }
        
        return <http:Ok>{
            body: {message: "Notification marked as read"}
        };
    }
    
    // Mark all notifications as read for user
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/user/{userId}/read-all"
    }
    resource function put markAllAsRead(int userId) returns http:Ok|http:InternalServerError {
        
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
            UPDATE notifications SET is_read = true WHERE user_id = ${userId} AND is_read = false
        `);
        
        if updateResult is sql:Error {
            log:printError("Failed to mark all notifications as read", 'error = updateResult);
            return <http:InternalServerError>{
                body: {message: "Failed to update notifications"}
            };
        }
        
        return <http:Ok>{
            body: {message: "All notifications marked as read"}
        };
    }
    
    // Delete notification
    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/{notificationId}"
    }
    resource function delete notification(int notificationId) returns http:Ok|http:NotFound|http:InternalServerError {
        
        sql:ExecutionResult|sql:Error deleteResult = dbClient->execute(`
            DELETE FROM notifications WHERE id = ${notificationId}
        `);
        
        if deleteResult is sql:Error {
            log:printError("Failed to delete notification", 'error = deleteResult);
            return <http:InternalServerError>{
                body: {message: "Failed to delete notification"}
            };
        }
        
        if deleteResult.affectedRowCount == 0 {
            return <http:NotFound>{
                body: {message: "Notification not found"}
            };
        }
        
        return <http:Ok>{
            body: {message: "Notification deleted successfully"}
        };
    }
    
    // Get notification statistics
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/statistics"
    }
    resource function get statistics(@http:Query int? userId) returns http:Ok|http:InternalServerError {
        
        string userFilter = userId is int ? `WHERE user_id = ${userId}` : "";
        
        stream<record {}, sql:Error?>|sql:Error statsStream = 
            dbClient->query(`
                SELECT 
                    COUNT(*) as total_notifications,
                    SUM(CASE WHEN is_read = false THEN 1 ELSE 0 END) as unread_notifications,
                    COUNT(CASE WHEN notification_type = 'TRIP_UPDATE' THEN 1 END) as trip_updates,
                    COUNT(CASE WHEN notification_type = 'PAYMENT_CONFIRMATION' THEN 1 END) as payment_confirmations,
                    COUNT(CASE WHEN notification_type = 'TICKET_VALIDATION' THEN 1 END) as ticket_validations
                FROM notifications 
                ${userFilter}
            `);
        
        record {}|sql:Error? statsResult = statsStream.next();
        if statsResult is sql:Error {
            log:printError("Database error retrieving notification statistics", 'error = statsResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve notification statistics"}
            };
        }
        
        return <http:Ok>{
            body: {
                totalNotifications: <int>statsResult["total_notifications"],
                unreadNotifications: <int>statsResult["unread_notifications"],
                tripUpdates: <int>statsResult["trip_updates"],
                paymentConfirmations: <int>statsResult["payment_confirmations"],
                ticketValidations: <int>statsResult["ticket_validations"]
            }
        };
    }
    
    // Send bulk notification
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/bulk"
    }
    resource function post sendBulk(@http:Payload record {
        int[] userIds;
        string notificationType;
        string title;
        string message;
    } bulkRequest) returns http:Created|http:BadRequest|http:InternalServerError {
        
        if bulkRequest.title == "" || bulkRequest.message == "" {
            return <http:BadRequest>{
                body: {message: "Title and message are required"}
            };
        }
        
        if bulkRequest.notificationType == "" {
            return <http:BadRequest>{
                body: {message: "Notification type is required"}
            };
        }
        
        if bulkRequest.userIds.length() == 0 {
            return <http:BadRequest>{
                body: {message: "At least one user ID is required"}
            };
        }
        
        int successCount = 0;
        foreach int userId in bulkRequest.userIds {
            createNotification({
                userId: userId,
                notificationType: bulkRequest.notificationType,
                title: bulkRequest.title,
                message: bulkRequest.message
            });
            successCount += 1;
        }
        
        return <http:Created>{
            body: {
                message: "Bulk notification sent successfully",
                sentTo: successCount,
                totalUsers: bulkRequest.userIds.length()
            }
        };
    }
}

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
public type PaymentRequest record {
    int ticketId;
    string paymentMethod;
    decimal amount;
    string currency?;
    string? paymentReference;
};

public type Payment record {
    int id?;
    int ticketId;
    string paymentMethod;
    decimal amount;
    string currency;
    string status;
    string? transactionId;
    string? paymentReference;
    string? processedAt;
    string createdAt?;
};

public type PaymentResponse record {
    boolean success;
    string message;
    Payment? payment;
    string? transactionId;
};

public type RefundRequest record {
    int paymentId;
    string reason?;
};

// Utility functions
function generateTransactionId() returns string {
    return "TXN_" + uuid:createType4AsString().substring(0, 12).toUpperAscii();
}

function simulatePaymentProcessing(string paymentMethod, decimal amount) returns boolean {
    // Simulate payment processing with 95% success rate
    // In real implementation, this would integrate with payment gateways
    return true; // Simplified for demo
}

function validatePaymentMethod(string paymentMethod) returns boolean {
    match paymentMethod {
        "CASH" => return true;
        "CARD" => return true;
        "MOBILE_MONEY" => return true;
        "BANK_TRANSFER" => return true;
        _ => return false;
    }
}

function validateCurrency(string currency) returns boolean {
    match currency {
        "NAD" => return true;
        "USD" => return true;
        "EUR" => return true;
        _ => return false;
    }
}

// HTTP service
@http:ServiceConfig {
    basePath: "/api/v1/payments"
}
service / on new http:Listener(8084) {
    
    // Process payment
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/process"
    }
    resource function post process(@http:Payload PaymentRequest paymentRequest) 
            returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError {
        
        // Validate input
        if paymentRequest.ticketId <= 0 {
            return <http:BadRequest>{
                body: {message: "Valid ticket ID is required"}
            };
        }
        
        if paymentRequest.paymentMethod == "" {
            return <http:BadRequest>{
                body: {message: "Payment method is required"}
            };
        }
        
        if paymentRequest.amount <= 0 {
            return <http:BadRequest>{
                body: {message: "Valid amount is required"}
            };
        }
        
        if !validatePaymentMethod(paymentRequest.paymentMethod) {
            return <http:BadRequest>{
                body: {message: "Invalid payment method"}
            };
        }
        
        string currency = paymentRequest.currency is string ? paymentRequest.currency : "NAD";
        if !validateCurrency(currency) {
            return <http:BadRequest>{
                body: {message: "Invalid currency"}
            };
        }
        
        // Check if ticket exists and is in CREATED status
        stream<record {}, sql:Error?>|sql:Error ticketStream = 
            dbClient->query(`SELECT * FROM tickets WHERE id = ${paymentRequest.ticketId}`);
        
        record {}|sql:Error? ticketResult = ticketStream.next();
        if ticketResult is sql:Error {
            log:printError("Database error checking ticket", 'error = ticketResult);
            return <http:InternalServerError>{
                body: {message: "Failed to process payment"}
            };
        }
        
        if ticketResult is () {
            return <http:NotFound>{
                body: {message: "Ticket not found"}
            };
        }
        
        string ticketStatus = <string>ticketResult["status"];
        if ticketStatus != "CREATED" {
            return <http:BadRequest>{
                body: {message: "Ticket is not in CREATED status for payment"}
            };
        }
        
        // Check if payment already exists for this ticket
        stream<record {}, sql:Error?>|sql:Error existingPaymentStream = 
            dbClient->query(`SELECT * FROM payments WHERE ticket_id = ${paymentRequest.ticketId}`);
        
        record {}|sql:Error? existingPaymentResult = existingPaymentStream.next();
        if existingPaymentResult is record {} {
            return <http:BadRequest>{
                body: {message: "Payment already exists for this ticket"}
            };
        }
        
        // Generate transaction ID
        string transactionId = generateTransactionId();
        
        // Simulate payment processing
        boolean paymentSuccess = simulatePaymentProcessing(paymentRequest.paymentMethod, paymentRequest.amount);
        
        string paymentStatus = paymentSuccess ? "COMPLETED" : "FAILED";
        string processedAt = paymentSuccess ? time:utcNow().toString() : ();
        
        // Create payment record
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(`
            INSERT INTO payments (ticket_id, payment_method, amount, currency, status, 
                                transaction_id, payment_reference, processed_at)
            VALUES (${paymentRequest.ticketId}, '${paymentRequest.paymentMethod}', 
                   ${paymentRequest.amount}, '${currency}', '${paymentStatus}', 
                   '${transactionId}', '${paymentRequest.paymentReference}', 
                   ${processedAt is string ? "'" + processedAt + "'" : "NULL"})
        `);
        
        if insertResult is sql:Error {
            log:printError("Failed to create payment record", 'error = insertResult);
            return <http:InternalServerError>{
                body: {message: "Failed to process payment"}
            };
        }
        
        // If payment successful, update ticket status
        if paymentSuccess {
            sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
                UPDATE tickets SET status = 'PAID' WHERE id = ${paymentRequest.ticketId}
            `);
            
            if updateResult is sql:Error {
                log:printError("Failed to update ticket status", 'error = updateResult);
                return <http:InternalServerError>{
                    body: {message: "Failed to update ticket status"}
                };
            }
        }
        
        // Get created payment
        stream<record {}, sql:Error?>|sql:Error paymentStream = 
            dbClient->query(`SELECT * FROM payments WHERE transaction_id = '${transactionId}'`);
        
        record {}|sql:Error? paymentResult = paymentStream.next();
        if paymentResult is sql:Error {
            log:printError("Failed to retrieve created payment", 'error = paymentResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve payment"}
            };
        }
        
        Payment payment = {
            id: <int>paymentResult["id"],
            ticketId: <int>paymentResult["ticket_id"],
            paymentMethod: <string>paymentResult["payment_method"],
            amount: <decimal>paymentResult["amount"],
            currency: <string>paymentResult["currency"],
            status: <string>paymentResult["status"],
            transactionId: <string?>paymentResult["transaction_id"],
            paymentReference: <string?>paymentResult["payment_reference"],
            processedAt: <string?>paymentResult["processed_at"],
            createdAt: <string>paymentResult["created_at"]
        };
        
        // Send payment event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: paymentSuccess ? "payment-completed" : "payment-failed",
            value: {
                paymentId: payment.id,
                ticketId: payment.ticketId,
                transactionId: payment.transactionId,
                amount: payment.amount,
                currency: payment.currency,
                status: payment.status,
                timestamp: time:utcNow().toString()
            }.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send payment event to Kafka", 'error = kafkaResult);
        }
        
        PaymentResponse response = {
            success: paymentSuccess,
            message: paymentSuccess ? "Payment processed successfully" : "Payment processing failed",
            payment: payment,
            transactionId: paymentSuccess ? transactionId : ()
        };
        
        return <http:Ok>{
            body: response
        };
    }
    
    // Get payment by transaction ID
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/transaction/{transactionId}"
    }
    resource function get paymentByTransaction(string transactionId) returns http:Ok|http:NotFound|http:InternalServerError {
        
        stream<record {}, sql:Error?>|sql:Error paymentStream = 
            dbClient->query(`SELECT * FROM payments WHERE transaction_id = '${transactionId}'`);
        
        record {}|sql:Error? paymentResult = paymentStream.next();
        if paymentResult is sql:Error {
            log:printError("Database error retrieving payment", 'error = paymentResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve payment"}
            };
        }
        
        if paymentResult is () {
            return <http:NotFound>{
                body: {message: "Payment not found"}
            };
        }
        
        Payment payment = {
            id: <int>paymentResult["id"],
            ticketId: <int>paymentResult["ticket_id"],
            paymentMethod: <string>paymentResult["payment_method"],
            amount: <decimal>paymentResult["amount"],
            currency: <string>paymentResult["currency"],
            status: <string>paymentResult["status"],
            transactionId: <string?>paymentResult["transaction_id"],
            paymentReference: <string?>paymentResult["payment_reference"],
            processedAt: <string?>paymentResult["processed_at"],
            createdAt: <string>paymentResult["created_at"]
        };
        
        return <http:Ok>{
            body: payment
        };
    }
    
    // Get payments for ticket
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/ticket/{ticketId}"
    }
    resource function get paymentsForTicket(int ticketId) returns http:Ok|http:InternalServerError {
        
        stream<record {}, sql:Error?>|sql:Error paymentsStream = 
            dbClient->query(`SELECT * FROM payments WHERE ticket_id = ${ticketId} ORDER BY created_at DESC`);
        
        Payment[] payments = [];
        record {}|sql:Error? paymentResult = paymentsStream.next();
        
        while paymentResult is record {} {
            Payment payment = {
                id: <int>paymentResult["id"],
                ticketId: <int>paymentResult["ticket_id"],
                paymentMethod: <string>paymentResult["payment_method"],
                amount: <decimal>paymentResult["amount"],
                currency: <string>paymentResult["currency"],
                status: <string>paymentResult["status"],
                transactionId: <string?>paymentResult["transaction_id"],
                paymentReference: <string?>paymentResult["payment_reference"],
                processedAt: <string?>paymentResult["processed_at"],
                createdAt: <string>paymentResult["created_at"]
            };
            payments.push(payment);
            paymentResult = paymentsStream.next();
        }
        
        if paymentResult is sql:Error {
            log:printError("Database error retrieving payments", 'error = paymentResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve payments"}
            };
        }
        
        return <http:Ok>{
            body: {payments: payments}
        };
    }
    
    // Process refund
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/refund"
    }
    resource function post refund(@http:Payload RefundRequest refundRequest) 
            returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError {
        
        if refundRequest.paymentId <= 0 {
            return <http:BadRequest>{
                body: {message: "Valid payment ID is required"}
            };
        }
        
        // Check if payment exists and is completed
        stream<record {}, sql:Error?>|sql:Error paymentStream = 
            dbClient->query(`SELECT * FROM payments WHERE id = ${refundRequest.paymentId}`);
        
        record {}|sql:Error? paymentResult = paymentStream.next();
        if paymentResult is sql:Error {
            log:printError("Database error retrieving payment for refund", 'error = paymentResult);
            return <http:InternalServerError>{
                body: {message: "Failed to process refund"}
            };
        }
        
        if paymentResult is () {
            return <http:NotFound>{
                body: {message: "Payment not found"}
            };
        }
        
        string paymentStatus = <string>paymentResult["status"];
        if paymentStatus != "COMPLETED" {
            return <http:BadRequest>{
                body: {message: "Only completed payments can be refunded"}
            };
        }
        
        // Update payment status to refunded
        sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`
            UPDATE payments SET status = 'REFUNDED' WHERE id = ${refundRequest.paymentId}
        `);
        
        if updateResult is sql:Error {
            log:printError("Failed to process refund", 'error = updateResult);
            return <http:InternalServerError>{
                body: {message: "Failed to process refund"}
            };
        }
        
        // Update ticket status to cancelled
        int ticketId = <int>paymentResult["ticket_id"];
        sql:ExecutionResult|sql:Error ticketUpdateResult = dbClient->execute(`
            UPDATE tickets SET status = 'CANCELLED' WHERE id = ${ticketId}
        `);
        
        if ticketUpdateResult is sql:Error {
            log:printError("Failed to update ticket status after refund", 'error = ticketUpdateResult);
        }
        
        // Send refund event to Kafka
        kafka:ProducerError? kafkaResult = kafkaProducer->send({
            topic: "payment-refunded",
            value: {
                paymentId: refundRequest.paymentId,
                ticketId: ticketId,
                reason: refundRequest.reason,
                timestamp: time:utcNow().toString()
            }.toString()
        });
        
        if kafkaResult is kafka:ProducerError {
            log:printWarn("Failed to send refund event to Kafka", 'error = kafkaResult);
        }
        
        return <http:Ok>{
            body: {message: "Refund processed successfully"}
        };
    }
    
    // Get payment statistics
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/statistics"
    }
    resource function get statistics(@http:Query string? startDate, @http:Query string? endDate) 
            returns http:Ok|http:InternalServerError {
        
        string dateFilter = "";
        if startDate is string && endDate is string {
            dateFilter = `AND created_at BETWEEN '${startDate}' AND '${endDate}'`;
        } else if startDate is string {
            dateFilter = `AND created_at >= '${startDate}'`;
        } else if endDate is string {
            dateFilter = `AND created_at <= '${endDate}'`;
        }
        
        // Get payment statistics
        stream<record {}, sql:Error?>|sql:Error statsStream = 
            dbClient->query(`
                SELECT 
                    COUNT(*) as total_payments,
                    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as successful_payments,
                    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_payments,
                    SUM(CASE WHEN status = 'REFUNDED' THEN 1 ELSE 0 END) as refunded_payments,
                    SUM(CASE WHEN status = 'COMPLETED' THEN amount ELSE 0 END) as total_amount,
                    AVG(CASE WHEN status = 'COMPLETED' THEN amount ELSE NULL END) as average_amount
                FROM payments 
                WHERE 1=1 ${dateFilter}
            `);
        
        record {}|sql:Error? statsResult = statsStream.next();
        if statsResult is sql:Error {
            log:printError("Database error retrieving payment statistics", 'error = statsResult);
            return <http:InternalServerError>{
                body: {message: "Failed to retrieve payment statistics"}
            };
        }
        
        return <http:Ok>{
            body: {
                totalPayments: <int>statsResult["total_payments"],
                successfulPayments: <int>statsResult["successful_payments"],
                failedPayments: <int>statsResult["failed_payments"],
                refundedPayments: <int>statsResult["refunded_payments"],
                totalAmount: <decimal>statsResult["total_amount"],
                averageAmount: <decimal?>statsResult["average_amount"]
            }
        };
    }
}

#!/bin/bash

# Kafka topics creation script for Windhoek Transport Ticketing System
# This script creates all necessary Kafka topics for the distributed system

echo "Creating Kafka topics for Windhoek Transport Ticketing System..."

# Wait for Kafka to be ready
echo "Waiting for Kafka to be ready..."
sleep 30

# Create topics
kafka-topics --create --topic user-registration --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic user-login --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic ticket-created --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic ticket-validated --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic ticket-cancelled --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic payment-completed --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic payment-failed --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic payment-refunded --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic trip-status-update --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1
kafka-topics --create --topic service-disruption --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1

echo "All Kafka topics created successfully!"

# List all topics
echo "Listing all topics:"
kafka-topics --list --bootstrap-server localhost:9092

#!/bin/bash

# Windhoek Transport System - Monitoring Setup Script
# This script starts the monitoring stack for the transport system

echo "🚀 Starting Windhoek Transport System Monitoring Stack..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create monitoring network if it doesn't exist
echo "📡 Creating monitoring network..."
docker network create monitoring 2>/dev/null || echo "Network already exists"

# Start monitoring services
echo "🔧 Starting monitoring services..."
docker-compose -f monitoring/docker-compose.monitoring.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 30

# Check service status
echo "📊 Checking service status..."
docker-compose -f monitoring/docker-compose.monitoring.yml ps

# Display access information
echo ""
echo "🎉 Monitoring stack is ready!"
echo ""
echo "📊 Access URLs:"
echo "  • Grafana: http://localhost:3000 (admin/admin123)"
echo "  • Prometheus: http://localhost:9090"
echo "  • Jaeger: http://localhost:16686"
echo "  • Kibana: http://localhost:5601"
echo "  • Elasticsearch: http://localhost:9200"
echo "  • cAdvisor: http://localhost:8080"
echo ""
echo "📈 Monitoring Features:"
echo "  • System metrics (CPU, Memory, Disk)"
echo "  • Application metrics (HTTP requests, response times)"
echo "  • Database metrics (connections, queries)"
echo "  • Kafka metrics (topics, consumers)"
echo "  • Container metrics (resource usage)"
echo "  • Distributed tracing"
echo "  • Centralized logging"
echo ""
echo "🔍 Useful Commands:"
echo "  • View logs: docker-compose -f monitoring/docker-compose.monitoring.yml logs"
echo "  • Stop monitoring: docker-compose -f monitoring/docker-compose.monitoring.yml down"
echo "  • Restart services: docker-compose -f monitoring/docker-compose.monitoring.yml restart"
echo ""
echo "✨ Happy monitoring!"

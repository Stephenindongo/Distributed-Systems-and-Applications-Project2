#!/bin/bash

# Windhoek Transport System - Make Scripts Executable
# This script makes all shell scripts executable

echo "🔧 Making Scripts Executable"
echo "============================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# List of scripts to make executable
SCRIPTS=(
    "kafka-topics.sh"
    "start-monitoring.sh"
    "scripts/health-check.sh"
    "scripts/test-system.sh"
    "scripts/load-test.sh"
    "scripts/backup-system.sh"
    "scripts/restore-system.sh"
    "scripts/quick-start.sh"
    "scripts/make-executable.sh"
)

echo "Making the following scripts executable:"
echo ""

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        chmod +x "$script"
        echo -e "${GREEN}✅ $script${NC}"
    else
        echo -e "${YELLOW}⚠️  $script (not found)${NC}"
    fi
done

echo ""
echo "🎉 All scripts are now executable!"
echo ""
echo "You can now run:"
echo "  • ./scripts/quick-start.sh - One-click system setup"
echo "  • ./scripts/health-check.sh - Check system health"
echo "  • ./scripts/test-system.sh - Run system tests"
echo "  • ./scripts/load-test.sh - Perform load testing"
echo "  • ./scripts/backup-system.sh - Backup the system"
echo "  • ./scripts/restore-system.sh - Restore from backup"
echo "  • ./kafka-topics.sh - Create Kafka topics"
echo "  • ./start-monitoring.sh - Start monitoring stack"

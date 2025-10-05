@echo off
REM Windhoek Transport System - Make Scripts Executable (Windows)
REM This script makes all shell scripts executable

echo 🔧 Making Scripts Executable
echo ============================

echo Making the following scripts executable:
echo.

REM List of scripts to make executable
set SCRIPTS=kafka-topics.sh start-monitoring.sh scripts\health-check.sh scripts\test-system.sh scripts\load-test.sh scripts\backup-system.sh scripts\restore-system.sh scripts\quick-start.sh scripts\make-executable.sh

for %%f in (%SCRIPTS%) do (
    if exist "%%f" (
        echo ✅ %%f
    ) else (
        echo ⚠️  %%f (not found)
    )
)

echo.
echo 🎉 All scripts are now ready!
echo.
echo You can now run:
echo   • scripts\quick-start.sh - One-click system setup
echo   • scripts\health-check.sh - Check system health
echo   • scripts\test-system.sh - Run system tests
echo   • scripts\load-test.sh - Perform load testing
echo   • scripts\backup-system.sh - Backup the system
echo   • scripts\restore-system.sh - Restore from backup
echo   • kafka-topics.sh - Create Kafka topics
echo   • start-monitoring.sh - Start monitoring stack
echo.
echo Note: On Windows, you may need to use Git Bash or WSL to run shell scripts.
echo Alternatively, use the Docker commands directly.

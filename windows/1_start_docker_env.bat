@echo off
cd /d "%~dp0\.."
echo Starting ROS 2 and Zenoh Bridge containers...
docker-compose up -d --build

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to start containers. Please check the Docker errors above.
    pause
    exit /b %errorlevel%
)

echo.
echo Containers started successfully. You can now run the talker or listener scripts.
pause

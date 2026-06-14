@echo off
if "%1"=="" ( set NAME=r2_jazzy ) else ( set NAME=%1 )
if "%2"=="" ( set DOMAIN_ID=0 ) else ( set DOMAIN_ID=%2 )

docker run -it --rm ^
    --name %NAME% ^
    --network host ^
    -e DISPLAY=host.docker.internal:0 ^
    -e ROS_DOMAIN_ID=%DOMAIN_ID% ^
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw ^
    r2_jazzy

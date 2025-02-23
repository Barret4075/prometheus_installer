@echo off
setlocal enabledelayedexpansion
chcp 65001

REM 检查管理员权限
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' (
    goto :admin
) else (
    echo 请求管理员权限...
    powershell -Command "Start-Process powershell -ArgumentList '/c %~f0' -Verb RunAs"
    exit /b
)

:admin
set MONITOR_DIR=%~dp0monitor
set EXPORTER_PORT=9182
set PROMETHEUS_PORT=9090
set NGINX_PORT=9091

echo 1. 创建监控目录
mkdir "%MONITOR_DIR%" 2>nul

REM 下载网址
set EXPORTER_URL=https://github.com/prometheus-community/windows_exporter/releases/download/v0.30.2/windows_exporter-0.30.2-amd64.exe
set PROMETHEUS_URL=https://github.com/prometheus/prometheus/releases/download/v3.1.0/prometheus-3.1.0.windows-amd64.zip
set NGINX_URL=https://nginx.org/download/nginx-1.26.3.zip

bitsadmin /transfer "Download_exprter" "%EXPORTER_URL%" "%MONITOR_DIR%\windows_exporter.exe"

start /d "%MONITOR_DIR%" cmd /k "%MONITOR_DIR%\windows_exporter.exe --web.listen-address=127.0.0.1:%EXPORTER_PORT%"

echo 3.下载并配置Prometheus
set PROMETHEUS_ZIP=%MONITOR_DIR%\prometheus.zip
set PROMETHEUS_DIR=%MONITOR_DIR%\prometheus

bitsadmin /transfer "Download_Prometheus" "%PROMETHEUS_URL%" "%PROMETHEUS_ZIP%"


powershell -Command "Expand-Archive -Path '%PROMETHEUS_ZIP%' -DestinationPath '%MONITOR_DIR%'"

ren %MONITOR_DIR%\prometheus-3.1.0.windows-amd64 prometheus

(
echo   - job_name: "windows_exporter"
echo     static_configs:
echo       - targets: ["localhost:%EXPORTER_PORT%"]
) >> "%PROMETHEUS_DIR%\prometheus.yml"

start /d "%MONITOR_DIR%" cmd /k "%PROMETHEUS_DIR%\prometheus.exe --config.file=%PROMETHEUS_DIR%\prometheus.yml  --web.listen-address=localhost:%PROMETHEUS_PORT%"

echo 4.配置Nginx

set NGINX_ZIP=%MONITOR_DIR%\nginx.zip
set NGINX_DIR=%MONITOR_DIR%\nginx
bitsadmin /transfer "Download_nginx" "%NGINX_URL%" "%NGINX_ZIP%"

powershell -Command "Expand-Archive -Path '%NGINX_ZIP%' -DestinationPath '%MONITOR_DIR%'"
ren "%MONITOR_DIR%\nginx-1.26.3" nginx
(
echo worker_processes  1;
echo events {worker_connections  1024;}
echo http {
echo     include       mime.types;
echo     default_type  application/octet-stream;
echo     sendfile        on;
echo     keepalive_timeout  65;
echo     include prometheus.conf;
echo }
) > "%NGINX_DIR%\conf\nginx.conf"

(
echo server {
echo     listen %NGINX_PORT%;
echo     server_name _;
echo     location / {
echo         proxy_pass http://localhost:%PROMETHEUS_PORT%/;
echo     }
echo }
) > "%NGINX_DIR%\conf\prometheus.conf"

REM 添加环境变量
setx PATH "%PATH%;%NGINX_DIR%" /m >nul

start /d "%NGINX_DIR%"  cmd /k "nginx.exe"

echo 安装完成！
echo 访问地址:http://localhost:%NGINX_PORT%/
echo Windows Exporter端口:%EXPORTER_PORT%
echo Prometheus端口:%PROMETHEUS_PORT%
echo Nginx代理端口:%NGINX_PORT%

endlocal
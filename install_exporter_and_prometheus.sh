#!bin/bash

EXPORTER_VERSION_NUM="1.8.2"
PROMETHEUS_VERSION_NUM="3.1.0"

# SSL setting
read -p "Do you want to enable SSL (Y/N)? " enable_ssl
if [[ $enable_ssl =~ ^[Yy]$ ]]; then
    SSL="ssl"
    read -p "Enter the path to SSL certificate: " SSL_CERTIFICATE
    read -p "Enter the path to SSL certificate key: " SSL_CERTIFICATE_KEY
else
    # SSL switch ["","ssl"]
    SSL=""
    # config "ssl_certificate your/path/to/ssl_certificate" or leave blank
    SSL_CERTIFICATE=""
    # config "ssl_certificate_key your/path/to/ssl_certificate_key" or leave blank
    SSL_CERTIFICATE_KEY=""
fi

## exporter 

EXPORTER_VERSION="$EXPORTER_VERSION_NUM.linux-amd64"
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v$EXPORTER_VERSION_NUM/node_exporter-$EXPORTER_VERSION.tar.gz"
TARGET_DIR="/opt/monitor/"
EXECUTABLE_DIR="/opt/monitor/node_exporter-$EXPORTER_VERSION"
SERVICE_NAME="node_exporter.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
EXECUTABLE_NAME="node_exporter"

mkdir -p "$TARGET_DIR"

echo "Downloading file from $DOWNLOAD_URL..."
wget -O /tmp/file.zip "$DOWNLOAD_URL"

if [ $? -ne 0 ]; then
  echo "Failed to download file. Please check the URL and try again."
  exit 1
fi

echo "Extracting file to $TARGET_DIR..."
tar -xzf /tmp/file.zip -C "$TARGET_DIR"

if [ $? -ne 0 ]; then
  echo "Failed to extract file. Please check the zip file and try again."
  exit 1
fi

if [ ! -f "$EXECUTABLE_DIR/$EXECUTABLE_NAME" ]; then
  echo "Executable file $EXECUTABLE_NAME not found in $TARGET_DIR."
  exit 1
fi

echo "Creating Systemd Service file at $SERVICE_FILE..."
cat <<EOF | tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=node_exporter service on local port 9100
After=network.target

[Service]
ExecStart=$EXECUTABLE_DIR/$EXECUTABLE_NAME --web.listen-address=127.0.0.1:9100
WorkingDirectory=$EXECUTABLE_DIR
Restart=always

[Install]
WantedBy=multi-user.target
EOF


if [ $? -ne 0 ]; then
  echo "Failed to create Systemd Service file."
  exit 1
fi

echo "Reloading Systemd configuration..."
systemctl daemon-reload

if [ $? -ne 0 ]; then
  echo "Failed to reload Systemd configuration."
  exit 1
fi

echo "Service $SERVICE_NAME created and Systemd configuration reloaded successfully."

systemctl start $SERVICE_NAME > /dev/null

## prometheus 

PROMETHEUS_VERSION="$PROMETHEUS_VERSION_NUM.linux-amd64"

DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION_NUM/prometheus-$PROMETHEUS_VERSION.tar.gz"
TARGET_DIR="/opt/monitor/"
EXECUTABLE_DIR="/opt/monitor/prometheus-$PROMETHEUS_VERSION"
SERVICE_NAME="prometheus.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
EXECUTABLE_NAME="prometheus"

mkdir -p "$TARGET_DIR"

echo "Downloading file from $DOWNLOAD_URL..."
wget -O /tmp/file.zip "$DOWNLOAD_URL"


if [ $? -ne 0 ]; then
  echo "Failed to download file. Please check the URL and try again."
  exit 1
fi


echo "Extracting file to $TARGET_DIR..."
tar -xzf /tmp/file.zip -C "$TARGET_DIR"

if [ $? -ne 0 ]; then
  echo "Failed to extract file. Please check the zip file and try again."
  exit 1
fi

if [ ! -f "$EXECUTABLE_DIR/$EXECUTABLE_NAME" ]; then
  echo "Executable file $EXECUTABLE_NAME not found in $TARGET_DIR."
  exit 1
fi
echo '
  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]' >> $EXECUTABLE_DIR/$EXECUTABLE_NAME.yml

echo "Creating Systemd Service file at $SERVICE_FILE..."
cat <<EOF | tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=prometheus service on local port 9090
After=network.target

[Service]
ExecStart=$EXECUTABLE_DIR/$EXECUTABLE_NAME --web.listen-address=127.0.0.1:9090
WorkingDirectory=$EXECUTABLE_DIR
Restart=always

[Install]
WantedBy=multi-user.target
EOF


if [ $? -ne 0 ]; then
  echo "Failed to create Systemd Service file."
  exit 1
fi

echo "Reloading Systemd configuration..."
systemctl daemon-reload

if [ $? -ne 0 ]; then
  echo "Failed to reload Systemd configuration."
  exit 1
fi

echo "Service $SERVICE_NAME created and Systemd configuration reloaded successfully."

echo "server {
    listen 9091 $SSL;
    ssl_certificate $SSL_CERTIFICATE;
    ssl_certificate_key $SSL_CERTIFICATE_KEY;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:9090/;
    }
}" > /etc/nginx/conf.d/prometheus.conf

systemctl start $SERVICE_NAME > /dev/null
systemctl restart nginx

echo "
installation finished
node_exporter.service  registered  start on local port 9100
prometheus.service     registered  start on local port 9090
prometheus config file /opt/monitor/prometheus-$PROMETHEUS_VERSION
nginx      config file /etc/nginx/conf.d/prometheus.conf
port 9091 via nginx : 127.0.0.1:9091
"
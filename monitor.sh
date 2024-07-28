# sudo apt-get update
# sudo apt-get install -y wget curl apt-transport-https software-properties-common

# Prometheus Installation
# wget https://github.com/prometheus/prometheus/releases/download/v2.53.1/prometheus-2.53.1.linux-amd64.tar.gz
# tar xvfz prometheus-2.53.1.linux-amd64.tar.gz
# sudo mv prometheus-2.53.1.linux-amd64/prometheus

#!/bin/bash

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        log "$1 successful"
    else
        log "Error: $1 failed"
        exit 1
    fi
}

# Update system
log "Updating system..."
sudo apt-get update && sudo apt-get upgrade -y
check_success "System update"

# Create a System User for Prometheus
log "creating system user for Prometheus"
sudo groupadd --system prometheus || true
sudo useradd -s /sbin/nologin --system -g prometheus prometheus || true
check_success "Created System User"

# Install dependencies
log "Installing dependencies..."
sudo apt-get install -y wget curl
check_success "Dependencies installation"

# Prometheus Installation
log "Starting Prometheus installation..."

# Download Prometheus
PROMETHEUS_VERSION="2.53.1"
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
check_success "Prometheus download"

# Extract Prometheus
tar xvfz prometheus*.tar.gz
check_success "Prometheus extraction"

# Setup Prometheus directories and user
sudo mkdir -p /opt/prometheus /etc/prometheus /var/lib/prometheus
sudo useradd --no-create-home --shell /bin/false prometheus || true
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus || true
check_success "Prometheus directory and user setup"

# Move Prometheus files
sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/* /opt/prometheus/
check_success "Prometheus files move"

# Copy Prometheus binaries
sudo cp /opt/prometheus/prometheus /usr/local/bin/
sudo cp /opt/prometheus/promtool /usr/local/bin/
sudo cp /opt/prometheus/consoles /etc/prometheus
sudo cp /opt/prometheus/console_libraries /etc/prometheus
sudo cp /opt/prometheus/prometheus.yml /etc/prometheus
check_success "Prometheus binaries copy"

# Set ownership for Prometheus binaries
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
sudo chown -R prometheus:prometheus /var/lib/prometheus
check_success "Prometheus binaries ownership"

# Create Prometheus configuration
cat << EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9090']
EOF
check_success "Prometheus configuration creation"

log "Prometheus installation completed"

cat << EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
check_success "Prometheus systemd service creation"

log "Reconfigured systemd service for Prometheus"

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Allow port 9090 on your firewall for Prometheus
sudo ufw allow 9090/tcp

# Grafana Installation
log "Starting Grafana installation..."

# Add Grafana GPG key
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
check_success "Grafana GPG key addition"

# Add Grafana repository
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
check_success "Grafana repository addition"

# Update and install Grafana
sudo apt-get update
sudo apt-get install -y grafana
check_success "Grafana installation"

# Start Grafana service
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
check_success "Grafana service start"

log "Grafana installation completed"

log "Installation process completed successfully"
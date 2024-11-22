#!/bin/bash

# Skrip lengkap untuk setup MTProxy dengan systemd service dan Management API

SERVICE_PATH="/etc/systemd/system/MTProxy.service"
NODEAPI_SERVICE_PATH="/etc/systemd/system/nodeapi.service"
WORKING_DIR="/opt/MTProxy"
EXECUTABLE="$WORKING_DIR/mtproto-proxy"
PORT="8888"
TLS_PORT="443"
MULTI_CONF="proxy-multi.conf"
SECRET_FILE="proxy-secret"
SECRET=""

echo "Memperbarui daftar paket..."
sudo apt update -y

echo "Menginstal dependensi..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y git curl build-essential libssl-dev zlib1g-dev nodejs npm

if [ $? -ne 0 ]; then
    echo "Gagal menginstal dependensi. Periksa kesalahan dan coba lagi."
    exit 1
fi

echo "Cloning repository MTProxy..."
git clone https://github.com/Rheyhans/MTProxy

if [ $? -ne 0 ]; then
    echo "Gagal melakukan clone repository MTProxy. Periksa koneksi internet atau URL."
    exit 1
fi

echo "Masuk ke direktori MTProxy..."
cd MTProxy || { echo "Gagal masuk ke direktori MTProxy."; exit 1; }

echo "Menjalankan proses build dengan make..."
make

if [ $? -ne 0 ]; then
    echo "Proses build gagal. Periksa kesalahan pada proses make."
    exit 1
fi

echo "Navigasi ke direktori objs/bin..."
cd objs/bin || { echo "Gagal masuk ke direktori objs/bin."; exit 1; }

echo "Mengunduh proxy-secret dari Telegram..."
curl -s https://core.telegram.org/getProxySecret -o proxy-secret

if [ $? -ne 0 ]; then
    echo "Gagal mengunduh proxy-secret. Periksa koneksi internet."
    exit 1
fi

echo "Mengunduh proxy-multi.conf dari Telegram..."
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf

if [ $? -ne 0 ]; then
    echo "Gagal mengunduh proxy-multi.conf. Periksa koneksi internet."
    exit 1
fi

echo "Membuat secret untuk MTProxy..."
SECRET=$(head -c 16 /dev/urandom | xxd -ps)

if [ -z "$SECRET" ]; then
    echo "Gagal membuat secret."
    exit 1
fi

echo "Secret berhasil dibuat: $SECRET"
echo "$SECRET" > proxy-secret.txt

echo "Memastikan direktori tujuan /opt/MTProxy ada..."
sudo mkdir -p /opt/MTProxy

echo "Memindahkan file hasil build ke /opt/MTProxy..."
sudo mv * /opt/MTProxy/

if [ $? -ne 0 ]; then
    echo "Gagal memindahkan file ke /opt/MTProxy."
    exit 1
fi

echo "Cloning repository MTProxy-Management-Api ke /opt/nodeapi..."
sudo git clone https://github.com/Rheyhans/MTProxy-Management-Api.git /opt/nodeapi

if [ $? -ne 0 ]; then
    echo "Gagal melakukan clone repository MTProxy-Management-Api. Periksa koneksi internet atau URL."
    exit 1
fi

echo "Masuk ke direktori /opt/nodeapi dan menginstal dependensi Node.js..."
cd /opt/nodeapi || { echo "Gagal masuk ke direktori /opt/nodeapi."; exit 1; }
sudo npm install

if [ $? -ne 0 ]; then
    echo "Gagal menginstal dependensi Node.js untuk MTProxy-Management-Api."
    exit 1
fi

echo "Menulis file service untuk MTProxy di $SERVICE_PATH..."
sudo bash -c "cat > $SERVICE_PATH" <<EOL
[Unit]
Description=MTProxy
After=network.target

[Service]
Type=simple
WorkingDirectory=$WORKING_DIR
ExecStart=$EXECUTABLE -u nobody -p $PORT -H $TLS_PORT -S $SECRET --aes-pwd $SECRET_FILE $MULTI_CONF -M 2
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

echo "Menulis file service untuk Node.js Management API di $NODEAPI_SERVICE_PATH..."
sudo bash -c "cat > $NODEAPI_SERVICE_PATH" <<EOL
[Unit]
Description=My Node.js App
After=network.target

[Service]
Environment=NODE_ENV=production
WorkingDirectory=/opt/nodeapi
ExecStart=/usr/bin/node /opt/nodeapi/index.js
Restart=always
User=nobody
Group=nogroup
EnvironmentFile=/opt/nodeapi/.env
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=nodeapi

[Install]
WantedBy=multi-user.target
EOL

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Mengaktifkan dan memulai service MTProxy..."
sudo systemctl enable MTProxy
sudo systemctl start MTProxy

echo "Mengaktifkan dan memulai service Node.js Management API..."
sudo systemctl enable nodeapi
sudo systemctl start nodeapi

echo "Setup selesai. MTProxy dan Node.js Management API telah berjalan."
echo "Periksa status dengan: sudo systemctl status MTProxy dan sudo systemctl status nodeapi"

#!/bin/bash

# Skrip lengkap untuk setup MTProxy dengan PM2 untuk Node.js Management API

SERVICE_PATH="/etc/systemd/system/MTProxy.service"
WORKING_DIR="/opt/MTProxy"
NODEAPI_DIR="/opt/nodeapi"
EXECUTABLE="$WORKING_DIR/mtproto-proxy"
PORT="8888"
TLS_PORT="443"
MULTI_CONF="proxy-multi.conf"
SECRET_FILE="proxy-secret"
SECRET=""
WHITELIST_FILE="$NODEAPI_DIR/whitelist.txt"

# 1. Prompt user memasukkan IP whitelist
echo -n "Masukkan IP yang ingin di-whitelist (pisah spasi untuk beberapa IP): "
read -r IP_LIST

echo "Memperbarui daftar paket..."
sudo apt update -y

echo "Menginstal dependensi..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y git curl build-essential libssl-dev zlib1g-dev nodejs npm

if [ $? -ne 0 ]; then
    echo "Gagal menginstal dependensi. Periksa kesalahan dan coba lagi."
    exit 1
fi

echo "Menginstal PM2..."
sudo npm install -g pm2

if [ $? -ne 0 ]; then
    echo "Gagal menginstal PM2. Periksa koneksi internet."
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

echo "# Whitelist MTProxy generated on $(date)" > "$WHITELIST_FILE"
for ip in $IP_LIST; do
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "$ip" >> "$WHITELIST_FILE"
  else
    echo "Warning: '$ip' bukan format IPv4, dilewati."
  fi
done

echo "Whitelist tersimpan di $WHITELIST_FILE:"
cat "$WHITELIST_FILE"


echo "Masuk ke direktori /opt/nodeapi dan menginstal dependensi Node.js..."
cd /opt/nodeapi || { echo "Gagal masuk ke direktori /opt/nodeapi."; exit 1; }
sudo npm install

if [ $? -ne 0 ]; then
    echo "Gagal menginstal dependensi Node.js untuk MTProxy-Management-Api."
    exit 1
fi

echo "Menambahkan aplikasi Node.js ke PM2 dengan watch mode..."
sudo pm2 start /opt/nodeapi/index.js --name "nodeapi" --env production --watch --watch-delay 1000 --ignore-watch "node_modules"

if [ $? -ne 0 ]; then
    echo "Gagal menambahkan aplikasi Node.js ke PM2."
    exit 1
fi

echo "Menjadikan aplikasi Node.js berjalan otomatis dengan PM2..."
sudo pm2 save
sudo pm2 startup

if [ $? -ne 0 ]; then
    echo "Gagal mengatur PM2 untuk berjalan otomatis."
    exit 1
fi

echo "Menulis file service di $SERVICE_PATH..."
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

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Mengaktifkan dan memulai service MTProxy..."
sudo systemctl enable MTProxy
sudo systemctl start MTProxy

echo "Setup selesai. MTProxy telah berjalan."
echo "Node.js Management API telah dijalankan menggunakan PM2 dengan watch mode."
echo "Periksa status dengan: sudo pm2 list dan sudo systemctl status MTProxy"

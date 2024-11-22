require('dotenv').config();
const express = require('express');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

// Port dari .env atau default ke 3000
const PORT = process.env.PORT || 3000;

// Path ke file proxy-secret.txt
const PROXY_SECRET_FILE = '/opt/MTProxy/proxy-secret.txt';

// Fungsi untuk membaca whitelist dari file
const getIPWhitelist = () => {
    try {
        const data = fs.readFileSync('./whitelist.txt', 'utf8');
        return data.split('\n').map(ip => ip.trim()).filter(ip => ip); // Bersihkan IP kosong
    } catch (error) {
        console.error('Gagal membaca whitelist.txt:', error);
        return [];
    }
};

// Middleware IP Whitelist
const checkIPWhitelist = (req, res, next) => {
    const ipWhitelist = getIPWhitelist();
    const clientIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress.replace('::ffff:', '');

    if (ipWhitelist.includes(clientIP)) {
        next();
    } else {
        res.status(403).json({
            success: false,
            message: 'Forbidden: Your IP is not allowed.',
        });
    }
};

// Gunakan middleware IP Whitelist di semua rute
app.use(checkIPWhitelist);

// Rute untuk memulai MTProxy
app.post('/start', (req, res) => {
    exec('systemctl start MTProxy', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ success: false, message: stderr.trim() });
        }
        res.json({ success: true, message: 'MTProxy started successfully', output: stdout.trim() });
    });
});

// Rute untuk menghentikan MTProxy
app.post('/stop', (req, res) => {
    exec('systemctl stop MTProxy', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ success: false, message: stderr.trim() });
        }
        res.json({ success: true, message: 'MTProxy stopped successfully', output: stdout.trim() });
    });
});

// Rute untuk Reboot VPS
app.post('/reboot', (req, res) => {
    exec('reboot', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ success: false, message: stderr.trim() });
        }
        res.json({ success: true, message: 'Server Reboot Success', output: stdout.trim() });
    });
});

// Rute untuk mengecek status MTProxy
app.get('/status', (req, res) => {
    exec('systemctl is-active MTProxy', (error, stdout) => {
        if (error) {
            return res.status(500).json({
                success: false,
                message: 'Service is not running',
                details: error.message,
            });
        }

        if (stdout.trim() === 'active') {
            res.json({
                success: true,
                message: 'Service is running',
                details: stdout.trim(),
            });
        } else {
            res.json({
                success: false,
                message: 'Service is not running',
                details: stdout.trim(),
            });
        }
    });
});

// Rute untuk mendapatkan secret dari proxy-secret.txt
app.get('/secret', (req, res) => {
    fs.readFile(PROXY_SECRET_FILE, 'utf8', (err, data) => {
        if (err) {
            console.error('Gagal membaca file proxy-secret.txt:', err);
            return res.status(500).json({
                success: false,
                message: 'Gagal membaca file secret.',
            });
        }
        const secrets = data.trim().split('\n'); // Pisahkan setiap secret
        res.json({
            success: true,
            message: 'Secret retrieved successfully.',
            secrets,
        });
    });
});

// Jalankan server
app.listen(PORT, () => {
    console.log(`MTProxy API server running on port ${PORT}`);
});


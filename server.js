const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;
const DATA_FILE = path.join(__dirname, 'data.json');
const ADMIN_CODE = 'taroyuan112510';

// Middleware
app.use(express.json());
app.use(express.static(__dirname));

// Helper: read visitor data
function readData() {
  try {
    if (!fs.existsSync(DATA_FILE)) {
      fs.writeFileSync(DATA_FILE, JSON.stringify({ count: 0, visits: [] }, null, 2));
    }
    const raw = fs.readFileSync(DATA_FILE, 'utf-8');
    return JSON.parse(raw);
  } catch (e) {
    return { count: 0, visits: [] };
  }
}

// Helper: write visitor data
function writeData(data) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
}

// Record a visitor
app.post('/api/visit', (req, res) => {
  const data = readData();
  data.count += 1;
  data.visits.push({
    ip: req.ip,
    userAgent: req.get('User-Agent') || 'unknown',
    time: new Date().toISOString()
  });
  // Keep only last 1000 visits
  if (data.visits.length > 1000) {
    data.visits = data.visits.slice(-1000);
  }
  writeData(data);
  res.json({ totalVisitors: data.count });
});

// Admin authentication
app.post('/api/admin', (req, res) => {
  const { code } = req.body;
  if (code === ADMIN_CODE) {
    const data = readData();
    res.json({
      authorized: true,
      totalVisitors: data.count,
      recentVisits: data.visits.slice(-20).reverse()
    });
  } else {
    res.json({ authorized: false });
  }
});

// Get visitor count (public)
app.get('/api/count', (req, res) => {
  const data = readData();
  res.json({ totalVisitors: data.count });
});

app.listen(PORT, () => {
  console.log(`🔮 Tarot Website running at http://localhost:${PORT}`);
  console.log(`✨ Open your browser and let the magic begin...`);
});

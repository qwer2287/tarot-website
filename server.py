"""
🔮 Tarot Website Server (Python)
Run: python server.py
Then open http://localhost:3000 (or http://<your-ip>:3000 from other devices)
"""
import json
import os
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse

DATA_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data.json')
ADMIN_CODE = 'taroyuan112510'
PORT = 3000


def read_data():
    try:
        if not os.path.exists(DATA_FILE):
            with open(DATA_FILE, 'w', encoding='utf-8') as f:
                json.dump({'count': 0, 'visits': []}, f)
        with open(DATA_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {'count': 0, 'visits': []}


def write_data(data):
    with open(DATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


class TarotHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        self.directory = os.path.dirname(os.path.abspath(__file__))
        super().__init__(*args, directory=self.directory, **kwargs)

    def log_message(self, format, *args):
        print(f"[{time.strftime('%H:%M:%S')}] {args[0]}")

    def do_POST(self):
        parsed = urlparse(self.path)
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length > 0 else b'{}'

        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            data = {}

        if parsed.path == '/api/visit':
            db = read_data()
            db['count'] += 1
            db['visits'].append({
                'ip': self.client_address[0],
                'userAgent': self.headers.get('User-Agent', 'unknown'),
                'time': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
            })
            if len(db['visits']) > 1000:
                db['visits'] = db['visits'][-1000:]
            write_data(db)
            self._send_json({'totalVisitors': db['count']})

        elif parsed.path == '/api/admin':
            if data.get('code') == ADMIN_CODE:
                db = read_data()
                self._send_json({
                    'authorized': True,
                    'totalVisitors': db['count'],
                    'recentVisits': list(reversed(db['visits'][-20:]))
                })
            else:
                self._send_json({'authorized': False})

        else:
            self._send_json({'error': 'Not found'}, 404)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/api/count':
            db = read_data()
            self._send_json({'totalVisitors': db['count']})
        else:
            super().do_GET()

    def _send_json(self, data, code=200):
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()


if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', PORT), TarotHandler)
    print(f'🔮 Tarot Website running at http://localhost:{PORT}')
    print(f'✨ Other devices on the same network can access via:')
    import socket
    hostname = socket.gethostname()
    try:
        local_ip = socket.gethostbyname(hostname)
        print(f'   http://{local_ip}:{PORT}')
    except Exception:
        pass
    print(f'📋 Admin code: {ADMIN_CODE}')
    print(f'Press Ctrl+C to stop the server.\n')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n✨ Server stopped. May the stars guide your path.')
        server.server_close()

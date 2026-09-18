#!/usr/bin/env python3
"""
Study Vault APK Local Server & QR Code Generator
Serves the built APK on the local network and displays a QR code for mobile download.
"""

import os
import sys
import socket
import qrcode
from http.server import HTTPServer, SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn

PORT = 8088
DEFAULT_APK_PATHS = [
    os.path.abspath("build/app/outputs/flutter-apk/app-release.apk"),
    os.path.abspath("build/app/outputs/flutter-apk/app-debug.apk"),
]

def get_lan_ip():
    """Detects primary LAN IP address."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Doesn't actually send packets
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def find_apk():
    """Finds the most recent APK file."""
    for path in DEFAULT_APK_PATHS:
        if os.path.isfile(path):
            return path
    
    # Search recursively in build/ if not in standard locations
    if os.path.isdir("build"):
        for root, _, files in os.walk("build"):
            for f in files:
                if f.endswith(".apk"):
                    return os.path.abspath(os.path.join(root, f))
    return None

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

class ApkDownloadHandler(SimpleHTTPRequestHandler):
    apk_path = None
    apk_filename = "study_vault.apk"
    qr_image_bytes = None
    lan_url = ""

    def log_message(self, format, *args):
        # Clean logging
        print(f"[{self.log_date_time_string()}] {self.address_string()} - {format % args}")

    def do_HEAD(self):
        if self.path in ['/', '/index.html']:
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
        elif self.path in ['/download', '/study_vault.apk', '/app-debug.apk', '/app-release.apk']:
            if self.apk_path and os.path.exists(self.apk_path):
                self.send_response(200)
                self.send_header("Content-Type", "application/vnd.android.package-archive")
                self.send_header("Content-Disposition", f'attachment; filename="{self.apk_filename}"')
                self.send_header("Content-Length", str(os.path.getsize(self.apk_path)))
                self.end_headers()
            else:
                self.send_error(404, "Not Found")
        elif self.path == '/qr.png':
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            if self.qr_image_bytes:
                self.send_header("Content-Length", str(len(self.qr_image_bytes)))
            self.end_headers()
        else:
            self.send_error(404, "Not Found")

    def do_GET(self):
        if self.path in ['/', '/index.html']:
            self.serve_landing_page()
        elif self.path in ['/download', '/study_vault.apk', '/app-debug.apk', '/app-release.apk']:
            self.serve_apk()
        elif self.path == '/qr.png':
            self.serve_qr_image()
        else:
            self.send_error(404, "Not Found")

    def serve_qr_image(self):
        if not self.qr_image_bytes:
            self.send_error(404, "QR not available")
            return
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(self.qr_image_bytes)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(self.qr_image_bytes)

    def serve_apk(self):
        if not self.apk_path or not os.path.exists(self.apk_path):
            self.send_error(404, "APK file not found on server")
            return
        
        file_size = os.path.getsize(self.apk_path)
        self.send_response(200)
        self.send_header("Content-Type", "application/vnd.android.package-archive")
        self.send_header("Content-Disposition", f'attachment; filename="{self.apk_filename}"')
        self.send_header("Content-Length", str(file_size))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        with open(self.apk_path, "rb") as f:
            while chunk := f.read(1024 * 256): # 256KB buffer
                self.wfile.write(chunk)

    def serve_landing_page(self):
        size_str = "Unknown size"
        if self.apk_path and os.path.exists(self.apk_path):
            size_mb = os.path.getsize(self.apk_path) / (1024 * 1024)
            size_str = f"{size_mb:.1f} MB"

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Study Vault v1.0.0 — Download APK</title>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background: #0f172a;
            color: #f8fafc;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            padding: 24px;
        }}
        .card {{
            background: #1e293b;
            border: 1px solid #334155;
            border-radius: 20px;
            max-width: 440px;
            width: 100%;
            padding: 32px;
            text-align: center;
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5);
        }}
        .logo-box {{
            width: 72px;
            height: 72px;
            margin: 0 auto 16px;
            background: linear-gradient(135deg, #6366f1, #3b82f6);
            border-radius: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 10px 15px -3px rgba(99, 102, 241, 0.4);
        }}
        .logo-box svg {{
            width: 40px;
            height: 40px;
            fill: white;
        }}
        h1 {{
            font-size: 24px;
            font-weight: 700;
            letter-spacing: -0.5px;
            margin-bottom: 6px;
            color: #ffffff;
        }}
        .badge {{
            display: inline-block;
            background: rgba(99, 102, 241, 0.2);
            color: #a5b4fc;
            padding: 4px 12px;
            border-radius: 9999px;
            font-size: 12px;
            font-weight: 600;
            margin-bottom: 20px;
        }}
        .qr-wrapper {{
            background: #ffffff;
            padding: 16px;
            border-radius: 16px;
            display: inline-block;
            margin-bottom: 20px;
            box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);
        }}
        .qr-wrapper img {{
            display: block;
            width: 180px;
            height: 180px;
        }}
        .download-btn {{
            display: block;
            width: 100%;
            background: #6366f1;
            color: #ffffff;
            text-decoration: none;
            padding: 16px 20px;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 600;
            transition: all 0.2s;
            box-shadow: 0 10px 15px -3px rgba(99, 102, 241, 0.4);
            margin-bottom: 12px;
        }}
        .download-btn:hover {{
            background: #4f46e5;
            transform: translateY(-1px);
        }}
        .info {{
            font-size: 13px;
            color: #94a3b8;
            margin-top: 16px;
            line-height: 1.5;
        }}
        .tip {{
            background: rgba(234, 179, 8, 0.1);
            border: 1px solid rgba(234, 179, 8, 0.2);
            border-radius: 10px;
            padding: 10px 14px;
            font-size: 12px;
            color: #fef08a;
            margin-top: 18px;
            text-align: left;
        }}
    </style>
</head>
<body>
    <div class="card">
        <div class="logo-box">
            <svg viewBox="0 0 24 24">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
            </svg>
        </div>
        <h1>Study Vault</h1>
        <div class="badge">v1.0.0 • {size_str}</div>
        
        <div class="qr-wrapper">
            <img src="/qr.png" alt="Scan QR Code to Download">
        </div>

        <a href="/study_vault.apk" class="download-btn">
            📥 Download APK ({size_str})
        </a>

        <div class="info">
            File: <code>study_vault.apk</code><br>
            Direct LAN link: <code>{self.lan_url}</code>
        </div>

        <div class="tip">
            💡 <strong>Android Tip:</strong> If prompted with <em>"File might be harmful"</em>, tap <strong>"Download anyway"</strong> and allow installation from this source in settings.
        </div>
    </div>
</body>
</html>"""
        encoded = html.encode('utf-8')
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

def main():
    apk_file = find_apk()
    if not apk_file:
        print("❌ Error: No APK file found in build/app/outputs/flutter-apk/.")
        print("Please build the APK first with:")
        print("  flutter build apk --debug")
        sys.exit(1)

    # Allow custom host and port via CLI: python3 serve_apk.py [host] [port] or python3 serve_apk.py [port]
    port = PORT
    host = None
    if len(sys.argv) == 2:
        if sys.argv[1].isdigit():
            port = int(sys.argv[1])
        else:
            host = sys.argv[1]
    elif len(sys.argv) >= 3:
        host = sys.argv[1]
        port = int(sys.argv[2])

    if not host:
        host = get_lan_ip()

    url = f"http://{host}:{port}"
    apk_url = f"http://{host}:{port}/study_vault.apk"

    print("=" * 60)
    print("🚀 STUDY VAULT APK DOWNLOAD SERVER")
    print("=" * 60)
    print(f"📦 APK File Found: {apk_file}")
    file_size_mb = os.path.getsize(apk_file) / (1024 * 1024)
    print(f"📊 Size: {file_size_mb:.2f} MB")
    print(f"🌐 Localhost URL: http://localhost:{PORT}")
    print(f"📱 LAN Download URL: {url}")
    print(f"📥 Direct APK Link:  {apk_url}")
    print("=" * 60)
    print("\n📲 SCAN THIS QR CODE WITH YOUR PHONE'S CAMERA / SCANNER:\n")

    # Generate QR Code
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=2,
    )
    qr.add_data(url)
    qr.make(fit=True)

    # Print terminal ASCII QR
    qr.print_ascii(invert=True)

    # Generate PNG bytes for browser display
    import io
    img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    qr_bytes = buf.getvalue()

    ApkDownloadHandler.apk_path = apk_file
    ApkDownloadHandler.apk_filename = "study_vault.apk"
    ApkDownloadHandler.qr_image_bytes = qr_bytes
    ApkDownloadHandler.lan_url = url

    server = ThreadedHTTPServer(('0.0.0.0', port), ApkDownloadHandler)
    print(f"\n✅ Server running on http://0.0.0.0:{port}")
    print("Press Ctrl+C to stop.")
    print("=" * 60)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server.")
        server.server_close()

if __name__ == '__main__':
    main()

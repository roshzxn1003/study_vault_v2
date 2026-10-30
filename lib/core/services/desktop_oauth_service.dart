import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Ephemeral localhost HTTP server for capturing OAuth redirects on Linux, macOS, and Windows.
class DesktopOAuthService {
  static final DesktopOAuthService instance = DesktopOAuthService._();
  DesktopOAuthService._();

  HttpServer? _server;
  static const int defaultPort = 54321;
  static const String callbackPath = '/auth-callback';

  int _activePort = defaultPort;
  int get port => _activePort;

  String get redirectUrl => 'http://localhost:$_activePort$callbackPath';

  /// Starts an ephemeral local HTTP server and waits for the browser redirect.
  Future<String?> listenForAuthCode({
    Duration timeout = const Duration(minutes: 3),
  }) async {
    await stop();

    try {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, defaultPort);
        _activePort = defaultPort;
      } catch (bindErr) {
        // Fallback to ephemeral port if 54321 is bound
        debugPrint('[DesktopOAuthService] Port $defaultPort busy, binding to any free loopback port: $bindErr');
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        _activePort = _server!.port;
      }

      debugPrint('[DesktopOAuthService] Listening on $redirectUrl');
      final completer = Completer<String?>();

      _server!.listen((HttpRequest request) async {
        final path = request.uri.path;

        if (path == callbackPath || path == '/login-callback' || path == '/token') {
          // Check for query parameters (PKCE code or error)
          final code = request.uri.queryParameters['code'] ??
              request.uri.queryParameters['access_token'];
          final error = request.uri.queryParameters['error_description'] ??
              request.uri.queryParameters['error'];

          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(_buildResponseHtml(isSuccess: error == null));
          await request.response.close();

          if (!completer.isCompleted) {
            if (code != null) {
              completer.complete(code);
            } else if (error != null) {
              completer.completeError(Exception(error));
            }
          }

          // Give browser a moment to receive response, then stop
          Future.delayed(const Duration(milliseconds: 750), () => stop());
        } else {
          request.response
            ..statusCode = 404
            ..write('Not found');
          await request.response.close();
        }
      });

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('[DesktopOAuthService] OAuth listener timed out after $timeout');
          stop();
          return null;
        },
      );
    } catch (e) {
      debugPrint('[DesktopOAuthService] Server error: $e');
      await stop();
      return null;
    }
  }

  Future<void> stop() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
  }

  String _buildResponseHtml({required bool isSuccess}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Study Vault Authentication</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: #0B0F19;
      color: #E2E8F0;
    }
    .card {
      background: #151D2F;
      border: 1px solid #1E293B;
      border-radius: 16px;
      padding: 36px 40px;
      text-align: center;
      max-width: 440px;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);
    }
    .badge {
      display: inline-block;
      width: 56px;
      height: 56px;
      line-height: 56px;
      border-radius: 28px;
      font-size: 28px;
      margin-bottom: 20px;
      background: ${isSuccess ? '#065F46' : '#991B1B'};
      color: ${isSuccess ? '#34D399' : '#F87171'};
    }
    h1 {
      font-size: 20px;
      margin: 0 0 10px 0;
      color: #F8FAFC;
    }
    p {
      color: #94A3B8;
      font-size: 14px;
      line-height: 1.5;
      margin: 0;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">${isSuccess ? '✓' : '✗'}</div>
    <h1>${isSuccess ? 'Authentication Successful' : 'Sign-In Incomplete'}</h1>
    <p>${isSuccess ? 'You are authenticated. You may close this browser tab and return to Study Vault.' : 'We could not complete your sign in. Please return to Study Vault and try again.'}</p>
  </div>
  <script>
    // Handle hash fragments if present
    if (window.location.hash && window.location.hash.length > 1) {
      const fragment = window.location.hash.substring(1);
      fetch('/token?' + fragment);
    }
  </script>
</body>
</html>
''';
  }
}

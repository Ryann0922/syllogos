import 'dart:convert';
import 'dart:io';

class WebDavService {
  /// Upload `file` to `url` (full URL including filename) using HTTP PUT with Basic auth if provided.
  /// Returns true on success (status code 2xx).
  static Future<bool> uploadFile(String url, {String? username, String? password, File? file}) async {
    if (file == null || !await file.exists()) return false;
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final req = await client.putUrl(uri);
      if (username != null && username.isNotEmpty) {
        final auth = base64.encode(utf8.encode('$username:${password ?? ''}'));
        req.headers.set(HttpHeaders.authorizationHeader, 'Basic $auth');
      }
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
      req.add(await file.readAsBytes());
      final resp = await req.close();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class WebDavService {
  /// Upload `file` to `url` (full URL including filename) using HTTP PUT with Basic auth if provided.
  /// Returns true on success (status code 2xx).
  static Future<bool> uploadFile(String url,
      {String? username, String? password, File? file}) async {
    if (file == null || !await file.exists()) return false;
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final req = await client.putUrl(uri);
      _addAuth(req, username, password);
      req.headers
          .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
      req.add(await file.readAsBytes());
      final resp = await req.close();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  /// 列出远程路径下的 ZIP 文件
  static Future<List<String>> listFiles(String url,
      {String? username, String? password}) async {
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final req = await client.openUrl('PROPFIND', uri);
      _addAuth(req, username, password);
      req.headers.set('Depth', '1');
      req.headers.contentType = ContentType('application', 'xml', charset: 'utf-8');
      req.write(
          '<?xml version="1.0" encoding="utf-8"?><propfind xmlns="DAV:"><propname/></propfind>');

      final resp = await req.close();
      if (resp.statusCode != 207) return [];

      final body = await resp.transform(utf8.decoder).join();

      // 解析 href 标签（兼容带命名空间和不带命名空间）
      final RegExp hrefReg = RegExp(r'<[^>]*href[^>]*>(.*?)</[^>]*href>',
          caseSensitive: false);
      final matches = hrefReg.allMatches(body);

      final files = <String>[];
      for (final m in matches) {
        var href = m.group(2)?.trim() ?? '';
        href = Uri.decodeComponent(href);
        if (href.endsWith('.zip')) {
          files.add(href);
        }
      }
      return files;
    } catch (e) {
      return [];
    } finally {
      client.close(force: true);
    }
  }

  /// 下载远程文件到临时目录，返回 File
  static Future<File?> downloadFile(String url,
      {String? username, String? password}) async {
    final uri = Uri.parse(url);
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      _addAuth(req, username, password);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;

      final bytes = <int>[];
      await for (final chunk in resp) {
        bytes.addAll(chunk);
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/webdav_import.zip';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static void _addAuth(HttpClientRequest req, String? username,
      String? password) {
    if (username != null && username.isNotEmpty) {
      final auth = base64.encode(utf8.encode('$username:${password ?? ''}'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Basic $auth');
    }
  }
}

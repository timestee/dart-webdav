import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:retry/retry.dart';
import 'file.dart';

class WebDavException implements Exception {
  String cause;
  WebDavException(this.cause);
}

class Client {
  String host;
  int port;
  String username;
  String password;
  String protocol = 'http';
  bool verifySsl = true;
  String path;
  String baseUrl;
  String cwd = "/";
  HttpClient httpClient = new HttpClient();

  Client(String host, String username, String password, String path,
      {String protocol, int port}) {
    if (port == null) {
      this.baseUrl = "$protocol://$host";
    } else {
      this.baseUrl = "$protocol://$host:$port";
    }

    if (!this.baseUrl.endsWith("/")) {
      this.baseUrl += "/";
    }
    this.path = path;
    if (this.path.isNotEmpty) {
      this.baseUrl = this.baseUrl + this.path;
    }
    this.httpClient.addCredentials(Uri.parse(this.baseUrl), "",
        HttpClientBasicCredentials(username, password));
  }

  String getUrl(String path) {
    path = path.trim();
    if (path.startsWith('/')) {
      return this.baseUrl + path;
    }
    return [this.baseUrl, this.cwd, path].join('');
  }

  void cd(String path) {
    path = path.trim();
    if (path.isEmpty) {
      return;
    }
    List tmp = path.split("/");
    tmp.removeWhere((value) => value == null || value == '');
    String strippedPath = tmp.join('/') + '/';
    if (strippedPath == '/') {
      this.cwd = strippedPath;
    } else if (path.startsWith("/")) {
      this.cwd = '/' + strippedPath;
    } else {
      this.cwd += strippedPath;
    }
  }

  Future<HttpClientResponse> _send(
      String method, String path, List<int> expectedCodes,
      {Uint8List data, Map headers}) async {
    return await retry(
            () => this
            .__send(method, path, expectedCodes, data: data, headers: headers),
        retryIf: (e) => e is WebDavException,
        maxAttempts: 5);
  }

  Future<HttpClientResponse> __send(
      String method, String path, List<int> expectedCodes,
      {Uint8List data, Map headers}) async {
    String url = this.getUrl(path);
    print("[wevdav] http send with method:$method path:$path url:$url");

    HttpClientRequest request =
    await this.httpClient.openUrl(method, Uri.parse(url));
    request
      ..followRedirects = false
      ..persistentConnection = true;

    if (data != null) {
      request.add(data);
    }
    if (headers != null) {
      headers.forEach((k, v) => request.headers.add(k, v));
    }

    HttpClientResponse response = await request.close();
    if (!expectedCodes.contains(response.statusCode)) {
      throw WebDavException("operation failed method:$method "
          "path:$path exceptionCodes:$expectedCodes "
          "statusCode:${response.statusCode}");
    }
    return response;
  }

  Future<HttpClientResponse> mkdir(String path, [bool safe = true]) {
    List<int> expectedCodes = [201];
    if (safe) {
      expectedCodes.addAll([301, 405]);
    }
    return this._send('MKCOL', path, expectedCodes);
  }

  void mkdirs(String path) async {
    path = path.trim();
    List<String> dirs = path.split("/");
    dirs.removeWhere((value) => value == null || value == '');
    if (dirs.isEmpty) {
      return;
    }
    if (path.startsWith("/")) {
      dirs[0] = '/' + dirs[0];
    }
    String oldCwd = this.cwd;
    try {
      for (String dir in dirs) {
        HttpClientResponse response;
        try {
          response = await this.mkdir(dir, true);
        } catch (e) {
          if (response.statusCode == 409) {
            throw e;
          }
        } finally {
          this.cd(dir);
        }
      }
    } catch (e) {} finally {
      this.cd(oldCwd);
    }
  }

  void rmdir(String path, [bool safe = true]) async {
    path = path.trim();
    List<int> expectedCodes = [204];
    if (safe) {
      expectedCodes.addAll([204, 404]);
    }
    this._send('DELETE', path, expectedCodes);
  }

  void delete(String path) async {
    this._send('DELETE', path, [204]);
  }

  void _upload(Uint8List localData, String remotePath) async {
    this._send('PUT', remotePath, [200, 201, 204], data: localData);
  }

  void upload(Uint8List data, String remotePath) async {
    this._upload(data, remotePath);
  }

  void uploadFile(String path, String remotePath) async {
    this._upload(await File(path).readAsBytes(), remotePath);
  }

  void download(String remotePath, String localFilePath) async {
    HttpClientResponse response = await this._send('GET', remotePath, [200]);
    response.pipe(new File(localFilePath).openWrite());
  }

  Future<String> downloadToBinaryString(String remotePath) async {
    HttpClientResponse response = await this._send('GET', remotePath, [200]);
    return response.transform(utf8.decoder).join();
  }

  Future<List<FileInfo>> ls(String remotePath) async {
    Map userHeader = {"Depth": 1};
    HttpClientResponse response = await this
        ._send('PROPFIND', remotePath, [207, 301], headers: userHeader);
    if (response.statusCode == 301) {
      this.ls(response.headers.value('location'));
    }
    return treeFromWevDavXml(await response.transform(utf8.decoder).join());
  }
}

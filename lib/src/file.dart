import 'dart:convert';

import 'package:xml2json/xml2json.dart';

class FileInfo {
  String name;
  String size;
  String mtime;
  String ctime;
  String contentType;

  FileInfo(this.name, this.size, this.mtime, this.ctime, this.contentType);

  bool get isDict => this.contentType == 'httpd/unix-directory';
}

/// get filed [name] from the property node
String prop(dynamic prop, String name, [String defaultVal]) {
  if (prop is Map) {
    final val = prop['D:' + name];
    if (val == null) {
      return defaultVal;
    }
    return val;
  }
  return defaultVal;
}

/// get file info list from `ls` command response
List<FileInfo> treeFromWevDavXml(String xmlStr) {
  final Xml2Json myTransformer = Xml2Json();
  myTransformer.parse(xmlStr);
  final jsonResponse = json.decode(myTransformer.toParker());
  final responses = jsonResponse['D:multistatus']['D:response'];
  var tree = new List<FileInfo>();
  if (responses is List) {
    responses.forEach((response) {
      final elem = response['D:propstat']['D:prop'];
      FileInfo f = FileInfo(
          response['D:href'],
          prop(elem, 'getcontentlength'),
          prop(elem, 'getlastmodified'),
          prop(elem, 'creationdate'),
          prop(elem, 'getcontenttype'));
      tree.add(f);
    });
  }
  return tree;
}

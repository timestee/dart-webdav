import 'package:xml/xml.dart' as xml;

class FileInfo {
  String path;
  String size;
  String modificationTime;
  DateTime creationTime;
  String contentType;

  FileInfo(this.path, this.size, this.modificationTime, this.creationTime,
      this.contentType);

  // Returns the decoded name of the file / folder without the whole path
  String get name {
    if (this.isDirectory) {
      return Uri.decodeFull(this.path
          .substring(0, this.path.lastIndexOf("/"))
          .split("/")
          .last);
    }

    return Uri.decodeFull(this.path
        .split("/")
        .last);
  }

  bool get isDirectory => this.path.endsWith("/");

  @override
  String toString() {
    return 'FileInfo{name: $name, isDirectory: $isDirectory ,path: $path, size: $size, modificationTime: $modificationTime, creationTime: $creationTime, contentType: $contentType}';
  }
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

List<FileInfo> treeFromWevDavXml(String xmlStr) {
  // Initialize a list to store the FileInfo Objects
  var tree = new List<FileInfo>();

  // parse the xml using the xml.parse method
  var xmlDocument = xml.parse(xmlStr);

  // Iterate over the response to find all folders / files and parse the information
  xmlDocument.findAllElements("D:response").forEach((response) {
    var davItemName = response.findElements("D:href").single.text;
    response
        .findElements("D:propstat")
        .single
        .findElements("D:prop")
        .forEach((element) {
      var contentLength =
          element
              .findElements("D:getcontentlength")
              .single
              .text;

      var lastModified = element
          .findElements("D:getlastmodified")
          .single
          .text;

      var creationTime = element
          .findElements("D:creationdate")
          .single
          .text;

      // Add the just found file to the tree
      tree.add(new FileInfo(davItemName, contentLength, lastModified,
          DateTime.parse(creationTime), ""));
    });
  });

  // Return the tree
  return tree;
}

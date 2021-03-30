import "package:test/test.dart";
import 'package:webdav/webdav.dart' as webdav;

void main() {
  webdav.Client client = webdav.Client(
      "https://dav.jianguoyun.com/dav/", "username", "password", "tmp");

  test('ls command', () async {
    List<webdav.FileInfo> list = await client.ls();
    for (webdav.FileInfo item in list) {
      print(item.path);
      print(
          "     - ${item.contentType} | ${item.size},  | ${item.creationTime},  | ${item.modificationTime}");
    }
  });
  test('mkdir & mkdirs &cd & rmdir command', () async {
    await client.mkdir("test0");
    client.cd("test0");
    await client.mkdirs("test1/test2");
    await client.rmdir("/test0");
  });
}

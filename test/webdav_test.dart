import "package:test/test.dart";
import 'package:webdav/webdav.dart' as webdav;


void main() {
  webdav.Client client =  webdav.Client(
    "https://dav.jianguoyun.com/dav/",
    "wanghuidev@gmail.com",
    "a7arqs48rr7xcn4k",
    "tmp"
  );

  test('ls command', () async {
    List<webdav.FileInfo> list = await client.ls();
    for (webdav.FileInfo item in list) {
      print(item.path);
      print("     - ${item.contentType} | ${item.size},  | ${item.creationTime},  | ${item.modificationTime}");
    }
  });
  test('mkdirs command', () async {
    client.mkdirs("test0/test1/test2");
  });
}
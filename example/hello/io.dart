import 'dart:convert';
import 'dart:io';

final String jsonString = JSON.encode({'hello': 'world'});

main() async {
  var server = await HttpServer.bind(InternetAddress.LOOPBACK_IP_V4, 3000);
  print('Listening at http://${server.address.address}:${server.port}');

  await for (var request in server) {
    var r = request.response;
    r
      ..headers.contentType = ContentType.JSON
      ..write(jsonString);
    await r.close();
  }
}

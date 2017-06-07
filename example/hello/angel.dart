import 'dart:convert';
import 'dart:io';
import 'package:angel_framework/angel_framework.dart';

final String jsonString = JSON.encode({'hello': 'world'});

main() async {
  var app = new Angel();
  app.lazyParseBodies = true;
  app.injectSerializer(JSON.encode);

  app.responseFinalizers.add((req, ResponseContext res) async {
    res.write(jsonString);
  });

  var server = await app.startServer(InternetAddress.LOOPBACK_IP_V4, 3000);
  print('Listening at http://${server.address.address}:${server.port}');
}

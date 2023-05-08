import 'package:dart_proxy_server/dart_proxy_server.dart' as dart_proxy_server;
import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pedantic/pedantic.dart';
import 'package:args/args.dart';

const String LocalHost = 'localhost';
const int LocalPort = 3000;
const String TargetUrl = 'https://api.ones.cn/';

void main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addOption('target', abbr: 't', defaultsTo: TargetUrl)
    ..addOption('port', abbr: 'p', defaultsTo: LocalPort.toString());
  final argResults = argParser.parse(arguments);
  final String targetUrl = argResults['target'];
  final port = int.parse(argResults['port']);
  final server = await shelf_io.serve(
    // proxyHandler(TargetUrl),
    customProxyHandler(targetUrl),
    LocalHost,
    port,
  );
  configServer(server);
  print('$targetUrl 的本地代理地址是 http://${server.address.host}:${server.port}');
}

void configServer(HttpServer server) {
  // 这里设置请求策略，允许所有
  server.defaultResponseHeaders.add('Access-Control-Allow-Origin', '*');
  server.defaultResponseHeaders.add('Access-Control-Allow-Credentials', true);
  server.defaultResponseHeaders.add('Access-Control-Allow-Methods', '*');
  server.defaultResponseHeaders.add('Access-Control-Allow-Headers', '*');
  server.defaultResponseHeaders.add('Access-Control-Max-Age', '3600');
}

Handler customProxyHandler(
  url, {
  http.Client? client,
  String? proxyName,
}) {
  Uri uri;
  if (url is String) {
    uri = Uri.parse(url);
  } else if (url is Uri) {
    uri = url;
  } else {
    throw ArgumentError.value(url, 'url', 'url must be a String or Uri.');
  }
  client ??= http.Client();
  proxyName ??= 'shelf_proxy';

  return (serverRequest) async {
    // TODO(nweiz): Support WebSocket requests.

    // TODO(nweiz): Handle TRACE requests correctly. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.8
    var requestUrl = uri.resolve(serverRequest.url.toString());
    var clientRequest = http.StreamedRequest(serverRequest.method, requestUrl);
    clientRequest.followRedirects = false;
    clientRequest.headers.addAll(serverRequest.headers);
    clientRequest.headers['Host'] = uri.authority;
    clientRequest.headers['referer'] = url;
    // Add a Via header. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
    _addHeader(clientRequest.headers, 'via',
        '${serverRequest.protocolVersion} $proxyName');

    unawaited(store(serverRequest.read(), clientRequest.sink));
    var clientResponse = await client!.send(clientRequest);
    // Add a Via header. See
    // http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.45
    _addHeader(clientResponse.headers, 'via', '1.1 $proxyName');

    // Remove the transfer-encoding since the body has already been decoded by
    // [client].
    clientResponse.headers.remove('transfer-encoding');

    // If the original response was gzipped, it will be decoded by [client]
    // and we'll have no way of knowing its actual content-length.
    if (clientResponse.headers['content-encoding'] == 'gzip') {
      clientResponse.headers.remove('content-encoding');
      clientResponse.headers.remove('content-length');

      // Add a Warning header. See
      // http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.2
      _addHeader(
          clientResponse.headers, 'warning', '214 $proxyName "GZIP decoded"');
    }

    // Make sure the Location header is pointing to the proxy server rather
    // than the destination server, if possible.
    if (clientResponse.isRedirect &&
        clientResponse.headers.containsKey('location')) {
      var location =
          requestUrl.resolve(clientResponse.headers['location']!).toString();
      if (p.url.isWithin(uri.toString(), location)) {
        clientResponse.headers['location'] =
            '/' + p.url.relative(location, from: uri.toString());
      } else {
        clientResponse.headers['location'] = location;
      }
    }

    return Response(clientResponse.statusCode,
        body: clientResponse.stream, headers: clientResponse.headers);
  };
}

void _addHeader(Map<String, String>? headers, String name, String value) {
  if (headers == null) {
    return;
  }
  if (headers.containsKey(name)) {
    headers[name] = (headers[name])! + ', $value';
  } else {
    headers[name] = value;
  }
}

Future store(Stream stream, EventSink sink,
    {bool cancelOnError = true, bool closeSink = true}) {
  var completer = Completer();
  stream.listen(sink.add, onError: (e, StackTrace stackTrace) {
    sink.addError(e, stackTrace);
    if (cancelOnError) {
      completer.complete();
      if (closeSink) sink.close();
    }
  }, onDone: () {
    if (closeSink) sink.close();
    completer.complete();
  }, cancelOnError: cancelOnError);
  return completer.future;
}

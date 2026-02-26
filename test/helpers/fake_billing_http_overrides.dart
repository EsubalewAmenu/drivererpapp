import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FakeBillingHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient();
  }
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(method: method, url: url);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(method: 'POST', url: url);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.method, required this.url});

  final String method;
  @override
  final Uri url;

  final _headers = _FakeHttpHeaders();
  final _bodyBytes = <int>[];
  final _doneCompleter = Completer<HttpClientResponse>();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  HttpHeaders get headers => _headers;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  void write(Object? obj) {
    add(encoding.encode(obj?.toString() ?? ''));
  }

  @override
  void writeln([Object? obj = '']) {
    write('$obj\n');
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    add([charCode]);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  Future<HttpClientResponse> get done => _doneCompleter.future;

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<HttpClientResponse> close() async {
    final path = url.path;
    late final HttpClientResponse response;

    if (path.endsWith('/getModulePricing')) {
      response = _FakeHttpClientResponse.ok({
        'isFree': false,
        'dailyPrice': 0.49,
        'monthlyPrice': 0.99,
        'annualPrice': 9.99,
      });
    } else if (path.endsWith('/getEntitlementStatus')) {
      response = _FakeHttpClientResponse.ok({
        'status': 'none',
        'hasAccess': false,
        'autoRenewing': false,
      });
    } else if (path.endsWith('/getWorkspaceCredits')) {
      response = _FakeHttpClientResponse.ok({
        'balance': 500.0,
        'autoTopupEnabled': false,
        'autoTopupThreshold': 0.0,
        'autoTopupAmount': 0.0,
      });
    } else {
      response = _FakeHttpClientResponse.ok({'ok': true});
    }

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete(response);
    }

    return response;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(this._statusCode, this._body);

  factory _FakeHttpClientResponse.ok(Map<String, dynamic> jsonBody) {
    return _FakeHttpClientResponse(200, jsonEncode(jsonBody));
  }

  final int _statusCode;
  final String _body;

  List<int> get _bytes => utf8.encode(_body);

  @override
  int get statusCode => _statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  List<Cookie> get cookies => const [];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase => 'OK';

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) async {
    return this;
  }

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.first;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

import 'abort_controller.dart';
import 'exceptions.dart';
import 'http_client.dart';
import 'logger.dart';
import 'transport.dart';
import 'utils.dart';

class LongPollingTransport implements Transport {
  final HTTPClient _httpClient;
  final dynamic Function() _accessTokenFactory;
  final Logger _logger;
  final bool _logMessageContent;
  final bool _withCredentials;
  final AbortController _pollAbort;
  final Map<String, String> _headers;

  String _url;
  bool _running;
  Future<void> _receiving;
  Exception _closeError;

  @override
  void Function(dynamic data) onreceive;
  @override
  void Function(Exception error) onclose;

  // This is an internal type, not exported from 'index' so this is really just internal.
  bool get pollAborted => _pollAbort.aborted;

  LongPollingTransport(this._httpClient, this._accessTokenFactory, this._logger,
      this._logMessageContent, this._withCredentials, this._headers)
      : _pollAbort = AbortController(),
        _running = false,
        onreceive = null,
        onclose = null;

  @override
  Future<void> connectAsync(String url, TransferFormat transferFormat) async {
    Arg.isRequired(url, 'url');
    Arg.isRequired(transferFormat, 'transferFormat');

    _url = url;
    _logger.log(LogLevel.trace, '(LongPolling transport) Connecting.');

    final headers = <String, String>{};
    final userAgent = getUserAgentHeader();
    headers[userAgent.key] = userAgent.value;

    if (_headers != null) {
      for (var header in _headers.entries) {
        headers[header.key] = header.value;
      }
    }

    final pollOptions = HTTPRequest(
        abortSignal: _pollAbort.signal,
        headers: headers,
        timeout: 100000,
        withCredentials: _withCredentials);

    if (transferFormat == TransferFormat.binary) {
      pollOptions.responseType = 'arraybuffer';
    }

    final token = await _getAccessTokenAsync();
    _updateHeaderToken(pollOptions, token);

    // Make initial long polling request
    // Server uses first long polling request to finish initializing connection and it returns without data
    final pollUrl = '$url&_=${DateTime.now().microsecondsSinceEpoch}';
    _logger.log(LogLevel.trace, '(LongPolling transport) polling: $pollUrl.');
    final response = await _httpClient.getAsync(pollUrl, pollOptions);
    if (response.statusCode != 200) {
      _logger.log(LogLevel.error,
          '(LongPolling transport) Unexpected response code: ${response.statusCode}.');
      // Mark running as false so that the poll immediately ends and runs the close logic
      _closeError =
          HTTPException(response.statusText ?? '', response.statusCode);
      _running = false;
    } else {
      _running = true;
    }
    _receiving = _pollAsync(_url, pollOptions);
  }

  @override
  Future<void> sendAsync(data) {
    if (!_running) {
      final error = Exception('Cannot send until the transport is connected');
      return Future.error(error);
    }
    return sendMessageAsync(
        _logger,
        'LongPolling',
        _httpClient,
        _url,
        _accessTokenFactory,
        data,
        _logMessageContent,
        _withCredentials,
        _headers);
  }

  @override
  Future<void> stopAsync() async {
    _logger.log(LogLevel.trace, '(LongPolling transport) Stopping polling.');

    // Tell receiving loop to stop, abort any current request, and then wait for it to finish
    _running = false;
    _pollAbort.abort();

    try {
      await _receiving;

      // Send DELETE to clean up long polling on the server
      _logger.log(LogLevel.trace,
          '(LongPolling transport) sending DELETE request to $_url.');

      final headers = <String, String>{};
      final userAgent = getUserAgentHeader();
      headers[userAgent.key] = userAgent.value;

      if (_headers != null) {
        for (var header in _headers.entries) {
          headers[header.key] = header.value;
        }
      }

      final deleteOptions =
          HTTPRequest(headers: headers, withCredentials: _withCredentials);
      final token = await _getAccessTokenAsync();
      _updateHeaderToken(deleteOptions, token);
      await _httpClient.deleteAsync(_url, deleteOptions);

      _logger.log(
          LogLevel.trace, '(LongPolling transport) DELETE request sent.');
    } finally {
      _logger.log(LogLevel.trace, '(LongPolling transport) Stop finished.');

      // Raise close event here instead of in polling
      // It needs to happen after the DELETE request is sent
      _raiseOnClose();
    }
  }

  Future<String> _getAccessTokenAsync() async {
    return await _accessTokenFactory?.call();
  }

  void _updateHeaderToken(HTTPRequest request, String token) {
    request.headers ??= {};
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
      return;
    }
    if (request.headers['Authorization'] != null) {
      request.headers.remove('Authorization');
    }
  }

  Future<void> _pollAsync(String url, HTTPRequest pollOptions) async {
    try {
      while (_running) {
        // We have to get the access token on each poll, in case it changes
        final token = await _getAccessTokenAsync();
        _updateHeaderToken(pollOptions, token);

        try {
          final pollUrl = '$url&_=${DateTime.now().microsecondsSinceEpoch}';
          _logger.log(
              LogLevel.trace, '(LongPolling transport) polling: $pollUrl.');
          final response = await _httpClient.getAsync(pollUrl, pollOptions);
          if (response.statusCode == 204) {
            _logger.log(LogLevel.information,
                '(LongPolling transport) Poll terminated by server.');
            _running = false;
          } else if (response.statusCode != 200) {
            _logger.log(LogLevel.error,
                '(LongPolling transport) Unexpected response code: ${response.statusCode}.');
            // Unexpected status code
            _closeError =
                HTTPException(response.statusText ?? '', response.statusCode);
            _running = false;
          } else {
            // Process the response
            if (response.content != null) {
              _logger.log(LogLevel.trace,
                  '(LongPolling transport) data received. ${getDataDetail(response.content, _logMessageContent)}.');
              onreceive?.call(response.content);
            } else {
              // This is another way timeout manifest.
              _logger.log(LogLevel.trace,
                  '(LongPolling transport) Poll timed out, reissuing.');
            }
          }
        } catch (e) {
          if (!_running) {
            // Log but disregard errors that occur after stopping
            _logger.log(LogLevel.trace,
                '(LongPolling transport) Poll errored after shutdown: ${e.message}');
          } else {
            if (e is TimeoutException) {
              // Ignore timeouts and reissue the poll.
              _logger.log(LogLevel.trace,
                  '(LongPolling transport) Poll timed out, reissuing.');
            } else {
              // Close the connection with the error as the result.
              _closeError = e;
              _running = false;
            }
          }
        }
      }
    } finally {
      _logger.log(LogLevel.trace, '(LongPolling transport) Polling complete.');

      // We will reach here with pollAborted==false when the server returned a response causing the transport to stop.
      // If pollAborted==true then client initiated the stop and the stop method will raise the close event after DELETE is sent.
      if (!pollAborted) {
        _raiseOnClose();
      }
    }
  }

  void _raiseOnClose() {
    if (onclose != null) {
      var logMessage = '(LongPolling transport) Firing onclose event.';
      if (_closeError != null) {
        logMessage += ' Error: $_closeError';
      }
      _logger.log(LogLevel.trace, logMessage);
      onclose(_closeError);
    }
  }
}

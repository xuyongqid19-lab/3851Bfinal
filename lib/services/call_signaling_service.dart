import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_config.dart';
import 'auth_service.dart';
import 'chat_service.dart';

class CallSignal {
  const CallSignal({
    required this.action,
    required this.from,
    this.fromName,
    this.fromPhoto,
    this.payload,
  });

  final String action;
  final String from;
  final String? fromName;
  final String? fromPhoto;
  final Map<String, dynamic>? payload;

  bool get isOffer => action == 'offer';
  bool get isAnswer => action == 'answer';
  bool get isIce => action == 'ice';
}

/// WebSocket signaling client for 1:1 WebRTC calls.
///
/// Connects to the chat API at `<chat base url>/ws?token=<jwt>` and keeps the
/// connection alive with automatic reconnect (unless closed on purpose, or
/// replaced by another session of the same user).
class CallSignalingService {
  CallSignalingService._();

  static final CallSignalingService instance = CallSignalingService._();

  static const List<Duration> _backoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  final StreamController<CallSignal> _signals =
      StreamController<CallSignal>.broadcast();
  final StreamController<bool> _status = StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  String? _token;
  int _attempt = 0;
  bool _connected = false;
  bool _closedByUser = false;
  bool _replaced = false;

  Stream<CallSignal> get signals => _signals.stream;
  Stream<bool> get status => _status.stream;
  bool get isConnected => _connected;

  Uri _socketUri(String token) {
    var base = portableApiUrl('chat') ?? ChatService.defaultBaseUrl;
    base = base.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return Uri.parse('$base/ws?token=${Uri.encodeComponent(token)}');
  }

  /// Connects (or waits for an in-progress connection) and reports whether the
  /// signaling socket is usable. Safe to call repeatedly.
  Future<bool> ensureConnected({Duration timeout = const Duration(seconds: 8)}) async {
    if (_connected) return true;
    if (_closedByUser || _replaced) return false;
    if (_channel == null) {
      final token = await AuthService.getAuthToken();
      if (token == null || token.isEmpty) return false;
      _token = token;
      unawaited(_connect());
    }
    final completer = Completer<bool>();
    late final StreamSubscription sub;
    sub = _status.stream.listen((ok) {
      if (!completer.isCompleted) completer.complete(ok);
    });
    try {
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _connect() async {
    final token = _token ?? await AuthService.getAuthToken();
    if (token == null || token.isEmpty) {
      _token = null;
      return;
    }
    _token = token;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    final channel = WebSocketChannel.connect(_socketUri(token));
    _channel = channel;
    try {
      await channel.ready.timeout(const Duration(seconds: 8));
    } catch (_) {
      _onClosed();
      return;
    }
    _connected = true;
    _attempt = 0;
    _status.add(true);
    _subscription = channel.stream.listen(
      _onData,
      onDone: _onClosed,
      onError: (_) => _onClosed(),
      cancelOnError: true,
    );
  }

  void _onData(dynamic data) {
    if (data is! String) return;
    Map<String, dynamic> decoded;
    try {
      decoded = Map<String, dynamic>.from(jsonDecode(data) as Map);
    } catch (_) {
      return;
    }
    if (decoded['type'] == 'replaced') {
      _replaced = true;
      _closedByUser = true; // stop reconnecting; another tab owns the session
      _onClosed();
      return;
    }
    if (decoded['type'] != 'call') return;
    final payload = decoded['payload'];
    _signals.add(CallSignal(
      action: decoded['action']?.toString() ?? '',
      from: decoded['from']?.toString() ?? '',
      fromName: decoded['fromName']?.toString(),
      fromPhoto: decoded['fromPhoto']?.toString(),
      payload: payload is Map<String, dynamic> ? payload : null,
    ));
  }

  void _onClosed() {
    final wasConnected = _connected;
    _connected = false;
    _channel = null;
    if (wasConnected) {
      _status.add(false);
    }
    if (_closedByUser || _replaced || _token == null || _token!.isEmpty) {
      return;
    }
    final delay = _backoff[_attempt.clamp(0, _backoff.length - 1)];
    _attempt += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connect);
  }

  void sendCall(String action, String to, [Map<String, dynamic>? payload]) {
    final channel = _channel;
    if (channel == null || !_connected) return;
    try {
      channel.sink.add(jsonEncode({
        'type': 'call',
        'action': action,
        'to': to,
        if (payload != null) 'payload': payload,
      }));
    } catch (_) {}
  }

  /// Called on logout: closes the socket and stops reconnecting.
  void reset() {
    _closedByUser = true;
    _replaced = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (_connected) {
      _connected = false;
      _status.add(false);
    }
    _attempt = 0;
  }

  /// Called on login / app start with a session: re-opens the socket.
  void wake() {
    _closedByUser = false;
    _replaced = false;
    _token = null;
    _attempt = 0;
  }

  @mustCallSuper
  void dispose() {
    reset();
    _signals.close();
    _status.close();
  }
}

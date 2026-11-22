import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../pages/call_page.dart';
import 'call_signaling_service.dart';
import 'group_call_manager.dart';

enum CallMediaType { audio, video }

enum CallStage { idle, outgoing, incoming, connecting, active, ended }

class CallPeer {
  const CallPeer({required this.id, required this.name, this.photoUrl});

  final String id;
  final String name;
  final String? photoUrl;
}

/// Owns the full lifecycle of 1:1 WebRTC voice/video calls:
/// signaling exchange, peer connection, media capture and the call screen.
class CallManager extends ChangeNotifier {
  CallManager._() {
    _signalingSubscription =
        CallSignalingService.instance.signals.listen(_onSignal);
  }

  static final CallManager instance = CallManager._();

  /// Root navigator key so the call screen can be raised from anywhere.
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'callNavigator');

  static const Duration _outgoingTimeout = Duration(seconds: 45);
  static const Duration _incomingTimeout = Duration(seconds: 60);

  StreamSubscription<CallSignal>? _signalingSubscription;

  CallStage _stage = CallStage.idle;
  CallMediaType _mediaType = CallMediaType.audio;
  CallPeer? _peer;
  String _statusText = '';
  int _durationSeconds = 0;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _pageOpen = false;
  bool _releasing = false;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  final List<RTCIceCandidate> _pendingIce = [];
  bool _remoteDescriptionSet = false;
  Map<String, dynamic>? _incomingOfferSdp;
  Timer? _callTimer;
  Timer? _ringTimer;
  Timer? _releaseTimer;
  Timer? _popTimer;

  CallStage get stage => _stage;
  CallMediaType get mediaType => _mediaType;
  CallPeer? get peer => _peer;
  String get statusText => _statusText;
  int get durationSeconds => _durationSeconds;
  bool get micEnabled => _micEnabled;
  bool get cameraEnabled => _cameraEnabled;
  bool get isBusy => _stage != CallStage.idle && _stage != CallStage.ended;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;
  bool get hasRemoteVideo =>
      _remoteRenderer?.srcObject != null &&
      _mediaType == CallMediaType.video;

  /// Idempotent; called on login/session restore.
  Future<void> ensureInitialized() async {
    CallSignalingService.instance.wake();
    await CallSignalingService.instance.ensureConnected();
  }

  /// Called on logout: drop the socket and any call without touching the UI
  /// tree (the whole app is being reset anyway).
  void reset() {
    _cancelTimers();
    _popTimer?.cancel();
    _popTimer = null;
    _popCallPage();
    CallSignalingService.instance.reset();
    _stage = CallStage.idle;
    _statusText = '';
    _durationSeconds = 0;
    unawaited(_releaseResources(immediate: true));
  }

  // ---------------------------------------------------------------------
  // Outgoing / incoming entry points
  // ---------------------------------------------------------------------

  Future<void> startCall({
    required String userId,
    required String name,
    String? photoUrl,
    required bool video,
  }) async {
    if (_stage != CallStage.idle && _stage != CallStage.ended) return;
    if (_releasing) {
      _showSnackBar('Previous call is still closing. Try again in a second.');
      return;
    }
    if (GroupCallManager.instance.isBusy) {
      _showSnackBar('You are already in a call.');
      return;
    }
    if (userId.isEmpty) return;

    final connected =
        await CallSignalingService.instance.ensureConnected();
    if (!connected) {
      _showSnackBar('Cannot reach the call service. Please try again.');
      return;
    }

    _peer = CallPeer(id: userId, name: name, photoUrl: photoUrl);
    _mediaType = video ? CallMediaType.video : CallMediaType.audio;
    _micEnabled = true;
    _cameraEnabled = true;
    _statusText = 'Calling…';

    try {
      await _preparePeerConnection();
      await _captureLocalMedia(video: video);
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      _send('offer', {
        'media': video ? 'video' : 'audio',
        'sdp': offer.toMap(),
      });
    } catch (_) {
      _endCallWith('Microphone or camera access was denied.');
      _pushCallPage();
      return;
    }

    _setStage(CallStage.outgoing);
    _pushCallPage();
    _ringTimer = Timer(_outgoingTimeout, () {
      if (_stage == CallStage.outgoing) {
        _send('cancel', null);
        _endCallWith('No answer');
      }
    });
  }

  void _handleIncomingOffer(CallSignal signal) {
    if (GroupCallManager.instance.isBusy) {
      _sendTo(signal.from, 'busy', null);
      return;
    }
    if (_stage != CallStage.idle && _stage != CallStage.ended) {
      _sendTo(signal.from, 'busy', null);
      return;
    }
    if (_releasing) {
      _sendTo(signal.from, 'busy', null);
      return;
    }
    final sdp = signal.payload?['sdp'];
    if (sdp is! Map) {
      _sendTo(signal.from, 'decline', null);
      return;
    }
    _incomingOfferSdp = Map<String, dynamic>.from(sdp);
    _peer = CallPeer(
      id: signal.from,
      name: signal.fromName ?? 'Unknown',
      photoUrl: signal.fromPhoto,
    );
    _mediaType = signal.payload?['media'] == 'video'
        ? CallMediaType.video
        : CallMediaType.audio;
    _micEnabled = true;
    _cameraEnabled = true;
    _durationSeconds = 0;
    _statusText = _mediaType == CallMediaType.video
        ? 'Incoming video call'
        : 'Incoming voice call';
    _setStage(CallStage.incoming);
    _pushCallPage();
    _ringTimer = Timer(_incomingTimeout, () {
      if (_stage == CallStage.incoming) {
        _sendTo(signal.from, 'decline', {'auto': true});
        _endCallWith('Missed call');
      }
    });
  }

  Future<void> acceptIncoming() async {
    if (_stage != CallStage.incoming) return;
    final offerSdp = _incomingOfferSdp;
    final peer = _peer;
    if (offerSdp == null || peer == null) return;
    _ringTimer?.cancel();
    _statusText = 'Connecting…';
    _setStage(CallStage.connecting);

    try {
      await _preparePeerConnection();
      await _captureLocalMedia(video: _mediaType == CallMediaType.video);
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          offerSdp['sdp']?.toString() ?? '',
          offerSdp['type']?.toString() ?? 'offer',
        ),
      );
      _remoteDescriptionSet = true;
      _flushPendingIce();
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      _send('answer', {'sdp': answer.toMap()});
    } catch (_) {
      _send('decline', null);
      _endCallWith('Microphone or camera access was denied.');
    }
  }

  void declineIncoming() {
    if (_stage != CallStage.incoming) return;
    _ringTimer?.cancel();
    _send('decline', null);
    _endCallWith('Declined');
  }

  void hangUp() {
    if (_stage == CallStage.idle || _stage == CallStage.ended) return;
    _send('end', null);
    _endCallWith(_durationSeconds > 0 ? 'Call ended' : 'Call ended');
  }

  // ---------------------------------------------------------------------
  // In-call controls
  // ---------------------------------------------------------------------

  void toggleMic() {
    final tracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    _micEnabled = !_micEnabled;
    for (final track in tracks) {
      track.enabled = _micEnabled;
    }
    notifyListeners();
  }

  void toggleCamera() {
    if (_mediaType != CallMediaType.video) return;
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    _cameraEnabled = !_cameraEnabled;
    for (final track in tracks) {
      track.enabled = _cameraEnabled;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Signaling reactions
  // ---------------------------------------------------------------------

  void _onSignal(CallSignal signal) {
    switch (signal.action) {
      case 'offer':
        _handleIncomingOffer(signal);
        break;
      case 'answer':
        _handleAnswer(signal);
        break;
      case 'ice':
        _handleRemoteIce(signal);
        break;
      case 'decline':
        if (signal.payload?['auto'] == true) {
          _endCallWith('No answer');
        } else {
          _endCallWith('Declined');
        }
        break;
      case 'cancel':
        _endCallWith('Call cancelled');
        break;
      case 'busy':
        _endCallWith('User is busy');
        break;
      case 'end':
        _endCallWith('Call ended');
        break;
      case 'offline':
        _handleOffline();
        break;
      case 'blocked':
        _endCallWith('Only friends can call each other');
        break;
    }
  }

  Future<void> _handleAnswer(CallSignal signal) async {
    if (_stage != CallStage.outgoing) return;
    final sdp = signal.payload?['sdp'];
    if (sdp is! Map) return;
    _ringTimer?.cancel();
    _statusText = 'Connecting…';
    _setStage(CallStage.connecting);
    try {
      await _pc?.setRemoteDescription(
        RTCSessionDescription(
          sdp['sdp']?.toString() ?? '',
          sdp['type']?.toString() ?? 'answer',
        ),
      );
      _remoteDescriptionSet = true;
      _flushPendingIce();
    } catch (_) {
      _endCallWith('Connection failed');
    }
  }

  Future<void> _handleRemoteIce(CallSignal signal) async {
    final candidate = signal.payload?['candidate'];
    if (candidate is! Map) return;
    final ice = RTCIceCandidate(
      candidate['candidate']?.toString() ?? '',
      candidate['sdpMid']?.toString(),
      candidate['sdpMLineIndex'] is int ? candidate['sdpMLineIndex'] as int : 0,
    );
    if (_remoteDescriptionSet) {
      try {
        await _pc?.addCandidate(ice);
      } catch (_) {}
    } else {
      _pendingIce.add(ice);
    }
  }

  void _handleOffline() {
    switch (_stage) {
      case CallStage.outgoing:
      case CallStage.connecting:
      case CallStage.active:
        _endCallWith('User is unavailable');
        break;
      case CallStage.incoming:
        _endCallWith('Missed call');
        break;
      default:
        break;
    }
  }

  // ---------------------------------------------------------------------
  // WebRTC plumbing
  // ---------------------------------------------------------------------

  Future<void> _preparePeerConnection() async {
    await _releaseResources(immediate: true);
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    _remoteDescriptionSet = false;
    _pendingIce.clear();
    await _ensureRenderers();

    pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      _send('ice', {
        'candidate': {
          'candidate': value,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
        },
      });
    };

    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remoteStream = event.streams.first;
      final remote = _remoteRenderer;
      if (remote != null) {
        remote.srcObject = _remoteStream;
      }
      if (_stage == CallStage.connecting) {
        _statusText = 'Connecting…';
        notifyListeners();
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (_stage == CallStage.connecting || _stage == CallStage.outgoing) {
          _statusText = 'Connected';
          _setStage(CallStage.active);
          _callTimer?.cancel();
          _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            _durationSeconds += 1;
            notifyListeners();
          });
        }
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        if (_stage != CallStage.ended && _stage != CallStage.idle) {
          _endCallWith('Connection failed');
        }
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        if (_stage == CallStage.active) {
          _endCallWith('Connection lost');
        }
      }
    };
  }

  Future<void> _captureLocalMedia({required bool video}) async {
    MediaStream? stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video
            ? {'width': 1280, 'height': 720, 'frameRate': 30}
            : false,
      });
    } catch (_) {
      if (video) {
        _cameraEnabled = false;
        try {
          stream = await navigator.mediaDevices
              .getUserMedia({'audio': true, 'video': false});
        } catch (_) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
    _localStream = stream;
    final local = _localRenderer;
    if (local != null) {
      local.srcObject = stream;
    }
    for (final track in stream.getTracks()) {
      _pc?.addTrack(track, stream);
    }
  }

  Future<void> _ensureRenderers() async {
    if (_localRenderer == null) {
      final local = RTCVideoRenderer();
      await local.initialize();
      local.srcObject = _localStream;
      _localRenderer = local;
    }
    if (_remoteRenderer == null) {
      final remote = RTCVideoRenderer();
      await remote.initialize();
      remote.srcObject = _remoteStream;
      _remoteRenderer = remote;
    }
  }

  void _flushPendingIce() {
    if (_pendingIce.isEmpty) return;
    final candidates = List<RTCIceCandidate>.from(_pendingIce);
    _pendingIce.clear();
    for (final candidate in candidates) {
      _pc?.addCandidate(candidate).catchError((_) {});
    }
  }

  // ---------------------------------------------------------------------
  // State transitions & cleanup
  // ---------------------------------------------------------------------

  void _setStage(CallStage stage) {
    _stage = stage;
    notifyListeners();
  }

  void _endCallWith(String status) {
    if (_stage == CallStage.ended || _stage == CallStage.idle) return;
    _cancelTimers();
    _statusText = status;
    _stage = CallStage.ended;
    _releasing = true;
    notifyListeners();
    _popTimer?.cancel();
    _popTimer = Timer(const Duration(milliseconds: 900), _popCallPage);
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: 1400), () async {
      await _releaseResources(immediate: false);
    });
  }

  Future<void> _releaseResources({required bool immediate}) async {
    if (!immediate && _stage != CallStage.ended && _stage != CallStage.idle) {
      return;
    }
    _callTimer?.cancel();
    _callTimer = null;
    _ringTimer?.cancel();
    _ringTimer = null;
    _releaseTimer?.cancel();
    _releaseTimer = null;

    final stream = _localStream;
    _localStream = null;
    _remoteStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
    }
    final pc = _pc;
    _pc = null;
    if (pc != null) {
      try {
        await pc.close();
      } catch (_) {}
    }
    if (immediate) {
      final local = _localRenderer;
      final remote = _remoteRenderer;
      _localRenderer = null;
      _remoteRenderer = null;
      if (local?.srcObject != null || remote?.srcObject != null) {
        try {
          local?.srcObject = null;
          remote?.srcObject = null;
        } catch (_) {}
      }
      if (local != null) {
        try {
          await local.dispose();
        } catch (_) {}
      }
      if (remote != null) {
        try {
          await remote.dispose();
        } catch (_) {}
      }
    }
    _remoteDescriptionSet = false;
    _pendingIce.clear();
    _incomingOfferSdp = null;
    if (immediate) {
      _durationSeconds = 0;
      _releasing = false;
      if (_stage == CallStage.ended) {
        _stage = CallStage.idle;
      }
      notifyListeners();
    } else {
      _releasing = false;
    }
  }

  void _cancelTimers() {
    _callTimer?.cancel();
    _callTimer = null;
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  // ---------------------------------------------------------------------
  // Call screen management
  // ---------------------------------------------------------------------

  void _pushCallPage() {
    if (_pageOpen) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    _pageOpen = true;
    unawaited(_ensureRenderers());
    navigator
        .push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const CallPage(),
      ),
    )
        .whenComplete(() {
      _pageOpen = false;
    });
  }

  void _popCallPage() {
    if (!_pageOpen) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    _pageOpen = false;
    navigator.pop();
  }

  void _send(String action, Map<String, dynamic>? payload) {
    final peer = _peer;
    if (peer == null) return;
    _sendTo(peer.id, action, payload);
  }

  void _sendTo(String to, String action, Map<String, dynamic>? payload) {
    CallSignalingService.instance.sendCall(action, to, payload);
  }

  void _showSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _cancelTimers();
    _popTimer?.cancel();
    _releaseTimer?.cancel();
    _signalingSubscription?.cancel();
    super.dispose();
  }
}

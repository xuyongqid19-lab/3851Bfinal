import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../pages/group_call_page.dart';
import 'auth_service.dart';
import 'call_manager.dart';
import 'call_signaling_service.dart';

enum GroupCallStage { idle, incoming, joining, active, ended }

class GroupCallParticipant {
  const GroupCallParticipant({
    required this.id,
    required this.name,
    this.photo,
  });

  final String id;
  final String name;
  final String? photo;
}

class MeshPeer {
  MeshPeer({required this.id, required this.pc, this.name, this.photo});

  final String id;
  final RTCPeerConnection pc;
  String? name;
  String? photo;
  RTCVideoRenderer? renderer;
  MediaStream? remoteStream;
  final List<RTCIceCandidate> pendingIce = [];
  bool remoteDescriptionSet = false;
}

/// Full-mesh WebRTC group calls: every participant holds one peer connection
/// per other participant. Joiners offer to everyone already in the room, so
/// no offer glare can occur.
class GroupCallManager extends ChangeNotifier {
  GroupCallManager._() {
    _signalingSubscription =
        CallSignalingService.instance.signals.listen(_onSignal);
  }

  static final GroupCallManager instance = GroupCallManager._();

  static const Duration _joinTimeout = Duration(seconds: 8);

  StreamSubscription<CallSignal>? _signalingSubscription;

  GroupCallStage _stage = GroupCallStage.idle;
  String? _groupId;
  String _groupName = '';
  CallMediaType _mediaType = CallMediaType.audio;
  GroupCallParticipant? _caller;
  String _statusText = '';
  int _durationSeconds = 0;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _pageOpen = false;
  bool _closing = false;

  MediaStream? _localStream;
  RTCVideoRenderer? _localRenderer;
  final Map<String, MeshPeer> _peers = {};
  final Map<String, GroupCallParticipant> _participants = {};

  Timer? _callTimer;
  Timer? _joinTimer;
  Timer? _popTimer;

  GroupCallStage get stage => _stage;
  String? get groupId => _groupId;
  String get groupName => _groupName;
  CallMediaType get mediaType => _mediaType;
  GroupCallParticipant? get caller => _caller;
  String get statusText => _statusText;
  int get durationSeconds => _durationSeconds;
  bool get micEnabled => _micEnabled;
  bool get cameraEnabled => _cameraEnabled;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  bool get isBusy =>
      _stage != GroupCallStage.idle && _stage != GroupCallStage.ended;

  List<GroupCallParticipant> get participants =>
      _participants.values.toList(growable: false);

  List<MeshPeer> get peers => _peers.values.toList(growable: false);

  MeshPeer? peerOf(String userId) => _peers[userId];

  bool amIInThisGroupCall(String groupId) =>
      _groupId == groupId &&
      (_stage == GroupCallStage.active || _stage == GroupCallStage.joining);

  String? _myUserId;
  String? get myUserId => _myUserId;
  GroupCallParticipant? get meAsParticipant => _participants[_myUserId];

  Future<void> _ensureMyUserId() async {
    if (_myUserId != null) return;
    try {
      final user = await AuthService.getCurrentUser();
      _myUserId = user?['id']?.toString();
    } catch (_) {}
  }

  Future<void> ensureInitialized() async {
    await _ensureMyUserId();
  }

  void reset() {
    _joinTimer?.cancel();
    _joinTimer = null;
    _popTimer?.cancel();
    _popTimer = null;
    _popCallPage();
    _cleanup(silent: true);
    _stage = GroupCallStage.idle;
    notifyListeners();
  }

  Future<void> startGroupCall({
    required String groupId,
    required String groupName,
    required bool video,
  }) async {
    if (isBusy || _closing) {
      _showSnackBar('You are already in a call.');
      return;
    }
    if (CallManager.instance.isBusy) {
      _showSnackBar('You are already in a call.');
      return;
    }
    final connected = await CallSignalingService.instance.ensureConnected();
    if (!connected) {
      _showSnackBar('Cannot reach the call service. Please try again.');
      return;
    }
    await _ensureMyUserId();
    _groupId = groupId;
    _groupName = groupName;
    _mediaType = video ? CallMediaType.video : CallMediaType.audio;
    _micEnabled = true;
    _cameraEnabled = true;
    _durationSeconds = 0;
    _statusText = 'Starting…';
    _stage = GroupCallStage.joining;
    notifyListeners();
    _send('group-start', groupId, {'media': video ? 'video' : 'audio'});
    _joinTimer = Timer(_joinTimeout, () {
      if (_stage == GroupCallStage.joining) {
        _failJoin('The group call could not be started.');
      }
    });
  }

  Future<void> joinGroupCall({
    required String groupId,
    required String groupName,
    required bool video,
  }) async {
    if (isBusy && _groupId != groupId) {
      _showSnackBar('You are already in a call.');
      return;
    }
    if (CallManager.instance.isBusy) {
      _showSnackBar('You are already in a call.');
      return;
    }
    final connected = await CallSignalingService.instance.ensureConnected();
    if (!connected) {
      _showSnackBar('Cannot reach the call service. Please try again.');
      return;
    }
    await _ensureMyUserId();
    _groupId = groupId;
    _groupName = groupName;
    _mediaType = video ? CallMediaType.video : CallMediaType.audio;
    _micEnabled = true;
    _cameraEnabled = true;
    _durationSeconds = 0;
    _statusText = 'Joining…';
    _stage = GroupCallStage.joining;
    notifyListeners();
    _send('group-join', groupId, {'media': video ? 'video' : 'audio'});
    _joinTimer = Timer(_joinTimeout, () {
      if (_stage == GroupCallStage.joining) {
        _failJoin('Could not join the group call.');
      }
    });
  }

  void acceptIncoming() {
    if (_stage != GroupCallStage.incoming) return;
    final groupId = _groupId;
    if (groupId == null) return;
    _statusText = 'Joining…';
    _stage = GroupCallStage.joining;
    notifyListeners();
    _send('group-join', groupId, {
      'media': _mediaType == CallMediaType.video ? 'video' : 'audio',
    });
    _joinTimer = Timer(_joinTimeout, () {
      if (_stage == GroupCallStage.joining) {
        _failJoin('Could not join the group call.');
      }
    });
  }

  void declineIncoming() {
    if (_stage != GroupCallStage.incoming) return;
    _cleanup(silent: true);
    _stage = GroupCallStage.idle;
    _popCallPage();
    notifyListeners();
  }

  void leave() {
    if (_stage == GroupCallStage.idle || _stage == GroupCallStage.ended) return;
    final groupId = _groupId;
    if (groupId != null) {
      _send('group-leave', groupId, null);
    }
    _statusText = 'You left the call';
    _stage = GroupCallStage.ended;
    notifyListeners();
    _scheduleClose();
  }

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

  void _onSignal(CallSignal signal) {
    switch (signal.action) {
      case 'group-incoming':
        _onGroupIncoming(signal);
        break;
      case 'group-members':
        _onGroupMembers(signal);
        break;
      case 'group-roster':
        _onGroupRoster(signal);
        break;
      case 'group-empty':
        if (_stage == GroupCallStage.joining && signal.from == _groupId) {
          _failJoin('No one else is online in this group.');
        }
        break;
      case 'group-busy':
        if (_stage == GroupCallStage.joining && signal.from == _groupId) {
          _joinTimer?.cancel();
          _send('group-join', signal.from, {
            'media': _mediaType == CallMediaType.video ? 'video' : 'audio',
          });
        }
        break;
      case 'group-gone':
        if (signal.from == _groupId && _stage != GroupCallStage.idle) {
          _statusText = 'The call has ended';
          _stage = GroupCallStage.ended;
          notifyListeners();
          _scheduleClose();
        }
        break;
      case 'group-denied':
        if (signal.from == _groupId && _stage == GroupCallStage.joining) {
          _failJoin('You are no longer a member of this group.');
        }
        break;
      case 'mesh-offer':
        _onMeshOffer(signal);
        break;
      case 'mesh-answer':
        _onMeshAnswer(signal);
        break;
      case 'mesh-ice':
        _onMeshIce(signal);
        break;
      default:
        break;
    }
  }

  void _onGroupIncoming(CallSignal signal) {
    if (isBusy || CallManager.instance.isBusy || _closing) {
      return;
    }
    unawaited(_ensureMyUserId());
    final payload = signal.payload ?? const {};
    _groupId = signal.from;
    _groupName = payload['groupName']?.toString() ?? 'Group';
    _mediaType = payload['media'] == 'video'
        ? CallMediaType.video
        : CallMediaType.audio;
    _caller = GroupCallParticipant(
      id: payload['callerId']?.toString() ?? signal.from,
      name: payload['callerName']?.toString() ?? 'Unknown',
      photo: payload['callerPhoto']?.toString(),
    );
    _micEnabled = true;
    _cameraEnabled = true;
    _durationSeconds = 0;
    _statusText = _mediaType == CallMediaType.video
        ? 'Incoming group video call'
        : 'Incoming group voice call';
    _stage = GroupCallStage.incoming;
    notifyListeners();
    _pushCallPage();
  }

  Future<void> _onGroupMembers(CallSignal signal) async {
    if (_stage != GroupCallStage.joining || signal.from != _groupId) return;
    _joinTimer?.cancel();
    try {
      await _captureLocalMedia();
    } catch (_) {
      _failJoin('Microphone or camera access was denied.');
      return;
    }
    await _ensureLocalRenderer();
    final list = signal.payload?['members'];
    if (list is List) {
      for (final item in list) {
        if (item is! Map) continue;
        final participant = GroupCallParticipant(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Member',
          photo: item['photo']?.toString(),
        );
        if (participant.id.isNotEmpty) {
          _participants[participant.id] = participant;
          await _connectToPeer(participant);
        }
      }
    }
    _statusText = 'Connected';
    _stage = GroupCallStage.active;
    notifyListeners();
    _pushCallPage();
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _durationSeconds += 1;
      notifyListeners();
    });
  }

  void _onGroupRoster(CallSignal signal) {
    if (signal.from != _groupId) return;
    if (_stage != GroupCallStage.active && _stage != GroupCallStage.joining) {
      return;
    }
    _participants.clear();
    final list = signal.payload?['members'];
    if (list is List) {
      for (final item in list) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        _participants[id] = GroupCallParticipant(
          id: id,
          name: item['name']?.toString() ?? 'Member',
          photo: item['photo']?.toString(),
        );
      }
    }
    notifyListeners();
  }

  Future<void> _onMeshOffer(CallSignal signal) async {
    if (_stage != GroupCallStage.active && _stage != GroupCallStage.joining) {
      return;
    }
    final groupId = _groupId;
    if (groupId == null) return;
    final payload = signal.payload ?? const {};
    if (payload['groupId']?.toString() != groupId) return;
    final sdp = payload['sdp'];
    if (sdp is! Map) return;

    try {
      await _captureLocalMedia();
      await _ensureLocalRenderer();
    } catch (_) {
      return;
    }

    final peer = _peers[signal.from] ??
        await _createMeshPeer(
          GroupCallParticipant(
            id: signal.from,
            name: signal.fromName ?? 'Member',
            photo: signal.fromPhoto,
          ),
        );
    try {
      await peer.pc.setRemoteDescription(
        RTCSessionDescription(
          sdp['sdp']?.toString() ?? '',
          sdp['type']?.toString() ?? 'offer',
        ),
      );
      peer.remoteDescriptionSet = true;
      _flushPendingIce(peer);
      final answer = await peer.pc.createAnswer();
      await peer.pc.setLocalDescription(answer);
      _send('mesh-answer', signal.from, {
        'groupId': groupId,
        'sdp': answer.toMap(),
      });
    } catch (_) {}
  }

  Future<void> _onMeshAnswer(CallSignal signal) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final payload = signal.payload ?? const {};
    if (payload['groupId']?.toString() != groupId) return;
    final peer = _peers[signal.from];
    if (peer == null) return;
    final sdp = payload['sdp'];
    if (sdp is! Map) return;
    try {
      await peer.pc.setRemoteDescription(
        RTCSessionDescription(
          sdp['sdp']?.toString() ?? '',
          sdp['type']?.toString() ?? 'answer',
        ),
      );
      peer.remoteDescriptionSet = true;
      _flushPendingIce(peer);
    } catch (_) {}
  }

  Future<void> _onMeshIce(CallSignal signal) async {
    final groupId = _groupId;
    if (groupId == null) return;
    final payload = signal.payload ?? const {};
    if (payload['groupId']?.toString() != groupId) return;
    final peer = _peers[signal.from];
    if (peer == null) return;
    final candidate = payload['candidate'];
    if (candidate is! Map) return;
    final ice = RTCIceCandidate(
      candidate['candidate']?.toString() ?? '',
      candidate['sdpMid']?.toString(),
      candidate['sdpMLineIndex'] is int
          ? candidate['sdpMLineIndex'] as int
          : 0,
    );
    if (peer.remoteDescriptionSet) {
      try {
        await peer.pc.addCandidate(ice);
      } catch (_) {}
    } else {
      peer.pendingIce.add(ice);
    }
  }

  Future<MeshPeer> _connectToPeer(GroupCallParticipant participant) async {
    final existing = _peers[participant.id];
    if (existing != null) return existing;
    final peer = await _createMeshPeer(participant);
    final offer = await peer.pc.createOffer();
    await peer.pc.setLocalDescription(offer);
    _send('mesh-offer', participant.id, {
      'groupId': _groupId,
      'media': _mediaType == CallMediaType.video ? 'video' : 'audio',
      'sdp': offer.toMap(),
    });
    return peer;
  }

  Future<MeshPeer> _createMeshPeer(GroupCallParticipant participant) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });
    final peer = MeshPeer(
      id: participant.id,
      pc: pc,
      name: participant.name,
      photo: participant.photo,
    );
    _peers[participant.id] = peer;

    final local = _localStream;
    if (local != null) {
      for (final track in local.getTracks()) {
        pc.addTrack(track, local);
      }
    }

    pc.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      if (_groupId == null) return;
      _send('mesh-ice', participant.id, {
        'groupId': _groupId,
        'candidate': {
          'candidate': value,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex ?? 0,
        },
      });
    };

    pc.onTrack = (event) async {
      if (event.streams.isEmpty) return;
      peer.remoteStream = event.streams.first;
      if (peer.renderer == null && _mediaType == CallMediaType.video) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = peer.remoteStream;
        peer.renderer = renderer;
      }
      peer.renderer?.srcObject = peer.remoteStream;
      notifyListeners();
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _removePeer(participant.id);
      }
    };

    return peer;
  }

  void _removePeer(String userId) {
    final peer = _peers.remove(userId);
    if (peer == null) return;
    _disposePeer(peer);
    notifyListeners();
  }

  void _flushPendingIce(MeshPeer peer) {
    if (peer.pendingIce.isEmpty) return;
    final candidates = List<RTCIceCandidate>.from(peer.pendingIce);
    peer.pendingIce.clear();
    for (final candidate in candidates) {
      peer.pc.addCandidate(candidate).catchError((_) {});
    }
  }

  Future<void>? _mediaCaptureFuture;

  Future<void> _captureLocalMedia() {
    return _mediaCaptureFuture ??= _doCaptureLocalMedia().catchError((Object e) {
      _mediaCaptureFuture = null;
      throw e;
    });
  }

  Future<void> _doCaptureLocalMedia() async {
    if (_localStream != null) return;
    final video = _mediaType == CallMediaType.video;
    MediaStream? stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video ? {'width': 640, 'height': 360, 'frameRate': 24} : false,
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
  }

  Future<void> _ensureLocalRenderer() async {
    if (_localRenderer == null) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = _localStream;
      _localRenderer = renderer;
    }
  }

  void _failJoin(String message) {
    _joinTimer?.cancel();
    _statusText = message;
    _stage = GroupCallStage.ended;
    notifyListeners();
    _showSnackBar(message);
    _scheduleClose();
  }

  void _scheduleClose() {
    _closing = true;
    _callTimer?.cancel();
    _callTimer = null;
    _popTimer?.cancel();
    _popTimer = Timer(const Duration(milliseconds: 900), _popCallPage);
    Timer(const Duration(milliseconds: 1400), () {
      _cleanup(silent: true);
      _closing = false;
    });
  }

  Future<void> _cleanup({bool silent = false}) async {
    _callTimer?.cancel();
    _callTimer = null;
    _joinTimer?.cancel();
    _joinTimer = null;

    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        try {
          await track.stop();
        } catch (_) {}
      }
    }
    final localRenderer = _localRenderer;
    _localRenderer = null;
    if (localRenderer != null) {
      try {
        localRenderer.srcObject = null;
        await localRenderer.dispose();
      } catch (_) {}
    }
    final peers = Map<String, MeshPeer>.from(_peers);
    _peers.clear();
    for (final peer in peers.values) {
      await _disposePeer(peer);
    }
    _participants.clear();
    _durationSeconds = 0;
    _mediaCaptureFuture = null;
    if (!silent) {
      _stage = GroupCallStage.idle;
      _statusText = '';
      notifyListeners();
    } else {
      _stage = GroupCallStage.idle;
      _statusText = '';
    }
  }

  Future<void> _disposePeer(MeshPeer peer) async {
    final renderer = peer.renderer;
    peer.renderer = null;
    if (renderer != null) {
      try {
        renderer.srcObject = null;
        await renderer.dispose();
      } catch (_) {}
    }
    try {
      await peer.pc.close();
    } catch (_) {}
  }

  void _pushCallPage() {
    if (_pageOpen) return;
    final navigator = CallManager.instance.navigatorKey.currentState;
    if (navigator == null) return;
    _pageOpen = true;
    navigator
        .push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const GroupCallPage(),
      ),
    )
        .whenComplete(() {
      _pageOpen = false;
    });
  }

  void _popCallPage() {
    if (!_pageOpen) return;
    final navigator = CallManager.instance.navigatorKey.currentState;
    if (navigator == null) return;
    _pageOpen = false;
    navigator.pop();
  }

  void _send(String action, String to, Map<String, dynamic>? payload) {
    CallSignalingService.instance.sendCall(action, to, payload);
  }

  void _showSnackBar(String message) {
    final context = CallManager.instance.navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _joinTimer?.cancel();
    _popTimer?.cancel();
    _signalingSubscription?.cancel();
    super.dispose();
  }
}

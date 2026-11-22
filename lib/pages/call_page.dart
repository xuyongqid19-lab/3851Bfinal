import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_manager.dart';
import '../theme/app_theme.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      lowerBound: 1.0,
      upperBound: 1.12,
    );
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final manager = CallManager.instance;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: manager,
            builder: (context, _) => _buildBody(context, manager),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CallManager manager) {
    final peer = manager.peer;
    final name = peer?.name ?? 'Unknown';
    final isVideo = manager.mediaType == CallMediaType.video;
    final showVideo = isVideo && manager.hasRemoteVideo;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2228), Color(0xFF0B0D10)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: showVideo ? _buildVideoArea(manager) : const SizedBox(),
          ),
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _buildStatusLabel(manager),
                const Spacer(),
                if (!showVideo) _buildAvatarArea(manager),
                const Spacer(),
                _buildControls(manager),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLabel(CallManager manager) {
    final isVideo = manager.mediaType == CallMediaType.video;
    final text = manager.stage == CallStage.active
        ? _formatDuration(manager.durationSeconds)
        : manager.statusText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isVideo ? Icons.videocam : Icons.phone,
          color: Colors.white70,
          size: 15,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoArea(CallManager manager) {
    final localRenderer = manager.localRenderer;
    final showPip = manager.cameraEnabled && localRenderer?.srcObject != null;
    return Stack(
      children: [
        Positioned.fill(
          child: RTCVideoView(
            manager.remoteRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        ),
        if (showPip)
          Positioned(
            right: 16,
            bottom: 150,
            child: Container(
              width: 110,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              clipBehavior: Clip.antiAlias,
              child: RTCVideoView(
                localRenderer!,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarArea(CallManager manager) {
    final peer = manager.peer;
    final photoUrl = peer?.photoUrl;
    final seed = peer?.id ?? peer?.name ?? 'unknown';
    final pulsing = manager.stage == CallStage.incoming ||
        manager.stage == CallStage.outgoing;
    final avatar = CircleAvatar(
      radius: 56,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.avatarGradientFor(seed),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(peer?.name ?? '?'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );

    return ScaleTransition(
      scale: pulsing ? _pulse : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white10,
        ),
        child: avatar,
      ),
    );
  }

  Widget _buildControls(CallManager manager) {
    switch (manager.stage) {
      case CallStage.incoming:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundButton(
              icon: Icons.call_end,
              colors: AppTheme.redGradientColors,
              onPressed: manager.declineIncoming,
            ),
            const SizedBox(width: 48),
            _RoundButton(
              icon: manager.mediaType == CallMediaType.video
                  ? Icons.videocam
                  : Icons.call,
              colors: AppTheme.greenGradientColors,
              onPressed: manager.acceptIncoming,
            ),
          ],
        );
      case CallStage.outgoing:
      case CallStage.connecting:
      case CallStage.active:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundButton(
              icon: manager.micEnabled ? Icons.mic : Icons.mic_off,
              muted: true,
              active: manager.micEnabled,
              onPressed: manager.toggleMic,
            ),
            const SizedBox(width: 28),
            _RoundButton(
              icon: Icons.call_end,
              colors: AppTheme.redGradientColors,
              onPressed: manager.hangUp,
              size: 68,
            ),
            if (manager.mediaType == CallMediaType.video) ...[
              const SizedBox(width: 28),
              _RoundButton(
                icon: manager.cameraEnabled ? Icons.videocam : Icons.videocam_off,
                muted: true,
                active: manager.cameraEnabled,
                onPressed: manager.toggleCamera,
              ),
            ],
          ],
        );
      case CallStage.idle:
      case CallStage.ended:
        return const SizedBox(height: 68);
    }
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onPressed,
    this.colors,
    this.muted = false,
    this.active = false,
    this.size = 64,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final List<Color>? colors;
  final bool muted;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gradient = colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(size / 2),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient != null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  )
                : null,
            color: gradient == null
                ? (active ? Colors.white24 : Colors.white12)
                : null,
          ),
          child: Icon(
            icon,
            color: gradient != null ? Colors.white : Colors.white70,
            size: size * 0.42,
          ),
        ),
      ),
    );
  }
}

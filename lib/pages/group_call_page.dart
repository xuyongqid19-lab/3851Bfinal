import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/call_manager.dart';
import '../services/group_call_manager.dart';
import '../theme/app_theme.dart';

class GroupCallPage extends StatefulWidget {
  const GroupCallPage({super.key});

  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage>
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
    final manager = GroupCallManager.instance;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF101418),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: manager,
            builder: (context, _) => _buildBody(manager),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(GroupCallManager manager) {
    final isVideo = manager.mediaType == CallMediaType.video;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2228), Color(0xFF0B0D10)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVideo ? Icons.videocam : Icons.phone,
                color: Colors.white70,
                size: 15,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  manager.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            manager.stage == GroupCallStage.active
                ? '${manager.participants.length} in call · ${_formatDuration(manager.durationSeconds)}'
                : manager.statusText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          Expanded(child: _buildCenter(manager)),
          _buildControls(manager),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildCenter(GroupCallManager manager) {
    switch (manager.stage) {
      case GroupCallStage.incoming:
        return _buildIncoming(manager);
      case GroupCallStage.joining:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Joining…',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        );
      case GroupCallStage.active:
        return _buildGrid(manager);
      case GroupCallStage.ended:
        return Center(
          child: Text(
            manager.statusText,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        );
      case GroupCallStage.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIncoming(GroupCallManager manager) {
    final caller = manager.caller;
    final photo = caller?.photo;
    return Center(
      child: ScaleTransition(
        scale: _pulse,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 52,
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              backgroundImage:
                  photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo == null || photo.isEmpty
                  ? Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.avatarGradientFor(
                            caller?.id ?? 'caller'),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(caller?.name ?? '?'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 18),
            Text(
              caller?.name ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              manager.mediaType == CallMediaType.video
                  ? 'Group video call'
                  : 'Group voice call',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(GroupCallManager manager) {
    final isVideo = manager.mediaType == CallMediaType.video;
    final myId = manager.myUserId;
    final tiles = <Widget>[_buildMeTile(manager)];
    for (final participant in manager.participants) {
      if (participant.id == myId) continue;
      tiles.add(_buildPeerTile(manager, participant, isVideo));
    }
    return GridView.count(
      crossAxisCount: tiles.length <= 2 ? 1 : 2,
      childAspectRatio: tiles.length <= 2 ? 1.2 : 0.95,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: tiles,
    );
  }

  Widget _buildTileShell({
    required Widget child,
    required String label,
    Widget? badge,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.white10,
            child: child,
          ),
          Positioned(
            left: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (badge != null) Positioned(right: 8, top: 8, child: badge),
        ],
      ),
    );
  }

  Widget _avatar(String id, String name, String? photo) {
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        foregroundColor: Colors.white,
        backgroundImage: NetworkImage(photo),
      );
    }
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.avatarGradientFor(id),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMeTile(GroupCallManager manager) {
    final isVideo = manager.mediaType == CallMediaType.video;
    final localRenderer = manager.localRenderer;
    final showVideo =
        isVideo && manager.cameraEnabled && localRenderer?.srcObject != null;
    final me = manager.meAsParticipant;
    return _buildTileShell(
      label: '${me?.name ?? 'You'} (You)',
      badge: !manager.micEnabled
          ? const Icon(Icons.mic_off, color: Colors.orangeAccent, size: 18)
          : null,
      child: Center(
        child: showVideo
            ? RTCVideoView(
                localRenderer!,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : _avatar(manager.myUserId ?? 'me', me?.name ?? 'You', me?.photo),
      ),
    );
  }

  Widget _buildPeerTile(
    GroupCallManager manager,
    GroupCallParticipant participant,
    bool isVideo,
  ) {
    final peer = manager.peerOf(participant.id);
    final renderer = peer?.renderer;
    final hasVideo = isVideo && renderer?.srcObject != null;
    return _buildTileShell(
      label: participant.name,
      child: Center(
        child: hasVideo
            ? RTCVideoView(
                renderer!,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : _avatar(participant.id, participant.name, participant.photo),
      ),
    );
  }

  Widget _buildControls(GroupCallManager manager) {
    switch (manager.stage) {
      case GroupCallStage.incoming:
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
      case GroupCallStage.joining:
      case GroupCallStage.active:
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
              onPressed: manager.leave,
              size: 68,
            ),
            if (manager.mediaType == CallMediaType.video) ...[
              const SizedBox(width: 28),
              _RoundButton(
                icon: manager.cameraEnabled
                    ? Icons.videocam
                    : Icons.videocam_off,
                muted: true,
                active: manager.cameraEnabled,
                onPressed: manager.toggleCamera,
              ),
            ],
          ],
        );
      case GroupCallStage.idle:
      case GroupCallStage.ended:
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

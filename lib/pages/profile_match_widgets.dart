part of 'profile_page.dart';

/// Shared parameters for the match tabs; candidates come from the backend.
class _MatchTabConfig {
  const _MatchTabConfig({
    required this.candidates,
    required this.loading,
    required this.error,
    required this.friendIds,
    required this.pendingIds,
    required this.onRetry,
    required this.onAddFriend,
  });

  final List<MatchUser> candidates;
  final bool loading;
  final String? error;
  final Set<String> friendIds;
  final Set<String> pendingIds;
  final VoidCallback onRetry;
  final ValueChanged<MatchUser> onAddFriend;
}

class _InterestMatchTab extends StatefulWidget {
  const _InterestMatchTab({required this.config});

  final _MatchTabConfig config;

  @override
  State<_InterestMatchTab> createState() => _InterestMatchTabState();
}

class _InterestMatchTabState extends State<_InterestMatchTab>
    with AutomaticKeepAliveClientMixin<_InterestMatchTab> {
  ProfileData? _cachedProfile;
  List<MatchUser>? _cachedCandidates;
  List<MatchUser> _matches = const [];

  @override
  bool get wantKeepAlive => true;

  List<MatchUser> _compute(ProfileData profile) {
    if (identical(_cachedProfile, profile) &&
        identical(_cachedCandidates, widget.config.candidates)) {
      return _matches;
    }
    _cachedProfile = profile;
    _cachedCandidates = widget.config.candidates;
    // Hide 0% entries: they have no shared interest, so they are not matches.
    _matches = interestMatch(profile, widget.config.candidates)
        .where((u) => u.matchScore > 0)
        .toList(growable: false);
    return _matches;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<ProfileData>(
      valueListenable: currentProfile,
      builder: (context, profile, _) {
        return _MatchList(
          matches: _compute(profile),
          emptyMessage: widget.config.candidates.isEmpty
              ? 'No other users to match with yet.'
              : 'No shared interests found yet. Add a few interest tags to '
                  'see better matches.',
          title: 'Based on your interests and age',
          config: widget.config,
        );
      },
    );
  }
}

class _RecommendedMatchTab extends StatefulWidget {
  const _RecommendedMatchTab({required this.config});

  final _MatchTabConfig config;

  @override
  State<_RecommendedMatchTab> createState() => _RecommendedMatchTabState();
}

class _RecommendedMatchTabState extends State<_RecommendedMatchTab>
    with AutomaticKeepAliveClientMixin<_RecommendedMatchTab> {
  ProfileData? _cachedProfile;
  List<MatchUser>? _cachedCandidates;
  List<MatchUser> _matches = const [];

  @override
  bool get wantKeepAlive => true;

  List<MatchUser> _compute(ProfileData profile) {
    if (identical(_cachedProfile, profile) &&
        identical(_cachedCandidates, widget.config.candidates)) {
      return _matches;
    }
    _cachedProfile = profile;
    _cachedCandidates = widget.config.candidates;
    _matches = recommendMatch(profile, widget.config.candidates)
        .where((u) => u.matchScore > 0)
        .toList(growable: false);
    return _matches;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<ProfileData>(
      valueListenable: currentProfile,
      builder: (context, profile, _) {
        return _MatchList(
          matches: _compute(profile),
          emptyMessage: widget.config.candidates.isEmpty
              ? 'No other users to match with yet.'
              : 'No recommendations yet. Add your community and interests to '
                  'improve suggestions.',
          title: 'Based on community, age & interests',
          config: widget.config,
        );
      },
    );
  }
}

class _MatchList extends StatelessWidget {
  final List<MatchUser> matches;
  final String emptyMessage;
  final String title;
  final _MatchTabConfig config;

  const _MatchList({
    required this.matches,
    required this.emptyMessage,
    required this.title,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(title,
              style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (config.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (config.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(config.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 15)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: config.onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.ink,
                  side: const BorderSide(color: AppTheme.ink),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 15)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: matches.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppTheme.divider),
      itemBuilder: (_, i) {
        final user = matches[i];
        return _MatchTile(
          user: user,
          isFriend: config.friendIds.contains(user.id),
          isPending: config.pendingIds.contains(user.id),
          onAdd: () => config.onAddFriend(user),
        );
      },
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  const _MatchAvatar({required this.user});

  final MatchUser user;

  @override
  Widget build(BuildContext context) {
    final photo = user.googlePhotoUrl?.trim() ?? '';
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppTheme.ink.withValues(alpha: 0.1),
      foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
      onForegroundImageError: photo.isEmpty ? null : (_, __) {},
      child: Text(
        user.avatarInitial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.ink,
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final MatchUser user;
  final bool isFriend;
  final bool isPending;
  final VoidCallback onAdd;

  const _MatchTile({
    required this.user,
    required this.isFriend,
    required this.isPending,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = user.matchScore >= 70
        ? AppTheme.green
        : user.matchScore >= 40
            ? AppTheme.orange
            : AppTheme.muted;
    // Friends and pending requests cannot be tapped to add again.
    final canAdd = !isFriend && !isPending;
    return InkWell(
      onTap: canAdd ? onAdd : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _MatchAvatar(user: user),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Age 0 means no birth date; do not show "0 yrs".
                      if (user.age > 0) ...[
                        Text('${user.age} yrs',
                            style: const TextStyle(fontSize: 12)),
                        if (user.community.isNotEmpty) const SizedBox(width: 8),
                      ],
                      if (user.community.isNotEmpty) ...[
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppTheme.muted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(user.community,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.muted),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  if (user.interestTags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 24,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: user.interestTags.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 4),
                        itemBuilder: (_, i) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.ink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(user.interestTags[i],
                              style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${user.matchScore.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: scoreColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _buildAction(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Reuse the Find Friends states: Friends / Pending / Add.
  Widget _buildAction() {
    if (isFriend) {
      return _statusPill('Friends', AppTheme.green);
    }
    if (isPending) {
      return _statusPill('Pending', AppTheme.muted);
    }
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onAdd,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.ink,
          side: const BorderSide(color: AppTheme.ink),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 30),
        ),
        child: const Text('Add',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

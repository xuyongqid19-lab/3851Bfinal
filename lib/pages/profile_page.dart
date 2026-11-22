import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'add_friend_page.dart';
import 'login_page.dart';
import 'change_password_page.dart';
import 'security_questions_page.dart';

part 'profile_match_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Interest-match candidates from the backend. Both tabs share this list.
  List<MatchUser> _candidates = const [];
  bool _candidatesLoading = false;
  String? _candidatesError;
  bool _candidatesRequested = false;

  /// Friend / outgoing-request state for the tile Add / Pending / Friends view.
  final Set<String> _friendIds = <String>{};
  final Set<String> _pendingIds = <String>{};

  ChatService? _chatService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    // Load candidates lazily: viewing only My Profile needs no match request.
    _loadFriendStatus();
  }

  ChatService _service() => _chatService ??= ChatService();

  void _onTabChanged() {
    if (_tabController.index == 0) return;
    _ensureCandidates();
    // Refresh friend state when entering a match tab so Add is never stale.
    _loadFriendStatus();
  }

  void _ensureCandidates() {
    if (_candidatesRequested) return;
    _candidatesRequested = true;
    _loadCandidates();
  }

  /// Retry / manual refresh entry point.
  Future<void> _loadCandidates() {
    if (mounted) {
      setState(() {
        _candidatesLoading = true;
        _candidatesError = null;
      });
    }
    return _fetchCandidates();
  }

  Future<void> _fetchCandidates() async {
    try {
      final rows = await AuthService.fetchMatchCandidates();
      if (!mounted) return;
      setState(() {
        // Drop records without an id: they cannot be used to add a friend.
        _candidates =
            rows.map(MatchUser.fromJson).where((u) => u.id.isNotEmpty).toList();
        _candidatesLoading = false;
        _candidatesError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _candidates = const [];
        _candidatesLoading = false;
        _candidatesError = e.toString();
      });
    }
  }

  Future<void> _loadFriendStatus() async {
    try {
      final summary = await _service().fetchFriends();
      if (!mounted) return;
      setState(() {
        _friendIds
          ..clear()
          ..addAll(summary.friends.map((u) => u.id));
        _pendingIds
          ..clear()
          ..addAll(summary.outgoing.map((u) => u.id));
      });
    } catch (_) {
      // Chat service being down must not break the match list.
    }
  }

  Future<void> _onAddFriend(MatchUser user) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddFriendPage(
          user: ChatUser(
            id: user.id,
            fullName: user.name,
            username: user.username,
            email: user.email,
            googlePhotoUrl: user.googlePhotoUrl,
            // ChatUser.interest is a single field; join tags for Add Friend.
            interest: user.interestTags.join(', '),
            authProvider: user.authProvider,
          ),
        ),
      ),
    );
    if (sent == true && mounted) {
      setState(() => _pendingIds.add(user.id));
    }
    if (mounted) {
      // Friend state may have changed on the request page; resync on return.
      _loadFriendStatus();
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your chats and profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _chatService?.close();
    super.dispose();
  }

  /// Candidates and friend state shared by both match tabs.
  _MatchTabConfig get _matchConfig => _MatchTabConfig(
        candidates: _candidates,
        loading: _candidatesLoading,
        error: _candidatesError,
        friendIds: _friendIds,
        pendingIds: _pendingIds,
        onRetry: _loadCandidates,
        onAddFriend: _onAddFriend,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: AppTheme.ink),
                    tooltip: 'Logout',
                    onPressed: _confirmLogout,
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppTheme.ink,
              unselectedLabelColor: AppTheme.hint,
              indicatorColor: AppTheme.ink,
              indicatorWeight: 2,
              tabs: const [
                Tab(text: 'My Profile'),
                Tab(text: 'Interest Match'),
                Tab(text: 'Recommended'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const _MyProfileTab(),
                  _InterestMatchTab(config: _matchConfig),
                  _RecommendedMatchTab(config: _matchConfig),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyProfileTab extends StatefulWidget {
  const _MyProfileTab();

  @override
  State<_MyProfileTab> createState() => _MyProfileTabState();
}

class _MyProfileTabState extends State<_MyProfileTab>
    with AutomaticKeepAliveClientMixin<_MyProfileTab> {
  // Keep the edit form alive while the user switches between profile tabs.
  @override
  bool get wantKeepAlive => true;

  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _customCtrl;
  DateTime? _birthDate;
  late List<String> _selectedInterests;
  late String _selectedCommunity;
  String _customCategory = 'Sports';
  late Map<String, String> _customCategories;

  bool _loadingProfile = true;
  bool _profileLoaded = false;
  bool _saving = false;
  String? _profileError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _customCtrl = TextEditingController();
    _customCategory = interestCategories.keys.first;
    _applyProfile(currentProfile.value);
    _loadRemoteProfile();
  }

  /// Reload entry point for pull-to-refresh. Never clobbers an in-progress edit.
  Future<void> _refreshProfile() async {
    if (_editing) {
      _showMessage('Finish or cancel your edit before refreshing.');
      return;
    }
    await _loadRemoteProfile();
  }

  Future<void> _loadRemoteProfile() async {
    if (mounted) {
      setState(() {
        _loadingProfile = true;
        _profileError = null;
      });
    }
    try {
      final user = await AuthService.fetchMe();
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _loadingProfile = false;
          _profileError = 'Could not load your profile. Please try again.';
        });
        return;
      }
      setState(() {
        currentProfile.value =
            profileFromAuthUser(user, fallback: currentProfile.value);
        _applyProfile(currentProfile.value);
        _profileLoaded = true;
        _loadingProfile = false;
        _profileError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = e is AuthException
            ? e.message
            : 'Could not load your profile. Check your connection and retry.';
      });
    }
  }

  /// Copies profile values into the existing controllers. Controllers are
  /// created once and reused, so they never leak on reload/save/cancel.
  void _applyProfile(ProfileData p) {
    _nameCtrl.text = p.name;
    _usernameCtrl.text = p.username;
    _emailCtrl.text = p.email;
    _phoneCtrl.text = p.phone;
    _addressCtrl.text = p.address;
    _birthDate = p.birthDate;
    _selectedInterests = List.from(p.interestTags);
    _selectedCommunity = p.community;
    _customCategories = Map<String, String>.from(p.customInterestCategories);
    _customCtrl.clear();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Select birth date',
      cancelText: 'Cancel',
      confirmText: 'OK',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String? _validate() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return 'Name cannot be empty.';
    final username = _usernameCtrl.text.trim();
    if (username.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9_.]{3,30}$').hasMatch(username)) {
      return 'Username must be 3-30 letters, numbers, "_" or "."';
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^[0-9+()\-\s]{6,24}$').hasMatch(phone)) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_profileLoaded) {
      _showMessage(
        'Your profile has not loaded from the server yet. '
        'Please retry before saving.',
      );
      return;
    }
    final validationError = _validate();
    if (validationError != null) {
      _showMessage(validationError);
      return;
    }
    // Keep only custom mappings still in the selected list.
    final customMap = <String, String>{};
    for (final e in _customCategories.entries) {
      if (_selectedInterests.contains(e.key)) customMap[e.key] = e.value;
    }
    final birthDate = _birthDate;
    final draft = ProfileData(
      name: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      age: birthDate == null ? 0 : calculateAge(birthDate),
      birthDate: birthDate,
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      community: _selectedCommunity,
      address: _addressCtrl.text.trim(),
      googlePhotoUrl: currentProfile.value.googlePhotoUrl,
      interestTags: List.from(_selectedInterests),
      customInterestCategories: customMap,
    );

    setState(() => _saving = true);
    try {
      final user = await AuthService.updateProfile(
        fullName: draft.name,
        username: draft.username,
        birthDate: birthDate == null ? null : formatBirthDate(birthDate),
        phone: draft.phone,
        community: draft.community,
        address: draft.address,
        interests: draft.interestTags,
        customCategories: draft.customInterestCategories,
      );
      if (!mounted) return;
      // Only publish the new values after the server accepted them.
      setState(() {
        currentProfile.value =
            user.isEmpty ? draft : profileFromAuthUser(user, fallback: draft);
        _applyProfile(currentProfile.value);
        _profileLoaded = true;
        _editing = false;
      });
      _showMessage('Profile saved');
    } on AuthException catch (e) {
      // Keep the user in edit mode so their input is not silently lost.
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) {
        _showMessage('Could not save your profile. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    _applyProfile(currentProfile.value);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }
    final p = currentProfile.value;
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_profileError != null) ...[
              _buildSyncBanner(),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                _buildAvatar(p),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name.isEmpty ? 'Your profile' : p.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.username.isEmpty ? 'Username not set' : p.username,
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (!_editing)
                  TextButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.ink),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChangePasswordPage(),
                  ),
                ),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Change Password'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.ink),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SecurityQuestionsPage(),
                  ),
                ),
                icon: const Icon(Icons.security_outlined, size: 18),
                label: const Text('Security Questions'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.ink),
              ),
            ),
            if (_editing) ...[
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 12),
              _buildEditableField('Name', _nameCtrl),
              const SizedBox(height: 12),
              _buildEditableField('Username', _usernameCtrl),
              const SizedBox(height: 12),
              _buildBirthDateField(),
              const SizedBox(height: 12),
              _buildEditableField(
                'Email',
                _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                readOnly: true,
                helperText:
                    'Email is your login ID and cannot be changed here.',
              ),
              const SizedBox(height: 12),
              _buildEditableField('Phone', _phoneCtrl,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildEditableField('Address', _addressCtrl),
              const SizedBox(height: 18),
              _buildSectionTitle('Community'),
              const SizedBox(height: 8),
              _buildCommunityDropdown(),
              const SizedBox(height: 18),
              _buildSectionTitle('Interest Tags'),
              const SizedBox(height: 8),
              _buildInterestChips(editable: true),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      'Cancel',
                      outlined: true,
                      onTap: _cancel,
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildButton(
                      'Save',
                      onTap: _save,
                      enabled: _profileLoaded,
                      busy: _saving,
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person_outline, 'Name',
                  p.name.isEmpty ? 'Not set' : p.name),
              _buildInfoRow(Icons.badge_outlined, 'Username',
                  p.username.isEmpty ? 'Not set' : p.username),
              _buildInfoRow(
                Icons.cake_outlined,
                'Birth Date',
                p.birthDate == null ? 'Not set' : formatBirthDate(p.birthDate!),
              ),
              _buildInfoRow(
                  Icons.numbers_outlined,
                  'Age',
                  p.birthDate == null && p.age == 0
                      ? 'Not set'
                      : '${p.displayAge}'),
              _buildInfoRow(Icons.email_outlined, 'Email',
                  p.email.isEmpty ? 'Not set' : p.email),
              _buildInfoRow(Icons.phone_outlined, 'Phone',
                  p.phone.isEmpty ? 'Not set' : p.phone),
              _buildInfoRow(Icons.home_outlined, 'Address',
                  p.address.isEmpty ? 'Not set' : p.address),
              const SizedBox(height: 16),
              _buildSectionTitle('Community'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.groups_outlined, 'Community',
                  p.community.isEmpty ? 'Not set' : p.community),
              const SizedBox(height: 16),
              _buildSectionTitle('Interest Tags'),
              const SizedBox(height: 8),
              _buildInterestChips(editable: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ProfileData p) {
    final name = p.name.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final photo = p.googlePhotoUrl.trim();
    return CircleAvatar(
      radius: 36,
      backgroundColor: AppTheme.ink,
      foregroundImage: photo.isEmpty ? null : NetworkImage(photo),
      onForegroundImageError: photo.isEmpty ? null : (_, __) {},
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSyncBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppTheme.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile not synced',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.red,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _profileError!,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loadingProfile ? null : _refreshProfile,
              child: const Text('Retry'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink));
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.muted),
          const SizedBox(width: 10),
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      color: AppTheme.muted, fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController ctrl,
      {TextInputType? keyboardType,
      bool readOnly = false,
      String? helperText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          readOnly: readOnly,
          decoration: InputDecoration(
            isDense: true,
            filled: readOnly,
            fillColor: readOnly ? AppTheme.canvas : null,
            helperText: helperText,
            helperMaxLines: 2,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
          ),
        ),
      ],
    );
  }

  Widget _buildBirthDateField() {
    final text = _birthDate == null
        ? 'Select birth date'
        : '${formatBirthDate(_birthDate!)}  ·  Age ${calculateAge(_birthDate!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Birth Date',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted)),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickBirthDate,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: _birthDate == null ? AppTheme.hint : AppTheme.ink,
                      fontWeight: _birthDate == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_month_outlined,
                    size: 20, color: AppTheme.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommunityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCommunity.isEmpty ? null : _selectedCommunity,
          isExpanded: true,
          hint: const Text('Select community',
              style: TextStyle(color: AppTheme.hint)),
          items: availableCommunities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedCommunity = v);
          },
        ),
      ),
    );
  }

  void _togglePreset(String interest, bool select) {
    if (select && _selectedInterests.length >= 10) {
      _showMessage('Max 10 interests');
      return;
    }
    setState(() {
      if (select) {
        _selectedInterests.add(interest);
      } else {
        _selectedInterests.remove(interest);
      }
    });
  }

  void _addCustomInterest() {
    final text = _customCtrl.text.trim();
    if (text.isEmpty) return;
    if (text.length > 12) {
      _showMessage('Custom interest must be within 12 characters');
      return;
    }
    final lower = text.toLowerCase();
    final exists = _selectedInterests.any((e) => e.toLowerCase() == lower);
    if (exists) {
      _showMessage('This interest already exists');
      return;
    }
    final presetHit = availableInterests.any((e) => e.toLowerCase() == lower);
    if (presetHit) {
      _showMessage('Already in presets, please select it above');
      return;
    }
    if (_selectedInterests.length >= 10) {
      _showMessage('Max 10 interests');
      return;
    }
    final customCount =
        _selectedInterests.where((e) => !availableInterests.contains(e)).length;
    if (customCount >= 5) {
      _showMessage('Max 5 custom interests');
      return;
    }
    setState(() {
      _selectedInterests.add(text);
      _customCategories[text] = _customCategory;
      _customCtrl.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedInterests.remove(tag);
      _customCategories.remove(tag);
    });
  }

  Widget _buildInterestChips({required bool editable}) {
    if (!editable) {
      // View mode: show selected only (custom tags with category suffix)
      final tags = currentProfile.value.interestTags;
      final customMap = currentProfile.value.customInterestCategories;
      if (tags.isEmpty) {
        return const Text('No interests',
            style: TextStyle(color: AppTheme.muted, fontSize: 14));
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) {
          final isCustom = !availableInterests.contains(tag);
          final suffix = isCustom && (customMap[tag]?.isNotEmpty ?? false)
              ? ' · ${customMap[tag]}'
              : '';
          return Chip(
            label: Text('$tag$suffix', style: const TextStyle(fontSize: 13)),
            backgroundColor: isCustom
                ? AppTheme.ink.withValues(alpha: 0.12)
                : AppTheme.ink.withValues(alpha: 0.06),
            side: BorderSide(color: isCustom ? AppTheme.ink : AppTheme.border),
          );
        }).toList(),
      );
    }
    final customTags = _selectedInterests
        .where((e) => !availableInterests.contains(e))
        .toList();
    final total = _selectedInterests.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selected $total/10 · Custom ${customTags.length}/5',
            style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableInterests.map((interest) {
            final selected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest, style: const TextStyle(fontSize: 13)),
              selected: selected,
              onSelected: (val) => _togglePreset(interest, val),
              selectedColor: AppTheme.ink.withValues(alpha: 0.15),
              checkmarkColor: AppTheme.ink,
              side: BorderSide(
                color: selected ? AppTheme.ink : AppTheme.border,
              ),
            );
          }).toList(),
        ),
        if (customTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: customTags.map((tag) {
              final big = _customCategories[tag] ?? '';
              return InputChip(
                label:
                    Text('$tag · $big', style: const TextStyle(fontSize: 13)),
                onDeleted: () => _removeTag(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                backgroundColor: AppTheme.ink.withValues(alpha: 0.12),
                side: const BorderSide(color: AppTheme.ink),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        const Text('Add custom interest',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted)),
        const SizedBox(height: 4),
        TextField(
          controller: _customCtrl,
          maxLength: 12,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'e.g. Lure fishing, Board games (1-12 chars)',
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
          ),
          onSubmitted: (_) => _addCustomInterest(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _customCategory,
                    isExpanded: true,
                    items: interestCategories.keys
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _customCategory = v);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _addCustomInterest,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildButton(
    String label, {
    bool outlined = false,
    required VoidCallback onTap,
    bool enabled = true,
    bool busy = false,
  }) {
    final canTap = enabled && !busy;
    final child = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w700));
    if (outlined) {
      return SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: canTap ? onTap : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.ink,
            side: const BorderSide(color: AppTheme.ink),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: canTap ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.ink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: child,
      ),
    );
  }
}

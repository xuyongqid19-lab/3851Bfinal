import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/chat_widgets.dart';
import 'ai_chat_page.dart';
import 'change_password_page.dart';
import 'chat_detail_page.dart';
import 'community_page.dart';
import 'family_page.dart';
import 'find_friends_page.dart';
import 'friend_requests_page.dart';
import 'profile_page.dart';
import 'security_questions_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({this.initialTabIndex = 0, super.key});

  final int initialTabIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late int _navIndex;
  String _selectedTab = 'All';

  final ChatService _chatService = ChatService();
  List<Chat> _chats = [];
  bool _loadingChats = true;
  String? _chatsError;
  int _requestCount = 0;
  String _aiPreview = 'Ask me anything';
  String? _aiTime;

  /// Tabs that have been opened at least once. IndexedStack keeps them mounted
  /// so unsaved profile edits and page state survive bottom-nav switches.
  late final Set<int> _visitedTabs;

  @override
  void initState() {
    super.initState();
    _navIndex = widget.initialTabIndex;
    _visitedTabs = {0, _navIndex};
    _loadConversations();
    _loadRequestCount();
    _loadAiPreview();
  }

  @override
  void dispose() {
    _chatService.close();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!mounted) return;
    if (silent && _chats.isNotEmpty) {
      try {
        final result = await _chatService.fetchAllConversations();
        if (!mounted) return;
        setState(() => _chats = _mergeChats(result));
      } catch (_) {}
      return;
    }
    setState(() {
      _loadingChats = true;
      _chatsError = null;
    });
    try {
      final result = await _chatService.fetchAllConversations();
      if (!mounted) return;
      setState(() {
        _chats = _mergeChats(result);
        _loadingChats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingChats = false;
        _chatsError = e.toString();
      });
    }
  }

  Future<void> _loadRequestCount() async {
    try {
      final summary = await _chatService.fetchFriends();
      if (!mounted) return;
      setState(() => _requestCount = summary.incoming.length);
    } catch (_) {}
  }

  Future<void> _openFriendRequests() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FriendRequestsPage()),
    );
    if (!mounted) return;
    await _loadRequestCount();
    await _loadConversations();
  }

  Chat _toChat(ChatConversation conversation) {
    final last = conversation.lastMessage;
    String preview = 'No messages yet';
    if (last != null) {
      if (last.isVoice) {
        preview = 'Voice message';
      } else if (last.isLocation) {
        preview = 'Location';
      } else {
        preview = last.text;
      }
    }
    return Chat(
      userId: conversation.user.id,
      name: conversation.user.fullName,
      time: _formatListTime(last?.createdAt),
      unreadCount: conversation.unreadCount,
      preview: preview,
    );
  }

  Chat _toGroupChat(ChatGroupConversation group) {
    final last = group.lastMessage;
    String preview = 'Group chat created';
    if (last != null) {
      if (last.isVoice) {
        preview = 'Voice message';
      } else if (last.isLocation) {
        preview = 'Location';
      } else {
        preview = last.text;
      }
    }
    return Chat(
      userId: '',
      groupId: group.id,
      name: group.name,
      memberCount: group.memberCount,
      groupCreatorId: group.createdBy,
      time: _formatListTime(last?.createdAt),
      unreadCount: group.unreadCount,
      preview: preview,
      isGroup: true,
      category: 'Groups',
    );
  }

  List<Chat> _mergeChats(ConversationsResult result) {
    final entries = <MapEntry<Chat, DateTime?>>[];
    for (final conversation in result.conversations) {
      entries.add(
          MapEntry(_toChat(conversation), conversation.lastMessage?.createdAt));
    }
    for (final group in result.groups) {
      entries.add(MapEntry(_toGroupChat(group), group.lastMessage?.createdAt));
    }
    entries.sort((a, b) {
      final at = a.value;
      final bt = b.value;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return entries.map((e) => e.key).toList();
  }

  String _formatListTime(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (!day.isBefore(today)) {
      final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      return '${local.hour < 12 ? 'AM' : 'PM'} $hour12:$minute';
    }
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    final diff = today.difference(day).inDays;
    if (diff < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[local.weekday - 1];
    }
    return '${local.month}/${local.day}';
  }

  List<Chat> get _filteredChats {
    return _chats.where((c) {
      if (_selectedTab == 'Friends') return !c.isGroup;
      if (_selectedTab == 'Groups') return c.isGroup;
      return true;
    }).toList();
  }

  void _openFindFriends() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FindFriendsPage()));
  }

  Future<void> _openChat(Chat chat) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ChatDetailPage(chat: chat)));
    if (!mounted) return;
    _loadConversations(silent: true);
  }

  Future<void> _openAiChat() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AiChatPage()));
    if (!mounted) return;
    _loadAiPreview();
  }

  Future<void> _loadAiPreview() async {
    try {
      final summary = await _chatService.fetchAiMessages(limit: 1);
      if (!mounted) return;
      final last = summary.messages.isEmpty ? null : summary.messages.last;
      setState(() {
        if (last == null) {
          _aiPreview = 'Ask me anything';
          _aiTime = null;
        } else {
          final content = last.content.trim();
          _aiPreview =
              (last.fromUser ? 'You: ' : '') +
              (content.length > 42
                  ? '${content.substring(0, 42)}…'
                  : content);
          _aiTime = _formatListTime(last.createdAt);
        }
      });
    } catch (_) {}
  }

  void _onNavSelected(int i) {
    setState(() {
      _navIndex = i;
      _visitedTabs.add(i);
    });
    if (i == 0) {
      _loadRequestCount();
      _loadConversations(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build lazily and keep every visited tab mounted. This preserves e.g. an
    // in-progress profile edit when the user briefly opens Chats or Community.
    return IndexedStack(
      index: _navIndex,
      children: List<Widget>.generate(4, (i) {
        if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
        return _buildTab(i);
      }),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 1:
        return Scaffold(
          backgroundColor: Colors.white,
          body: const CommunityPage(),
          bottomNavigationBar: BottomNav(
            selectedIndex: _navIndex,
            onSelected: _onNavSelected,
          ),
        );
      case 2:
        return Scaffold(
          backgroundColor: Colors.white,
          body: const FamilyPage(),
          bottomNavigationBar: BottomNav(
            selectedIndex: _navIndex,
            onSelected: _onNavSelected,
          ),
        );
      case 3:
        return Scaffold(
          backgroundColor: Colors.white,
          body: const ProfilePage(),
          bottomNavigationBar: BottomNav(
            selectedIndex: _navIndex,
            onSelected: _onNavSelected,
          ),
        );
      default:
        return _buildMessagesTab();
    }
  }

  Widget _buildMessagesTab() {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(
        requestCount: _requestCount,
        onFindFriends: _openFindFriends,
        onFriendRequests: _openFriendRequests,
        onTabSelected: _onNavSelected,
        onChangePassword: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ChangePasswordPage(),
          ),
        ),
        onSecurityQuestions: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SecurityQuestionsPage(),
          ),
        ),
      ),
      body: Column(
        children: [
          Navbar(
            notificationCount: _requestCount,
            onNotificationTap: _openFriendRequests,
            onMenuTap: () => Scaffold.of(context).openDrawer(),
          ),
          MessagesHeader(onAddTap: _openFindFriends),
          _SearchBarButton(onTap: _openFindFriends),
          CategoryTabs(
            selected: _selectedTab,
            onSelected: (t) => setState(() => _selectedTab = t),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadConversations,
              child: _buildChatArea(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: _navIndex,
        onSelected: _onNavSelected,
      ),
    );
  }

  Widget _buildChatArea() {
    return Column(
      children: [
        if (_selectedTab == 'All')
          _AiEntryCard(preview: _aiPreview, time: _aiTime, onTap: _openAiChat),
        Expanded(child: _buildConversationArea()),
      ],
    );
  }

  Widget _buildConversationArea() {
    if (_loadingChats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_chatsError != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _chatsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadConversations,
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (_filteredChats.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        children: const [
          Icon(Icons.chat_bubble_outline, size: 56, color: Color(0xFFB7BBC1)),
          SizedBox(height: 16),
          Text(
            'No conversations yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF777777),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Search for friends by their Google email using the search bar above, '
            'then start chatting.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Color(0xFF9A9A9A), fontSize: 13, height: 1.4),
          ),
        ],
      );
    }
    return ChatList(
      chats: _filteredChats,
      onChatTap: (chat) {
        _openChat(chat);
      },
    );
  }
}

class _SearchBarButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 14),
                child: Icon(Icons.search, color: Color(0xFF9A9A9A), size: 20),
              ),
              SizedBox(width: 8),
              Text(
                'Search',
                style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinned entry that opens the AI assistant conversation.
class _AiEntryCard extends StatefulWidget {
  const _AiEntryCard({
    required this.preview,
    required this.time,
    required this.onTap,
  });

  final String preview;
  final String? time;
  final VoidCallback onTap;

  @override
  State<_AiEntryCard> createState() => _AiEntryCardState();
}

class _AiEntryCardState extends State<_AiEntryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          margin: EdgeInsets.symmetric(
            horizontal: _hovering ? 8 : 12,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: _hovering ? const Color(0xFFEAF2FE) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.brand.withValues(
                alpha: _hovering ? 0.45 : 0.25,
              ),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40246BCE),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'AI Assistant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        if (widget.time != null)
                          Text(
                            widget.time!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9A9A9A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

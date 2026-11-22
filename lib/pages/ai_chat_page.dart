import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import '../theme/app_theme.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  List<AiChatMessage> _messages = const [];
  bool _loading = true;
  String? _error;
  bool _enabled = true;

  bool _streaming = false;
  bool _finishing = false;
  String _pendingReply = '';
  int _revealed = 0;
  Timer? _typeTimer;
  StreamSubscription<AiChatChunk>? _replySub;

  static const _welcomeText =
      "Hi! I'm the Global Village AI assistant. Ask me anything — ideas, "
      'translations, travel tips, or help using the app.';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _replySub?.cancel();
    _typeTimer?.cancel();
    _chatService.close();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _chatService.fetchAiMessages();
      if (!mounted) return;
      setState(() {
        _enabled = summary.enabled;
        _messages = summary.messages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _streaming) return;
    _inputController.clear();
    setState(() {
      _messages = [
        ..._messages,
        AiChatMessage(
          id: '',
          role: 'user',
          content: text,
          createdAt: DateTime.now(),
        ),
      ];
      _streaming = true;
      _finishing = false;
      _pendingReply = '';
      _revealed = 0;
    });
    _scrollToBottom();

    _replySub = _chatService.sendAiMessage(text).listen(
      (chunk) {
        if (!mounted) return;
        if (chunk.delta != null) {
          _pendingReply += chunk.delta!;
          _ensureTyping();
        }
        if (chunk.done) {
          _finishing = true;
          _ensureTyping();
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        _resetStreamState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      },
      onDone: () {
        if (!mounted || !_streaming) return;
        // Stream ended abruptly without a done event: finalize what we have.
        _finishing = true;
        _ensureTyping();
      },
    );
  }

  /// Reveals the accumulated reply a few characters per tick, so the reply
  /// types out smoothly whether deltas arrive one by one (native) or in a
  /// single burst (web, where XHR cannot stream incrementally).
  void _ensureTyping() {
    _typeTimer ??= Timer.periodic(const Duration(milliseconds: 24), (_) {
      if (!mounted) {
        _typeTimer?.cancel();
        _typeTimer = null;
        return;
      }
      if (_revealed < _pendingReply.length) {
        setState(() {
          _revealed = math.min(_revealed + 3, _pendingReply.length);
        });
        _scrollToBottom();
      } else if (_finishing) {
        _finalizeReply();
      } else {
        // Caught up with the stream; idle until more deltas arrive.
        _typeTimer?.cancel();
        _typeTimer = null;
      }
    });
  }

  void _finalizeReply() {
    _typeTimer?.cancel();
    _typeTimer = null;
    final content = _pendingReply;
    setState(() {
      if (content.isNotEmpty) {
        _messages = [
          ..._messages,
          AiChatMessage(
            id: '',
            role: 'assistant',
            content: content,
            createdAt: DateTime.now(),
          ),
        ];
      }
      _streaming = false;
      _finishing = false;
      _pendingReply = '';
      _revealed = 0;
    });
    _scrollToBottom();
  }

  void _resetStreamState() {
    _typeTimer?.cancel();
    _typeTimer = null;
    if (!mounted) return;
    setState(() {
      _streaming = false;
      _finishing = false;
      _pendingReply = '';
      _revealed = 0;
    });
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Clear AI chat history?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
        content: const Text(
          'All messages with the AI assistant will be deleted. '
          'This cannot be undone.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6F6F6F)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(
                color: AppTheme.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _chatService.clearAiMessages();
      if (!mounted) return;
      setState(() => _messages = const []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          if (!_enabled) _buildDisabledNotice(),
          Expanded(child: _buildBody()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Assistant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.ink,
                          ),
                        ),
                        Text(
                          'Smart assistant · Always online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9A9A9A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppTheme.ink),
                  onSelected: (value) {
                    if (value == 'clear') _confirmClearHistory();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text(
                        'Clear chat history',
                        style: TextStyle(color: AppTheme.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E8E8)),
        ],
      ),
    );
  }

  Widget _buildDisabledNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8D48A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFB08500), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI is not configured yet. The server admin needs to set '
              'AI_API_KEY in the chat server .env file — a free key from '
              'open.bigmodel.cn works with the default glm-4-flash model.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF8A6D00),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadHistory,
            child: const Text('Retry'),
          ),
        ],
      );
    }
    final showWelcome = _messages.isEmpty && !_streaming;
    final itemCount =
        (showWelcome ? 1 : 0) + _messages.length + (_streaming ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showWelcome && index == 0) {
          return _buildBubble(
            text: _welcomeText,
            incoming: true,
            time: null,
          );
        }
        final messageIndex = index - (showWelcome ? 1 : 0);
        if (messageIndex < _messages.length) {
          final message = _messages[messageIndex];
          return _buildBubble(
            text: message.content,
            incoming: !message.fromUser,
            time: _formatTime(message.createdAt),
          );
        }
        return _buildStreamingBubble();
      },
    );
  }

  Widget _aiAvatar({double radius = 14}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        gradient: AppTheme.brandGradient,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.smart_toy, color: Colors.white, size: radius + 2),
    );
  }

  Widget _buildBubble({
    required String text,
    required bool incoming,
    String? time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            incoming ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (incoming) ...[
            _aiAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: incoming
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: incoming
                        ? const Color(0xFFE8E8E8)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(incoming ? 6 : 18),
                      bottomRight: Radius.circular(incoming ? 18 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.ink,
                      height: 1.35,
                    ),
                  ),
                ),
                if (time != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9A9A),
                        ),
                      ),
                      if (!incoming) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all,
                          size: 14,
                          color: Color(0xFF4CAF50),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    final shown = _pendingReply.substring(
      0,
      math.min(_revealed, _pendingReply.length),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _aiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFE8E8E8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: shown.isEmpty
                  ? const _ThinkingDots()
                  : Text(
                      '$shown${_streaming ? ' ▍' : ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.ink,
                        height: 1.35,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final hasText = _inputController.text.isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 4,
        left: 8,
        right: 8,
        top: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_streaming,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Ask AI anything...',
                  hintStyle: TextStyle(color: Color(0xFF9A9A9A), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          if (_streaming)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(
                Icons.send,
                color: hasText ? AppTheme.ink : const Color(0xFFB7BBC1),
              ),
              onPressed: hasText ? _send : null,
            ),
        ],
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final wave = math.max(
              0.0,
              math.sin(_controller.value * 2 * math.pi - i * math.pi / 3),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: const Color(0xFF9A9A9A).withValues(
                    alpha: 0.35 + 0.65 * wave,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

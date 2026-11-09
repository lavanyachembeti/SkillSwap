import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../models/conversation_model.dart';
import '../../services/api_service.dart';
import '../../services/chat_service.dart';

/// A message model for the responsive conversation view.
class ChatMessageItem {
  final int? id;
  final String text;
  final bool isMe;
  final String time;

  const ChatMessageItem({
    this.id,
    required this.text,
    required this.isMe,
    required this.time,
  });

  factory ChatMessageItem.fromModel(
    ChatMessageModel model,
    String currentUsername,
  ) {
    return ChatMessageItem(
      id: model.id,
      text: model.message,
      isMe: model.isSentBy(currentUsername),
      time: model.formattedTime,
    );
  }
}

/// SkillSwap Messages (Chat) Screen.
///
/// Supports responsive presentation across:
/// - Small mobile phones (320px onwards) with no horizontal scroll or overflow.
/// - Tablets (balanced spacing, centered constraints).
/// - Desktop & laptops (centered layout, avoiding excessive stretching).
/// - Responsive conversation view with text wrapping and keyboard avoidance.
class ChatScreen extends StatefulWidget {
  final ChatService? chatService;
  final ApiService? apiService;
  final int? conversationId;
  final int? peerUserId;
  final String? peerName;
  final String? peerSkill;
  final List<ChatMessageItem>? initialMessages;

  const ChatScreen({
    super.key,
    this.chatService,
    this.apiService,
    this.conversationId,
    this.peerUserId,
    this.peerName,
    this.peerSkill,
    this.initialMessages,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chatService;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ConversationModel> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  String _currentUsername = '';

  int? _activeConversationId;
  int? _activePeerUserId;
  String? _activePeerName;
  String? _activePeerSkill;
  List<ChatMessageItem> _messages = [];
  bool _isLoadingMessages = false;
  String? _messagesError;

  bool get _isConversationActive =>
      _activePeerName != null && _activePeerName!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _chatService =
        widget.chatService ?? ChatService(apiService: widget.apiService);
    _activeConversationId = widget.conversationId;
    _activePeerUserId = widget.peerUserId;
    _activePeerName = widget.peerName;
    _activePeerSkill = widget.peerSkill;
    _messages = widget.initialMessages != null
        ? List<ChatMessageItem>.from(widget.initialMessages!)
        : [];

    _initChat();
  }

  Future<void> _initChat() async {
    try {
      _currentUsername = await _chatService.getCurrentUsername();
    } catch (_) {}

    if (!mounted) return;

    if (_activePeerUserId != null && _activeConversationId == null) {
      // Start or retrieve conversation with peer user ID
      await _startConversationWithPeerId(_activePeerUserId!);
    } else if (_activeConversationId != null) {
      await _loadMessages(_activeConversationId!);
    } else if (!_isConversationActive) {
      await _fetchConversations();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (_activePeerName == null && args != null) {
      if (args is Map<String, dynamic>) {
        setState(() {
          _activePeerName =
              args['peerName']?.toString() ?? args['username']?.toString();
          _activePeerSkill = args['peerSkill']?.toString();
          final rawConvId = args['conversationId'];
          if (rawConvId is int) {
            _activeConversationId = rawConvId;
          } else if (rawConvId != null) {
            _activeConversationId = int.tryParse(rawConvId.toString());
          }
          final rawPeerId = args['peerUserId'];
          if (rawPeerId is int) {
            _activePeerUserId = rawPeerId;
          } else if (rawPeerId != null) {
            _activePeerUserId = int.tryParse(rawPeerId.toString());
          }
        });
        if (_activePeerUserId != null && _activeConversationId == null) {
          _startConversationWithPeerId(_activePeerUserId!);
        } else if (_activeConversationId != null) {
          _loadMessages(_activeConversationId!);
        }
      } else if (args is String && args.isNotEmpty) {
        setState(() {
          _activePeerName = args;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    setState(() {
      _isLoadingConversations = true;
      _conversationsError = null;
    });

    try {
      if (_currentUsername.isEmpty) {
        _currentUsername = await _chatService.getCurrentUsername();
      }
      final list = await _chatService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = list;
        _isLoadingConversations = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _conversationsError = e.message;
        _isLoadingConversations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _conversationsError = 'Unable to load conversations. Please try again.';
        _isLoadingConversations = false;
      });
    }
  }

  Future<void> _startConversationWithPeerId(int peerId) async {
    setState(() {
      _isLoadingMessages = true;
      _messagesError = null;
    });

    try {
      final conv = await _chatService.getOrCreateConversation(peerId);
      if (!mounted) return;
      setState(() {
        _activeConversationId = conv.id;
        if (_activePeerName == null || _activePeerName!.isEmpty) {
          _activePeerName = conv.getPartnerName(_currentUsername);
        }
      });
      await _loadMessages(conv.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMessages = false;
        _messagesError = 'Unable to initiate conversation.';
      });
    }
  }

  Future<void> _loadMessages(int conversationId) async {
    setState(() {
      _isLoadingMessages = true;
      _messagesError = null;
    });

    try {
      if (_currentUsername.isEmpty) {
        _currentUsername = await _chatService.getCurrentUsername();
      }
      final list = await _chatService.getMessages(conversationId);
      if (!mounted) return;
      setState(() {
        _messages = list
            .map((m) => ChatMessageItem.fromModel(m, _currentUsername))
            .toList();
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messagesError = e.message;
        _isLoadingMessages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messagesError =
            'Failed to load messages. Please check your connection.';
        _isLoadingMessages = false;
      });
    }
  }

  void _openConversation(ConversationModel conv) {
    final partnerName = conv.getPartnerName(_currentUsername);
    setState(() {
      _activeConversationId = conv.id;
      _activePeerName = partnerName;
      _activePeerSkill = 'Skill Exchange Partner';
      _messages = [];
    });
    _loadMessages(conv.id);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final now = DateTime.now();
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $ampm';

    setState(() {
      _messages.add(ChatMessageItem(text: text, isMe: true, time: timeStr));
      _messageController.clear();
    });

    _scrollToBottom();

    if (_activeConversationId != null) {
      try {
        await _chatService.sendMessage(_activeConversationId!, text);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deliver message: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _closeConversation() {
    setState(() {
      _activeConversationId = null;
      _activePeerUserId = null;
      _activePeerName = null;
      _activePeerSkill = null;
      _messages = [];
    });
    _fetchConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_isConversationActive) {
              return _buildConversationView(context, constraints);
            }
            if (_isLoadingConversations) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading messages...',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (_conversationsError != null && _conversations.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: AppTheme.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _conversationsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _fetchConversations,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (_conversations.isNotEmpty) {
              return _buildConversationListView(context, constraints);
            }
            return _buildEmptyStateView(context, constraints);
          },
        ),
      ),
    );
  }

  /// App bar adapting between Messages title and active Conversation header.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_isConversationActive) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Messages',
          onPressed: _closeConversation,
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFDBEAFE),
              child: Text(
                _activePeerName!.isNotEmpty
                    ? _activePeerName![0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _activePeerName!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_activePeerSkill != null &&
                      _activePeerSkill!.trim().isNotEmpty)
                    Text(
                      _activePeerSkill!.trim(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppBar(
      title: const Text(
        'Messages',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _isLoadingConversations ? null : _fetchConversations,
        ),
      ],
    );
  }

  /// Active conversation list view when conversations exist.
  Widget _buildConversationListView(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final isTabletOrDesktop = constraints.maxWidth >= 600;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isTabletOrDesktop ? 720 : double.infinity,
        ),
        child: RefreshIndicator(
          onRefresh: _fetchConversations,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final conv = _conversations[index];
              final partnerName = conv.getPartnerName(_currentUsername);

              return Card(
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.borderLight, width: 1),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _openConversation(conv),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFDBEAFE),
                          child: Text(
                            partnerName.isNotEmpty
                                ? partnerName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partnerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Skill Exchange Partner',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Responsive empty-state view matching the SkillSwap visual reference.
  Widget _buildEmptyStateView(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final screenWidth = constraints.maxWidth;
    final isSmallMobile = screenWidth < 360;
    final isTabletOrDesktop = screenWidth >= 600;

    final double iconPadding = isSmallMobile
        ? 16.0
        : (isTabletOrDesktop ? 22.0 : 20.0);
    final double iconSize = isSmallMobile
        ? 40.0
        : (isTabletOrDesktop ? 54.0 : 48.0);
    final double titleFontSize = isSmallMobile
        ? 18.0
        : (isTabletOrDesktop ? 22.0 : 20.0);
    final double bodyFontSize = isSmallMobile
        ? 13.0
        : (isTabletOrDesktop ? 15.0 : 14.0);
    final double spacingLarge = isSmallMobile ? 14.0 : 20.0;
    final double horizontalPadding = isSmallMobile
        ? 16.0
        : (isTabletOrDesktop ? 32.0 : 24.0);

    return RefreshIndicator(
      onRefresh: _fetchConversations,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
            minWidth: constraints.maxWidth,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(iconPadding),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0E7FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: iconSize,
                        color: const Color(0xFF4338CA),
                      ),
                    ),
                    SizedBox(height: spacingLarge),
                    Text(
                      'SkillSwap Messages',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chat with your matched skill partners and arrange sessions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Responsive active conversation screen.
  Widget _buildConversationView(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final screenWidth = constraints.maxWidth;
    final isSmall = screenWidth < 360;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            // Message List
            Expanded(
              child: _isLoadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : _messagesError != null && _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _messagesError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_activeConversationId != null) {
                                  _loadMessages(_activeConversationId!);
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No messages yet. Send a greeting to start chatting!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 13 : 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 10.0 : 16.0,
                        vertical: 12.0,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return _buildMessageBubble(msg, screenWidth, isSmall);
                      },
                    ),
            ),

            // Message Input Bar
            _buildInputBar(context, isSmall),
          ],
        ),
      ),
    );
  }

  /// Message bubble with correct wrapping, max-width and styling.
  Widget _buildMessageBubble(
    ChatMessageItem msg,
    double screenWidth,
    bool isSmall,
  ) {
    final bubbleMaxWidth = isSmall
        ? screenWidth * 0.82
        : (screenWidth < 600 ? screenWidth * 0.75 : 460.0);

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12.0 : 14.0,
          vertical: isSmall ? 8.0 : 10.0,
        ),
        decoration: BoxDecoration(
          color: msg.isMe ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(msg.isMe ? 14 : 2),
            bottomRight: Radius.circular(msg.isMe ? 2 : 14),
          ),
          border: msg.isMe
              ? null
              : Border.all(color: AppTheme.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: msg.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isMe ? Colors.white : AppTheme.textPrimary,
                fontSize: isSmall ? 13.0 : 14.0,
                height: 1.35,
              ),
              softWrap: true,
            ),
            const SizedBox(height: 3),
            Text(
              msg.time,
              style: TextStyle(
                color: msg.isMe
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppTheme.textMuted,
                fontSize: isSmall ? 10.0 : 11.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Message input field bar with send button.
  Widget _buildInputBar(BuildContext context, bool isSmall) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderLight, width: 1)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8.0 : 12.0,
        vertical: 8.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  fontSize: isSmall ? 13.0 : 14.0,
                  color: AppTheme.textMuted,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 12.0 : 16.0,
                  vertical: 10.0,
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
              tooltip: 'Send message',
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

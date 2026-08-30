import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../state/chat_notifier.dart';
import '../state/session_notifier.dart';
import '../widgets/chat_empty_view.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/connection_status_banner.dart';
import '../widgets/memory_drawer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/session_drawer.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSessionAndChat();
    });
  }

  Future<void> _initSessionAndChat() async {
    final sessionNotifier = ref.read(sessionProvider.notifier);
    await sessionNotifier.loadSessions();

    final sessionState = ref.read(sessionProvider);
    if (sessionState.sessions.isEmpty) {
      await sessionNotifier.createSession(title: 'Casual English Practice');
    }

    final activeSession = ref.read(sessionProvider).currentSession;
    if (activeSession != null) {
      await ref.read(chatProvider.notifier).switchSession(activeSession.id);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final chatState = ref.watch(chatProvider);

    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          (previous?.isStreaming == true && next.isStreaming == true)) {
        _scrollToBottom(animated: true);
      }
    });

    final currentSession = sessionState.currentSession;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SessionDrawer(
        sessions: sessionState.sessions,
        currentSession: currentSession,
        onSelectSession: (session) {
          ref.read(sessionProvider.notifier).selectSession(session);
          ref.read(chatProvider.notifier).switchSession(session.id);
        },
        onCreateSession: () async {
          final newSession = await ref.read(sessionProvider.notifier).createSession();
          if (newSession != null) {
            await ref.read(chatProvider.notifier).switchSession(newSession.id);
          }
        },
        onDeleteSession: (sessionId) {
          ref.read(sessionProvider.notifier).deleteSession(sessionId);
        },
      ),
      endDrawer: const MemoryDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, size: 24.r),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentSession?.title ?? 'Snape Companion',
              style: AppTypography.titleMedium,
            ),
            Row(
              children: [
                Container(
                  width: 6.r,
                  height: 6.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: chatState.isSpeaking
                        ? AppColors.indigoAccent
                        : (chatState.isConnected
                            ? AppColors.statusOnline
                            : (chatState.isReconnecting
                                ? AppColors.statusReconnecting
                                : AppColors.statusError)),
                  ),
                ),
                SizedBox(width: AppSpacing.xs.w),
                Text(
                  chatState.isSpeaking
                      ? 'Speaking...'
                      : (chatState.isConnected
                          ? 'Live Companion'
                          : (chatState.isReconnecting ? 'Reconnecting...' : 'Offline')),
                  style: AppTypography.caption,
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.psychology_outlined, size: 22.r, color: AppColors.indigoAccent),
            tooltip: 'Memory Drawer',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined, size: 22.r, color: AppColors.indigoAccent),
            tooltip: 'New Practice Session',
            onPressed: () async {
              final newSession = await ref.read(sessionProvider.notifier).createSession();
              if (newSession != null) {
                await ref.read(chatProvider.notifier).switchSession(newSession.id);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectionStatusBanner(
            status: chatState.connectionStatus,
            errorMessage: chatState.errorMessage,
            onRetry: () => ref.read(chatProvider.notifier).retryConnection(),
          ),
          Expanded(
            child: chatState.isLoadingHistory
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.indigoAccent),
                    ),
                  )
                : chatState.messages.isEmpty
                    ? ChatEmptyView(
                        onStartPrompt: () {
                          ref.read(chatProvider.notifier).sendMessage('Hello Snape! Let\'s practice.');
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          return MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                          );
                        },
                      ),
          ),
          ChatInputBar(
            isStreaming: chatState.isStreaming,
            isRecording: _isRecording,
            onMicTap: () {
              setState(() {
                _isRecording = !_isRecording;
              });
            },
            onSendMessage: (text) {
              ref.read(chatProvider.notifier).sendMessage(text);
            },
          ),
        ],
      ),
    );
  }
}

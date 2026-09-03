import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/speech_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/session.dart';
import '../state/chat_notifier.dart';
import '../state/providers.dart';
import '../state/session_notifier.dart';
import '../widgets/chat_empty_view.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/connection_status_banner.dart';
import '../widgets/materials_panel.dart';
import '../widgets/memory_drawer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/rename_session_dialog.dart';
import '../widgets/session_drawer.dart';
import 'voice_call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? sessionId;
  final String? spaceSlug;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    this.sessionId,
    this.spaceSlug,
    this.initialMessage,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final SpeechService _speechService = SpeechService();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _textController.text = widget.initialMessage!;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSessionAndChat();
    });
  }

  Future<void> _initSessionAndChat() async {
    if (widget.sessionId != null) {
      if (widget.spaceSlug != null) {
        final spaceState = ref.read(spaceProvider);
        if (spaceState.activeSpace?.slug != widget.spaceSlug) {
          final matching = spaceState.spaces
              .where((s) => s.slug == widget.spaceSlug)
              .firstOrNull;
          if (matching != null) {
            ref.read(spaceProvider.notifier).selectSpace(matching);
          }
        }
      }

      final chatState = ref.read(chatProvider);
      if (chatState.sessionId != widget.sessionId) {
        await ref.read(chatProvider.notifier).switchSession(widget.sessionId!);
      }
      return;
    }

    final activeSpace = ref.read(spaceProvider).activeSpace;
    final spaceSlug = widget.spaceSlug ?? activeSpace?.slug;
    final sessionNotifier = ref.read(sessionProvider.notifier);

    final resolvedSession = await sessionNotifier.ensureActiveSession(
      spaceSlug: spaceSlug ?? 'english_b2',
      defaultTitle: activeSpace?.displayName ?? 'Casual English Practice',
    );
    if (mounted) {
      final currentChatId = ref.read(chatProvider).sessionId;
      if (currentChatId != resolvedSession.id) {
        await ref.read(chatProvider.notifier).switchSession(resolvedSession.id);
      }
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

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _speechService.stopListening();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    } else {
      final available = await _speechService.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Speech recognition is not available on this device or permission was denied.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isRecording = true;
        });
      }
      final prefs = await SharedPreferences.getInstance();
      final localeId = prefs.getString('stt_locale') ?? 'id_ID';

      await _speechService.startListening(
        localeId: localeId,
        onResult: (text, isFinal) {
          if (mounted && text.isNotEmpty) {
            setState(() {
              _textController.text = text;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            });
          }
        },
        onListeningStateChanged: (listening) {
          if (mounted) {
            setState(() {
              _isRecording = listening;
            });
          }
        },
      );
    }
  }

  void _openVoiceCall() {
    final activeSpace = ref.read(spaceProvider).activeSpace;
    if (activeSpace != null && !activeSpace.voiceCallEnabled) return;
    if (_isRecording) {
      _speechService.stopListening();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
    Navigator.of(context).push(VoiceCallScreen.route());
  }

  Future<void> _renameSession(SessionModel session) async {
    final newTitle = await RenameSessionDialog.show(
      context,
      currentTitle: session.title,
    );
    if (newTitle != null &&
        newTitle.isNotEmpty &&
        newTitle != session.title &&
        mounted) {
      final success = await ref
          .read(sessionProvider.notifier)
          .renameSession(session.id, newTitle);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to rename session'),
            backgroundColor: AppColors.statusError,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _speechService.stopListening();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final chatState = ref.watch(chatProvider);
    final spaceState = ref.watch(spaceProvider);

    final effectiveSessionId = widget.sessionId ?? chatState.sessionId;
    final currentSession = (effectiveSessionId != null
            ? sessionState.sessions
                .where((s) => s.id == effectiveSessionId)
                .firstOrNull
            : null) ??
        sessionState.currentSession;

    final effectiveSpaceSlug = widget.spaceSlug ??
        currentSession?.spaceSlug ??
        spaceState.activeSpace?.slug;
    final activeSpace = (effectiveSpaceSlug != null
            ? spaceState.spaces
                .where((s) => s.slug == effectiveSpaceSlug)
                .firstOrNull
            : null) ??
        spaceState.activeSpace;

    final isVoiceCallEnabled = activeSpace?.voiceCallEnabled ?? true;
    final isMaterialsEnabled = activeSpace?.cefrLevel != null;

    final isInitializing = (widget.sessionId != null &&
            chatState.sessionId != widget.sessionId) ||
        chatState.isLoadingHistory ||
        (chatState.sessionId == null &&
            widget.sessionId == null &&
            sessionState.isLoading);

    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          (previous?.isStreaming == true && next.isStreaming == true)) {
        _scrollToBottom(animated: true);
      }
    });

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
          final newSession =
              await ref.read(sessionProvider.notifier).createSession(
                    title: activeSpace?.displayName ??
                        'Casual English Practice',
                    spaceSlug: activeSpace?.slug ?? 'english_b2',
                  );
          if (newSession != null) {
            await ref.read(chatProvider.notifier).switchSession(newSession.id);
          }
        },
        onRenameSession: (session) => _renameSession(session),
        onDeleteSession: (sessionId) {
          ref.read(sessionProvider.notifier).deleteSession(sessionId);
        },
      ),
      endDrawer: const MemoryDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Navigator.canPop(context)
                ? Icons.arrow_back_rounded
                : Icons.home_outlined,
            size: 22.r,
          ),
          tooltip: Navigator.canPop(context) ? 'Back' : 'Lobby',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        title: InkWell(
          onTap: currentSession != null
              ? () => _renameSession(currentSession)
              : null,
          borderRadius: BorderRadius.circular(AppRadii.sm.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 2.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        currentSession?.title ?? 'Snape Companion',
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (currentSession != null) ...[
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.edit_outlined,
                        size: 14.r,
                        color: AppColors.slateTertiary,
                      ),
                    ],
                  ],
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
                              : (chatState.isReconnecting
                                  ? 'Reconnecting...'
                                  : 'Offline')),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (isMaterialsEnabled && activeSpace != null)
            IconButton(
              icon: Icon(Icons.menu_book_rounded,
                  size: 22.r, color: AppColors.indigoAccent),
              tooltip: 'Materi',
              onPressed: () {
                MaterialsPanel.show(
                  context,
                  spaceSlug: activeSpace.slug,
                  cefrLevel: activeSpace.cefrLevel,
                  displayName: activeSpace.displayName,
                );
              },
            ),
          if (isVoiceCallEnabled)
            IconButton(
              icon: Icon(Icons.phone_in_talk_rounded,
                  size: 22.r, color: AppColors.indigoAccent),
              tooltip: 'Start Voice Call',
              onPressed: _openVoiceCall,
            ),
          IconButton(
            icon: Icon(Icons.psychology_outlined,
                size: 22.r, color: AppColors.indigoAccent),
            tooltip: 'Memory Drawer',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined,
                size: 22.r, color: AppColors.indigoAccent),
            tooltip: 'New Practice Session',
            onPressed: () async {
              final newSession =
                  await ref.read(sessionProvider.notifier).createSession(
                        title: activeSpace?.displayName ??
                            'Casual English Practice',
                        spaceSlug: activeSpace?.slug ?? 'english_b2',
                      );
              if (newSession != null) {
                await ref
                    .read(chatProvider.notifier)
                    .switchSession(newSession.id);
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
            child: isInitializing
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.indigoAccent),
                    ),
                  )
                : chatState.messages.isEmpty
                    ? ChatEmptyView(
                        starterPrompts: activeSpace?.starterPrompts,
                        space: activeSpace,
                        onSelectPrompt: (prompt) {
                          ref
                              .read(chatProvider.notifier)
                              .sendMessage(prompt);
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                        itemCount: chatState.messages.length,
                        itemBuilder: (context, index) {
                          final message = chatState.messages[index];
                          final isPlaying =
                              chatState.playingMessageId == message.id &&
                                  chatState.isSpeaking;
                          final isLoadingAudio =
                              chatState.loadingAudioMessageId == message.id;
                          return MessageBubble(
                            key: ValueKey(message.id),
                            message: message,
                            isPlaying: isPlaying,
                            isLoadingAudio: isLoadingAudio,
                            onPlayAudio: () {
                              ref
                                  .read(chatProvider.notifier)
                                  .playMessageAudio(message.id, message.content);
                            },
                            onStopAudio: () {
                              ref.read(chatProvider.notifier).stopAudio();
                            },
                          );
                        },
                      ),
          ),
          ChatInputBar(
            controller: _textController,
            isStreaming: chatState.isStreaming,
            isRecording: _isRecording,
            onMicTap: _toggleVoiceRecording,
            onVoiceCallTap: isVoiceCallEnabled ? _openVoiceCall : null,
            onSendMessage: (text) {
              ref.read(chatProvider.notifier).sendMessage(text);
            },
          ),
        ],
      ),
    );
  }
}

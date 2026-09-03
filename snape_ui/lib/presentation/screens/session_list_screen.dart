import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/session.dart';
import '../../domain/models/space.dart';
import '../state/chat_notifier.dart';
import '../state/session_notifier.dart';
import '../widgets/rename_session_dialog.dart';
import '../widgets/session_list_item.dart';
import 'chat_screen.dart';

class SessionListScreen extends ConsumerStatefulWidget {
  final SpaceModel space;

  const SessionListScreen({
    super.key,
    required this.space,
  });

  @override
  ConsumerState<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends ConsumerState<SessionListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).loadSessions(
            spaceSlug: widget.space.slug,
          );
    });
  }

  Future<void> _createNewSession() async {
    final title = widget.space.displayName;
    final newSession = await ref.read(sessionProvider.notifier).createSession(
          title: title,
          spaceSlug: widget.space.slug,
        );
    if (newSession != null && mounted) {
      await ref.read(chatProvider.notifier).switchSession(newSession.id);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              sessionId: newSession.id,
              spaceSlug: widget.space.slug,
            ),
          ),
        );
      }
    }
  }

  Future<void> _openSession(SessionModel session) async {
    ref.read(sessionProvider.notifier).selectSession(session);
    await ref.read(chatProvider.notifier).switchSession(session.id);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            sessionId: session.id,
            spaceSlug: widget.space.slug,
          ),
        ),
      );
    }
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
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);
    final sessions = sessionState.sessions
        .where((s) => s.spaceSlug == widget.space.slug)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.parchmentBackground,
      appBar: AppBar(
        title: Text(
          widget.space.displayName,
          style: AppTypography.titleMedium,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, size: 22.r),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_comment_outlined,
              size: 22.r,
              color: AppColors.indigoAccent,
            ),
            tooltip: 'New Session',
            onPressed: _createNewSession,
          ),
        ],
      ),
      body: sessionState.isLoading && sessions.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.indigoAccent),
              ),
            )
          : RefreshIndicator(
              color: AppColors.indigoAccent,
              onRefresh: () => ref
                  .read(sessionProvider.notifier)
                  .loadSessions(spaceSlug: widget.space.slug),
              child: sessions.isEmpty
                  ? _buildEmptyState()
                  : _buildSessionListView(
                      sessions, sessionState.currentSession),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewSession,
        backgroundColor: AppColors.indigoAccent,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add_rounded, size: 20.r),
        label: Text(
          'New Session',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl.w,
        vertical: AppSpacing.xxl.h,
      ),
      children: [
        SizedBox(height: 60.h),
        Center(
          child: Container(
            width: 64.r,
            height: 64.r,
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 32.r,
              color: AppColors.slateTertiary,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md.h),
        Text(
          'No Sessions Yet',
          style: AppTypography.titleMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          'Start a new conversation in ${widget.space.displayName} to begin practice.',
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: AppSpacing.lg.h),
        Center(
          child: ElevatedButton.icon(
            onPressed: _createNewSession,
            icon: Icon(Icons.add_rounded, size: 18.r),
            label: const Text('Start Conversation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigoAccent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w,
                vertical: AppSpacing.sm.h,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionListView(
      List<SessionModel> sessions, SessionModel? currentSession) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.base.w,
        vertical: AppSpacing.md.h,
      ),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelected = currentSession?.id == session.id;

        return SessionListItem(
          session: session,
          isSelected: isSelected,
          onTap: () => _openSession(session),
          onRename: () => _renameSession(session),
          onDelete: () {
            ref.read(sessionProvider.notifier).deleteSession(session.id);
          },
        );
      },
    );
  }
}

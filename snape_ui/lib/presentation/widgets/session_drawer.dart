import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/session.dart';

class SessionDrawer extends StatelessWidget {
  final List<SessionModel> sessions;
  final SessionModel? currentSession;
  final ValueChanged<SessionModel> onSelectSession;
  final VoidCallback onCreateSession;
  final ValueChanged<SessionModel> onRenameSession;
  final ValueChanged<String> onDeleteSession;

  const SessionDrawer({
    super.key,
    required this.sessions,
    required this.currentSession,
    required this.onSelectSession,
    required this.onCreateSession,
    required this.onRenameSession,
    required this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.parchmentBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.base.w,
                vertical: AppSpacing.md.h,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Practice Sessions',
                      style: AppTypography.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: AppColors.indigoAccent, size: 24.r),
                    tooltip: 'New Session',
                    onPressed: () {
                      Navigator.pop(context);
                      onCreateSession();
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Text(
                        'No sessions yet',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.slateTertiary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: sessions.length,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w,
                        vertical: AppSpacing.xs.h,
                      ),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isSelected = currentSession?.id == session.id;
                        final dateStr = DateFormat('MMM d, h:mm a').format(session.createdAt);

                        return Container(
                          margin: EdgeInsets.only(bottom: AppSpacing.xs.h),
                          child: Material(
                            color: isSelected ? AppColors.indigoSoftBackground : AppColors.surfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md.r),
                              side: BorderSide(
                                color: isSelected ? AppColors.indigoAccentLight : AppColors.dividerColor,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              dense: true,
                              title: Text(
                                session.title,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? AppColors.indigoAccent : AppColors.slatePrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                dateStr,
                                style: AppTypography.caption,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 18.r,
                                      color: AppColors.slateTertiary,
                                    ),
                                    tooltip: 'Rename Session',
                                    onPressed: () => onRenameSession(session),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18.r,
                                      color: AppColors.slateTertiary,
                                    ),
                                    tooltip: 'Delete Session',
                                    onPressed: () => onDeleteSession(session.id),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                onSelectSession(session);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

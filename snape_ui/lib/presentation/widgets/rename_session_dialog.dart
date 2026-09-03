import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class RenameSessionDialog extends StatefulWidget {
  final String currentTitle;

  const RenameSessionDialog({
    super.key,
    required this.currentTitle,
  });

  static Future<String?> show(
    BuildContext context, {
    required String currentTitle,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => RenameSessionDialog(currentTitle: currentTitle),
    );
  }

  @override
  State<RenameSessionDialog> createState() => _RenameSessionDialogState();
}

class _RenameSessionDialogState extends State<RenameSessionDialog> {
  late final TextEditingController _controller;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentTitle.length,
    );
    _controller.addListener(_onTextChanged);
    _canSubmit = _controller.text.trim().isNotEmpty;
  }

  void _onTextChanged() {
    final valid = _controller.text.trim().isNotEmpty;
    if (valid != _canSubmit) {
      setState(() {
        _canSubmit = valid;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isNotEmpty) {
      Navigator.of(context).pop(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg.r),
        side: const BorderSide(color: AppColors.dividerColor, width: 1),
      ),
      title: Text(
        'Rename Session',
        style: AppTypography.titleMedium,
      ),
      content: SizedBox(
        width: 320.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: AppTypography.bodyLarge,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter session title',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.slateMuted,
                ),
                filled: true,
                fillColor: AppColors.surfaceWarm,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.base.w,
                  vertical: AppSpacing.sm.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md.r),
                  borderSide: const BorderSide(color: AppColors.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md.r),
                  borderSide: const BorderSide(color: AppColors.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md.r),
                  borderSide: const BorderSide(
                    color: AppColors.indigoAccent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.base.w,
        vertical: AppSpacing.sm.h,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.slateTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.indigoAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.slateMuted.withValues(alpha: 0.3),
            disabledForegroundColor: AppColors.slateTertiary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md.r),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.base.w,
              vertical: AppSpacing.xs.h,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

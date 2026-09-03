import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/material_parsed.dart';

class MaterialVocabCard extends StatelessWidget {
  final VocabMaterialItem item;
  final bool isPlaying;
  final bool isLoadingAudio;
  final VoidCallback onPlay;

  const MaterialVocabCard({
    super.key,
    required this.item,
    required this.isPlaying,
    required this.isLoadingAudio,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadii.md.r),
        border: Border.all(
          color: isPlaying ? AppColors.indigoAccentLight : AppColors.dividerColor,
          width: isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(AppSpacing.md.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (item.definition.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xs.h),
            Text(
              item.definition,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slateSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (item.examples.isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm.h),
            _buildExamplesSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs.w,
            runSpacing: AppSpacing.xs.h,
            children: [
              Text(
                item.term,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.slatePrimary,
                ),
              ),
              if (item.phonetic != null)
                Text(
                  item.phonetic!,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontStyle: FontStyle.italic,
                    color: AppColors.slateTertiary,
                  ),
                ),
              if (item.partOfSpeech != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 6.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.indigoSoftBackground,
                    borderRadius: BorderRadius.circular(AppRadii.xs.r),
                  ),
                  child: Text(
                    item.partOfSpeech!,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.indigoAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildAudioButton(),
      ],
    );
  }

  Widget _buildAudioButton() {
    if (isLoadingAudio) {
      return SizedBox(
        width: 32.r,
        height: 32.r,
        child: Padding(
          padding: EdgeInsets.all(6.r),
          child: CircularProgressIndicator(
            strokeWidth: 2.r,
            color: AppColors.indigoAccent,
          ),
        ),
      );
    }

    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 32.r, minHeight: 32.r),
      icon: Icon(
        isPlaying ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
        size: 20.r,
        color: isPlaying ? AppColors.indigoAccent : AppColors.slateSecondary,
      ),
      tooltip: isPlaying ? 'Berhenti' : 'Dengarkan Pengucapan',
      onPressed: onPlay,
    );
  }

  Widget _buildExamplesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: item.examples.map((example) {
        return Container(
          margin: EdgeInsets.only(top: AppSpacing.xxs.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm.w,
            vertical: AppSpacing.xs.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(AppRadii.sm.r),
            border: Border.all(
              color: AppColors.dividerColor.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 14.r,
                color: AppColors.indigoAccentLight,
              ),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Text(
                  example,
                  style: AppTypography.bodyMedium.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppColors.slatePrimary,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

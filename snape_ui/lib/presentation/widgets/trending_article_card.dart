import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/trending_article.dart';

class TrendingArticleCard extends StatelessWidget {
  final TrendingArticleModel article;
  final ValueChanged<TrendingArticleModel>? onEnglishDiscussion;
  final ValueChanged<TrendingArticleModel>? onIndonesianDiscussion;
  final VoidCallback? onOpenSource;

  const TrendingArticleCard({
    super.key,
    required this.article,
    this.onEnglishDiscussion,
    this.onIndonesianDiscussion,
    this.onOpenSource,
  });

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'politics':
        return const Color(0xFF8C3B3B); // Deep Brick Red
      case 'music':
        return const Color(0xFF5B3F8C); // Rich Purple
      case 'creator_trends':
        return const Color(0xFF2C6E64); // Dark Teal
      case 'general':
      default:
        return AppColors.indigoAccent;
    }
  }

  Color _getCategoryBackgroundColor(String category) {
    switch (category.toLowerCase()) {
      case 'politics':
        return const Color(0xFFFBF0F0);
      case 'music':
        return const Color(0xFFF4EEFB);
      case 'creator_trends':
        return const Color(0xFFEAF5F3);
      case 'general':
      default:
        return AppColors.indigoSoftBackground;
    }
  }

  String _formatPublicationDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes.clamp(1, 59);
      return '${mins}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  (List<String> bullets, String? whyTrending) _parseSummary(String summary) {
    final lines = summary.split('\n');
    final bullets = <String>[];
    final whyTrendingLines = <String>[];
    bool inWhyTrending = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.toLowerCase().startsWith('why it\'s trending:') ||
          trimmed.toLowerCase().startsWith('**why it\'s trending:**') ||
          trimmed.toLowerCase().startsWith('kenapa tren:') ||
          trimmed.toLowerCase().startsWith('alasan tren:')) {
        inWhyTrending = true;
        final colonIndex = trimmed.indexOf(':');
        if (colonIndex != -1 && colonIndex < trimmed.length - 1) {
          final remainder = trimmed.substring(colonIndex + 1).replaceAll('*', '').trim();
          if (remainder.isNotEmpty) {
            whyTrendingLines.add(remainder);
          }
        }
        continue;
      }

      if (inWhyTrending) {
        whyTrendingLines.add(trimmed.replaceAll(RegExp(r'^[-*•]\s*'), ''));
      } else {
        bullets.add(trimmed.replaceAll(RegExp(r'^[-*•]\s*'), ''));
      }
    }

    final whyTrendingText = whyTrendingLines.isNotEmpty
        ? whyTrendingLines.join(' ')
        : null;

    return (bullets, whyTrendingText);
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(article.category);
    final categoryBgColor = _getCategoryBackgroundColor(article.category);
    final (bullets, whyTrending) = _parseSummary(article.summary);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadii.lg.r),
        border: Border.all(
          color: AppColors.dividerColor,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.base.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category Badge + Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: categoryBgColor,
                    borderRadius: BorderRadius.circular(AppRadii.xs.r),
                  ),
                  child: Text(
                    article.categoryDisplayName.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: categoryColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  _formatPublicationDate(article.publishedAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.slateMuted,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm.h),

            // Title
            Text(
              article.title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                height: 1.3,
                color: AppColors.slatePrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),

            // Digest Bullets
            if (bullets.isNotEmpty)
              ...bullets.take(3).map((bullet) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 6.h, right: 6.w),
                          child: Container(
                            width: 4.r,
                            height: 4.r,
                            decoration: const BoxDecoration(
                              color: AppColors.slateTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            bullet,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.slateSecondary,
                              fontSize: 13.sp,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

            // Why It's Trending Rationale Box
            if (whyTrending != null && whyTrending.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xs.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w,
                  vertical: AppSpacing.xs.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(AppRadii.sm.r),
                  border: Border.all(
                    color: AppColors.dividerColor.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.electric_bolt_rounded,
                      size: 14.r,
                      color: categoryColor,
                    ),
                    SizedBox(width: AppSpacing.xs.w),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: "Why it's trending: ",
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.slatePrimary,
                          ),
                          children: [
                            TextSpan(
                              text: whyTrending,
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.normal,
                                color: AppColors.slateSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tags & Source Link
            SizedBox(height: AppSpacing.sm.h),
            Row(
              children: [
                if (article.tags.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: article.tags
                            .take(4)
                            .map((tag) => Container(
                                  margin: EdgeInsets.only(right: 6.w),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceWarm,
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.xs.r),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.sp,
                                      color: AppColors.slateTertiary,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                if (article.sourceUrl.isNotEmpty) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.xs.r),
                    onTap: onOpenSource ??
                        () {
                          Clipboard.setData(ClipboardData(text: article.sourceUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Source URL copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 2.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 13.r,
                            color: AppColors.indigoAccentLight,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'Source',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.indigoAccentLight,
                              fontSize: 11.sp,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            Divider(height: AppSpacing.lg.h, color: AppColors.dividerColor),

            // Discussion Bridge Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEnglishDiscussion != null
                        ? () => onEnglishDiscussion!(article)
                        : null,
                    icon: Text('💬', style: TextStyle(fontSize: 13.sp)),
                    label: Text(
                      'Bahas (English)',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.indigoAccent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      side: const BorderSide(
                        color: AppColors.indigoAccent,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.sm.r),
                      ),
                      backgroundColor: AppColors.indigoSoftBackground.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onIndonesianDiscussion != null
                        ? () => onIndonesianDiscussion!(article)
                        : null,
                    icon: Text('🇮🇩', style: TextStyle(fontSize: 13.sp)),
                    label: Text(
                      'Diskusi Santai',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.slatePrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      side: const BorderSide(
                        color: AppColors.dividerColor,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.sm.r),
                      ),
                      backgroundColor: AppColors.surfaceWarm,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

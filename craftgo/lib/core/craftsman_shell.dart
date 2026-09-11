import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/session_service.dart';
import '../screens/artisan/craftsman_dashboard.dart';
import '../screens/artisan/craftsman_offers_screen.dart';
import '../screens/artisan/craftsman_orders_screen.dart';
import '../screens/artisan/craftsman_profile_screen.dart';
import '../screens/customer/chat_inbox_screen.dart';
import '../screens/custom_order/custom_order_provider.dart';

enum CraftsmanVerificationStatus {
  notSubmitted,
  pendingReview,
  approved,
  rejected,
  retakeRequired,
}

extension CraftsmanVerificationStatusX on CraftsmanVerificationStatus {
  String get apiValue {
    switch (this) {
      case CraftsmanVerificationStatus.notSubmitted:
        return 'not_submitted';
      case CraftsmanVerificationStatus.pendingReview:
        return 'pending_review';
      case CraftsmanVerificationStatus.approved:
        return 'approved';
      case CraftsmanVerificationStatus.rejected:
        return 'rejected';
      case CraftsmanVerificationStatus.retakeRequired:
        return 'retake_required';
    }
  }

  static CraftsmanVerificationStatus fromApi(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'approved':
        return CraftsmanVerificationStatus.approved;
      case 'rejected':
        return CraftsmanVerificationStatus.rejected;
      case 'retake_required':
      case 'retake-required':
        return CraftsmanVerificationStatus.retakeRequired;
      case 'not_submitted':
      case 'not-submitted':
        return CraftsmanVerificationStatus.notSubmitted;
      case 'pending':
      case 'pending_review':
      case 'pending-review':
      default:
        return CraftsmanVerificationStatus.pendingReview;
    }
  }
}

class CraftsmanShell extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final String craftsmanName;
  final String craftsmanCategoryAr;
  final String craftsmanCategoryEn;
  final String craftsmanCity;
  final String craftsmanBio;
  final String craftsmanExperience;

  final String? verificationStatus;
  final String? verificationReason;
  final bool isVerified;
  final bool isPending;
  final VoidCallback? onResubmitDocuments;
  final VoidCallback? onViewSubmission;

  const CraftsmanShell({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.craftsmanName,
    required this.craftsmanCategoryAr,
    required this.craftsmanCategoryEn,
    required this.craftsmanCity,
    required this.craftsmanBio,
    required this.craftsmanExperience,
    this.verificationStatus,
    this.verificationReason,
    this.isVerified = false,
    this.isPending = true,
    this.onResubmitDocuments,
    this.onViewSubmission,
  });

  @override
  State<CraftsmanShell> createState() => _CraftsmanShellState();
}

class _CraftsmanShellState extends State<CraftsmanShell> {
  int _currentIndex = 0;
  late bool _isArabic;
  late bool _isDarkMode;
  String _craftsmanId = '';
  int _dashboardRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _isArabic = widget.isArabic;
    _isDarkMode = widget.isDarkMode;

    final appState = context.read<AppState>();
    _craftsmanId = appState.userId ?? '';

    if (_craftsmanId.isNotEmpty && _isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CustomOrderProvider>().loadForArtisan(_craftsmanId);
      });
    }
  }

  Future<void> _checkApprovalNotification() async {
    final hasSeen =
        await SessionService.hasSeenApprovalDialog(userId: _craftsmanId);
    if (!hasSeen && mounted) {
      await SessionService.setHasSeenApprovalDialog(userId: _craftsmanId);
      if (mounted) _showApprovalSuccessDialog();
    }
  }

  void _showApprovalSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2128), Color(0xFF13151A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: -5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      border:
                          Border.all(color: const Color(0xFFD4AF37), width: 2),
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Color(0xFFD4AF37),
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isArabic ? 'تهانينا!' : 'Congratulations!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'ArefRuqaa',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isArabic
                      ? 'تمت الموافقة على حسابك كحرفي من قبل الإدارة.\nيمكنك الآن البدء في إضافة منتجاتك واستقبال الطلبات وإدارة متجرك بالكامل.'
                      : 'Your artisan account has been approved by the admin.\nYou can now start adding products, receiving orders, and fully managing your store.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF13151A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      _isArabic ? 'ابدأ الآن' : 'Start Now',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant CraftsmanShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isArabic != widget.isArabic) {
      _isArabic = widget.isArabic;
    }

    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _isDarkMode = widget.isDarkMode;
    }

    final oldStatus = _resolveStatus(
      status: oldWidget.verificationStatus,
      isVerified: oldWidget.isVerified,
      isPending: oldWidget.isPending,
    );

    final becameApproved = oldStatus != CraftsmanVerificationStatus.approved &&
        _status == CraftsmanVerificationStatus.approved;

    if (becameApproved && _craftsmanId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CustomOrderProvider>().loadForArtisan(_craftsmanId);
        _checkApprovalNotification();
      });
    }

    if (!_isApproved && _currentIndex != 0 && _currentIndex != 4) {
      _currentIndex = 0;
    }
  }

  CraftsmanVerificationStatus _resolveStatus({
    required String? status,
    required bool isVerified,
    required bool isPending,
  }) {
    if (status != null && status.trim().isNotEmpty) {
      return CraftsmanVerificationStatusX.fromApi(status);
    }

    if (isVerified) return CraftsmanVerificationStatus.approved;
    if (isPending) return CraftsmanVerificationStatus.pendingReview;
    return CraftsmanVerificationStatus.notSubmitted;
  }

  CraftsmanVerificationStatus get _status => _resolveStatus(
        status: widget.verificationStatus,
        isVerified: widget.isVerified,
        isPending: widget.isPending,
      );

  bool get _isApproved => _status == CraftsmanVerificationStatus.approved;
  bool get _isLocked => !_isApproved;

  void _toggleLanguage() {
    setState(() => _isArabic = !_isArabic);
    widget.onToggleLanguage();
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
    widget.onToggleTheme();
  }

  Color get bg =>
      _isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => _isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => _isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryText => _isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => _isDarkMode ? Colors.white12 : Colors.black12;
  Color get accent =>
      _isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
  Color get unselected => _isDarkMode ? Colors.white38 : Colors.black38;

  List<String> get _titles => _isArabic
      ? ['الرئيسية', 'عروضي', 'الطلبات', 'الرسائل', 'حسابي']
      : ['Home', 'My Offers', 'Orders', 'Messages', 'Profile'];

  String get _name => context.read<AppState>().userName ?? widget.craftsmanName;
  String get _city => widget.craftsmanCity;
  String get _bio => widget.craftsmanBio;
  String get _experience => widget.craftsmanExperience;

  List<Widget> get _pages => [
        CraftsmanDashboard(
          key: ValueKey('craftsman-dashboard-$_dashboardRefreshKey'),
          isArabic: _isArabic,
          isDarkMode: _isDarkMode,
          onToggleLanguage: _toggleLanguage,
          onToggleTheme: _toggleTheme,
          name: _name,
          categoryTitleAr: widget.craftsmanCategoryAr,
          categoryTitleEn: widget.craftsmanCategoryEn,
          city: _city,
          bio: _bio,
          experience: _experience,
          isVerified: _isApproved,
          isPending: _isLocked,
          craftsmanId: _craftsmanId,
        ),
        _buildPreviewPage(
          CraftsmanOffersScreen(
            isArabic: _isArabic,
            isDarkMode: _isDarkMode,
            artisanId: _craftsmanId,
          ),
        ),
        _buildPreviewPage(
          CraftsmanOrdersScreen(
            isArabic: _isArabic,
            isDarkMode: _isDarkMode,
            artisanId: _craftsmanId,
          ),
        ),
        _buildPreviewPage(
          ChatInboxScreen(
            isArabic: _isArabic,
            isDarkMode: _isDarkMode,
          ),
        ),
        CraftsmanProfileScreen(
          isArabic: _isArabic,
          isDarkMode: _isDarkMode,
          onToggleLanguage: _toggleLanguage,
          onToggleTheme: _toggleTheme,
          craftsmanId: _craftsmanId,
        ),
      ];

  Widget _buildPreviewPage(Widget child) {
    if (_isApproved) return child;

    return Stack(
      children: [
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: child,
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _showLockedFeatureSheet,
            child: const SizedBox.expand(),
          ),
        ),
        PositionedDirectional(
          top: 14,
          start: 14,
          end: 14,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _statusColor.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_statusIcon, color: _statusColor, size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _isArabic
                          ? 'وضع الاستكشاف: التفاعل متاح بعد تفعيل الحساب'
                          : 'Preview mode: actions unlock after account approval',
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _lockedDescription {
    switch (_status) {
      case CraftsmanVerificationStatus.pendingReview:
        return _isArabic
            ? 'حسابك قيد المراجعة. ستصبح هذه الميزة متاحة فور موافقة الأدمن.'
            : 'Your account is under review. This feature will be available after admin approval.';
      case CraftsmanVerificationStatus.rejected:
        return _isArabic
            ? 'تعذّر قبول طلب التوثيق. راجع السبب وأعد إرسال المستندات.'
            : 'Your verification request was not approved. Review the reason and resubmit your documents.';
      case CraftsmanVerificationStatus.retakeRequired:
        return _isArabic
            ? 'طلب الأدمن صورة أوضح للهوية. أعد التصوير والرفع للمتابعة.'
            : 'The admin requested a clearer ID image. Retake and upload it to continue.';
      case CraftsmanVerificationStatus.notSubmitted:
        return _isArabic
            ? 'يجب إرسال مستندات التوثيق أولاً قبل استخدام هذه الميزة.'
            : 'You need to submit your verification documents before using this feature.';
      case CraftsmanVerificationStatus.approved:
        return '';
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        _dashboardRefreshKey++;
      }
    });
  }

  Future<void> _showLockedFeatureSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryText.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(_statusIcon, color: _statusColor, size: 36),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _statusTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lockedDescription,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: secondaryText,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  if ((widget.verificationReason ?? '').trim().isNotEmpty &&
                      (_status == CraftsmanVerificationStatus.rejected ||
                          _status ==
                              CraftsmanVerificationStatus.retakeRequired)) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _statusColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        '${_isArabic ? 'السبب' : 'Reason'}: ${widget.verificationReason}',
                        style: GoogleFonts.cairo(
                          color: text,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: text,
                            side: BorderSide(color: border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isArabic ? 'حسنًا' : 'Got it',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (_status == CraftsmanVerificationStatus.rejected ||
                          _status ==
                              CraftsmanVerificationStatus.retakeRequired) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.onResubmitDocuments == null
                                ? null
                                : () {
                                    Navigator.pop(sheetContext);
                                    widget.onResubmitDocuments!.call();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4A017),
                              foregroundColor: Colors.black87,
                              disabledBackgroundColor: const Color(0xFFD4A017)
                                  .withValues(alpha: 0.35),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _isArabic ? 'إعادة الرفع' : 'Resubmit',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _statusTitle {
    switch (_status) {
      case CraftsmanVerificationStatus.pendingReview:
        return _isArabic ? 'حسابك قيد المراجعة' : 'Account Under Review';
      case CraftsmanVerificationStatus.approved:
        return _isArabic ? 'تم توثيق الحساب' : 'Account Approved';
      case CraftsmanVerificationStatus.rejected:
        return _isArabic ? 'لم يتم قبول التوثيق' : 'Verification Rejected';
      case CraftsmanVerificationStatus.retakeRequired:
        return _isArabic ? 'مطلوب إعادة تصوير الهوية' : 'New ID Photo Required';
      case CraftsmanVerificationStatus.notSubmitted:
        return _isArabic ? 'التوثيق غير مكتمل' : 'Verification Incomplete';
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case CraftsmanVerificationStatus.pendingReview:
        return Icons.hourglass_top_rounded;
      case CraftsmanVerificationStatus.approved:
        return Icons.verified_rounded;
      case CraftsmanVerificationStatus.rejected:
        return Icons.cancel_outlined;
      case CraftsmanVerificationStatus.retakeRequired:
        return Icons.camera_alt_outlined;
      case CraftsmanVerificationStatus.notSubmitted:
        return Icons.description_outlined;
    }
  }

  Color get _statusColor {
    switch (_status) {
      case CraftsmanVerificationStatus.pendingReview:
        return const Color(0xFFD4A017);
      case CraftsmanVerificationStatus.approved:
        return Colors.green;
      case CraftsmanVerificationStatus.rejected:
        return Colors.redAccent;
      case CraftsmanVerificationStatus.retakeRequired:
        return Colors.orange;
      case CraftsmanVerificationStatus.notSubmitted:
        return Colors.blueGrey;
    }
  }

  Widget _buildStatusBanner() {
    if (_isApproved) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: _isDarkMode ? 0.16 : 0.11),
        border: Border(
          bottom: BorderSide(
            color: _statusColor.withValues(alpha: 0.28),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(_statusIcon, size: 20, color: _statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusTitle,
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _bannerSubtitle,
                      style: GoogleFonts.cairo(
                        color: secondaryText,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onViewSubmission != null)
                TextButton(
                  onPressed: widget.onViewSubmission,
                  child: Text(
                    _isArabic ? 'عرض' : 'View',
                    style: GoogleFonts.cairo(
                      color: _statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _bannerSubtitle {
    switch (_status) {
      case CraftsmanVerificationStatus.pendingReview:
        return _isArabic
            ? 'يمكنك استكشاف جميع الواجهات، لكن تنفيذ الإجراءات متاح بعد موافقة الأدمن.'
            : 'You can explore every screen, but actions unlock after admin approval.';
      case CraftsmanVerificationStatus.rejected:
        return _isArabic
            ? 'راجع سبب الرفض وأعد إرسال المستندات.'
            : 'Review the rejection reason and resubmit your documents.';
      case CraftsmanVerificationStatus.retakeRequired:
        return _isArabic
            ? 'أعد تصوير الهوية بصورة أوضح لإكمال المراجعة.'
            : 'Retake a clearer ID photo to continue the review.';
      case CraftsmanVerificationStatus.notSubmitted:
        return _isArabic
            ? 'أكمل إرسال مستندات التوثيق لتفعيل الحساب.'
            : 'Submit your verification documents to activate the account.';
      case CraftsmanVerificationStatus.approved:
        return '';
    }
  }

  Widget _navIcon(IconData icon, {required bool locked}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 24),
        if (locked)
          Positioned(
            right: -3,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 11,
                color: Color(0xFFD4A017),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getDesktopIcon(int index, bool selected) {
    switch (index) {
      case 0:
        return selected ? Icons.home_filled : Icons.home_outlined;
      case 1:
        return selected ? Icons.storefront : Icons.storefront_outlined;
      case 2:
        return selected ? Icons.receipt_long : Icons.receipt_long_outlined;
      case 3:
        return selected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded;
      case 4:
        return selected ? Icons.person_rounded : Icons.person_outline_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildMobileLayout() {
      return Directionality(
        textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _isDarkMode
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: bg,
            appBar: AppBar(
              backgroundColor: surface,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              leadingWidth: 96,
              title: Text(
                'CraftGo',
                style: GoogleFonts.playfairDisplay(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              centerTitle: true,
              leading: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _topBarButton(
                      icon: Icons.language,
                      label: _isArabic ? 'EN' : 'عربي',
                      onTap: _toggleLanguage,
                      color: text,
                      bg: surface,
                      border: border,
                    ),
                    const SizedBox(width: 4),
                    _topBarButton(
                      icon: _isDarkMode
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      label: '',
                      onTap: _toggleTheme,
                      color: text,
                      bg: surface,
                      border: border,
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: border),
              ),
            ),
            body: Column(
              children: [
                _buildStatusBanner(),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: border)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                  backgroundColor: surface,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: accent,
                  unselectedItemColor: unselected,
                  selectedFontSize: 12,
                  unselectedFontSize: 11,
                  selectedLabelStyle:
                      GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  unselectedLabelStyle:
                      GoogleFonts.cairo(fontWeight: FontWeight.normal),
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined, size: 24),
                      activeIcon: const Icon(Icons.home_filled, size: 26),
                      label: _titles[0],
                    ),
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        Icons.storefront_outlined,
                        locked: _isLocked,
                      ),
                      activeIcon: const Icon(Icons.storefront, size: 26),
                      label: _titles[1],
                    ),
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        Icons.receipt_long_outlined,
                        locked: _isLocked,
                      ),
                      activeIcon: const Icon(Icons.receipt_long, size: 26),
                      label: _titles[2],
                    ),
                    BottomNavigationBarItem(
                      icon: _navIcon(
                        Icons.chat_bubble_outline_rounded,
                        locked: _isLocked,
                      ),
                      activeIcon: const Icon(Icons.chat_bubble_rounded, size: 26),
                      label: _titles[3],
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline_rounded, size: 24),
                      activeIcon: const Icon(Icons.person_rounded, size: 26),
                      label: _titles[4],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildDesktopLayout() {
      return Directionality(
        textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _isDarkMode
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: bg,
            body: Row(
              children: [
                // Sidebar Navigation
                Container(
                  width: 240,
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border(
                      right: _isArabic
                          ? BorderSide.none
                          : BorderSide(color: border),
                      left: _isArabic
                          ? BorderSide(color: border)
                          : BorderSide.none,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          'CraftGo',
                          style: GoogleFonts.playfairDisplay(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _isArabic ? 'لوحة الحرفي' : 'Craftsman Hub',
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: border),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _titles.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final selected = _currentIndex == index;
                              final isItemLocked =
                                  (index == 1 || index == 2 || index == 3) &&
                                      _isLocked;
                              return ListTile(
                                leading: _navIcon(
                                  _getDesktopIcon(index, selected),
                                  locked: isItemLocked,
                                ),
                                title: Text(
                                  _titles[index],
                                  style: GoogleFonts.cairo(
                                    color: selected ? accent : text,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                selected: selected,
                                selectedTileColor:
                                    accent.withValues(alpha: 0.12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                onTap: () => _onTabTapped(index),
                              );
                            },
                          ),
                        ),
                        Divider(height: 1, color: border),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _topBarButton(
                                icon: Icons.language,
                                label: _isArabic ? 'EN' : 'عربي',
                                onTap: _toggleLanguage,
                                color: text,
                                bg: bg,
                                border: border,
                              ),
                              _topBarButton(
                                icon: _isDarkMode
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                label: '',
                                onTap: _toggleTheme,
                                color: text,
                                bg: bg,
                                border: border,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content Pane
                Expanded(
                  child: Column(
                    children: [
                      _buildStatusBanner(),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: _pages,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return buildDesktopLayout();
        } else {
          return buildMobileLayout();
        }
      },
    );
  }

  Widget _topBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color bg,
    required Color border,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

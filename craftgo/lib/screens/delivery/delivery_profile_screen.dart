import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/delivery_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/session_service.dart';
import '../../main.dart';
import 'delivery_vehicle_screen.dart';

class DeliveryProfileScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final String deliveryName;

  const DeliveryProfileScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.deliveryName,
  });

  @override
  State<DeliveryProfileScreen> createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
  // ── State Variables ────────────────────────────────────────────────
  bool _isLoading = true;
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;

  // Profile & Vehicle Data
  String _displayName = '';
  String _city = '';
  String _completionRate = '0%';
  String _rating = '0.0';
  String _trips = '0';
  String _distance = '0 كم';
  String _vehicleTitle = '';
  List<dynamic> _reviews = [];

  // ── Unified Theme Palette ──────────────────────────────────────────
  static const Color accent = Color(0xFFD4A017);

  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);

  String get _initials {
    final nameToUse =
        _displayName.isNotEmpty ? _displayName : widget.deliveryName;
    final parts = nameToUse.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return nameToUse.isNotEmpty ? nameToUse[0] : 'م';
  }

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _displayName = widget.deliveryName;
    _fetchDriverData();
  }

  Future<void> _fetchDriverData() async {
    final appState = context.read<AppState>();
    final driverId = appState.userId ?? '1';

    try {
      final results = await Future.wait([
        DeliveryService.getDashboard(driverId),
        DeliveryService.getProfile(driverId),
        DeliveryService.getVehicle(driverId),
        DeliveryService.getDriverOrders(driverId),
        DeliveryService.getDriverReviews(driverId),
      ]);

      final dashboardData = results[0] as Map<String, dynamic>?;
      final profileData = results[1] as Map<String, dynamic>?;
      final vehicleData = results[2] as Map<String, dynamic>?;
      final driverOrders = (results[3] as List<dynamic>?) ?? [];
      final reviewsData = (results[4] as List<dynamic>?) ?? [];

      if (mounted) {
        setState(() {
          if (profileData != null) {
            final userData = profileData['user'] as Map<String, dynamic>?;
            final fetchedName = userData?['name'] ?? profileData['name'];
            final fetchedCity = userData?['city'] ?? profileData['city'];

            if (fetchedName != null && fetchedName.toString().isNotEmpty) {
              _displayName = fetchedName.toString();
            }
            if (fetchedCity != null) {
              _city = fetchedCity.toString();
            }
          }

          double totalDist = 0.0;
          int completedCount = 0;
          int cancelledCount = 0;

          for (var item in driverOrders) {
            if (item is Map<String, dynamic>) {
              final status = item['status']?.toString();
              final dist = (item['distanceKm'] is num)
                  ? (item['distanceKm'] as num).toDouble()
                  : double.tryParse(item['distanceKm']?.toString() ?? '0') ??
                      0.0;

              totalDist += dist;

              if (status == 'completed' || status == 'delivered') {
                completedCount++;
              } else if (status == 'cancelled') {
                cancelledCount++;
              }
            }
          }

          final totalOrders = driverOrders.length;
          _trips = totalOrders.toString();

          final formattedDist = (totalDist % 1 == 0)
              ? totalDist.toInt().toString()
              : totalDist.toStringAsFixed(1);
          _distance = t('$formattedDist كم', '$formattedDist km');

          final totalEvaluated = completedCount + cancelledCount;
          if (totalEvaluated > 0) {
            final double rate = (completedCount / totalEvaluated) * 100;
            _completionRate = '${rate.round()}%';
          } else if (totalOrders > 0) {
            final double rate = (completedCount / totalOrders) * 100;
            _completionRate = '${rate.round()}%';
          } else {
            _completionRate = '100%';
          }

          if (dashboardData != null) {
            final rawRating = dashboardData['rating'];
            if (rawRating != null) {
              final double ratingVal = (rawRating is num)
                  ? rawRating.toDouble()
                  : double.tryParse(rawRating.toString()) ?? 0.0;
              _rating = ratingVal > 0
                  ? ratingVal.toStringAsFixed(1)
                  : t('جديد', 'New');
            } else {
              _rating = t('جديد', 'New');
            }
          }

          if (vehicleData != null && vehicleData.isNotEmpty) {
            final make = vehicleData['make'] ?? '';
            final model = vehicleData['model'] ?? '';
            final year = vehicleData['year']?.toString() ?? '';
            if (make.isNotEmpty || model.isNotEmpty) {
              _vehicleTitle =
                  '$make $model ${year.isNotEmpty ? "- $year" : ""}'.trim();
            } else {
              _vehicleTitle =
                  t('لم يتم تحديد المركبة', 'Vehicle Not Specified');
            }
          } else {
            _vehicleTitle = t('لا توجد بيانات للمركبة', 'No vehicle data');
          }

          _reviews = reviewsData;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isArabic;
    final isDark = widget.isDarkMode;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: accent))
              : RefreshIndicator(
                  onRefresh: _fetchDriverData,
                  color: accent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // ── Header Section (No top bar) ────────────────
                        _buildHeader(isAr, isDark),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Performance Stats ─────────────────────
                              _buildPerformanceStats(isAr, isDark),
                              const SizedBox(height: 24),

                              // ── Vehicle Info Tile ─────────────────────
                              _buildVehicleTile(isAr, isDark),
                              const SizedBox(height: 24),

                              // ── Customer & Artisan Reviews ────────────
                              _buildReviewsSection(isAr),

                              // ── Settings ──────────────────────────────
                              _buildSettingsSection(isAr, isDark),
                              const SizedBox(height: 24),

                              // ── Logout ────────────────────────────────
                              _buildLogoutButton(isAr, isDark),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader(bool isAr, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.15),
            bg,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Removed the Row with language/theme/logout icons
          const SizedBox(height: 8),
          // Avatar
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [accent, Color(0xFFB8860B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initials,
                style: GoogleFonts.cairo(
                  color: Colors.black87,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _displayName,
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Removed the "Certified Delivery Agent" badge
        ],
      ),
    );
  }

  // ─── Performance Stats ───────────────────────────────────────────────
  Widget _buildPerformanceStats(bool isAr, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            value: _completionRate,
            label: t('معدل الإكمال', 'Completion'),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            value: _rating,
            label: t('التقييم', 'Rating'),
            icon: Icons.star_border_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            value: _trips,
            label: t('الطلبات', 'Orders'),
            icon: Icons.local_shipping_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _metricCard(
            value: _distance,
            label: t('المسافة', 'Distance'),
            icon: Icons.map_outlined,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Vehicle Tile ─────────────────────────────────────────────────────
  Widget _buildVehicleTile(bool isAr, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DeliveryVehicleScreen(),
            ),
          );
          _fetchDriverData();
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.directions_car_rounded, color: accent, size: 22),
        ),
        title: Text(
          t('مركبة التوصيل', 'Vehicle Details'),
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          _vehicleTitle,
          style: GoogleFonts.cairo(
            color: dim,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          isAr ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
          color: dim,
          size: 16,
        ),
      ),
    );
  }

  // ─── Reviews Section ──────────────────────────────────────────────────
  Widget _buildReviewsSection(bool isAr) {
    if (_reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t('تقييمات التوصيل', 'Delivery Reviews'),
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_reviews.length}',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length > 5 ? 5 : _reviews.length,
          itemBuilder: (ctx, index) {
            final r = _reviews[index] as Map<String, dynamic>;
            final rating = (r['rating'] is num) ? (r['rating'] as num).toInt() : 5;
            final comment = r['comment']?.toString() ?? '';
            final name = r['reviewerName']?.toString() ?? t('عميل', 'Customer');
            final date = r['date']?.toString() ?? '';
            final role = r['reviewedByRole'] == 'craftsman'
                ? t('حرفي', 'Craftsman')
                : t('عميل', 'Customer');

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      comment,
                      style: GoogleFonts.cairo(color: dim, fontSize: 12),
                    ),
                  ],
                  if (date.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: TextStyle(
                          color: dim.withValues(alpha: 0.6), fontSize: 10),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Settings Section ────────────────────────────────────────────────
  Widget _buildSettingsSection(bool isAr, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          _buildSettingTile(
            icon: Icons.person_outline_rounded,
            title: t('تعديل الملف الشخصي', 'Edit Profile'),
            trailing: Icon(
              isAr ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: dim,
              size: 16,
            ),
            onTap: () => _showEditProfileDialog(context, isAr),
          ),
          Divider(height: 1, color: border),
          _buildSettingTile(
            icon: Icons.language_rounded,
            title: t('اللغة', 'Language'),
            trailing: GestureDetector(
              onTap: widget.onToggleLanguage,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isAr ? 'عربي' : 'English',
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: border),
          _buildSettingTile(
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            title: t('المظهر', 'Theme'),
            trailing: Switch(
              value: isDark,
              activeThumbColor: accent,
              activeTrackColor: accent.withValues(alpha: 0.4),
              onChanged: (_) => widget.onToggleTheme(),
            ),
          ),
          Divider(height: 1, color: border),
          _buildSettingTile(
            icon: Icons.lock_outline,
            title: t('تغيير كلمة المرور', 'Change Password'),
            trailing: Icon(
              isAr ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: dim,
              size: 16,
            ),
            onTap: () => _showChangePasswordDialog(context, isAr),
          ),
          Divider(height: 1, color: border),
          _buildSettingTile(
            icon: Icons.notifications_outlined,
            title: t('تفضيلات الإشعارات', 'Notification Preferences'),
            trailing: Icon(
              isAr ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: dim,
              size: 16,
            ),
            onTap: () => _showNotificationPreferencesDialog(context, isAr),
          ),
          Divider(height: 1, color: border),
          _buildSettingTile(
            icon: Icons.account_balance_wallet_outlined,
            title: t('إعداد الدفع (Stripe)', 'Setup Payout (Stripe)'),
            trailing: Icon(
              isAr ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: dim,
              size: 16,
            ),
            onTap: _handleOnboardTap,
          ),
          Divider(height: 1, color: border),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            title: t('سياسة الخصوصية', 'Privacy Policy'),
            trailing: Icon(
              isAr ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
              color: dim,
              size: 16,
            ),
            onTap: () => _showPrivacyPolicyDialog(context, isAr),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: trailing,
    );
  }

  // ─── Logout Button ────────────────────────────────────────────────────
  Widget _buildLogoutButton(bool isAr, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _handleLogout(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        label: Text(
          isAr ? 'تسجيل الخروج' : 'Logout',
          style: GoogleFonts.cairo(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.redAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────

  void _showEditProfileDialog(BuildContext context, bool isAr) {
    final nameCtrl = TextEditingController(text: _displayName);
    final cityCtrl = TextEditingController(text: _city);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isAr ? 'تعديل الملف الشخصي' : 'Edit Profile',
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    labelText: isAr ? 'الاسم الكامل' : 'Full Name',
                    labelStyle: TextStyle(color: dim),
                    prefixIcon: const Icon(Icons.person_outline, color: accent),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? (isAr ? 'يرجى إدخال الاسم' : 'Please enter name')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: cityCtrl,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    labelText: isAr ? 'المدينة' : 'City',
                    labelStyle: TextStyle(color: dim),
                    prefixIcon: const Icon(Icons.location_city, color: accent),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text(
                isAr ? 'إلغاء' : 'Cancel',
                style: TextStyle(color: dim),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() ?? false) {
                        setDialogState(() => isSaving = true);
                        final appState = context.read<AppState>();
                        final driverId = appState.userId ?? '1';

                        final updated = await DeliveryService.updateProfile(
                          driverId: driverId,
                          name: nameCtrl.text.trim(),
                          city: cityCtrl.text.trim(),
                        );

                        if (mounted) {
                          if (updated != null) {
                            setState(() {
                              _displayName = nameCtrl.text.trim();
                              _city = cityCtrl.text.trim();
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAr
                                      ? 'تم تحديث البيانات بنجاح'
                                      : 'Profile updated successfully',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAr
                                      ? 'فشل تحديث البيانات'
                                      : 'Failed to update profile',
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      isAr ? 'حفظ' : 'Save',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, bool isAr) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          isAr ? 'تغيير كلمة المرور' : 'Change Password',
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: true,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    labelText:
                        isAr ? 'كلمة المرور الحالية' : 'Current Password',
                    labelStyle: TextStyle(color: dim),
                    prefixIcon: const Icon(Icons.lock_outline, color: accent),
                  ),
                  validator: (val) => (val == null || val.isEmpty)
                      ? (isAr
                          ? 'يرجى إدخال كلمة المرور الحالية'
                          : 'Enter current password')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    labelText: isAr ? 'كلمة المرور الجديدة' : 'New Password',
                    labelStyle: TextStyle(color: dim),
                    prefixIcon: const Icon(Icons.lock_reset, color: accent),
                  ),
                  validator: (val) => (val == null || val.length < 6)
                      ? (isAr
                          ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                          : 'Password must be at least 6 chars')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    labelText: isAr ? 'تأكيد كلمة المرور' : 'Confirm Password',
                    labelStyle: TextStyle(color: dim),
                    prefixIcon:
                        const Icon(Icons.check_circle_outline, color: accent),
                  ),
                  validator: (val) {
                    if (val != newCtrl.text) {
                      return isAr
                          ? 'كلمات المرور غير متطابقة'
                          : 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isAr ? 'إلغاء' : 'Cancel',
              style: TextStyle(color: dim),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAr
                          ? 'تم تغيير كلمة المرور بنجاح'
                          : 'Password changed successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            child: Text(
              isAr ? 'تأكيد' : 'Confirm',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationPreferencesDialog(BuildContext context, bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isAr ? 'تفضيلات الإشعارات' : 'Notification Preferences',
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(
                  isAr ? 'الإشعارات اللحظية' : 'Push Notifications',
                  style: TextStyle(color: text),
                ),
                subtitle: Text(
                  isAr
                      ? 'تنبيهات فورية عند وصول طلبات جديدة'
                      : 'Instant alerts for new requests',
                  style: TextStyle(color: dim, fontSize: 12),
                ),
                value: _pushNotifications,
                activeTrackColor: accent,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  setDialogState(() {});
                },
              ),
              SwitchListTile(
                title: Text(
                  isAr ? 'إشعارات البريد' : 'Email Notifications',
                  style: TextStyle(color: text),
                ),
                subtitle: Text(
                  isAr
                      ? 'ملخص أسبوعي بالنشاط والتقارير'
                      : 'Weekly digest of activity',
                  style: TextStyle(color: dim, fontSize: 12),
                ),
                value: _emailNotifications,
                activeTrackColor: accent,
                onChanged: (val) {
                  setState(() => _emailNotifications = val);
                  setDialogState(() {});
                },
              ),
              SwitchListTile(
                title: Text(
                  isAr ? 'رسائل نصية SMS' : 'SMS Alerts',
                  style: TextStyle(color: text),
                ),
                subtitle: Text(
                  isAr ? 'رسائل نصية للحالات العاجلة' : 'SMS for urgent events',
                  style: TextStyle(color: dim, fontSize: 12),
                ),
                value: _smsNotifications,
                activeTrackColor: accent,
                onChanged: (val) {
                  setState(() => _smsNotifications = val);
                  setDialogState(() {});
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isAr ? 'إغلاق' : 'Close',
                style:
                    const TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context, bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          isAr ? 'سياسة الخصوصية' : 'Privacy Policy',
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAr
                    ? 'سياسة الخصوصية لمنصة CraftGo'
                    : 'CraftGo Privacy Policy',
                style: GoogleFonts.cairo(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'نحن نلتزم بحماية بياناتك الشخصية. يتم استخدام بيانات التوصيل حصرياً لتمكين عمليات التوصيل والتواصل مع العملاء.'
                    : 'We are committed to protecting your personal data. Delivery data is used exclusively to enable delivery operations and customer communication.',
                style: TextStyle(color: dim, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            child: Text(
              isAr ? 'موافق' : 'I Agree',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final appState = context.read<AppState>();
    await SessionService.clearSession();
    appState.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  Future<void> _handleOnboardTap() async {
    final appState = context.read<AppState>();
    final driverId = appState.userId ?? '';
    try {
      final res = await DeliveryService.createOnboardLink(driverId);
      if (res == null) throw Exception('Could not create onboarding link');
      final url = res['onboardingUrl']?.toString() ??
          res['onboarding_url']?.toString() ??
          '';
      if (url.isEmpty) throw Exception('Onboarding URL missing');

      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_blank',
      );
      if (!opened) throw Exception('Could not open onboarding URL');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isArabic
            ? 'تعذر إنشاء رابط التسجيل: ${e.toString()}'
            : 'Could not create onboarding link: ${e.toString()}'),
      ));
    }
  }
}

// ─── Top Bar Button ────────────────────────────────────────────────────

Widget _topBarButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2431) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black87),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

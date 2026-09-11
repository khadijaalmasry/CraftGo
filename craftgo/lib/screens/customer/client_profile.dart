import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../app_state.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../services/payment_service.dart';

class CustomerProfileScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final String userName;

  const CustomerProfileScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    this.userName = 'Customer',
  });

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  // Real user data – loaded from API
  String name = '';
  String email = '';
  String phone = '';
  String bio = '';
  String location = '';
  String _bankName = '';
  String _accountTitle = '';
  String _iban = '';
  String? profileImageUrl;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers for editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // Payment controllers
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _accountTitleCtrl = TextEditingController();
  final TextEditingController _ibanCtrl = TextEditingController();

  // Notification toggle state
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'] ?? data;
        setState(() {
          name = user['name'] ?? widget.userName;
          email = user['email'] ?? '';
          phone = user['phone'] ?? '';
          bio = user['bio'] ?? '';
          location = user['location'] ?? user['city'] ?? '';
          _bankName = user['bankName'] ?? '';
          _accountTitle = user['accountTitle'] ?? '';
          _iban = user['iban'] ?? '';
          profileImageUrl = user['profileImage'] ?? user['avatar'];
          _nameController.text = name;
          _phoneController.text = phone;
          _bioController.text = bio;
          _locationController.text = location;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final response = await ApiService.put('/auth/profile', body: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'] ?? data;
        setState(() {
          name = user['name'] ?? _nameController.text.trim();
          phone = user['phone'] ?? _phoneController.text.trim();
          bio = user['bio'] ?? _bioController.text.trim();
          location = user['location'] ?? _locationController.text.trim();
        });
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(t(
                    'تم تحديث الملف الشخصي', 'Profile updated successfully'))),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    t('فشل التحديث، حاول مجدداً', 'Update failed, try again'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Theme colors
  Color get backgroundColor =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get primaryTextColor =>
      widget.isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryTextColor =>
      widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get cardBorderColor => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);
  Color get surfaceColor =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  // ─── Payment Details (password-gated) ───────────────────────────────────
  void _showPaymentPasswordGate() {
    final passCtrl = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Directionality(
          textDirection:
              widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: surfaceColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t('تأكيد الهوية', 'Confirm Your Identity'),
                    style: GoogleFonts.cairo(
                        color: primaryTextColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('لحماية حسابك، أدخل كلمة المرور للوصول إلى تفاصيل الدفع',
                      'To protect your account, enter your password to access payment details.'),
                  style: TextStyle(color: secondaryTextColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                _passField(passCtrl, t('كلمة المرور', 'Password'), obscure,
                    () => setD(() => obscure = !obscure)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('إلغاء', 'Cancel'),
                    style: TextStyle(color: secondaryTextColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  // In real implementation, verify password via API.
                  // For now, any non-empty password unlocks the sheet.
                  if (passCtrl.text.isNotEmpty) {
                    Navigator.pop(ctx);
                    _showPaymentDetailsSheet();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t(
                            'أدخل كلمة المرور', 'Please enter your password')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(t('تأكيد', 'Confirm'),
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentDetailsSheet() {
    _bankNameCtrl.text = _bankName;
    _accountTitleCtrl.text = _accountTitle;
    _ibanCtrl.text = _iban;
    bool isSavingPayment = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Directionality(
            textDirection:
                widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: cardBorderColor),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: secondaryTextColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.account_balance_outlined,
                              color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('تفاصيل الدفع', 'Payment Details'),
                                style: GoogleFonts.arefRuqaa(
                                  color: primaryTextColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                t('بيانات بطاقتك المحفوظة وحساب الاستلام',
                                    'Your saved card & payout account'),
                                style: TextStyle(
                                    color: secondaryTextColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Escrow notice
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t('جميع مدفوعاتك محمية بنظام Escrow. لا يصل مبلغ الحرفي حتى تؤكد استلام الخدمة.',
                                  'All your payments are Escrow-protected. Craftsmen are only paid once you confirm delivery.'),
                              style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bank details section header
                    Text(
                      t('حساب الاستلام (IBAN)', 'Payout Account (IBAN)'),
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(
                      label: t('اسم البنك', 'Bank Name'),
                      controller: _bankNameCtrl,
                    ),
                    _buildEditField(
                      label: t('اسم صاحب الحساب', 'Account Holder Name'),
                      controller: _accountTitleCtrl,
                    ),
                    _buildEditField(
                      label: t('رقم الحساب / IBAN', 'IBAN / Account Number'),
                      controller: _ibanCtrl,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final success = await PaymentService.openPayoutOnboarding();
                          if (!success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t('تعذر فتح رابط إعدادات السحب من Stripe', 'Could not open Stripe Payout setup link'),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 18),
                        label: Text(
                          t('ربط حساب Stripe Express للصرف الفوري', 'Connect Stripe Express for Instant Payouts'),
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF635BFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: cardBorderColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              t('إلغاء', 'Cancel'),
                              style: TextStyle(color: primaryTextColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                              ),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              onPressed: () async {
                                setSheet(() => isSavingPayment = true);
                                try {
                                  final response = await ApiService.put(
                                      '/auth/profile',
                                      body: {
                                        'bankName': _bankNameCtrl.text.trim(),
                                        'accountTitle':
                                            _accountTitleCtrl.text.trim(),
                                        'iban': _ibanCtrl.text.trim(),
                                      });
                                  if (response.statusCode == 200) {
                                    setState(() {
                                      _bankName = _bankNameCtrl.text.trim();
                                      _accountTitle =
                                          _accountTitleCtrl.text.trim();
                                      _iban = _ibanCtrl.text.trim();
                                    });
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(t(
                                              'تم حفظ تفاصيل الدفع بنجاح',
                                              'Payment details saved successfully')),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  }
                                } catch (_) {
                                  // ignore
                                } finally {
                                  if (ctx.mounted)
                                    setSheet(() => isSavingPayment = false);
                                }
                              },
                              child: isSavingPayment
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.black, strokeWidth: 2))
                                  : Text(
                                      t('حفظ', 'Save'),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Edit Profile Sheet ──────────────────────────────────────────────
  void _showEditProfileSheet() {
    _nameController.text = name;
    _phoneController.text = phone;
    _bioController.text = bio;
    _locationController.text = location;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: cardBorderColor),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t('تعديل الملف الشخصي', 'Edit Profile'),
                  style: GoogleFonts.arefRuqaa(
                    color: primaryTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Avatar (edit placeholder)
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: accent.withValues(alpha: 0.2),
                        child: Icon(Icons.person, size: 50, color: accent),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: surfaceColor, width: 2),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.camera_alt,
                                size: 18, color: Colors.black),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildEditField(
                  label: t('الاسم', 'Full Name'),
                  controller: _nameController,
                ),
                _buildReadOnlyField(
                  label: t('البريد الإلكتروني', 'Email'),
                  value: email,
                ),
                _buildEditField(
                  label: t('رقم الهاتف', 'Phone'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                _buildEditField(
                  label: t('نبذة', 'Bio'),
                  controller: _bioController,
                  maxLines: 3,
                ),
                _buildEditField(
                  label: t('الموقع', 'Location'),
                  controller: _locationController,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cardBorderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          t('إلغاء', 'Cancel'),
                          style: TextStyle(color: primaryTextColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                          ),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () async {
                            await _saveProfile();
                          },
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.black, strokeWidth: 2),
                                )
                              : Text(
                                  t('حفظ', 'Save'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accent),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(color: secondaryTextColor, fontSize: 14),
                  ),
                ),
                Icon(Icons.lock_outline, size: 16, color: secondaryTextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Settings Dialog (now inline in the profile page) ───────────────
  // All these methods are kept, but we'll call them from the settings tiles.

  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t('سياسة الخصوصية', 'Privacy Policy'),
                  style: GoogleFonts.cairo(
                    color: primaryTextColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _privacySection(
                          t('جمع البيانات', 'Data Collection'),
                          t(
                            'نجمع بياناتك فقط لتحسين تجربتك على التطبيق. لا نبيع بياناتك لأي جهة خارجية.',
                            'We collect your data only to improve your app experience. We never sell your data to third parties.',
                          ),
                        ),
                        _privacySection(
                          t('الدفع والأمان', 'Payment & Security'),
                          t(
                            'جميع المدفوعات محمية بنظام Escrow — لا يصل الحرفي مبلغه حتى تأكدك من استلام الخدمة.',
                            'All payments are protected by Escrow — the craftsman does not receive funds until you confirm service delivery.',
                          ),
                        ),
                        _privacySection(
                          t('حذف الحساب', 'Account Deletion'),
                          t(
                            'يمكنك طلب حذف حسابك وبياناتك في أي وقت عبر التواصل مع الدعم.',
                            'You can request account and data deletion at any time by contacting support.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.cairo(
              color: secondaryTextColor,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Directionality(
          textDirection:
              widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              t('تغيير كلمة المرور', 'Change Password'),
              style: GoogleFonts.cairo(
                color: primaryTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passField(
                  currentCtrl,
                  t('كلمة المرور الحالية', 'Current Password'),
                  obscure1,
                  () => setDlg(() => obscure1 = !obscure1),
                ),
                const SizedBox(height: 12),
                _passField(
                  newCtrl,
                  t('كلمة المرور الجديدة', 'New Password'),
                  obscure2,
                  () => setDlg(() => obscure2 = !obscure2),
                ),
                const SizedBox(height: 12),
                _passField(
                  confirmCtrl,
                  t('تأكيد كلمة المرور', 'Confirm Password'),
                  obscure3,
                  () => setDlg(() => obscure3 = !obscure3),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  t('إلغاء', 'Cancel'),
                  style: TextStyle(color: secondaryTextColor),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green,
                      content: Text(
                        t('تم تغيير كلمة المرور بنجاح',
                            'Password changed successfully'),
                        style: GoogleFonts.cairo(color: Colors.white),
                      ),
                    ),
                  );
                },
                child: Text(
                  t('حفظ', 'Save'),
                  style: GoogleFonts.cairo(
                    color: Colors.black,
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

  Widget _passField(
    TextEditingController ctrl,
    String label,
    bool obscure,
    VoidCallback onToggle,
  ) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: primaryTextColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: secondaryTextColor),
        prefixIcon: Icon(Icons.lock_outline, color: secondaryTextColor),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: secondaryTextColor,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: cardBorderColor.withValues(alpha: 0.5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          t('تسجيل الخروج', 'Logout'),
          style: TextStyle(color: primaryTextColor),
        ),
        content: Text(
          t(
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            'Are you sure you want to logout?',
          ),
          style: TextStyle(color: primaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              t('إلغاء', 'Cancel'),
              style: TextStyle(color: primaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              await SessionService.clearSession();

              if (!mounted) return;

              context.read<AppState>().logout();
              nav.pop();

              nav.pushNamedAndRemoveUntil(
                '/onboarding',
                (route) => false,
              );
            },
            child: Text(
              t('تسجيل الخروج', 'Logout'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          t('حسابي', 'Profile'),
          style: GoogleFonts.arefRuqaa(
            color: primaryTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Removed settings icon – settings are now inline
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── Avatar with edit button ──────────────────────────────
              Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: accent.withValues(alpha: 0.2),
                    child: Icon(Icons.person, size: 56, color: accent),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showEditProfileSheet,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: backgroundColor, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 16, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: GoogleFonts.arefRuqaa(
                  color: primaryTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: secondaryTextColor),
                  const SizedBox(width: 4),
                  Text(
                    location,
                    style: TextStyle(color: secondaryTextColor, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── Bio (only shown if not empty) ──────────────────────
              if (bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // ─── Menu: Wishlist ────────────────────────────────────────
              _MenuItem(
                icon: Icons.favorite_border,
                label: t('المفضلة', 'Wishlist'),
                onTap: () {},
                accent: accent,
                primaryText: primaryTextColor,
                surface: surfaceColor,
                border: cardBorderColor,
              ),

              Divider(height: 30, color: cardBorderColor),

              // ─── Settings Section ──────────────────────────────────────
              Text(
                t('الإعدادات', 'Settings'),
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Dark Mode
              _SettingsTile(
                icon: widget.isDarkMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                label: t('الوضع الليلي', 'Dark Mode'),
                trailing: Switch(
                  value: widget.isDarkMode,
                  onChanged: (_) => widget.onToggleTheme(),
                  activeThumbColor: accent,
                ),
                accent: accent,
                primaryText: primaryTextColor,
                surface: surfaceColor,
                border: cardBorderColor,
              ),

              // Language
              _SettingsTile(
                icon: Icons.language,
                label: t('اللغة', 'Language'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isArabic ? 'عربي' : 'English',
                      style: TextStyle(color: primaryTextColor, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.swap_horiz, color: accent, size: 20),
                      onPressed: widget.onToggleLanguage,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                accent: accent,
                primaryText: primaryTextColor,
                surface: surfaceColor,
                border: cardBorderColor,
              ),

              // Notifications
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: t('الإشعارات', 'Notifications'),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                  activeThumbColor: accent,
                ),
                accent: accent,
                primaryText: primaryTextColor,
                surface: surfaceColor,
                border: cardBorderColor,
              ),

              // Payment Details (password-gated)
              _SettingsTile(
                icon: Icons.credit_card_outlined,
                label: _iban.isNotEmpty
                    ? t('تفاصيل الدفع • ${_iban.length > 6 ? '...${_iban.substring(_iban.length - 4)}' : _iban}',
                        'Payment Details • ...${_iban.length > 4 ? _iban.substring(_iban.length - 4) : _iban}')
                    : t('تفاصيل الدفع', 'Payment Details'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _showPaymentPasswordGate,
                accent: accent,
                primaryText: primaryTextColor,
                surface: surfaceColor,
                border: cardBorderColor,
              ),

              // Switch Role (only shown if user has owner/artisan role)
              Builder(
                builder: (ctx) {
                  final appState = context.watch<AppState>();
                  final hasOwnerRole =
                      appState.roles.contains('exhibition_owner');
                  final hasArtisanRole = appState.roles.contains('artisan');
                  if (!hasOwnerRole && !hasArtisanRole)
                    return const SizedBox.shrink();
                  final targetRole =
                      hasOwnerRole ? 'exhibition_owner' : 'artisan';
                  final roleLabel = hasOwnerRole
                      ? t('انتقل إلى واجهة منظم المعرض',
                          'Switch to Exhibition Owner')
                      : t('انتقل إلى واجهة الحرفي',
                          'Switch to Artisan Dashboard');
                  return _SettingsTile(
                    icon: Icons.swap_horiz_rounded,
                    label: roleLabel,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      appState.setActiveRole(targetRole);
                    },
                    accent: const Color(0xFFD4A017),
                    primaryText: const Color(0xFFD4A017),
                    surface: surfaceColor,
                    border: cardBorderColor,
                  );
                },
              ),

              // Privacy
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: t('الخصوصية', 'Privacy'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _showPrivacySheet,
                accent: accent,
                primaryText: primaryTextColor,
                surface: surfaceColor,
                border: cardBorderColor,
              ),

              // Change Password
              _SettingsTile(
                icon: Icons.lock_outline,
                label: t('تغيير كلمة المرور', 'Change Password'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _showChangePasswordDialog,
                accent: accent,
                primaryText: primaryTextColor,
                surface: surfaceColor,
                border: cardBorderColor,
              ),

              // Logout
              _SettingsTile(
                icon: Icons.logout,
                label: t('تسجيل الخروج', 'Logout'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: _showLogoutDialog,
                accent: Colors.redAccent,
                primaryText: Colors.redAccent,
                surface: surfaceColor,
                border: cardBorderColor,
                isDanger: true,
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Menu Item (Wishlist) ──────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent, primaryText, surface, border;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
    required this.primaryText,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        color: surface,
      ),
      child: ListTile(
        leading: Icon(icon, color: accent),
        title: Text(label, style: TextStyle(color: primaryText, fontSize: 15)),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: primaryText.withValues(alpha: 0.4),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color accent, primaryText, surface, border;
  final bool isDanger;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
    required this.accent,
    required this.primaryText,
    required this.surface,
    required this.border,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        color: surface,
      ),
      child: ListTile(
        leading: Icon(icon, color: isDanger ? Colors.redAccent : accent),
        title: Text(
          label,
          style: TextStyle(
            color: isDanger ? Colors.redAccent : primaryText,
            fontSize: 14,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import 'dart:convert';
// import '../../app_state.dart';
// import '../../services/api_service.dart';
// import '../../services/session_service.dart';

// class CustomerProfileScreen extends StatefulWidget {
//   final bool isArabic;
//   final bool isDarkMode;
//   final VoidCallback onToggleLanguage;
//   final VoidCallback onToggleTheme;
//   final String userName;

//   const CustomerProfileScreen({
//     super.key,
//     required this.isArabic,
//     required this.isDarkMode,
//     required this.onToggleLanguage,
//     required this.onToggleTheme,
//     this.userName = 'Customer',
//   });

//   @override
//   State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
// }

// class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
//   // Real user data – loaded from API
//   String name = '';
//   String email = '';
//   String phone = '';
//   String bio = '';
//   String location = '';
//   String _bankName = '';
//   String _accountTitle = '';
//   String _iban = '';
//   String? profileImageUrl;
//   bool _isLoading = true;
//   bool _isSaving = false;

//   // Controllers for editing
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _phoneController = TextEditingController();
//   final TextEditingController _bioController = TextEditingController();
//   final TextEditingController _locationController = TextEditingController();

//   // Payment controllers
//   final TextEditingController _bankNameCtrl = TextEditingController();
//   final TextEditingController _accountTitleCtrl = TextEditingController();
//   final TextEditingController _ibanCtrl = TextEditingController();

//   // Notification toggle state
//   bool _notificationsEnabled = true;

//   @override
//   void initState() {
//     super.initState();
//     _fetchProfile();
//   }

//   Future<void> _fetchProfile() async {
//     setState(() => _isLoading = true);
//     try {
//       final response = await ApiService.get('/auth/me');
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final user = data['user'] ?? data;
//         setState(() {
//           name = user['name'] ?? widget.userName;
//           email = user['email'] ?? '';
//           phone = user['phone'] ?? '';
//           bio = user['bio'] ?? '';
//           location = user['location'] ?? user['city'] ?? '';
//           _bankName = user['bankName'] ?? '';
//           _accountTitle = user['accountTitle'] ?? '';
//           _iban = user['iban'] ?? '';
//           profileImageUrl = user['profileImage'] ?? user['avatar'];
//           _nameController.text = name;
//           _phoneController.text = phone;
//           _bioController.text = bio;
//           _locationController.text = location;
//           _isLoading = false;
//         });
//       } else {
//         setState(() => _isLoading = false);
//       }
//     } catch (e) {
//       debugPrint('Error fetching profile: $e');
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _saveProfile() async {
//     setState(() => _isSaving = true);
//     try {
//       final response = await ApiService.put('/auth/profile', body: {
//         'name': _nameController.text.trim(),
//         'phone': _phoneController.text.trim(),
//         'bio': _bioController.text.trim(),
//         'location': _locationController.text.trim(),
//       });
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final user = data['user'] ?? data;
//         setState(() {
//           name = user['name'] ?? _nameController.text.trim();
//           phone = user['phone'] ?? _phoneController.text.trim();
//           bio = user['bio'] ?? _bioController.text.trim();
//           location = user['location'] ?? _locationController.text.trim();
//         });
//         if (mounted) Navigator.pop(context);
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(t('تم تحديث الملف الشخصي', 'Profile updated successfully'))),
//           );
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(t('فشل التحديث، حاول مجدداً', 'Update failed, try again'))),
//           );
//         }
//       }
//     } catch (e) {
//       debugPrint('Error saving profile: $e');
//     } finally {
//       if (mounted) setState(() => _isSaving = false);
//     }
//   }

//   // Theme colors
//   Color get backgroundColor =>
//       widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
//   Color get primaryTextColor =>
//       widget.isDarkMode ? Colors.white : Colors.black87;
//   Color get secondaryTextColor =>
//       widget.isDarkMode ? Colors.white70 : Colors.black54;
//   Color get cardBorderColor =>
//       widget.isDarkMode ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
//   Color get surfaceColor =>
//       widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
//   Color get accent => const Color(0xFFD4A017);

//   String t(String ar, String en) => widget.isArabic ? ar : en;

//   // ─── Payment Details (password-gated) ───────────────────────────────────
//   void _showPaymentPasswordGate() {
//     final passCtrl = TextEditingController();
//     bool obscure = true;
//     showDialog(
//       context: context,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setD) => Directionality(
//           textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//           child: AlertDialog(
//             backgroundColor: surfaceColor,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//             title: Row(
//               children: [
//                 Icon(Icons.lock_outline, color: accent, size: 22),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     t('تأكيد الهوية', 'Confirm Your Identity'),
//                     style: GoogleFonts.cairo(color: primaryTextColor, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   t('لحماية حسابك، أدخل كلمة المرور للوصول إلى تفاصيل الدفع',
//                     'To protect your account, enter your password to access payment details.'),
//                   style: TextStyle(color: secondaryTextColor, fontSize: 13),
//                 ),
//                 const SizedBox(height: 16),
//                 _passField(passCtrl, t('كلمة المرور', 'Password'), obscure,
//                     () => setD(() => obscure = !obscure)),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: Text(t('إلغاء', 'Cancel'),
//                     style: TextStyle(color: secondaryTextColor)),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: accent,
//                   shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                 ),
//                 onPressed: () {
//                   // In real implementation, verify password via API.
//                   // For now, any non-empty password unlocks the sheet.
//                   if (passCtrl.text.isNotEmpty) {
//                     Navigator.pop(ctx);
//                     _showPaymentDetailsSheet();
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(t('أدخل كلمة المرور', 'Please enter your password')),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                   }
//                 },
//                 child: Text(t('تأكيد', 'Confirm'),
//                     style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _showPaymentDetailsSheet() {
//     _bankNameCtrl.text = _bankName;
//     _accountTitleCtrl.text = _accountTitle;
//     _ibanCtrl.text = _iban;
//     bool isSavingPayment = false;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setSheet) => DraggableScrollableSheet(
//           initialChildSize: 0.85,
//           minChildSize: 0.5,
//           maxChildSize: 0.95,
//           builder: (_, scrollController) => Directionality(
//             textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//             child: Container(
//               padding: EdgeInsets.only(
//                 bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
//                 top: 24,
//                 left: 24,
//                 right: 24,
//               ),
//               decoration: BoxDecoration(
//                 color: surfaceColor,
//                 borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
//                 border: Border.all(color: cardBorderColor),
//               ),
//               child: SingleChildScrollView(
//                 controller: scrollController,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Drag handle
//                     Center(
//                       child: Container(
//                         width: 40, height: 4,
//                         decoration: BoxDecoration(
//                           color: secondaryTextColor.withValues(alpha: 0.3),
//                           borderRadius: BorderRadius.circular(2),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.all(10),
//                           decoration: BoxDecoration(
//                             color: accent.withValues(alpha: 0.12),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Icon(Icons.account_balance_outlined, color: accent, size: 22),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 t('تفاصيل الدفع', 'Payment Details'),
//                                 style: GoogleFonts.arefRuqaa(
//                                   color: primaryTextColor,
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               Text(
//                                 t('بيانات بطاقتك المحفوظة وحساب الاستلام', 'Your saved card & payout account'),
//                                 style: TextStyle(color: secondaryTextColor, fontSize: 12),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 24),

//                     // Escrow notice
//                     Container(
//                       padding: const EdgeInsets.all(14),
//                       decoration: BoxDecoration(
//                         color: accent.withValues(alpha: 0.08),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: accent.withValues(alpha: 0.25)),
//                       ),
//                       child: Row(
//                         children: [
//                           Icon(Icons.shield_outlined, color: accent, size: 20),
//                           const SizedBox(width: 10),
//                           Expanded(
//                             child: Text(
//                               t('جميع مدفوعاتك محمية بنظام Escrow. لا يصل مبلغ الحرفي حتى تؤكد استلام الخدمة.',
//                                 'All your payments are Escrow-protected. Craftsmen are only paid once you confirm delivery.'),
//                               style: TextStyle(color: secondaryTextColor, fontSize: 12, height: 1.4),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 24),

//                     // Bank details section header
//                     Text(
//                       t('حساب الاستلام (IBAN)', 'Payout Account (IBAN)'),
//                       style: TextStyle(
//                         color: secondaryTextColor,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     _buildEditField(
//                       label: t('اسم البنك', 'Bank Name'),
//                       controller: _bankNameCtrl,
//                     ),
//                     _buildEditField(
//                       label: t('اسم صاحب الحساب', 'Account Holder Name'),
//                       controller: _accountTitleCtrl,
//                     ),
//                     _buildEditField(
//                       label: t('رقم الحساب / IBAN', 'IBAN / Account Number'),
//                       controller: _ibanCtrl,
//                     ),
//                     const SizedBox(height: 30),

//                     // Action buttons
//                     Row(
//                       children: [
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: () => Navigator.pop(ctx),
//                             style: OutlinedButton.styleFrom(
//                               side: BorderSide(color: cardBorderColor),
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(16),
//                               ),
//                             ),
//                             child: Text(
//                               t('إلغاء', 'Cancel'),
//                               style: TextStyle(color: primaryTextColor),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           flex: 2,
//                           child: Container(
//                             height: 50,
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(16),
//                               gradient: const LinearGradient(
//                                 colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
//                               ),
//                             ),
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.transparent,
//                                 shadowColor: Colors.transparent,
//                               ),
//                               onPressed: () async {
//                                 setSheet(() => isSavingPayment = true);
//                                 try {
//                                   final response = await ApiService.put('/auth/profile', body: {
//                                     'bankName': _bankNameCtrl.text.trim(),
//                                     'accountTitle': _accountTitleCtrl.text.trim(),
//                                     'iban': _ibanCtrl.text.trim(),
//                                   });
//                                   if (response.statusCode == 200) {
//                                     setState(() {
//                                       _bankName = _bankNameCtrl.text.trim();
//                                       _accountTitle = _accountTitleCtrl.text.trim();
//                                       _iban = _ibanCtrl.text.trim();
//                                     });
//                                     if (ctx.mounted) Navigator.pop(ctx);
//                                     if (mounted) {
//                                       ScaffoldMessenger.of(context).showSnackBar(
//                                         SnackBar(
//                                           content: Text(t('تم حفظ تفاصيل الدفع بنجاح', 'Payment details saved successfully')),
//                                           backgroundColor: Colors.green,
//                                         ),
//                                       );
//                                     }
//                                   }
//                                 } catch (_) {
//                                   // ignore
//                                 } finally {
//                                   if (ctx.mounted) setSheet(() => isSavingPayment = false);
//                                 }
//                               },
//                               child: isSavingPayment
//                                   ? const SizedBox(width: 20, height: 20,
//                                       child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
//                                   : Text(
//                                       t('حفظ', 'Save'),
//                                       style: const TextStyle(
//                                         color: Colors.black,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 20),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ─── Edit Profile Sheet ──────────────────────────────────────────────
//   void _showEditProfileSheet() {
//     _nameController.text = name;
//     _phoneController.text = phone;
//     _bioController.text = bio;
//     _locationController.text = location;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => DraggableScrollableSheet(
//         initialChildSize: 0.9,
//         minChildSize: 0.5,
//         maxChildSize: 0.95,
//         builder: (_, scrollController) => Container(
//           padding: EdgeInsets.only(
//             bottom: MediaQuery.of(context).viewInsets.bottom + 20,
//             top: 24,
//             left: 24,
//             right: 24,
//           ),
//           decoration: BoxDecoration(
//             color: surfaceColor,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
//             border: Border.all(color: cardBorderColor),
//           ),
//           child: SingleChildScrollView(
//             controller: scrollController,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Center(
//                   child: Container(
//                     width: 40,
//                     height: 4,
//                     decoration: BoxDecoration(
//                       color: secondaryTextColor.withValues(alpha: 0.3),
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   t('تعديل الملف الشخصي', 'Edit Profile'),
//                   style: GoogleFonts.arefRuqaa(
//                     color: primaryTextColor,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 20),

//                 // Avatar (edit placeholder)
//                 Center(
//                   child: Stack(
//                     children: [
//                       CircleAvatar(
//                         radius: 50,
//                         backgroundColor: accent.withValues(alpha: 0.2),
//                         child: Icon(Icons.person, size: 50, color: accent),
//                       ),
//                       Positioned(
//                         bottom: 0,
//                         right: 0,
//                         child: Container(
//                           decoration: BoxDecoration(
//                             color: accent,
//                             shape: BoxShape.circle,
//                             border: Border.all(color: surfaceColor, width: 2),
//                           ),
//                           child: IconButton(
//                             icon: Icon(Icons.camera_alt, size: 18, color: Colors.black),
//                             onPressed: () {},
//                             padding: EdgeInsets.zero,
//                             constraints: const BoxConstraints(),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),

//                 _buildEditField(
//                   label: t('الاسم', 'Full Name'),
//                   controller: _nameController,
//                 ),
//                 _buildReadOnlyField(
//                   label: t('البريد الإلكتروني', 'Email'),
//                   value: email,
//                 ),
//                 _buildEditField(
//                   label: t('رقم الهاتف', 'Phone'),
//                   controller: _phoneController,
//                   keyboardType: TextInputType.phone,
//                 ),
//                 _buildEditField(
//                   label: t('نبذة', 'Bio'),
//                   controller: _bioController,
//                   maxLines: 3,
//                 ),
//                 _buildEditField(
//                   label: t('الموقع', 'Location'),
//                   controller: _locationController,
//                 ),
//                 const SizedBox(height: 30),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: OutlinedButton(
//                         onPressed: () => Navigator.pop(context),
//                         style: OutlinedButton.styleFrom(
//                           side: BorderSide(color: cardBorderColor),
//                           padding: const EdgeInsets.symmetric(vertical: 14),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(16),
//                           ),
//                         ),
//                         child: Text(
//                           t('إلغاء', 'Cancel'),
//                           style: TextStyle(color: primaryTextColor),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       flex: 2,
//                       child: Container(
//                         height: 50,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(16),
//                           gradient: const LinearGradient(
//                             colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
//                           ),
//                         ),
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.transparent,
//                             shadowColor: Colors.transparent,
//                           ),
//                           onPressed: () async {
//                             await _saveProfile();
//                           },
//                           child: _isSaving
//                               ? const SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                                 color: Colors.black, strokeWidth: 2),
//                           )
//                               : Text(
//                             t('حفظ', 'Save'),
//                             style: const TextStyle(
//                               color: Colors.black,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildEditField({
//     required String label,
//     required TextEditingController controller,
//     int maxLines = 1,
//     TextInputType keyboardType = TextInputType.text,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: secondaryTextColor,
//               fontSize: 13,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 6),
//           TextField(
//             controller: controller,
//             maxLines: maxLines,
//             keyboardType: keyboardType,
//             style: TextStyle(color: primaryTextColor),
//             decoration: InputDecoration(
//               filled: true,
//               fillColor: widget.isDarkMode
//                   ? Colors.white.withValues(alpha: 0.04)
//                   : Colors.black.withValues(alpha: 0.02),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide.none,
//               ),
//               focusedBorder: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide(color: accent),
//               ),
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 16,
//                 vertical: 14,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildReadOnlyField({required String label, required String value}) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               color: secondaryTextColor,
//               fontSize: 13,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//             decoration: BoxDecoration(
//               color: widget.isDarkMode
//                   ? Colors.white.withValues(alpha: 0.04)
//                   : Colors.black.withValues(alpha: 0.02),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: cardBorderColor),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     value,
//                     style: TextStyle(color: secondaryTextColor, fontSize: 14),
//                   ),
//                 ),
//                 Icon(Icons.lock_outline, size: 16, color: secondaryTextColor),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Settings Dialog (now inline in the profile page) ───────────────
//   // All these methods are kept, but we'll call them from the settings tiles.

//   void _showPrivacySheet() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: surfaceColor,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//       ),
//       builder: (ctx) => Directionality(
//         textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//         child: SizedBox(
//           height: MediaQuery.of(context).size.height * 0.7,
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Center(
//                   child: Container(
//                     width: 40,
//                     height: 4,
//                     decoration: BoxDecoration(
//                       color: secondaryTextColor.withValues(alpha: 0.3),
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                   t('سياسة الخصوصية', 'Privacy Policy'),
//                   style: GoogleFonts.cairo(
//                     color: primaryTextColor,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     physics: const BouncingScrollPhysics(),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _privacySection(
//                           t('جمع البيانات', 'Data Collection'),
//                           t(
//                             'نجمع بياناتك فقط لتحسين تجربتك على التطبيق. لا نبيع بياناتك لأي جهة خارجية.',
//                             'We collect your data only to improve your app experience. We never sell your data to third parties.',
//                           ),
//                         ),
//                         _privacySection(
//                           t('الدفع والأمان', 'Payment & Security'),
//                           t(
//                             'جميع المدفوعات محمية بنظام Escrow — لا يصل الحرفي مبلغه حتى تأكدك من استلام الخدمة.',
//                             'All payments are protected by Escrow — the craftsman does not receive funds until you confirm service delivery.',
//                           ),
//                         ),
//                         _privacySection(
//                           t('حذف الحساب', 'Account Deletion'),
//                           t(
//                             'يمكنك طلب حذف حسابك وبياناتك في أي وقت عبر التواصل مع الدعم.',
//                             'You can request account and data deletion at any time by contacting support.',
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _privacySection(String title, String body) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 4,
//                 height: 18,
//                 decoration: BoxDecoration(
//                   color: accent,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 title,
//                 style: GoogleFonts.cairo(
//                   color: primaryTextColor,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 15,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 6),
//           Text(
//             body,
//             style: GoogleFonts.cairo(
//               color: secondaryTextColor,
//               fontSize: 13,
//               height: 1.6,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showChangePasswordDialog() {
//     final currentCtrl = TextEditingController();
//     final newCtrl = TextEditingController();
//     final confirmCtrl = TextEditingController();
//     bool obscure1 = true, obscure2 = true, obscure3 = true;

//     showDialog(
//       context: context,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setDlg) => Directionality(
//           textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
//           child: AlertDialog(
//             backgroundColor: surfaceColor,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//             title: Text(
//               t('تغيير كلمة المرور', 'Change Password'),
//               style: GoogleFonts.cairo(
//                 color: primaryTextColor,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 _passField(
//                   currentCtrl,
//                   t('كلمة المرور الحالية', 'Current Password'),
//                   obscure1,
//                       () => setDlg(() => obscure1 = !obscure1),
//                 ),
//                 const SizedBox(height: 12),
//                 _passField(
//                   newCtrl,
//                   t('كلمة المرور الجديدة', 'New Password'),
//                   obscure2,
//                       () => setDlg(() => obscure2 = !obscure2),
//                 ),
//                 const SizedBox(height: 12),
//                 _passField(
//                   confirmCtrl,
//                   t('تأكيد كلمة المرور', 'Confirm Password'),
//                   obscure3,
//                       () => setDlg(() => obscure3 = !obscure3),
//                 ),
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(ctx),
//                 child: Text(
//                   t('إلغاء', 'Cancel'),
//                   style: TextStyle(color: secondaryTextColor),
//                 ),
//               ),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: accent,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 onPressed: () {
//                   Navigator.pop(ctx);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       backgroundColor: Colors.green,
//                       content: Text(
//                         t('تم تغيير كلمة المرور بنجاح', 'Password changed successfully'),
//                         style: GoogleFonts.cairo(color: Colors.white),
//                       ),
//                     ),
//                   );
//                 },
//                 child: Text(
//                   t('حفظ', 'Save'),
//                   style: GoogleFonts.cairo(
//                     color: Colors.black,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _passField(
//       TextEditingController ctrl,
//       String label,
//       bool obscure,
//       VoidCallback onToggle,
//       ) {
//     return TextField(
//       controller: ctrl,
//       obscureText: obscure,
//       style: TextStyle(color: primaryTextColor),
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: TextStyle(color: secondaryTextColor),
//         prefixIcon: Icon(Icons.lock_outline, color: secondaryTextColor),
//         suffixIcon: IconButton(
//           icon: Icon(
//             obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
//             color: secondaryTextColor,
//             size: 20,
//           ),
//           onPressed: onToggle,
//         ),
//         filled: true,
//         fillColor: cardBorderColor.withValues(alpha: 0.5),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: cardBorderColor),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: accent, width: 2),
//         ),
//         contentPadding: const EdgeInsets.symmetric(
//           horizontal: 16,
//           vertical: 14,
//         ),
//       ),
//     );
//   }

//   void _showLogoutDialog() {
//     showDialog(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         backgroundColor: surfaceColor,
//         title: Text(
//           t('تسجيل الخروج', 'Logout'),
//           style: TextStyle(color: primaryTextColor),
//         ),
//         content: Text(
//           t(
//             'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
//             'Are you sure you want to logout?',
//           ),
//           style: TextStyle(color: primaryTextColor),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(dialogContext),
//             child: Text(
//               t('إلغاء', 'Cancel'),
//               style: TextStyle(color: primaryTextColor),
//             ),
//           ),
//           TextButton(
//             onPressed: () async {
//               final nav = Navigator.of(context);
//               await SessionService.clearSession();

//               if (!mounted) return;

//               context.read<AppState>().logout();
//               nav.pop();

//               nav.pushNamedAndRemoveUntil(
//                 '/onboarding',
//                     (route) => false,
//               );
//             },
//             child: Text(
//               t('تسجيل الخروج', 'Logout'),
//               style: const TextStyle(color: Colors.redAccent),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─── Build ──────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         backgroundColor: backgroundColor,
//         elevation: 0,
//         title: Text(
//           t('حسابي', 'Profile'),
//           style: GoogleFonts.arefRuqaa(
//             color: primaryTextColor,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         // Removed settings icon – settings are now inline
//       ),
//       body: SingleChildScrollView(
//         physics: const BouncingScrollPhysics(),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               // ─── Avatar with edit button ──────────────────────────────
//               Stack(
//                 children: [
//                   CircleAvatar(
//                     radius: 56,
//                     backgroundColor: accent.withValues(alpha: 0.2),
//                     child: Icon(Icons.person, size: 56, color: accent),
//                   ),
//                   Positioned(
//                     bottom: 0,
//                     right: 0,
//                     child: GestureDetector(
//                       onTap: _showEditProfileSheet,
//                       child: Container(
//                         padding: const EdgeInsets.all(4),
//                         decoration: BoxDecoration(
//                           color: accent,
//                           shape: BoxShape.circle,
//                           border: Border.all(color: backgroundColor, width: 2),
//                         ),
//                         child: const Icon(Icons.edit, size: 16, color: Colors.black),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 name,
//                 style: GoogleFonts.arefRuqaa(
//                   color: primaryTextColor,
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.location_on_outlined, size: 14, color: secondaryTextColor),
//                   const SizedBox(width: 4),
//                   Text(
//                     location,
//                     style: TextStyle(color: secondaryTextColor, fontSize: 12),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   color: surfaceColor,
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(color: cardBorderColor),
//                 ),
//                 child: Text(
//                   bio,
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     color: secondaryTextColor,
//                     fontSize: 13,
//                     height: 1.5,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 30),

//               // ─── Menu: Wishlist ────────────────────────────────────────
//               _MenuItem(
//                 icon: Icons.favorite_border,
//                 label: t('المفضلة', 'Wishlist'),
//                 onTap: () {},
//                 accent: accent,
//                 primaryText: primaryTextColor,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//               ),

//               Divider(height: 30, color: cardBorderColor),

//               // ─── Settings Section ──────────────────────────────────────
//               Text(
//                 t('الإعدادات', 'Settings'),
//                 style: GoogleFonts.cairo(
//                   color: primaryTextColor,
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),

//               // Dark Mode
//               _SettingsTile(
//                 icon: widget.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
//                 label: t('الوضع الليلي', 'Dark Mode'),
//                 trailing: Switch(
//                   value: widget.isDarkMode,
//                   onChanged: (_) => widget.onToggleTheme(),
//                   activeThumbColor: accent,
//                 ),
//                 accent: accent,
//                 primaryText: primaryTextColor,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//               ),

//               // Language
//               _SettingsTile(
//                 icon: Icons.language,
//                 label: t('اللغة', 'Language'),
//                 trailing: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       widget.isArabic ? 'عربي' : 'English',
//                       style: TextStyle(color: primaryTextColor, fontSize: 13),
//                     ),
//                     const SizedBox(width: 8),
//                     IconButton(
//                       icon: Icon(Icons.swap_horiz, color: accent, size: 20),
//                       onPressed: widget.onToggleLanguage,
//                       padding: EdgeInsets.zero,
//                       constraints: const BoxConstraints(),
//                     ),
//                   ],
//                 ),
//                 accent: accent,
//                 primaryText: primaryTextColor,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//               ),

//               // Notifications
//               _SettingsTile(
//                 icon: Icons.notifications_outlined,
//                 label: t('الإشعارات', 'Notifications'),
//                 trailing: Switch(
//                   value: _notificationsEnabled,
//                   onChanged: (v) => setState(() => _notificationsEnabled = v),
//                   activeThumbColor: accent,
//                 ),
//                 accent: accent,
//                 primaryText: primaryTextColor,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//               ),

//               // Payment Details (password-gated)
//               _SettingsTile(
//                 icon: Icons.credit_card_outlined,
//                 label: _iban.isNotEmpty
//                     ? t('تفاصيل الدفع • ${_iban.length > 6 ? '...${_iban.substring(_iban.length - 4)}' : _iban}',
//                         'Payment Details • ...${_iban.length > 4 ? _iban.substring(_iban.length - 4) : _iban}')
//                     : t('تفاصيل الدفع', 'Payment Details'),
//                 trailing: const Icon(Icons.arrow_forward_ios, size: 14),
//                 onTap: _showPaymentPasswordGate,
//                 accent: accent,
//                 primaryText: primaryTextColor,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//               ),

//               // Switch Role (only shown if user has owner/artisan role)
//               Builder(
//                 builder: (ctx) {
//                   final appState = context.watch<AppState>();
//                   final hasOwnerRole = appState.roles.contains('exhibition_owner');
//                   final hasArtisanRole = appState.roles.contains('artisan');
//                   if (!hasOwnerRole && !hasArtisanRole) return const SizedBox.shrink();
//                   final targetRole = hasOwnerRole ? 'exhibition_owner' : 'artisan';
//                   final roleLabel = hasOwnerRole
//                       ? t('انتقل إلى واجهة منظم المعرض', 'Switch to Exhibition Owner')
//                       : t('انتقل إلى واجهة الحرفي', 'Switch to Artisan Dashboard');
//                   return _SettingsTile(
//                     icon: Icons.swap_horiz_rounded,
//                     label: roleLabel,
//                     trailing: const Icon(Icons.arrow_forward_ios, size: 14),
//                     onTap: () {
//                       appState.setActiveRole(targetRole);
//                     },
//                     accent: const Color(0xFFD4A017),
//                     primaryText: const Color(0xFFD4A017),
//                     surface: surfaceColor,
//                     border: cardBorderColor,
//                   );
//                 },
//               ),

//               // Privacy
//               _SettingsTile(
//                 icon: Icons.privacy_tip_outlined,
//                 label: t('الخصوصية', 'Privacy'),
//                 trailing: const Icon(Icons.arrow_forward_ios, size: 14),
//                 onTap: _showPrivacySheet,
//                 accent: accent,
//                 primaryText: primaryTextColor,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//               ),

//               // Change Password
//               _SettingsTile(
//                 icon: Icons.lock_outline,
//                 label: t('تغيير كلمة المرور', 'Change Password'),
//                 trailing: const Icon(Icons.arrow_forward_ios, size: 14),
//                 onTap: _showChangePasswordDialog,
//                 accent: accent,
//                 primaryText: primaryTextColor,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//               ),

//               // Logout
//               _SettingsTile(
//                 icon: Icons.logout,
//                 label: t('تسجيل الخروج', 'Logout'),
//                 trailing: const Icon(Icons.arrow_forward_ios, size: 14),
//                 onTap: _showLogoutDialog,
//                 accent: Colors.redAccent,
//                 primaryText: Colors.redAccent,
//                 surface: surfaceColor,
//                 border: cardBorderColor,
//                 isDanger: true,
//               ),

//               const SizedBox(height: 30),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─── Menu Item (Wishlist) ──────────────────────────────────────────────────────
// class _MenuItem extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final VoidCallback onTap;
//   final Color accent, primaryText, surface, border;

//   const _MenuItem({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//     required this.accent,
//     required this.primaryText,
//     required this.surface,
//     required this.border,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 8),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: border),
//         color: surface,
//       ),
//       child: ListTile(
//         leading: Icon(icon, color: accent),
//         title: Text(label, style: TextStyle(color: primaryText, fontSize: 15)),
//         trailing: Icon(
//           Icons.arrow_forward_ios,
//           size: 16,
//           color: primaryText.withValues(alpha: 0.4),
//         ),
//         onTap: onTap,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       ),
//     );
//   }
// }

// // ─── Settings Tile ────────────────────────────────────────────────────────────
// class _SettingsTile extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Widget trailing;
//   final VoidCallback? onTap;
//   final Color accent, primaryText, surface, border;
//   final bool isDanger;

//   const _SettingsTile({
//     required this.icon,
//     required this.label,
//     required this.trailing,
//     this.onTap,
//     required this.accent,
//     required this.primaryText,
//     required this.surface,
//     required this.border,
//     this.isDanger = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 4),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: border),
//         color: surface,
//       ),
//       child: ListTile(
//         leading: Icon(icon, color: isDanger ? Colors.redAccent : accent),
//         title: Text(
//           label,
//           style: TextStyle(
//             color: isDanger ? Colors.redAccent : primaryText,
//             fontSize: 14,
//           ),
//         ),
//         trailing: trailing,
//         onTap: onTap,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//     );
//   }
// }

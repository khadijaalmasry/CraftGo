import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';

class CustomerPublicProfile extends StatefulWidget {
  final String customerId;
  final bool isArabic;
  final bool isDarkMode;

  const CustomerPublicProfile({
    super.key,
    required this.customerId,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<CustomerPublicProfile> createState() =>
      _CustomerPublicProfileState();
}

class _CustomerPublicProfileState extends State<CustomerPublicProfile> {
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _customer;

  Color get backgroundColor =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color get surfaceColor =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  Color get primaryTextColor =>
      widget.isDarkMode ? Colors.white : Colors.black87;

  Color get secondaryTextColor =>
      widget.isDarkMode ? Colors.white70 : Colors.black54;

  Color get borderColor => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);

  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _fetchCustomer();
  }

  Future<void> _fetchCustomer() async {
    if (widget.customerId.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error = t(
          'معرّف الزبون غير موجود',
          'Customer ID is missing',
        );
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.get(
        '/auth/user/${widget.customerId}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        setState(() {
          _customer = Map<String, dynamic>.from(decoded);
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = t(
            'تعذر تحميل بيانات الزبون',
            'Could not load customer profile',
          );
        });
      }
    } catch (error) {
      debugPrint('Customer public profile error: $error');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = t(
          'حدث خطأ أثناء تحميل البيانات',
          'An error occurred while loading the profile',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
      widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          foregroundColor: primaryTextColor,
          elevation: 0,
          title: Text(
            t('ملف الزبون', 'Customer Profile'),
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: accent,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 70,
                color: Colors.redAccent.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 18),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: primaryTextColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchCustomer,
                icon: const Icon(Icons.refresh),
                label: Text(
                  t('إعادة المحاولة', 'Retry'),
                  style: GoogleFonts.cairo(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final customer = _customer ?? {};

    final name = (customer['name'] ?? '').toString();
    final city = (customer['city'] ?? '').toString();
    final phone = (customer['phone'] ?? '').toString();
    final image = (customer['profileImage'] ?? '').toString();

    final firstLetter =
    name.trim().isEmpty ? '?' : name.trim().characters.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          CircleAvatar(
            radius: 58,
            backgroundColor: accent.withValues(alpha: 0.2),
            backgroundImage:
            image.trim().isEmpty ? null : NetworkImage(image),
            child: image.trim().isEmpty
                ? Text(
              firstLetter,
              style: TextStyle(
                color: accent,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
            )
                : null,
          ),

          const SizedBox(height: 18),

          Text(
            name.isEmpty ? t('مستخدم', 'User') : name,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: primaryTextColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (city.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: secondaryTextColor,
                ),
                const SizedBox(width: 5),
                Text(
                  city,
                  style: GoogleFonts.cairo(
                    color: secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 30),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: Column(
              children: [
                _ProfileInfoRow(
                  icon: Icons.person_outline,
                  label: t('الاسم', 'Name'),
                  value: name.isEmpty ? '-' : name,
                  accent: accent,
                  primaryText: primaryTextColor,
                  secondaryText: secondaryTextColor,
                ),

                if (city.isNotEmpty) ...[
                  Divider(
                    height: 28,
                    color: borderColor,
                  ),
                  _ProfileInfoRow(
                    icon: Icons.location_city_outlined,
                    label: t('المدينة', 'City'),
                    value: city,
                    accent: accent,
                    primaryText: primaryTextColor,
                    secondaryText: secondaryTextColor,
                  ),
                ],

                if (phone.isNotEmpty) ...[
                  Divider(
                    height: 28,
                    color: borderColor,
                  ),
                  _ProfileInfoRow(
                    icon: Icons.phone_outlined,
                    label: t('رقم الهاتف', 'Phone'),
                    value: phone,
                    accent: accent,
                    primaryText: primaryTextColor,
                    secondaryText: secondaryTextColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: secondaryText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.cairo(
                  color: primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_state.dart';
import '../../services/delivery_service.dart';
import '../../services/cloudinary_service.dart';

class DeliveryVehicleScreen extends StatefulWidget {
  const DeliveryVehicleScreen({super.key});

  @override
  State<DeliveryVehicleScreen> createState() => _DeliveryVehicleScreenState();
}

class _DeliveryVehicleScreenState extends State<DeliveryVehicleScreen> {
  Map<String, dynamic>? _vehicle;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  String? _errorMessage;

  static const Color accent = Color(0xFFD4A017);

  @override
  void initState() {
    super.initState();
    _fetchVehicle();
  }

  Future<void> _fetchVehicle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final driverId = context.read<AppState>().userId ?? '1';

    try {
      final data = await DeliveryService.getVehicle(driverId);
      setState(() {
        _vehicle = data ?? {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source, bool isArabic) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final photoUrl = await CloudinaryService.uploadImage(pickedFile);
      if (photoUrl != null && mounted) {
        final driverId = context.read<AppState>().userId ?? '1';

        await DeliveryService.updateVehicle(
          driverId: driverId,
          photoUrl: photoUrl,
        );

        setState(() {
          _vehicle ??= {};
          _vehicle!['photoUrl'] = photoUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? 'تم تحديث صورة المركبة بنجاح'
                    : 'Vehicle image updated successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'فشل رفع الصورة' : 'Failed to upload image',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic
                  ? 'حدث خطأ أثناء رفع الصورة'
                  : 'An error occurred while uploading',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImageSourcePicker({
    required Color surface,
    required Color text,
    required bool isArabic,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: accent),
                title: Text(
                  isArabic ? 'المعرض' : 'Gallery',
                  style: GoogleFonts.cairo(color: text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.gallery, isArabic);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: accent),
                title: Text(
                  isArabic ? 'الكاميرا' : 'Camera',
                  style: GoogleFonts.cairo(color: text),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(ImageSource.camera, isArabic);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;
    final isDarkMode = appState.isDarkMode;

    final bg = isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = isDarkMode ? Colors.white : Colors.black87;
    final dim = isDarkMode ? Colors.white70 : Colors.black54;
    final border = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    String t(String ar, String en) => isArabic ? ar : en;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('المركبة', 'Vehicle'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          actions: [
            if (!_isLoading && _errorMessage == null)
              TextButton(
                onPressed: () => _showEditVehicleDialog(
                  context: context,
                  isArabic: isArabic,
                  surface: surface,
                  text: text,
                  dim: dim,
                ),
                child: Text(
                  t('تعديل', 'Edit'),
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: accent))
            : _errorMessage != null
                ? _buildErrorState(text: text, t: t)
                : RefreshIndicator(
                    onRefresh: _fetchVehicle,
                    color: accent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Vehicle Image Container ──────────────────────
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Stack(
                              children: [
                                if (_vehicle?['photoUrl'] != null &&
                                    (_vehicle!['photoUrl'] as String)
                                        .isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      _vehicle!['photoUrl'],
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _buildImagePlaceholder(
                                              dim: dim, t: t),
                                    ),
                                  )
                                else
                                  _buildImagePlaceholder(dim: dim, t: t),
                                if (_isUploadingImage)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                          color: accent),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 8,
                                  right: isArabic ? null : 8,
                                  left: isArabic ? 8 : null,
                                  child: Material(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: _isUploadingImage
                                          ? null
                                          : () => _showImageSourcePicker(
                                                surface: surface,
                                                text: text,
                                                isArabic: isArabic,
                                              ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.camera_alt,
                                                size: 16, color: accent),
                                            const SizedBox(width: 6),
                                            Text(
                                              t('تغيير الصورة', 'Change Photo'),
                                              style: GoogleFonts.cairo(
                                                color: accent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Vehicle Details ──────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              children: [
                                _detailRow(
                                  icon: Icons.business,
                                  label: t('الماركة', 'Make'),
                                  value: _vehicle?['make'] ?? '-',
                                  dim: dim,
                                  text: text,
                                ),
                                _divider(border),
                                _detailRow(
                                  icon: Icons.car_repair,
                                  label: t('الموديل', 'Model'),
                                  value: _vehicle?['model'] ?? '-',
                                  dim: dim,
                                  text: text,
                                ),
                                _divider(border),
                                _detailRow(
                                  icon: Icons.calendar_today,
                                  label: t('السنة', 'Year'),
                                  value: _vehicle?['year']?.toString() ?? '-',
                                  dim: dim,
                                  text: text,
                                ),
                                _divider(border),
                                _detailRow(
                                  icon: Icons.palette,
                                  label: t('اللون', 'Color'),
                                  value: isArabic
                                      ? (_vehicle?['color'] ?? '-')
                                      : (_vehicle?['colorEn'] ??
                                          _vehicle?['color'] ??
                                          '-'),
                                  dim: dim,
                                  text: text,
                                ),
                                _divider(border),
                                _detailRow(
                                  icon: Icons.confirmation_number,
                                  label: t('رقم اللوحة', 'License Plate'),
                                  value: _vehicle?['licensePlate'] ?? '-',
                                  dim: dim,
                                  text: text,
                                ),
                                _divider(border),
                                _detailRow(
                                  icon: Icons.category,
                                  label: t('النوع', 'Type'),
                                  value: isArabic
                                      ? (_vehicle?['type'] ?? '-')
                                      : (_vehicle?['typeEn'] ??
                                          _vehicle?['type'] ??
                                          '-'),
                                  dim: dim,
                                  text: text,
                                ),
                                _divider(border),
                                _detailRow(
                                  icon: Icons.speed,
                                  label: t('السعة', 'Capacity'),
                                  value: isArabic
                                      ? (_vehicle?['capacity'] ?? '-')
                                      : (_vehicle?['capacityEn'] ??
                                          _vehicle?['capacity'] ??
                                          '-'),
                                  dim: dim,
                                  text: text,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Vehicle Status ──────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t('المركبة معتمدة', 'Vehicle Verified'),
                                        style: GoogleFonts.cairo(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        t('جميع الوثائق صالحة',
                                            'All documents are valid'),
                                        style: GoogleFonts.cairo(
                                          color: dim,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildImagePlaceholder({
    required Color dim,
    required String Function(String ar, String en) t,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.directions_car,
          size: 60,
          color: accent.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 8),
        Text(
          t('صورة المركبة', 'Vehicle Image'),
          style: GoogleFonts.cairo(
            color: dim,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color dim,
    required Color text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                color: dim,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                color: text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color border) {
    return Divider(color: border, height: 1);
  }

  Widget _buildErrorState({
    required Color text,
    required String Function(String ar, String en) t,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            t('فشل في تحميل بيانات المركبة', 'Failed to load vehicle data'),
            style: GoogleFonts.cairo(
              color: text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchVehicle,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            child: Text(
              t('إعادة المحاولة', 'Retry'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditVehicleDialog({
    required BuildContext context,
    required bool isArabic,
    required Color surface,
    required Color text,
    required Color dim,
  }) {
    final makeCtrl = TextEditingController(text: _vehicle?['make'] ?? '');
    final modelCtrl = TextEditingController(text: _vehicle?['model'] ?? '');
    final yearCtrl =
        TextEditingController(text: _vehicle?['year']?.toString() ?? '');
    final colorCtrl = TextEditingController(text: _vehicle?['color'] ?? '');
    final colorEnCtrl = TextEditingController(text: _vehicle?['colorEn'] ?? '');
    final plateCtrl =
        TextEditingController(text: _vehicle?['licensePlate'] ?? '');
    final capacityCtrl =
        TextEditingController(text: _vehicle?['capacity'] ?? '');
    final capacityEnCtrl =
        TextEditingController(text: _vehicle?['capacityEn'] ?? '');

    bool isSaving = false;
    String t(String ar, String en) => isArabic ? ar : en;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = context.read<AppState>().isDarkMode;

          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              t('تعديل بيانات المركبة', 'Edit Vehicle Details'),
              style: GoogleFonts.cairo(
                color: text,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField(
                    controller: makeCtrl,
                    label: t('الماركة', 'Make'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    controller: modelCtrl,
                    label: t('الموديل', 'Model'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    controller: yearCtrl,
                    label: t('السنة', 'Year'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    controller: colorCtrl,
                    label: t('اللون (بالعربية)', 'Color (Arabic)'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    controller: colorEnCtrl,
                    label: t('اللون (بالإنجليزية)', 'Color (English)'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    controller: plateCtrl,
                    label: t('رقم اللوحة', 'License Plate'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    controller: capacityCtrl,
                    label: t('السعة (بالعربية)', 'Capacity (Arabic)'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildDialogField(
                    controller: capacityEnCtrl,
                    label: t('السعة (بالإنجليزية)', 'Capacity (English)'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(
                  t('إلغاء', 'Cancel'),
                  style: TextStyle(color: dim),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        final driverId = context.read<AppState>().userId ?? '1';

                        final updated = await DeliveryService.updateVehicle(
                          driverId: driverId,
                          make: makeCtrl.text.trim(),
                          model: modelCtrl.text.trim(),
                          year: yearCtrl.text.trim(),
                          color: colorCtrl.text.trim(),
                          colorEn: colorEnCtrl.text.trim(),
                          licensePlate: plateCtrl.text.trim(),
                          capacity: capacityCtrl.text.trim(),
                          capacityEn: capacityEnCtrl.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          if (updated != null) {
                            setState(() => _vehicle = updated);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t('تم تحديث بيانات المركبة',
                                      'Vehicle details updated'),
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  t('فشل تحديث البيانات',
                                      'Failed to update details'),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
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
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        t('حفظ', 'Save'),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4A017), width: 2),
        ),
      ),
    );
  }
}

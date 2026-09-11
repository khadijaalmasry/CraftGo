import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'craftsman_category_screen.dart';
import '../../main.dart';
import '../../services/craftsman_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/products_service.dart';
import 'add_product_screen.dart';
import 'craftsman_offers_screen.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/api_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/id_camera_screen.dart';

class CraftsmanProfileScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final String craftsmanId;

  const CraftsmanProfileScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.craftsmanId,
  });

  @override
  State<CraftsmanProfileScreen> createState() => _CraftsmanProfileScreenState();
}

class _CraftsmanProfileScreenState extends State<CraftsmanProfileScreen> {
  // ── State variables ──────────────────────────────────────────────────
  bool _isLoadingProfile = true;
  bool _isLoadingPortfolio = true;
  bool _isLoadingReviews = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _portfolioItems = [];
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingProducts = true;
  int _currentPage = 0;
  int _totalPages = 1;
  final int _pageSize = 5;

  // ── Editable fields (local copy) ──────────────────────────────────────
  late String _editableName;
  late String _editableCity;
  late String _editableBio;
  late int _editableExperience;
  late String _editablePhone;
  late String _editableEmail;
  late String _editablePriceRange;

  // ── Extra crafts ──────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _extraCrafts = [];

  // ── Danger Zone state ──────────────────────────────────────────────────
  bool _dangerZoneExpanded = false;
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _notificationsEnabled = true;

  // ── Image picker ──────────────────────────────────────────────────────
  final ImagePicker _imagePicker = ImagePicker();

  // ── Theme colors ──────────────────────────────────────────────────────
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchPortfolio();
    _fetchProducts();
    _fetchReviews(0);
  }

  // ── API methods ──────────────────────────────────────────────────────
  Future<void> _fetchProfile() async {
    setState(() => _isLoadingProfile = true);
    final data = await CraftsmanService.getProfile(widget.craftsmanId);
    if (data != null && mounted) {
      setState(() {
        _profileData = data;
        _editableName = data['name'] ?? '';
        _editableCity = data['city'] ?? '';
        _editableBio = data['bio'] ?? '';
        _editableExperience = data['experienceYears'] ?? 0;
        _editablePriceRange = data['priceRange'] ?? '';
        _editablePhone = (data['phone'] ?? '').toString();
        _editableEmail = data['email'] ?? '';
        _isLoadingProfile = false;
      });
    } else {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _fetchPortfolio() async {
    setState(() => _isLoadingPortfolio = true);
    final items = await CraftsmanService.getPortfolio(widget.craftsmanId);
    if (mounted) {
      setState(() {
        _portfolioItems = items.cast<Map<String, dynamic>>();
        _isLoadingPortfolio = false;
      });
    }
  }

  Future<void> _fetchProducts() async {
    if (mounted) {
      setState(() => _isLoadingProducts = true);
    }

    final items =
    await ProductsService.getProductsByCraftsman(widget.craftsmanId);

    if (!mounted) return;

    setState(() {
      _products = items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      _isLoadingProducts = false;
    });
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          t('حذف المنتج', 'Delete Product'),
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          t(
            'هل أنت متأكد من حذف هذا المنتج؟',
            'Are you sure you want to delete this product?',
          ),
          style: GoogleFonts.cairo(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('إلغاء', 'Cancel'),
              style: GoogleFonts.cairo(color: dim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('حذف', 'Delete'),
              style: GoogleFonts.cairo(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await ProductsService.deleteProduct(productId);
    if (!mounted) return;

    if (deleted) {
      await _fetchProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم حذف المنتج', 'Product deleted')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل حذف المنتج', 'Failed to delete product')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchReviews(int page) async {
    setState(() => _isLoadingReviews = true);
    final data = await CraftsmanService.getReviews(widget.craftsmanId,
        page: page + 1, limit: _pageSize);
    if (data != null && mounted) {
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data['reviews'] ?? []);
        _totalPages = data['totalPages'] ?? 1;
        _currentPage = page;
        _isLoadingReviews = false;
      });
    } else {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<bool> _updateProfile(Map<String, dynamic> updatedData) async {
    setState(() => _isSaving = true);
    final result =
    await CraftsmanService.updateProfile(widget.craftsmanId, updatedData);
    if (mounted) setState(() => _isSaving = false);
    if (result != null) {
      await _fetchProfile();
      return true;
    }
    return false;
  }


  Future<void> _deletePortfolioItem(String itemId) async {
    final success = await CraftsmanService.deletePortfolioItem(itemId);
    if (success) {
      await _fetchPortfolio();
    }
  }

  // ─── Image Picker Methods ──────────────────────────────────────────────

  Future<XFile?> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      return pickedFile;
    } catch (e) {
      debugPrint('Image pick error: $e');
      return null;
    }
  }

  Future<void> _updateProfileImage() async {
    final XFile? pickedFile = await _pickAndUploadImage();
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);
    final imageUrl = await CloudinaryService.uploadImage(pickedFile);
    setState(() => _isUploadingImage = false);

    if (imageUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل رفع الصورة', 'Failed to upload image')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success =
    await CraftsmanService.updateProfileImage(widget.craftsmanId, imageUrl);
    if (success && mounted) {
      await _fetchProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم تحديث الصورة ✅', 'Image updated ✅')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل تحديث الصورة', 'Failed to update image')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateBannerImage() async {
    final XFile? pickedFile = await _pickAndUploadImage();
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);
    final imageUrl = await CloudinaryService.uploadImage(pickedFile);
    setState(() => _isUploadingImage = false);

    if (imageUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل رفع الصورة', 'Failed to upload image')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success =
    await CraftsmanService.updateBannerImage(widget.craftsmanId, imageUrl);
    if (success && mounted) {
      await _fetchProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('تم تحديث البانر ✅', 'Banner updated ✅')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل تحديث البانر', 'Failed to update banner')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Edit Profile Bottom Sheet ────────────────────────────────────────
  void _showEditProfileSheet() {
    final nameCtrl = TextEditingController(text: _editableName);
    final cityCtrl = TextEditingController(text: _editableCity);
    final bioCtrl = TextEditingController(text: _editableBio);
    final expCtrl = TextEditingController(text: _editableExperience.toString());
    final priceCtrl = TextEditingController(text: _editablePriceRange);
    final phoneCtrl = TextEditingController(text: _editablePhone);
    final emailCtrl = TextEditingController(text: _editableEmail);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: border),
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: dim.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t('تعديل الملف الشخصي', 'Edit Profile'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Avatar (with upload capability)
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: accent.withValues(alpha: 0.2),
                        backgroundImage: _profileData?['profileImage'] != null
                            ? NetworkImage(_profileData!['profileImage'])
                            : null,
                        child: _profileData?['profileImage'] == null
                            ? Icon(Icons.person, size: 50, color: accent)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: surface, width: 2),
                          ),
                          child: _isUploadingImage
                              ? const SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          )
                              : IconButton(
                            icon: Icon(Icons.camera_alt,
                                size: 18, color: Colors.black),
                            onPressed: _updateProfileImage,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _buildEditField(t('الاسم', 'Name'), nameCtrl),
                _buildEditField(t('المدينة', 'City'), cityCtrl),
                _buildEditField(t('نبذة', 'Bio'), bioCtrl, maxLines: 3),
                _buildEditField(t('سنوات الخبرة', 'Experience'), expCtrl,
                    keyboardType: TextInputType.number),
                _buildEditField(
                    t('نطاق السعر (مثال: 50-200)', 'Price Range'), priceCtrl),
                _buildEditField(t('رقم الهاتف', 'Phone'), phoneCtrl,
                    keyboardType: TextInputType.phone),
                _buildReadOnlyField(
                    t('البريد الإلكتروني', 'Email'), emailCtrl.text),

                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(t('إلغاء', 'Cancel'),
                            style: TextStyle(color: dim)),
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
                          onPressed: _isSaving
                              ? null
                              : () async {
                            final data = {
                              'name': nameCtrl.text.trim(),
                              'city': cityCtrl.text.trim(),
                              'bio': bioCtrl.text.trim(),
                              'experienceYears':
                              int.tryParse(expCtrl.text.trim()) ?? 0,
                              'priceRange': priceCtrl.text.trim(),
                            };
                            final success = await _updateProfile(data);
                            if (success && mounted) {
                              if (ctx.mounted) Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t(
                                      'تم تحديث الملف الشخصي ✅',
                                      'Profile updated ✅')),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t(
                                      'فشل التحديث، حاول مجدداً',
                                      'Update failed, try again')),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: _isSaving
                              ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.black))
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

  Widget _buildEditField(String label, TextEditingController ctrl,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: dim, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(color: text),
            decoration: InputDecoration(
              filled: true,
              fillColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent)),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: dim, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(value,
                        style: TextStyle(color: dim, fontSize: 14))),
                Icon(Icons.lock_outline, size: 16, color: dim),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }

    final data = _profileData!;
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final name = data['name'] ?? '';
    final city = data['city'] ?? '';
    final bio = data['bio'] ?? '';
    final experience = data['experienceYears'] ?? 0;
    final trustedHands = data['trustedHands'] ?? false;
    final primaryCategory = data['primaryCategory'] ?? '';
    final priceRange = data['priceRange'] ?? '';
    final profileImage = data['profileImage']?.toString();
    final bannerImage =
    (data['bannerImage'] ?? data['coverImage'])?.toString();
    final earnings = stats['earnings'] ?? 0;
    final rating = stats['rating'] ?? 0.0;
    final completedOrders = stats['completedOrders'] ?? 0;
    final views = stats['views'] ?? 0;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: RefreshIndicator(
          onRefresh: () async {
            await _fetchProfile();
            await _fetchPortfolio();
            await _fetchProducts();
            await _fetchReviews(0);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ── Banner ──────────────────────────────────────────────────
              GestureDetector(
                onTap: _updateBannerImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.3),
                        accent.withValues(alpha: 0.05)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (bannerImage != null && bannerImage.isNotEmpty)
                        Positioned.fill(
                          child: Image.network(
                            bannerImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: accent.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      if (bannerImage == null || bannerImage.isEmpty)
                        Positioned.fill(
                          child: Icon(
                            Icons.image_outlined,
                            size: 80,
                            color: accent.withValues(alpha: 0.3),
                          ),
                        ),
                      Positioned(
                        bottom: 10,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              if (_isUploadingImage)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                Icon(Icons.edit,
                                    size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                _isUploadingImage
                                    ? t('جاري الرفع...', 'Uploading...')
                                    : t('تغيير البانر', 'Change Banner'),
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _updateProfileImage,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: accent.withValues(alpha: 0.2),
                                backgroundImage: profileImage != null
                                    ? NetworkImage(profileImage)
                                    : null,
                                child: profileImage == null
                                    ? Icon(Icons.person,
                                    color: accent, size: 40)
                                    : null,
                              ),
                              if (_isUploadingImage)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                      Colors.black.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    border:
                                    Border.all(color: surface, width: 2),
                                  ),
                                  child: Icon(Icons.camera_alt,
                                      size: 12, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: GoogleFonts.cairo(
                                        color: text,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: dim, size: 18),
                                    onPressed: _showEditProfileSheet,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (primaryCategory.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        primaryCategory,
                                        style: GoogleFonts.cairo(
                                            color: accent, fontSize: 12),
                                      ),
                                    ),
                                  if (trustedHands) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                        Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified,
                                              color: Colors.green, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            t('أيدٍ موثوقة', 'Trusted Hands'),
                                            style: GoogleFonts.cairo(
                                                color: Colors.green,
                                                fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 14, color: dim),
                                  const SizedBox(width: 4),
                                  Text(city,
                                      style: GoogleFonts.cairo(
                                          color: dim, fontSize: 13)),
                                  if (experience > 0) ...[
                                    const SizedBox(width: 12),
                                    Icon(Icons.workspace_premium_outlined,
                                        size: 14, color: dim),
                                    const SizedBox(width: 4),
                                    Text(
                                      localizeNumber(
                                          '$experience ${t('سنوات', 'years')}'),
                                      style: GoogleFonts.cairo(
                                          color: dim, fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Stats Bar ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: border, width: 1.5),
                        color: surface,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            t("الأرباح", "Earnings"),
                            "${earnings.toStringAsFixed(0)} JOD",
                            Icons.account_balance_wallet_outlined,
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            t("التقييم", "Rating"),
                            rating > 0 ? rating.toStringAsFixed(1) : "—",
                            Icons.star_outline,
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            t("مكتمل", "Completed"),
                            "$completedOrders",
                            Icons.done_all_outlined,
                          ),
                          _buildStatDivider(),
                          _buildStatItem(
                            t("مشاهدات", "Views"),
                            "$views",
                            Icons.remove_red_eye_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Bio ──────────────────────────────────────────────
                    Text(
                      t('نبذة عني', 'About Me'),
                      style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bio.isNotEmpty
                          ? bio
                          : t('لا توجد نبذة مضافة', 'No bio added'),
                      textDirection: widget.isArabic
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      textAlign: widget.isArabic
                          ? TextAlign.right
                          : TextAlign.left,
                      style: GoogleFonts.cairo(
                        color: dim,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    if (priceRange.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${t('نطاق السعر:', 'Price Range:')} $priceRange ${t('دينار', 'JOD')}',
                        style: GoogleFonts.cairo(color: dim, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── My Crafts ─────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('حرفي', 'My Crafts'),
                          style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        TextButton.icon(
                          onPressed: _openAddCraftFlow,
                          icon: Icon(Icons.add_circle_outline,
                              color: accent, size: 18),
                          label: Text(
                            t('أضف حرفة', 'Add Craft'),
                            style: GoogleFonts.cairo(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _craftTile(
                      {
                        'name': primaryCategory.isNotEmpty
                            ? primaryCategory
                            : t('حرفة رئيسية', 'Primary Craft'),
                        'isPublic': true
                      },
                      isPrimary: true,
                    ),
                    ..._extraCrafts.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final craft = entry.value;
                      return _craftTile(craft, isPrimary: false, index: idx);
                    }),
                    if (_extraCrafts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          t('لا توجد حرف إضافية. اضغط "أضف حرفة" لإضافة واحدة.',
                              'No additional crafts. Tap "Add Craft" to add one.'),
                          style: TextStyle(color: dim, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // ── Products ───────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('منتجاتي', 'My Products'),
                            style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CraftsmanOffersScreen(
                                  isArabic: widget.isArabic,
                                  isDarkMode: widget.isDarkMode,
                                  artisanId: widget.craftsmanId,
                                ),
                              ),
                            );

                            // Refresh the 4-product preview after returning
                            // in case a product was edited, hidden, or deleted.
                            if (mounted) {
                              await _fetchProducts();
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            t('عرض الكل', 'View All'),
                            style: GoogleFonts.cairo(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddProductScreen(
                                  isArabic: widget.isArabic,
                                  isDarkMode: widget.isDarkMode,
                                  onProductAdded: (_) {
                                    _fetchProducts();
                                  },
                                ),
                              ),
                            );
                            if (mounted) {
                              await _fetchProducts();
                            }
                          },
                          icon: Icon(Icons.add, color: accent, size: 17),
                          label: Text(
                            t('أضف منتج', 'Add Product'),
                            style: GoogleFonts.cairo(
                              color: accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildProductsSection(),
                    const SizedBox(height: 24),

                    // ── Portfolio ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('معرض أعمالي', 'My Portfolio'),
                          style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        TextButton.icon(
                          onPressed: _showAddPortfolioDialog,
                          icon: Icon(Icons.add, color: accent, size: 18),
                          label: Text(
                            t('أضف صورة', 'Add Image'),
                            style: GoogleFonts.cairo(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPortfolioGrid(),
                    const SizedBox(height: 24),

                    // ── Reviews ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t('التقييمات', 'Reviews'),
                          style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : '0.0',
                              style: GoogleFonts.cairo(
                                  color: text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_isLoadingReviews)
                      const Center(child: CircularProgressIndicator())
                    else if (_reviews.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.star_border_rounded,
                              color: accent,
                              size: 34,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t('لا توجد تقييمات بعد', 'No reviews yet'),
                              style: GoogleFonts.cairo(
                                color: text,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              t(
                                'ستظهر تقييمات العملاء هنا بعد إكمال الطلبات.',
                                'Customer reviews will appear here after completed orders.',
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                color: dim,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._reviews.map((r) => _reviewCard(r)),

                    if (_totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                widget.isArabic
                                    ? Icons.arrow_forward_ios
                                    : Icons.arrow_back_ios,
                                size: 18,
                              ),
                              onPressed: _currentPage > 0
                                  ? () => _fetchReviews(_currentPage - 1)
                                  : null,
                              color: _currentPage > 0 ? accent : dim,
                            ),
                            ...List.generate(_totalPages, (index) {
                              final isActive = index == _currentPage;
                              return GestureDetector(
                                onTap: () => _fetchReviews(index),
                                child: Container(
                                  margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    isActive ? accent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isActive
                                        ? null
                                        : Border.all(color: border),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isActive ? Colors.black : text,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            IconButton(
                              icon: Icon(
                                widget.isArabic
                                    ? Icons.arrow_back_ios
                                    : Icons.arrow_forward_ios,
                                size: 18,
                              ),
                              onPressed: _currentPage < _totalPages - 1
                                  ? () => _fetchReviews(_currentPage + 1)
                                  : null,
                              color:
                              _currentPage < _totalPages - 1 ? accent : dim,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Settings ──────────────────────────────────────────
                    Divider(color: border),
                    const SizedBox(height: 8),
                    Text(
                      t('الإعدادات', 'Settings'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _settingsTile(
                      icon: widget.isDarkMode
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      label: t('الوضع الليلي', 'Dark Mode'),
                      trailing: Switch(
                        value: widget.isDarkMode,
                        onChanged: (_) => widget.onToggleTheme(),
                        activeThumbColor: accent,
                      ),
                    ),
                    _settingsTile(
                      icon: Icons.language,
                      label: t('اللغة', 'Language'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.isArabic ? 'عربي' : 'English',
                            style: TextStyle(color: text, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon:
                            Icon(Icons.swap_horiz, color: accent, size: 20),
                            onPressed: widget.onToggleLanguage,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    _settingsTile(
                      icon: Icons.notifications_outlined,
                      label: t('الإشعارات', 'Notifications'),
                      trailing: Switch(
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                        },
                        activeThumbColor: accent,
                      ),
                    ),
                    _settingsTile(
                      icon: Icons.privacy_tip_outlined,
                      label: t('الخصوصية', 'Privacy'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _showPrivacySheet,
                    ),
                    _settingsTile(
                      icon: Icons.lock_outline,
                      label: t('تغيير كلمة المرور', 'Change Password'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _showChangePasswordDialog,
                    ),
                    _settingsTile(
                      icon: Icons.account_balance_outlined,
                      label: t('إعدادات حساب Stripe لصرف الأرباح', 'Stripe Express Payout Setup'),
                      trailing: const Icon(Icons.open_in_new, size: 16),
                      onTap: () async {
                        final success = await PaymentService.openPayoutOnboarding();
                        if (!success && mounted) {
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
                    ),
                    _settingsTile(
                      icon: Icons.verified_user_outlined,
                      label: t('توثيق الهوية والشارة الذهبية', 'Identity Verification & Badge'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (trustedHands)
                            Icon(Icons.stars_rounded, color: accent, size: 18)
                          else
                            Text(
                              t('غير موثق', 'Not Verified'),
                              style: TextStyle(color: dim, fontSize: 12),
                            ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios, size: 14),
                        ],
                      ),
                      onTap: () => _showVerificationBadgeSheet(trustedHands),
                    ),

                    _buildDangerZone(),
                    _settingsTile(
                      icon: Icons.logout,
                      label: t('تسجيل الخروج', 'Logout'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: _showLogoutDialog,
                      isDanger: true,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper Widgets ──────────────────────────────────────────────────

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style:
          TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: dim, fontSize: 11)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: border);
  }

  String localizeNumber(String value) {
    if (!widget.isArabic) return value;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < en.length; i++) {
      value = value.replaceAll(en[i], ar[i]);
    }
    return value;
  }

  Widget _buildProductsSection() {
    if (_isLoadingProducts) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: accent),
        ),
      );
    }

    if (_products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: accent,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              t('لا توجد منتجات بعد', 'No products yet'),
              style: GoogleFonts.cairo(
                color: text,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              t(
                'أضيفي أول منتج ليظهر هنا وفي متجر CraftGo.',
                'Add your first product to show it here and in CraftGo.',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: dim,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Profile shows only the 4 most recently added products.
    // My Offers remains the full product-management screen.
    final sortedProducts = List<Map<String, dynamic>>.from(_products);

    sortedProducts.sort((a, b) {
      final aDate = DateTime.tryParse(
        (a['createdAt'] ?? a['created_at'] ?? '').toString(),
      );
      final bDate = DateTime.tryParse(
        (b['createdAt'] ?? b['created_at'] ?? '').toString(),
      );

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    final visibleProducts = sortedProducts.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visibleProducts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, index) {
        final product = visibleProducts[index];
        final productId =
        (product['id'] ?? product['_id'] ?? '').toString();
        final title = widget.isArabic
            ? (product['titleAr'] ?? product['titleEn'] ?? '')
            : (product['titleEn'] ?? product['titleAr'] ?? '');
        final imageUrl =
        (product['imageUrl'] ?? product['image'] ?? '').toString();
        final price =
            double.tryParse((product['price'] ?? 0).toString()) ?? 0;
        final isPublic = product['isPublic'] != false;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl.isNotEmpty)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: accent.withValues(alpha: 0.08),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: dim,
                            ),
                          ),
                        )
                      else
                        Container(
                          color: accent.withValues(alpha: 0.08),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: accent,
                            size: 34,
                          ),
                        ),
                      PositionedDirectional(
                        top: 7,
                        end: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isPublic
                                ? Colors.green.withValues(alpha: 0.9)
                                : Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isPublic
                                ? t('ظاهر', 'Visible')
                                : t('مخفي', 'Hidden'),
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.isArabic
                                  ? '${localizeNumber(price.toStringAsFixed(price % 1 == 0 ? 0 : 2))} دينار'
                                  : '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} JOD',
                              style: GoogleFonts.cairo(
                                color: accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: t('حذف', 'Delete'),
                            onPressed: productId.isEmpty
                                ? null
                                : () => _deleteProduct(productId),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 19,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Portfolio Grid ──────────────────────────────────────────────────

  Widget _buildPortfolioGrid() {
    if (_isLoadingPortfolio) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_portfolioItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(
            t('لا توجد أعمال في المعرض', 'No portfolio items yet'),
            style: TextStyle(color: dim, fontSize: 13),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: _portfolioItems.length,
      itemBuilder: (context, index) {
        final item = _portfolioItems[index];
        final title = widget.isArabic ? item['titleAr'] : item['titleEn'];
        final imageUrl = item['imageUrl'] ?? '';
        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                )
              else
                Center(
                  child: Icon(Icons.image_outlined, size: 40, color: dim),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: Colors.redAccent),
                  onPressed: () => _confirmDeletePortfolio(item['id']),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12)),
                  ),
                  child: Text(
                    title ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeletePortfolio(String itemId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('حذف العمل', 'Delete Item'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Text(
          t('هل أنت متأكد من حذف هذا العمل من معرضك؟',
              'Are you sure you want to delete this item?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePortfolioItem(itemId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(t('تم الحذف', 'Deleted')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(t('حذف', 'Delete'),
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddPortfolioDialog() {
    final titleArCtrl = TextEditingController();
    final titleEnCtrl = TextEditingController();
    final descArCtrl = TextEditingController();
    final descEnCtrl = TextEditingController();

    XFile? selectedImage; // local variable for the dialog

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: surface,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(t('إضافة عمل جديد', 'Add New Portfolio Item'),
              style: TextStyle(color: text, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                    titleArCtrl, t('العنوان (عربي)', 'Title (Arabic)')),
                const SizedBox(height: 10),
                _buildDialogTextField(
                    titleEnCtrl, t('العنوان (إنجليزي)', 'Title (English)')),
                const SizedBox(height: 10),
                _buildDialogTextField(
                    descArCtrl, t('الوصف (عربي)', 'Description (Arabic)'),
                    maxLines: 2),
                const SizedBox(height: 10),
                _buildDialogTextField(
                    descEnCtrl, t('الوصف (إنجليزي)', 'Description (English)'),
                    maxLines: 2),
                const SizedBox(height: 10),
                // ── Image picker button ──────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('الصورة', 'Image'),
                      style: TextStyle(color: dim, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final XFile? picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 80,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedImage = picked);
                        }
                      },
                      icon: Icon(Icons.photo_camera, color: accent),
                      label: Text(
                        selectedImage == null
                            ? t('اختر صورة من المعرض',
                            'Pick image from gallery')
                            : t('تم اختيار الصورة', 'Image selected'),
                        style: TextStyle(color: accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final profileId = _profileData?['id'];
                if (profileId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(t('خطأ', 'Error')),
                        backgroundColor: Colors.red),
                  );
                  return;
                }

                final data = {
                  'artisanProfileId': profileId,
                  'titleAr': titleArCtrl.text.trim(),
                  'titleEn': titleEnCtrl.text.trim(),
                  'descriptionAr': descArCtrl.text.trim(),
                  'descriptionEn': descEnCtrl.text.trim(),
                };

                Navigator.pop(ctx);

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                              color: Color(0xFFD4A017)),
                          const SizedBox(height: 12),
                          Text(
                            t('جاري رفع الصورة...', 'Uploading image...'),
                            style: TextStyle(color: text),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                final result = await CraftsmanService.addPortfolioItemWithImage(
                    data, selectedImage);
                if (!mounted) return;
                Navigator.pop(context); // close loading

                if (mounted) {
                  if (result != null) {
                    await _fetchPortfolio();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('تمت إضافة العمل', 'Item added')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            t('فشل الإضافة، حاول مجدداً', 'Failed, try again')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(t('إضافة', 'Add'),
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dim),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: accent),
        ),
      ),
    );
  }

  // ─── Settings Tile ──────────────────────────────────────────────────────
  Widget _settingsTile({
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
    bool isDanger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: ListTile(
              leading: Icon(
                icon,
                color: isDanger ? Colors.redAccent : accent,
              ),
              title: Text(
                label,
                style: GoogleFonts.cairo(
                  color: isDanger ? Colors.redAccent : text,
                  fontSize: 14,
                ),
              ),
              trailing: trailing,
              onTap: null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Verification Badge Sheet ───────────────────────────────────────────
  void _showVerificationBadgeSheet(bool isVerifiedBadge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  isVerifiedBadge ? Icons.verified_user_rounded : Icons.shield_outlined,
                  color: accent,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t('توثيق الهوية والشارة الذهبية', 'Identity Verification & Badge'),
                    style: GoogleFonts.cairo(
                      color: text,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isVerifiedBadge) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars_rounded, color: accent, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('حسابك موثق بالشارة الذهبية! 🏆', 'Verified Artisan Badge Active 🏆'),
                            style: GoogleFonts.cairo(
                              color: accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t('تم التحقق من هويتك بنجاح وتظهر الشارة للمترددين على متجرك.', 'Your identity has been verified. The badge is displayed on your store.'),
                            style: GoogleFonts.cairo(color: dim, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                t(
                  'توثيق الهوية يمنحك الشارة الذهبية (Trusted Hands) لزيادة ثقة المشترين في متجرك وحرفيتك.',
                  'Identity verification awards you the Golden Trusted Badge, boosting customer confidence in your artisan store.',
                ),
                style: GoogleFonts.cairo(color: dim, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IDCameraScreen(isArabic: widget.isArabic),
                      ),
                    );
                    if (result != null && mounted) {
                      await ApiService.put(
                        '/craftsman/profile/${widget.craftsmanId}',
                        body: {
                          'idVerificationDetails': result,
                        },
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            t('تم إرسال وثائق الهوية بنجاح! سيتم مراجعتها من قبل الإدارة لمنحك الشارة الذهبية.', 'ID documents submitted! Admin will review to award your badge.'),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    t('بدء توثيق الهوية (Scan ID)', 'Start ID Verification'),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Privacy Sheet ──────────────────────────────────────────────────────
  void _showPrivacySheet() {

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(
              t('سياسة الخصوصية', 'Privacy Policy'),
              style: GoogleFonts.cairo(
                  color: text, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              t(
                'نحن في كرافت جو نلتزم بحماية بياناتك الشخصية ومشاركتها فقط لغايات إتمام الطلبات وتأمين الدفعات عبر نظام الضمان (Escrow).',
                'We at CraftGo are committed to protecting your personal data and sharing it only for fulfilling orders and securing payments via Escrow.',
              ),
              style: GoogleFonts.cairo(color: dim, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(t('إغلاق', 'Close'),
                    style:
                    TextStyle(color: accent, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Change Password Dialog ─────────────────────────────────────────────
  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: surface,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            t('تغيير كلمة المرور', 'Change Password'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _passwordField(
                  currentCtrl,
                  t('كلمة المرور الحالية', 'Current Password'),
                  obscure1,
                      () => setDlg(() => obscure1 = !obscure1)),
              const SizedBox(height: 12),
              _passwordField(newCtrl, t('كلمة المرور الجديدة', 'New Password'),
                  obscure2, () => setDlg(() => obscure2 = !obscure2)),
              const SizedBox(height: 12),
              _passwordField(
                  confirmCtrl,
                  t('تأكيد كلمة المرور', 'Confirm Password'),
                  obscure3,
                      () => setDlg(() => obscure3 = !obscure3)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) {
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
                }
              },
              child: Text(
                t('حفظ', 'Save'),
                style:
                TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField(TextEditingController ctrl, String label, bool obscure,
      VoidCallback onToggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dim),
        prefixIcon: Icon(Icons.lock_outline, color: dim),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: dim,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── Logout Dialog ──────────────────────────────────────────────────────
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('تسجيل الخروج', 'Logout'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Text(
          t('هل أنت متأكد من رغبتك في تسجيل الخروج؟',
              'Are you sure you want to logout?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          TextButton(
            onPressed: () async {
              final appState = context.read<AppState>();
              Navigator.pop(ctx); // close dialog
              appState.logout(); // <-- Fix: actually log out

              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const OnboardingScreen()),
                      (route) => false,
                );
              }
            },
            child: Text(t('تسجيل الخروج', 'Logout'),
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Review Card ──────────────────────────────────────────────────────
  Widget _reviewCard(Map<String, dynamic> r) {
    final customer = r['customer'] as Map<String, dynamic>?;
    final name = customer?['name'] ?? r['name'] ?? 'User';
    final rating = r['rating'] ?? 0;
    final comment = widget.isArabic ? r['commentAr'] : r['commentEn'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Text(name[0],
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              Row(
                children: List.generate(
                  5,
                      (i) => Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: i < rating
                        ? Colors.amber
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment,
                style: TextStyle(color: dim, fontSize: 13, height: 1.5)),
          ],
        ],
      ),
    );
  }

  // ── Danger Zone ──────────────────────────────────────────────────────────
  Widget _buildDangerZone() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading:
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          title: Text(
            t('منطقة خطيرة', 'Danger Zone'),
            style: GoogleFonts.cairo(
                color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          trailing: Icon(
            _dangerZoneExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.redAccent,
          ),
          onExpansionChanged: (expanded) {
            if (expanded) {
              _showPasswordDialog();
            } else {
              setState(() => _dangerZoneExpanded = false);
            }
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _dangerTile(
                    Icons.payment_outlined,
                    t('إدارة طرق الدفع', 'Manage Payment Methods'),
                    t('أضف أو عدّل بطاقات الدفع', 'Add or edit payment cards'),
                  ),
                  _dangerTile(
                    Icons.history,
                    t('سجل المعاملات', 'Transaction History'),
                    t('عرض جميع المعاملات المالية',
                        'View all financial transactions'),
                  ),
                  _dangerTile(
                    Icons.delete_forever_outlined,
                    t('حذف الحساب', 'Delete Account'),
                    t('حذف حسابك نهائياً', 'Permanently delete your account'),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangerTile(IconData icon, String title, String subtitle,
      {bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : accent),
      title: Text(title,
          style: TextStyle(
              color: isDestructive ? Colors.redAccent : text,
              fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: dim, fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: dim),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t(
                'هذه الميزة قيد التطوير', 'This feature is under development')),
            backgroundColor: accent,
          ),
        );
      },
    );
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('تأكيد كلمة المرور', 'Confirm Password'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('أدخل كلمة المرور للوصول إلى المنطقة الخطيرة',
                  'Enter your password to access the danger zone'),
              style: TextStyle(color: dim, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              style: TextStyle(color: text),
              decoration: InputDecoration(
                labelText: t('كلمة المرور', 'Password'),
                labelStyle: TextStyle(color: dim),
                prefixIcon: Icon(Icons.lock_outline, color: dim),
                suffixIcon: IconButton(
                  icon: Icon(
                      _passwordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: dim),
                  onPressed: () =>
                      setState(() => _passwordVisible = !_passwordVisible),
                ),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _dangerZoneExpanded = false);
            },
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_passwordController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _dangerZoneExpanded = true);
                _passwordController.clear();
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content:
                    Text(t('كلمة المرور غير صحيحة', 'Incorrect password')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(t('تأكيد', 'Confirm'),
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Craft management ──────────────────────────────────────────────────
  void _openAddCraftFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CraftsmanCategoryScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          onToggleLanguage: widget.onToggleLanguage,
          onToggleTheme: widget.onToggleTheme,
          addCraftMode: true,
          onCraftAdded: (Map<String, dynamic> cat) {
            setState(() {
              final name = widget.isArabic
                  ? cat['titleAr'] as String
                  : cat['titleEn'] as String;
              if (!_extraCrafts.any((c) => c['name'] == name)) {
                _extraCrafts.add({
                  'name': name,
                  'isPublic': true,
                  'experience': cat['addedExperience'] ?? '',
                  'bio': cat['addedBio'] ?? '',
                  'specificAnswer': cat['addedSpecificAnswer'] ?? '',
                });
              }
            });
          },
        ),
      ),
    );
  }

  void _toggleCraftVisibility(int index) {
    setState(() {
      _extraCrafts[index]['isPublic'] = !_extraCrafts[index]['isPublic'];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _extraCrafts[index]['isPublic']
                ? t('الحرفة أصبحت عامة', 'Craft is now public')
                : t('الحرفة أصبحت خاصة', 'Craft is now private'),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _editCraft(int index) {
    final craft = _extraCrafts[index];
    final nameController = TextEditingController(text: craft['name']);
    final expController =
    TextEditingController(text: craft['experience'] ?? '');
    final bioController = TextEditingController(text: craft['bio'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('تعديل الحرفة', 'Edit Craft'),
            style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: text),
              decoration: InputDecoration(
                labelText: t('اسم الحرفة', 'Craft Name'),
                labelStyle: TextStyle(color: dim),
                enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expController,
              style: TextStyle(color: text),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: t('سنوات الخبرة', 'Years of Experience'),
                labelStyle: TextStyle(color: dim),
                enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioController,
              style: TextStyle(color: text),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: t('نبذة مختصرة', 'Short Bio'),
                labelStyle: TextStyle(color: dim),
                enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: border)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _extraCrafts[index]['name'] = nameController.text.trim();
                _extraCrafts[index]['experience'] = expController.text.trim();
                _extraCrafts[index]['bio'] = bioController.text.trim();
              });
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('تم تحديث الحرفة ✅', 'Craft updated ✅')),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(t('حفظ', 'Save'),
                style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteCraft(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('حذف الحرفة', 'Delete Craft'),
            style: TextStyle(color: text)),
        content: Text(
          t('هل أنت متأكد من حذف هذه الحرفة؟',
              'Are you sure you want to delete this craft?'),
          style: TextStyle(color: dim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _extraCrafts.removeAt(index));
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t('تم حذف الحرفة', 'Craft deleted')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(t('حذف', 'Delete'),
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _craftTile(Map<String, dynamic> craft,
      {bool isPrimary = false, int? index}) {
    final name = craft['name'] as String;
    final isPublic = craft['isPublic'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.handyman_outlined, size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: text,
                      fontWeight:
                      isPrimary ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPrimary) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t('رئيسية', 'Primary'),
                      style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isPublic ? Icons.visibility : Icons.visibility_off,
              size: 16,
              color: isPublic ? Colors.green : Colors.grey,
            ),
            onPressed: isPrimary ? null : () => _toggleCraftVisibility(index!),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 16, color: dim),
            onPressed: isPrimary ? null : () => _editCraft(index!),
          ),
          if (!isPrimary)
            IconButton(
              icon:
              Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              onPressed: () => _deleteCraft(index!),
            ),
        ],
      ),
    );
  }

  Color get cardBorderColor => border;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import '../../services/products_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/ai_service.dart';
import 'package:image_picker/image_picker.dart';

// Runs away from the UI thread on Android. On web, Flutter handles the same
// callback without requiring a separate backend service.
Uint8List _applyLocalStudioPreset(Map<String, dynamic> input) {
  final bytes = input['bytes'] as Uint8List;
  final preset = input['preset'] as String;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported image format');
  }

  // Keep processing responsive and uploads reasonably sized.
  img.Image working = decoded;
  const maxSide = 1800;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    working = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxSide)
        : img.copyResize(decoded, height: maxSide);
  }

  switch (preset) {
    case 'warm':
      working = img.adjustColor(
        working,
        brightness: 1.04,
        contrast: 1.08,
        saturation: 1.13,
        hue: -3,
      );
      break;
    case 'premium':
      working = img.adjustColor(
        working,
        brightness: 0.98,
        contrast: 1.18,
        saturation: 1.09,
      );
      break;
    case 'clean':
    default:
      working = img.adjustColor(
        working,
        brightness: 1.08,
        contrast: 1.10,
        saturation: 1.03,
      );
  }

  return Uint8List.fromList(img.encodeJpg(working, quality: 92));
}

class AddProductScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String craftsmanId;
  final Map<String, dynamic>? product;
  final VoidCallback? onProductSaved;
  // Legacy callback kept for compatibility
  final void Function(Map<String, dynamic>)? onProductAdded;

  const AddProductScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    this.craftsmanId = '',
    this.product,
    this.onProductSaved,
    this.onProductAdded,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // ── Controllers ──────────────────────────────────────────────────────
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _otherMaterialController = TextEditingController();
  final TextEditingController _dimensionsController = TextEditingController();
  final TextEditingController _colorsController = TextEditingController();
  final FocusNode _colorsFocusNode = FocusNode();
  final FocusNode _dimensionsFocusNode = FocusNode();

  final GlobalKey _colorsFieldKey = GlobalKey();
  final GlobalKey _dimensionsFieldKey = GlobalKey();
  final GlobalKey _materialsSectionKey = GlobalKey();

  // ── Image / AI state ─────────────────────────────────────────────────
  bool _isGeneratingBackground = false;
  bool _isPricing = false;
  bool _isAnalyzingProduct = false;
  bool _isImprovingDescription = false;
  bool _hasImage = false;
  bool _hasAiBackground = false;
  String _studioPreset = 'clean';
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  Uint8List? _originalImageBytes;
  String? _existingImageUrl;

  // Product gallery: 1 main image + up to 4 additional images (5 total).
  static const int _maxProductImages = 5;
  final List<XFile> _additionalPickedImages = <XFile>[];
  final List<Uint8List> _additionalImageBytes = <Uint8List>[];
  final List<String> _existingAdditionalImageUrls = <String>[];


  // ── Categories (multi‑select) ──────────────────────────────────────
  // key = Arabic (stored in DB), value = English label
  final Map<String, String> _categoriesMap = const {
    'خشب': 'Wood',
    'فخار': 'Pottery',
    'خياطة': 'Sewing',
    'تطريز': 'Embroidery',
    'مجوهرات': 'Jewelry',
    'زجاج': 'Glass',
    'حجر': 'Stone',
    'ورق': 'Paper',
    'جلد': 'Leather',
    'معادن': 'Metals',
  };
  List<String> get _allCategories => _categoriesMap.keys.toList();
  final Set<String> _selectedCategories = {};

  // ── Materials (multi-select) ───────────────────────────────────────────
  // key = Arabic (stored in DB), value = English label
  final Map<String, String> _materialsMap = const {
    'خشب': 'Wood',
    'طين': 'Clay',
    'فخار': 'Pottery',
    'خزف': 'Ceramic',
    'زجاج': 'Glass',
    'معدن': 'Metal',
    'جلد': 'Leather',
    'قماش': 'Fabric',
    'خيوط': 'Thread',
    'ورق': 'Paper',
    'حجر': 'Stone',
    'راتنج': 'Resin',
    'نحاس': 'Copper',
    'أخرى': 'Other',
  };
  List<String> get _allMaterials => _materialsMap.keys.toList();
  final Set<String> _selectedMaterials = {};

  Map<String, dynamic>? _aiResult;

  // ── Visibility ─────────────────────────────────────────────────────
  bool _isPublic = true;

  // ── Theme helpers ─────────────────────────────────────────────────
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);

  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;

  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;

  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;

  Color get border =>
      widget.isDarkMode
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.1);

  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;
    if (product == null) return;

    _titleController.text =
        (product['titleAr'] ?? product['titleEn'] ?? '').toString();
    _descController.text = (product['description'] ?? '').toString();
    _priceController.text = (product['price'] ?? '').toString();
    _dimensionsController.text = (product['dimensions'] ?? '').toString();
    _colorsController.text = (product['colors'] ?? '').toString();
    _isPublic = product['isPublic'] ?? true;

    // Restore the latest saved AI analysis when reopening Edit Product.
    final savedAiAnalysis = product['aiAnalysis'];
    if (savedAiAnalysis is Map) {
      _aiResult = Map<String, dynamic>.from(savedAiAnalysis);
    }

    final category = (product['category'] ?? '').toString().trim();
    if (category.isNotEmpty) {
      final categories = category
          .split(RegExp(r'[,،]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty);
      _selectedCategories.addAll(categories);
    }

    final materials = (product['materials'] ?? '')
        .toString()
        .split(RegExp(r'[,،]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);

    final otherMaterials = <String>[];
    for (final material in materials) {
      if (_allMaterials.contains(material)) {
        _selectedMaterials.add(material);
      } else {
        otherMaterials.add(material);
      }
    }

    if (otherMaterials.isNotEmpty) {
      _selectedMaterials.add('أخرى');
      _otherMaterialController.text = otherMaterials.join('، ');
    }

    final imageUrl = (product['imageUrl'] ?? '').toString().trim();
    if (imageUrl.isNotEmpty) {
      _existingImageUrl = imageUrl;
      _hasImage = true;
    }

    // Load existing gallery images when editing. Keep the main image first and
    // avoid duplicates so old products with only imageUrl still work.
    final rawImages = product['images'] ?? product['imageUrls'] ?? product['Images'];
    if (rawImages is List) {
      for (final raw in rawImages) {
        final url = raw is Map
            ? (raw['url'] ?? raw['imageUrl'] ?? raw['secure_url'] ?? raw['path'])
            ?.toString()
            .trim()
            : raw?.toString().trim();
        if (url == null || url.isEmpty || url == imageUrl) continue;
        if (!_existingAdditionalImageUrls.contains(url) &&
            _existingAdditionalImageUrls.length < _maxProductImages - 1) {
          _existingAdditionalImageUrls.add(url);
        }
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() {
        _pickedImage = image;
        _pickedImageBytes = bytes;
        _originalImageBytes = Uint8List.fromList(bytes);
        _hasImage = true;
        _hasAiBackground = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('تعذر اختيار الصورة', 'Could not select the image'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  int get _galleryImageCount =>
      (_hasImage ? 1 : 0) +
          _existingAdditionalImageUrls.length +
          _additionalPickedImages.length;

  Future<void> _pickAdditionalImages() async {
    final remaining = _maxProductImages - _galleryImageCount;
    if (remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'يمكنك إضافة 5 صور كحد أقصى للمنتج',
              'You can add up to 5 product images',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;

      final accepted = picked.take(remaining).toList();
      final bytes = <Uint8List>[];

      for (final file in accepted) {
        bytes.add(await file.readAsBytes());
      }

      if (!mounted) return;
      setState(() {
        _additionalPickedImages.addAll(accepted);
        _additionalImageBytes.addAll(bytes);
      });

      if (picked.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'تمت إضافة الصور حتى الحد الأقصى (5 صور)',
                'Images were added up to the 5-image limit',
              ),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('تعذر اختيار الصور', 'Could not select the images'),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeExistingAdditionalImage(int index) {
    setState(() => _existingAdditionalImageUrls.removeAt(index));
  }

  void _removeNewAdditionalImage(int index) {
    setState(() {
      _additionalPickedImages.removeAt(index);
      _additionalImageBytes.removeAt(index);
    });
  }

  Widget _buildGallerySection() {
    if (!_hasImage) return const SizedBox.shrink();

    final total = _galleryImageCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                t('صور إضافية للمنتج', 'Product Gallery'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              '$total/$_maxProductImages',
              style: GoogleFonts.cairo(
                color: dim,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          t(
            'الصورة الكبيرة هي الصورة الرئيسية. أضيفي زوايا وتفاصيل أخرى للمنتج.',
            'The large image is the main image. Add other angles and detail shots.',
          ),
          style: GoogleFonts.cairo(color: dim, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _galleryThumbnail(
                child: _productImagePreview(),
                label: t('رئيسية', 'Main'),
                removable: false,
              ),
              ...List.generate(
                _existingAdditionalImageUrls.length,
                    (index) => _galleryThumbnail(
                  child: Image.network(
                    _existingAdditionalImageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.withValues(alpha: 0.25),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  onRemove: () => _removeExistingAdditionalImage(index),
                ),
              ),
              ...List.generate(
                _additionalImageBytes.length,
                    (index) => _galleryThumbnail(
                  child: Image.memory(
                    _additionalImageBytes[index],
                    fit: BoxFit.cover,
                  ),
                  onRemove: () => _removeNewAdditionalImage(index),
                ),
              ),
              if (total < _maxProductImages)
                InkWell(
                  onTap: _pickAdditionalImages,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 88,
                    margin: const EdgeInsetsDirectional.only(end: 10),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.purpleAccent.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.purpleAccent,
                          size: 27,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          t('أضف صور', 'Add More'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            color: Colors.purpleAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _galleryThumbnail({
    required Widget child,
    String? label,
    bool removable = true,
    VoidCallback? onRemove,
  }) {
    return Container(
      width: 88,
      margin: const EdgeInsetsDirectional.only(end: 10),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: child,
            ),
          ),
          if (label != null)
            PositionedDirectional(
              start: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (removable && onRemove != null)
            PositionedDirectional(
              end: 4,
              top: 4,
              child: InkWell(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Local image studio (works on Flutter web and Android) ───────────
  Future<void> _generateAiBackground() async {
    if (!_hasImage || _isGeneratingBackground) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('استوديو صورة المنتج', 'Product Image Studio'),
                style: GoogleFonts.cairo(
                  color: text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t('اختاري أسلوب تحسين مناسب للمنتج',
                    'Choose an enhancement style for the product'),
                style: GoogleFonts.cairo(color: dim, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _studioOption(sheetContext, 'clean', Icons.light_mode_outlined,
                  t('إضاءة نظيفة', 'Clean & Bright')),
              _studioOption(sheetContext, 'warm', Icons.wb_sunny_outlined,
                  t('دفء الحرف اليدوية', 'Warm Handmade')),
              _studioOption(sheetContext, 'premium', Icons.auto_awesome,
                  t('عرض فاخر', 'Premium Contrast')),
              _studioOption(sheetContext, 'original', Icons.restore,
                  t('الصورة الأصلية', 'Original Image')),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    if (selected == 'original') {
      if (_originalImageBytes == null) return;
      final restored = Uint8List.fromList(_originalImageBytes!);
      setState(() {
        _studioPreset = 'original';
        _hasAiBackground = false;
        _pickedImageBytes = restored;
        _pickedImage = XFile.fromData(restored,
            mimeType: 'image/png', name: 'craftgo-original.png');
      });
      return;
    }

    final source = _originalImageBytes ?? _pickedImageBytes;
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('اختاري صورة جديدة أولاً',
            'Please select a new image first')),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isGeneratingBackground = true);
    Uint8List? generated;
    try {
      generated = await compute(_applyLocalStudioPreset, {
        'bytes': Uint8List.fromList(source),
        'preset': selected,
      });
    } catch (_) {
      generated = null;
    }
    if (!mounted) return;
    setState(() => _isGeneratingBackground = false);

    if (generated == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('تعذر إنشاء صورة الاستوديو. حاولي مجدداً',
            'Could not generate the studio image. Please try again.')),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Keep a non-null reference before crossing another async gap and before
    // capturing it inside setState.
    final enhancedBytes = generated;

    final accepted = await _showBeforeAfterDialog(source, enhancedBytes);
    if (!mounted || accepted != true) return;

    setState(() {
      _studioPreset = selected;
      _hasAiBackground = true;
      _pickedImageBytes = enhancedBytes;
      _pickedImage = XFile.fromData(enhancedBytes,
          mimeType: 'image/jpeg', name: 'craftgo-studio.jpg');
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t('✨ تم اعتماد الصورة وستُحفظ مع المنتج',
          '✨ Studio image accepted and will be saved with the product')),
      backgroundColor: Colors.green,
    ));
  }

  Future<bool?> _showBeforeAfterDialog(Uint8List before, Uint8List after) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t('معاينة قبل وبعد', 'Before & After'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 520,
          child: Row(children: [
            Expanded(child: _comparisonImage(before, t('قبل', 'Before'))),
            const SizedBox(width: 10),
            Expanded(child: _comparisonImage(after, t('بعد', 'After'))),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check, color: Colors.black),
            label: Text(t('استخدام الصورة', 'Use Image'),
                style: const TextStyle(color: Colors.black)),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
          ),
        ],
      ),
    );
  }

  Widget _comparisonImage(Uint8List bytes, String label) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      ),
      const SizedBox(height: 6),
      Text(label, style: GoogleFonts.cairo(color: dim)),
    ]);
  }

  Widget _studioOption(
      BuildContext sheetContext, String value, IconData icon, String label) {
    final selected = _studioPreset == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? Colors.purpleAccent.withValues(alpha: 0.18)
              : bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.purpleAccent),
      ),
      title: Text(label, style: GoogleFonts.cairo(color: text)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Colors.purpleAccent)
          : const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: () => Navigator.pop(sheetContext, value),
    );
  }

  Widget _productImagePreview() {
    Widget image;
    if (_pickedImageBytes != null) {
      image = Image.memory(_pickedImageBytes!, fit: BoxFit.cover);
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      image = Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.withValues(alpha: 0.3),
          child: const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 70, color: Colors.white),
          ),
        ),
      );
    } else {
      image = Container(
        color: Colors.grey.withValues(alpha: 0.3),
        child: const Center(
          child: Icon(Icons.image, size: 80, color: Colors.white),
        ),
      );
    }

    return image;
  }

  List<String> _currentMaterials() {
    final values = _selectedMaterials.where((item) => item != 'أخرى').toList();
    final other = _otherMaterialController.text.trim();
    if (_selectedMaterials.contains('أخرى') && other.isNotEmpty) {
      values.add(other);
    }
    return values;
  }

  void _toggleMaterial(String material) {
    setState(() {
      if (_selectedMaterials.contains(material)) {
        _selectedMaterials.remove(material);
        if (material == 'أخرى') _otherMaterialController.clear();
      } else {
        _selectedMaterials.add(material);
      }
    });
  }

  bool _keepCurrentDescriptionDuringAnalysis = false;

  Future<void> _runAiProductAssistant() async {
    final title = _titleController.text.trim();
    final category =
    _selectedCategories.isNotEmpty ? _selectedCategories.first : '';
    final materials = _currentMaterials();

    if (title.isEmpty || category.isEmpty || materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'أدخلي اسم المنتج واختاري التصنيف ومادة واحدة على الأقل أولاً',
              'Enter the product name, category, and at least one material first',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isAnalyzingProduct = true);

    final result = await AiService.analyzeProduct(
      title: title,
      category: category,
      materials: materials,
      dimensions: _dimensionsController.text.trim(),
      colors: _colorsController.text.trim(),
      hasImage: _hasImage,
      description: _descController.text.trim(),
      imageCount: _galleryImageCount,
      language: widget.isArabic ? 'ar' : 'en',

    );

    if (!mounted) return;

    setState(() {
      _isAnalyzingProduct = false;
      _aiResult = result;
      if (result != null) {
        final description = result['description']?.toString().trim() ?? '';
        final suggestedPrice = result['suggestedPrice'];
        if (!_keepCurrentDescriptionDuringAnalysis && description.isNotEmpty) {
          _descController.text = description;
        }
        if (suggestedPrice != null) {
          final price = double.tryParse(suggestedPrice.toString());
          if (price != null) {
            _priceController.text = price == price.roundToDouble()
                ? price.toInt().toString()
                : price.toStringAsFixed(2);
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? t(
            'تعذر تحليل المنتج، حاولي مجدداً',
            'Could not analyze the product. Please try again',
          )
              : _keepCurrentDescriptionDuringAnalysis
              ? t(
            '✨ تم تحديث المنتج وإعادة تحليله بنجاح',
            '✨ Product updated and reanalyzed successfully',
          )
              : t(
            '✨ تم تحليل المنتج وتعبئة الوصف والسعر',
            '✨ Product analyzed and description and price were filled',
          ),
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: result == null ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _runAiPricing() async {
    if (_isPricing || _isAnalyzingProduct) return;

    final title = _titleController.text.trim();
    final category =
    _selectedCategories.isNotEmpty ? _selectedCategories.first : '';
    final materials = _currentMaterials();

    if (title.isEmpty || category.isEmpty || materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'أدخلي اسم المنتج واختاري التصنيف ومادة واحدة على الأقل أولاً',
              'Enter the product name, category, and at least one material first',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPricing = true);

    try {
      final result = await AiService.analyzeProduct(
        title: title,
        category: category,
        materials: materials,
        dimensions: _dimensionsController.text.trim(),
        colors: _colorsController.text.trim(),
        hasImage: _hasImage,
        description: _descController.text.trim(),
        imageCount: _galleryImageCount,
        language: widget.isArabic ? 'ar' : 'en',
      );

      if (!mounted) return;

      if (result == null) {
        throw Exception('No pricing result returned');
      }

      double? suggestedPrice =
      double.tryParse(result['suggestedPrice']?.toString() ?? '');

      // Some backend responses return only a minimum and maximum range.
      if (suggestedPrice == null) {
        final minimumPrice =
        double.tryParse(result['minimumPrice']?.toString() ?? '');
        final maximumPrice =
        double.tryParse(result['maximumPrice']?.toString() ?? '');

        if (minimumPrice != null && maximumPrice != null) {
          suggestedPrice = (minimumPrice + maximumPrice) / 2;
        } else {
          suggestedPrice = minimumPrice ?? maximumPrice;
        }
      }

      if (suggestedPrice == null || suggestedPrice <= 0) {
        throw Exception('Invalid suggested price');
      }

      final price = suggestedPrice;

      setState(() {
        _aiResult = result;
        _priceController.text =
        price == price.roundToDouble()
            ? price.toInt().toString()
            : price.toStringAsFixed(2);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              '✨ السعر المقترح من AI هو ${_priceController.text} دينار',
              '✨ AI suggested price: ${_priceController.text} JOD',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تعذر اقتراح السعر، حاولي مرة أخرى',
              'Could not suggest a price. Please try again.',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPricing = false);
    }
  }


  bool _isDescriptionRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();
    return value.contains('وصف') ||
        value.contains('description') ||
        value.contains('تفصيل');
  }

  bool _isImageRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('صورة') ||
        value.contains('صور') ||
        value.contains('image') ||
        value.contains('photo');
  }

  bool _isMaterialsRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('مادة') ||
        value.contains('مواد') ||
        value.contains('material');
  }

  bool _isCareRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('عناية') ||
        value.contains('تعليمات العناية') ||
        value.contains('care instruction') ||
        value.contains('care instructions') ||
        value.contains('product care');
  }

  bool _isKeywordRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('كلمات مفتاحية') ||
        value.contains('كلمات البحث') ||
        value.contains('keyword') ||
        value.contains('search visibility') ||
        value.contains('searchability') ||
        value.contains('search visibility');
  }

  bool _isCustomizationRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('تخصيص') ||
        value.contains('customization') ||
        value.contains('customisation') ||
        value.contains('customize') ||
        value.contains('customise');
  }

  bool _isColorRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('لون') ||
        value.contains('ألوان') ||
        value.contains('color');
  }

  bool _isDimensionsRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('أبعاد') ||
        value.contains('قياسات') ||
        value.contains('مقاس') ||
        value.contains('dimension') ||
        value.contains('size');
  }

  bool _isProductSpecificationsRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('product specification') ||
        value.contains('specifications') ||
        value.contains('specification') ||
        value.contains('مواصفات المنتج') ||
        value.contains('المواصفات') ||
        value.contains('تفاصيل المنتج');
  }

  bool _isGiftPackagingRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('gift packaging') ||
        value.contains('gift wrap') ||
        value.contains('gift wrapping') ||
        value.contains('تغليف هدايا') ||
        value.contains('تغليف كهدية') ||
        value.contains('تغليف الهدية');
  }

  bool _isReviewsRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('review') ||
        value.contains('rating') ||
        value.contains('customer feedback') ||
        value.contains('تقييم') ||
        value.contains('تقييمات') ||
        value.contains('مراجعات') ||
        value.contains('آراء العملاء');
  }

  bool _isDiscountRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('discount') ||
        value.contains('bulk purchase') ||
        value.contains('bulk order') ||
        value.contains('bundle') ||
        value.contains('خصم') ||
        value.contains('شراء بالجملة') ||
        value.contains('طلبات كبيرة');
  }

  bool _isAdviceRecommendation(String recommendation) {
    final value = recommendation.toLowerCase();

    return value.contains('styling') ||
        value.contains('style suggestion') ||
        value.contains('presentation') ||
        value.contains('photography') ||
        value.contains('marketing') ||
        value.contains('display suggestion') ||
        value.contains('تنسيق') ||
        value.contains('ستايل') ||
        value.contains('تصوير') ||
        value.contains('عرض المنتج') ||
        value.contains('تسويق');
  }

  bool _hasRecommendationAction(String recommendation) {
    // Every recommendation gets a meaningful action. Known recommendation
    // types use Apply/Add/Edit; unknown advisory recommendations fall back to View.
    return recommendation.trim().isNotEmpty;
  }

  Future<void> _reanalyzeKeepingDescription() async {
    _keepCurrentDescriptionDuringAnalysis = true;
    try {
      await _runAiProductAssistant();
    } finally {
      _keepCurrentDescriptionDuringAnalysis = false;
    }
  }

  Future<void> _handleRecommendationAction(String recommendation) async {
    if (_isDescriptionRecommendation(recommendation)) {
      await _improveDescription();
      return;
    }

    if (_isImageRecommendation(recommendation)) {
      final beforeCount = _galleryImageCount;

      if (_hasImage) {
        await _pickAdditionalImages();
      } else {
        await _pickImage();
      }

      if (!mounted || _galleryImageCount <= beforeCount) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              '📷 تمت إضافة صورة، جارٍ إعادة التحليل...',
              '📷 Image added. Reanalyzing...',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _reanalyzeKeepingDescription();
      return;
    }

    if (_isMaterialsRecommendation(recommendation)) {
      final sectionContext = _materialsSectionKey.currentContext;

      if (sectionContext != null) {
        await Scrollable.ensureVisible(
          sectionContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.22,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'عدّلي المواد المستخدمة ثم اضغطي إعادة التحليل',
              'Edit the materials used, then analyze the product again',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.purpleAccent,
        ),
      );
      return;
    }

    if (_isCareRecommendation(recommendation)) {
      await _applyCareInstructionsRecommendation();
      return;
    }

    if (_isKeywordRecommendation(recommendation)) {
      await _applyKeywordRecommendation();
      return;
    }

    // A customization recommendation can involve BOTH colors and sizes, so
    // handle it before the generic color/dimension checks.
    if (_isCustomizationRecommendation(recommendation)) {
      await _showCustomizationDialog();
      return;
    }

    if (_isProductSpecificationsRecommendation(recommendation)) {
      await _showProductSpecificationsDialog();
      return;
    }

    if (_isGiftPackagingRecommendation(recommendation)) {
      await _applyGiftPackagingRecommendation();
      return;
    }

    if (_isReviewsRecommendation(recommendation) ||
        _isDiscountRecommendation(recommendation)) {
      await _showAiAdviceDialog(recommendation);
      return;
    }

    if (_isAdviceRecommendation(recommendation)) {
      await _showAiAdviceDialog(recommendation);
      return;
    }

    if (_isColorRecommendation(recommendation)) {
      final fieldContext = _colorsFieldKey.currentContext;

      if (fieldContext != null) {
        await Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.35,
        );
      }

      await Future.delayed(const Duration(milliseconds: 550));

      if (!mounted) return;

      _colorsFocusNode.requestFocus();
      return;
    }

    if (_isDimensionsRecommendation(recommendation)) {
      final fieldContext = _dimensionsFieldKey.currentContext;

      if (fieldContext != null) {
        await Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.25,
        );
      }

      await Future.delayed(const Duration(milliseconds: 450));

      if (!mounted) return;

      _dimensionsFocusNode.requestFocus();
      return;
    }

    // Future/unknown AI recommendations should never appear without an action.
    await _showAiAdviceDialog(recommendation);
  }

  String _recommendationActionText(String recommendation) {
    if (_isDescriptionRecommendation(recommendation)) {
      return t('تطبيق', 'Apply');
    }

    if (_isImageRecommendation(recommendation)) {
      return t('إضافة', 'Add');
    }

    if (_isCareRecommendation(recommendation) ||
        _isKeywordRecommendation(recommendation)) {
      return t('تطبيق', 'Apply');
    }

    if (_isGiftPackagingRecommendation(recommendation)) {
      return t('إضافة', 'Add');
    }

    if (_isProductSpecificationsRecommendation(recommendation)) {
      return t('تعديل', 'Edit');
    }

    if (_isReviewsRecommendation(recommendation) ||
        _isDiscountRecommendation(recommendation) ||
        _isAdviceRecommendation(recommendation)) {
      return t('عرض', 'View');
    }

    if (_isMaterialsRecommendation(recommendation) ||
        _isCustomizationRecommendation(recommendation) ||
        _isColorRecommendation(recommendation) ||
        _isDimensionsRecommendation(recommendation)) {
      return t('تعديل', 'Edit');
    }

    return t('عرض', 'View');
  }

  IconData _recommendationActionIcon(String recommendation) {
    if (_isDescriptionRecommendation(recommendation)) {
      return Icons.auto_awesome;
    }

    if (_isImageRecommendation(recommendation)) {
      return Icons.add_photo_alternate_outlined;
    }

    if (_isMaterialsRecommendation(recommendation)) {
      return Icons.inventory_2_outlined;
    }

    if (_isCareRecommendation(recommendation)) {
      return Icons.cleaning_services_outlined;
    }

    if (_isKeywordRecommendation(recommendation)) {
      return Icons.search_rounded;
    }

    if (_isCustomizationRecommendation(recommendation)) {
      return Icons.tune_rounded;
    }

    if (_isGiftPackagingRecommendation(recommendation)) {
      return Icons.card_giftcard_rounded;
    }

    if (_isProductSpecificationsRecommendation(recommendation)) {
      return Icons.fact_check_outlined;
    }

    if (_isReviewsRecommendation(recommendation)) {
      return Icons.reviews_outlined;
    }

    if (_isDiscountRecommendation(recommendation)) {
      return Icons.local_offer_outlined;
    }

    if (_isAdviceRecommendation(recommendation)) {
      return Icons.visibility_outlined;
    }

    if (_isColorRecommendation(recommendation)) {
      return Icons.palette_outlined;
    }

    if (_isDimensionsRecommendation(recommendation)) {
      return Icons.straighten_outlined;
    }

    return Icons.visibility_outlined;
  }

  Future<void> _showProductSpecificationsDialog() async {
    final dimensionsController =
    TextEditingController(text: _dimensionsController.text.trim());
    final colorsController =
    TextEditingController(text: _colorsController.text.trim());
    final extraMaterialController = TextEditingController(
      text: _selectedMaterials.contains('أخرى')
          ? _otherMaterialController.text.trim()
          : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection:
        widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.fact_check_outlined,
                  color: Colors.purpleAccent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('مواصفات المنتج', 'Product Specifications'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dimensionsController,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      labelText: t('الأبعاد / المقاس', 'Dimensions / Size'),
                      hintText: t('مثال: 2 × 1.5 سم', 'e.g. 2 x 1.5 cm'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: colorsController,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      labelText: t('الألوان', 'Colors'),
                      hintText: t('مثال: ذهبي، كريمي', 'e.g. Gold, Cream'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: extraMaterialController,
                    style: GoogleFonts.cairo(color: text),
                    decoration: InputDecoration(
                      labelText: t(
                        'تفاصيل مادة إضافية (اختياري)',
                        'Extra material detail (optional)',
                      ),
                      hintText: t(
                        'مثال: معدن مطلي باللون الذهبي',
                        'e.g. gold-tone plated metal',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      t(
                        'يمكنك تعديل المواد الأساسية من قسم Materials أيضاً.',
                        'You can also edit the main material chips in the Materials section.',
                      ),
                      style: GoogleFonts.cairo(color: dim, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('إلغاء', 'Cancel'),
                  style: GoogleFonts.cairo(color: dim)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check, color: Colors.black, size: 18),
              label: Text(
                t('حفظ وإعادة التحليل', 'Save & Reanalyze'),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final extraMaterial = extraMaterialController.text.trim();
      setState(() {
        _dimensionsController.text = dimensionsController.text.trim();
        _colorsController.text = colorsController.text.trim();
        if (extraMaterial.isNotEmpty) {
          _selectedMaterials.add('أخرى');
          _otherMaterialController.text = extraMaterial;
        }
      });
      await _reanalyzeKeepingDescription();
    }

    dimensionsController.dispose();
    colorsController.dispose();
    extraMaterialController.dispose();
  }

  Future<void> _applyGiftPackagingRecommendation() async {
    final current = _descController.text.trim();
    final alreadyAdded = current.toLowerCase().contains('gift packaging') ||
        current.toLowerCase().contains('gift wrap') ||
        current.contains('تغليف هدايا') ||
        current.contains('تغليف كهدية');

    if (alreadyAdded) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'خيار تغليف الهدايا مذكور بالفعل في الوصف',
              'Gift packaging is already included in the description',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _reanalyzeKeepingDescription();
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection:
        widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.card_giftcard_rounded,
                  color: Colors.purpleAccent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('إضافة تغليف هدايا', 'Add Gift Packaging'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            t(
              'سيتم إضافة أن تغليف الهدايا متاح عند الطلب إلى وصف المنتج. هكذا تظهر الميزة للعميل وتُحفظ مع المنتج بدون إضافة سعر تلقائي.',
              'Gift packaging availability will be added to the product description. This makes the option visible to customers and saves it with the product without inventing an extra fee.',
            ),
            style: GoogleFonts.cairo(color: text, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('إلغاء', 'Cancel'),
                  style: GoogleFonts.cairo(color: dim)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.add, color: Colors.black, size: 18),
              label: Text(
                t('إضافة', 'Add'),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (accepted != true || !mounted) return;

    final sentence = widget.isArabic
        ? 'يتوفر تغليف هدايا أنيق عند الطلب.'
        : 'Elegant gift packaging is available upon request.';

    setState(() {
      _descController.text = current.isEmpty ? sentence : '$current\n\n$sentence';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            '🎁 تمت إضافة خيار تغليف الهدايا، جارٍ إعادة التحليل...',
            '🎁 Gift packaging added. Reanalyzing...',
          ),
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: Colors.green,
      ),
    );

    await _reanalyzeKeepingDescription();
  }

  String _careInstructionsSuggestion() {
    final values = _currentMaterials()
        .map((item) => item.toLowerCase())
        .toList();

    final hasThreadOrFabric = values.any(
          (value) =>
      value.contains('خيوط') ||
          value.contains('thread') ||
          value.contains('قماش') ||
          value.contains('fabric'),
    );

    final hasMetal = values.any(
          (value) =>
      value.contains('معدن') ||
          value.contains('metal') ||
          value.contains('نحاس') ||
          value.contains('copper'),
    );

    final hasResin = values.any(
          (value) => value.contains('راتنج') || value.contains('resin'),
    );

    if (widget.isArabic) {
      final tips = <String>[];

      if (hasThreadOrFabric) {
        tips.add('تجنّب النقع الطويل واحتكاك القطعة القوي بالماء');
      }
      if (hasMetal) {
        tips.add('احفظ الأجزاء المعدنية بعيداً عن الرطوبة والعطور');
      }
      if (hasResin) {
        tips.add('تجنّب الحرارة العالية وأشعة الشمس المباشرة لفترات طويلة');
      }

      if (tips.isEmpty) {
        tips.add('نظّف القطعة بلطف واحفظها في مكان جاف عند عدم الاستخدام');
      }

      return 'تعليمات العناية: ${tips.join('، ')}.';
    }

    final tips = <String>[];

    if (hasThreadOrFabric) {
      tips.add('avoid prolonged soaking and harsh rubbing');
    }
    if (hasMetal) {
      tips.add('keep metal details away from moisture and perfume');
    }
    if (hasResin) {
      tips.add('avoid high heat and prolonged direct sunlight');
    }

    if (tips.isEmpty) {
      tips.add('clean gently and store in a dry place when not in use');
    }

    return 'Care instructions: ${tips.join('; ')}.';
  }

  Future<void> _applyCareInstructionsRecommendation() async {
    final suggestion = _careInstructionsSuggestion();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection:
        widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.cleaning_services_outlined,
                color: Colors.purpleAccent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('تعليمات العناية المقترحة', 'Suggested Care Instructions'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            suggestion,
            style: GoogleFonts.cairo(
              color: text,
              height: 1.65,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                t('إلغاء', 'Cancel'),
                style: GoogleFonts.cairo(color: dim),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check, color: Colors.black, size: 18),
              label: Text(
                t('إضافة للوصف', 'Add to Description'),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (accepted != true || !mounted) return;

    final current = _descController.text.trim();
    if (!current.toLowerCase().contains(
      widget.isArabic ? 'تعليمات العناية' : 'care instructions',
    )) {
      setState(() {
        _descController.text =
        current.isEmpty ? suggestion : '$current\n\n$suggestion';
      });
    }

    await _reanalyzeKeepingDescription();
  }

  Future<void> _applyKeywordRecommendation() async {
    final rawTags = (_aiResult?['tags'] as List?)
        ?.map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList() ??
        <String>[];

    if (rawTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'لا توجد كلمات مفتاحية مقترحة حالياً. أعيدي تحليل المنتج أولاً.',
              'No suggested keywords are available yet. Analyze the product first.',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final sentence = widget.isArabic
        ? 'مناسب للباحثين عن ${rawTags.join('، ')}.'
        : 'Ideal for shoppers looking for ${rawTags.join(', ')}.';

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection:
        widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.purpleAccent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('تحسين ظهور المنتج في البحث', 'Improve Search Visibility'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(
                  'سيتم دمج الكلمات المفتاحية التالية بشكل طبيعي في الوصف:',
                  'These keywords will be naturally added to the description:',
                ),
                style: GoogleFonts.cairo(color: dim, height: 1.5),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: rawTags
                    .map(
                      (tag) => Chip(
                    label: Text(
                      tag,
                      style: GoogleFonts.cairo(fontSize: 11),
                    ),
                  ),
                )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                t('إلغاء', 'Cancel'),
                style: GoogleFonts.cairo(color: dim),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.auto_awesome, color: Colors.black, size: 18),
              label: Text(
                t('تطبيق الكلمات', 'Apply Keywords'),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (accepted != true || !mounted) return;

    final current = _descController.text.trim();
    if (!current.contains(sentence)) {
      setState(() {
        _descController.text =
        current.isEmpty ? sentence : '$current\n\n$sentence';
      });
    }

    await _reanalyzeKeepingDescription();
  }

  Future<void> _showCustomizationDialog() async {
    final colorsController =
    TextEditingController(text: _colorsController.text.trim());
    final sizeController =
    TextEditingController(text: _dimensionsController.text.trim());

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection:
        widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Colors.purpleAccent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('خيارات التخصيص', 'Customization Options'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: colorsController,
                  style: GoogleFonts.cairo(color: text),
                  decoration: InputDecoration(
                    labelText: t('الألوان المتاحة', 'Available Colors'),
                    hintText: t(
                      'مثال: كريمي، أخضر، ذهبي',
                      'e.g. Cream, Olive Green, Gold',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: sizeController,
                  style: GoogleFonts.cairo(color: text),
                  decoration: InputDecoration(
                    labelText: t('المقاس / خيارات الحجم', 'Size / Dimensions'),
                    hintText: t(
                      'مثال: مقاس قابل للتعديل',
                      'e.g. Adjustable size',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                t('إلغاء', 'Cancel'),
                style: GoogleFonts.cairo(color: dim),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check, color: Colors.black, size: 18),
              label: Text(
                t('حفظ', 'Save'),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _colorsController.text = colorsController.text.trim();
        _dimensionsController.text = sizeController.text.trim();
      });

      await _reanalyzeKeepingDescription();
    }

    colorsController.dispose();
    sizeController.dispose();
  }

  List<String> _buildAdviceSuggestions(String recommendation) {
    final value = recommendation.toLowerCase();
    final suggestions = <String>[];

    if (_isReviewsRecommendation(recommendation)) {
      suggestions.addAll(
        widget.isArabic
            ? [
          'تظهر تقييمات وآراء العملاء بعد إتمام الطلب وقيام العميل بتقييم المنتج؛ لا يتم إنشاء تقييمات وهمية تلقائياً.',
          'استخدمي صوراً ووصفاً دقيقاً للمنتج حتى تكون توقعات العميل واضحة ويكون التقييم أكثر واقعية.',
          'بعد وصول أول تقييمات، اعرضي متوسط النجوم وعدد المراجعات في صفحة المنتج لزيادة الثقة.',
        ]
            : [
          'Customer reviews and ratings should come from completed orders and real customer feedback; CraftGo should not generate fake reviews.',
          'Use accurate photos and a precise description so customer expectations match the delivered product.',
          'Once reviews are available, show the average star rating and review count on the product page to build trust.',
        ],
      );
    }

    if (_isDiscountRecommendation(recommendation)) {
      suggestions.addAll(
        widget.isArabic
            ? [
          'استخدمي خصم الكمية فقط عندما يطلب العميل أكثر من قطعة، ولا تغيّري السعر الأساسي للمنتج تلقائياً.',
          'مثال عملي: خصم بسيط عند شراء 3 قطع أو أكثر، مع الحفاظ على هامش ربح مناسب.',
          'إذا لم يكن المنتج مناسباً للبيع بالكميات، اتركي السعر الحالي كما هو وتجاهلي هذا الاقتراح.',
        ]
            : [
          'Use a bulk discount only when a customer buys multiple pieces; do not automatically change the product base price.',
          'A practical option is a small discount for 3 or more items while keeping a reasonable profit margin.',
          'If this product is not suitable for quantity sales, keep the current price and ignore this suggestion.',
        ],
      );
    }

    if (value.contains('styling') ||
        value.contains('style') ||
        value.contains('تنسيق') ||
        value.contains('ستايل')) {
      suggestions.addAll(
        widget.isArabic
            ? [
          'اعرضي المنتج مع إطلالة بسيطة ومحايدة حتى تبقى القطعة هي العنصر الأبرز.',
          'أضيفي صورة أثناء الاستخدام لتوضيح الحجم وطريقة تنسيق القطعة.',
          'استخدمي خلفية قريبة من ألوان المنتج من دون أن تشتت الانتباه عنه.',
        ]
            : [
          'Pair the product with a simple, neutral outfit so the piece remains the focal point.',
          'Add a worn/on-model photo to show scale and how the item can be styled.',
          'Use a background that complements the product colors without distracting from it.',
        ],
      );
    }

    if (value.contains('photography') || value.contains('تصوير')) {
      suggestions.addAll(
        widget.isArabic
            ? [
          'أضيفي لقطة قريبة للتفاصيل ولقطة كاملة للمنتج.',
          'استخدمي إضاءة طبيعية ناعمة وصورة واضحة من زاوية مختلفة.',
        ]
            : [
          'Add one close-up detail shot and one full-product shot.',
          'Use soft natural light and include a clear image from another angle.',
        ],
      );
    }

    if (value.contains('marketing') || value.contains('تسويق')) {
      suggestions.addAll(
        widget.isArabic
            ? [
          'ركزي في عرض المنتج على كونه مصنوعاً يدوياً وعلى التفاصيل التي تميزه.',
          'استخدمي الكلمات المفتاحية المقترحة في الوصف والعنوان بشكل طبيعي.',
        ]
            : [
          'Highlight the handmade nature of the product and the details that make it unique.',
          'Use the suggested keywords naturally in the title and description.',
        ],
      );
    }

    if (value.contains('presentation') ||
        value.contains('display') ||
        value.contains('عرض المنتج')) {
      suggestions.addAll(
        widget.isArabic
            ? [
          'اجعلي الصورة الرئيسية أبسط وأوضح صورة للمنتج.',
          'رتبي الصور بحيث تبدأ بالصورة الرئيسية ثم الاستخدام ثم التفاصيل.',
        ]
            : [
          'Use the clearest, simplest product shot as the main image.',
          'Order the gallery as main view, in-use view, then detail shots.',
        ],
      );
    }

    if (suggestions.isEmpty) {
      suggestions.addAll(
        widget.isArabic
            ? [
          'أضيفي صوراً واضحة من زوايا مختلفة.',
          'حافظي على وصف مختصر يوضح المواد والحجم وأهم ميزة في المنتج.',
          'اعرضي المنتج بطريقة توضح استخدامه الحقيقي للعميل.',
        ]
            : [
          'Add clear images from multiple useful angles.',
          'Keep the description focused on materials, size, and the product’s main selling point.',
          'Present the product in a way that helps the customer understand real-world use.',
        ],
      );
    }

    return suggestions.toSet().toList();
  }

  Future<void> _showAiAdviceDialog(String recommendation) async {
    final suggestions = _buildAdviceSuggestions(recommendation);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection:
        widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  t('اقتراحات CraftGo AI', 'CraftGo AI Suggestions'),
                  style: GoogleFonts.cairo(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation,
                  style: GoogleFonts.cairo(
                    color: Colors.purpleAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                ...suggestions.map(
                      (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            suggestion,
                            style: GoogleFonts.cairo(
                              color: text,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t('تم', 'Done'),
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _improveDescription() async {
    if (_isImprovingDescription) return;

    final title = _titleController.text.trim();
    final category =
    _selectedCategories.isNotEmpty ? _selectedCategories.first : '';

    if (title.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'أدخلي اسم المنتج واختاري التصنيف أولاً',
              'Enter the product name and select a category first',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isImprovingDescription = true);

    final improved = await AiService.improveProductDescription(
      title: title,
      category: category,
      materials: _currentMaterials(),
      dimensions: _dimensionsController.text.trim(),
      colors: _colorsController.text.trim(),
      currentDescription: _descController.text.trim(),
      language: widget.isArabic ? 'ar' : 'en',
    );

    if (!mounted) return;
    setState(() => _isImprovingDescription = false);

    if (improved == null || improved.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'تعذر تحسين الوصف، حاولي مجدداً',
              'Could not improve the description. Please try again',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final useDescription = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          Directionality(
            textDirection:
            widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      t('الوصف المحسّن بالذكاء الاصطناعي',
                          'AI Improved Description'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_descController.text
                        .trim()
                        .isNotEmpty) ...[
                      Text(
                        t('الوصف الحالي', 'Current Description'),
                        style: GoogleFonts.cairo(
                          color: dim,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          _descController.text.trim(),
                          style: GoogleFonts.cairo(color: dim, height: 1.6),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      t('الوصف المقترح', 'Suggested Description'),
                      style: GoogleFonts.cairo(
                        color: Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purpleAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: SelectableText(
                        improved,
                        style: GoogleFonts.cairo(color: text, height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    t('إلغاء', 'Cancel'),
                    style: GoogleFonts.cairo(color: dim),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.check, color: Colors.black, size: 18),
                  label: Text(
                    t('استخدام الوصف', 'Use Description'),
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );

    if (useDescription == true && mounted) {
      setState(() {
        _descController.text = improved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              '✨ تم تطبيق الوصف، جارٍ إعادة تحليل المنتج...',
              '✨ Description applied. Reanalyzing product...',
            ),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      _keepCurrentDescriptionDuringAnalysis = true;
      try {
        await _runAiProductAssistant();
      } finally {
        _keepCurrentDescriptionDuringAnalysis = false;
      }
    }
  }


  // ── Category toggle ─────────────────────────────────────────────────
  void _toggleCategory(String cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        _selectedCategories.add(cat);
      }
    });
  }

  // ── Save product to backend ─────────────────────────────────────────
  Future<void> _saveProduct() async {
    if (_isPricing) return;

    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final materialsList = _currentMaterials();
    final materials = materialsList.join('، ');
    final dimensions = _dimensionsController.text.trim();
    final colors = _colorsController.text.trim();
    final FocusNode colorsFocusNode = FocusNode();
    final GlobalKey colorsFieldKey = GlobalKey();
    final price = double.tryParse(_priceController.text.trim());
    final category =
    _selectedCategories.isNotEmpty ? _selectedCategories.first : '';

    if (widget.craftsmanId
        .trim()
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              t('تعذر تحديد حساب الحرفي', 'Artisan account was not found')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              t('الرجاء إدخال اسم المنتج', 'Please enter product name')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('الرجاء اختيار تصنيف', 'Please select a category')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (materialsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('الرجاء اختيار مادة واحدة على الأقل',
              'Please select at least one material')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              t('الرجاء إدخال سعر صحيح', 'Please enter a valid price')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isPricing = true);

    try {
      String? imageUrl;

      // Upload/keep the main image.
      if (_pickedImage != null) {
        imageUrl = await CloudinaryService.uploadImage(_pickedImage!);
        if (imageUrl == null || imageUrl.isEmpty) {
          throw Exception('Main image upload failed');
        }
      } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
        imageUrl = _existingImageUrl;
      }

      // Keep existing additional images and upload any newly selected ones.
      final galleryUrls = <String>[
        ..._existingAdditionalImageUrls,
      ];

      for (final file in _additionalPickedImages) {
        final uploaded = await CloudinaryService.uploadImage(file);
        if (uploaded == null || uploaded.isEmpty) {
          throw Exception('Gallery image upload failed');
        }
        galleryUrls.add(uploaded);
      }

      final allImages = <String>[
        if (imageUrl != null && imageUrl.isNotEmpty) imageUrl,
        ...galleryUrls,
      ];

      // Defensive de-duplication and hard limit.
      final uniqueImages = <String>[];
      for (final url in allImages) {
        final clean = url.trim();
        if (clean.isNotEmpty && !uniqueImages.contains(clean)) {
          uniqueImages.add(clean);
        }
        if (uniqueImages.length == _maxProductImages) break;
      }

      Map<String, dynamic>? result;

      if (isEditing) {
        final productId = widget.product!['id'].toString();
        final fields = <String, dynamic>{
          'craftsmanId': widget.craftsmanId,
          'titleAr': title,
          'titleEn': title,
          'description': description,
          'materials': materials,
          'dimensions': dimensions,
          'colors': colors,
          'price': price,
          'category': category,
          'isPublic': _isPublic,
          'images': uniqueImages,
          'aiAnalysis': _aiResult,
        };

        if (imageUrl != null && imageUrl.isNotEmpty) {
          fields['imageUrl'] = imageUrl;
        }

        result = await ProductsService.updateProduct(productId, fields);
      } else {
        result = await ProductsService.createProduct(
          craftsmanId: widget.craftsmanId,
          titleAr: title,
          titleEn: title,
          description: description,
          materials: materials,
          dimensions: dimensions,
          colors: colors,
          price: price,
          category: category,
          isPublic: _isPublic,
          imageUrl: imageUrl,
          images: uniqueImages,
        );

        // createProduct service may not expose aiAnalysis as a named argument.
        // Persist the AI result immediately after creation when an id is returned.
        if (result != null && _aiResult != null) {
          final created = result['product'] is Map ? result['product'] : result;
          final createdId = created is Map ? created['id']?.toString() : null;
          if (createdId != null && createdId.isNotEmpty) {
            final updated = await ProductsService.updateProduct(createdId, {
              'aiAnalysis': _aiResult,
              'images': uniqueImages,
            });
            if (updated != null) result = updated;
          }
        }
      }

      if (!mounted) return;

      if (result != null) {
        widget.onProductSaved?.call();
        widget.onProductAdded?.call(result);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? t(
                  '✅ تم تعديل المنتج بنجاح', '✅ Product updated successfully')
                  : t('✅ تم حفظ المنتج بنجاح', '✅ Product saved successfully'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                '❌ فشل حفظ المنتج، تحقق من الاتصال وحاول مجدداً',
                '❌ Failed to save product. Check the connection and try again',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              '❌ تعذر رفع الصورة أو حفظ المنتج',
              '❌ Could not upload the image or save the product',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPricing = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _otherMaterialController.dispose();
    _dimensionsController.dispose();
    _colorsController.dispose();
    _colorsFocusNode.dispose();
    _dimensionsFocusNode.dispose();

    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isArabic ? Icons.arrow_back_ios : Icons.arrow_back_ios_new,
              color: text,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isEditing
                ? t('تعديل المنتج', 'Edit Product')
                : t('إضافة منتج جديد', 'Add New Product'),
            style: GoogleFonts.cairo(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image Upload & AI Studio ────────────────────────────
              Text(
                t('صورة المنتج', 'Product Image'),
                style: GoogleFonts.cairo(
                    color: text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _hasImage ? null : _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasAiBackground ? Colors.purpleAccent : border,
                      width: _hasAiBackground ? 2 : 1,
                    ),
                  ),
                  child: !_hasImage
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate,
                          size: 50, color: dim),
                      const SizedBox(height: 8),
                      Text(
                        t('اضغط لرفع صورة', 'Tap to upload image'),
                        style:
                        GoogleFonts.cairo(color: dim, fontSize: 14),
                      ),
                    ],
                  )
                      : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _productImagePreview(),
                      ),
                      if (_isGeneratingBackground)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                  color: Colors.purpleAccent),
                              const SizedBox(height: 12),
                              Text(
                                t('جاري إنشاء استوديو افتراضي...',
                                    'Generating virtual studio...'),
                                style: GoogleFonts.cairo(
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      if (!_isGeneratingBackground)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                            child: IconButton(
                              tooltip: t('تغيير الصورة', 'Change image'),
                              onPressed: _pickImage,
                              icon: const Icon(Icons.edit,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_hasImage && !_isGeneratingBackground) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _generateAiBackground,
                  icon: const Icon(Icons.auto_awesome, color: Colors.white),
                  label: Text(
                    _hasAiBackground
                        ? t('تغيير نمط الاستوديو', 'Change Studio Style')
                        : t('تحسين الصورة (AI Studio)',
                        'Enhance Image (AI Studio)'),
                    style: GoogleFonts.cairo(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purpleAccent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                _buildGallerySection(),
              ],
              const SizedBox(height: 24),

              // ── Title ────────────────────────────────────────────────
              _buildTextField(
                  _titleController, t('اسم المنتج', 'Product Name')),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.purpleAccent.withValues(alpha: 0.55),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                            Icons.auto_awesome, color: Colors.purpleAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CraftGo AI Product Assistant',
                            style: GoogleFonts.cairo(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(
                        'يولّد وصفاً احترافياً، ويقترح السعر والكلمات المفتاحية ونصائح لتحسين فرصة البيع.',
                        'Generates a professional description, price, tags, and practical selling recommendations.',
                      ),
                      style: GoogleFonts.cairo(color: dim, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isAnalyzingProduct
                          ? null
                          : _runAiProductAssistant,
                      icon: _isAnalyzingProduct
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.psychology, color: Colors.white),
                      label: Text(
                        _isAnalyzingProduct
                            ? t('جاري تحليل المنتج...', 'Analyzing product...')
                            : (_aiResult != null || isEditing)
                            ? t('🔄 إعادة تحليل المنتج', '🔄 Analyze Again')
                            : t('✨ تحليل المنتج بالذكاء الاصطناعي',
                            '✨ Analyze Product with AI'),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Description ──────────────────────────────────────────
              _buildTextField(_descController, t('وصف المنتج', 'Description'),
                  maxLines: 4),
              const SizedBox(height: 16),

              // ── Materials ────────────────────────────────────────────
              Text(
                t('المواد المستخدمة', 'Materials'),
                key: _materialsSectionKey,
                style: GoogleFonts.cairo(
                  color: text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allMaterials.map((material) {
                  final selected = _selectedMaterials.contains(material);
                  final label = widget.isArabic
                      ? material
                      : (_materialsMap[material] ?? material);
                  return FilterChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.black : text,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => _toggleMaterial(material),
                    backgroundColor: surface,
                    selectedColor: accent,
                    side: BorderSide(
                      color: selected ? accent : border,
                      width: selected ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
              if (_selectedMaterials.contains('أخرى')) ...[
                const SizedBox(height: 12),
                _buildTextField(
                  _otherMaterialController,
                  t('اكتبي المادة الأخرى', 'Specify other material'),
                ),
              ],
              const SizedBox(height: 16),

              // ── Dimensions ───────────────────────────────────────────
              Container(
                key: _dimensionsFieldKey,
                child: _buildTextField(
                  _dimensionsController,
                  t(
                    'الأبعاد (مثال: 30x40 سم)',
                    'Dimensions (e.g., 30x40 cm)',
                  ),
                  focusNode: _dimensionsFocusNode,
                ),
              ),
              const SizedBox(height: 16),

              // ── Colors ───────────────────────────────────────────────
              Container(
                key: _colorsFieldKey,
                child: _buildTextField(
                  _colorsController,
                  t(
                    'الألوان المتوفرة (افصل بينها بفواصل)',
                    'Colors (comma separated)',
                  ),
                  focusNode: _colorsFocusNode,
                ),
              ),
              const SizedBox(height: 16),

              // ── Categories (multi‑select chips) ─────────────────────
              Text(
                t('التصنيفات', 'Categories'),
                style: GoogleFonts.cairo(
                    color: text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allCategories.map((cat) {
                  final selected = _selectedCategories.contains(cat);
                  final label = widget.isArabic
                      ? cat
                      : (_categoriesMap[cat] ?? cat);
                  return FilterChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.black : text,
                        fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => _toggleCategory(cat),
                    backgroundColor: surface,
                    selectedColor: accent,
                    side: BorderSide(
                      color: selected ? accent : border,
                      width: selected ? 2 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ── Public / Private toggle ────────────────────────────
              Row(
                children: [
                  Text(
                    t('عام / خاص', 'Public / Private'),
                    style: TextStyle(color: text, fontSize: 16),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    activeThumbColor: accent,
                  ),
                  Text(
                    _isPublic ? t('عام', 'Public') : t('خاص', 'Private'),
                    style: TextStyle(
                      color: _isPublic ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Price & AI ──────────────────────────────────────────
              Text(
                t('السعر (بالدينار)', 'Price (JD)'),
                style: GoogleFonts.cairo(
                    color: text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_priceController, '',
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (_isPricing || _isAnalyzingProduct)
                        ? null
                        : _runAiPricing,
                    icon: _isPricing
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.purpleAccent))
                        : const Icon(Icons.psychology,
                        color: Colors.purpleAccent),
                    label: Text(
                      t('تسعير AI', 'AI Pricing'),
                      style: GoogleFonts.cairo(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: surface,
                      side: const BorderSide(color: Colors.purpleAccent),
                      minimumSize: const Size(0, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              if (_aiResult != null) ...[
                const SizedBox(height: 16),
                _buildAiResultCard(),
              ],
              const SizedBox(height: 40),

              // ── Save Button ──────────────────────────────────────────
              ElevatedButton(
                onPressed: _isPricing ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isPricing
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
                    : Text(
                  isEditing
                      ? t('حفظ التعديلات', 'Save Changes')
                      : t('حفظ المنتج', 'Save Product'),
                  style: GoogleFonts.cairo(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }


  bool _specificationsAreComplete() {
    return _dimensionsController.text.trim().isNotEmpty &&
        _colorsController.text.trim().isNotEmpty &&
        _currentMaterials().isNotEmpty;
  }

  bool _giftPackagingIsAlreadyAdded() {
    final value = _descController.text.toLowerCase();
    return value.contains('gift packaging') ||
        value.contains('gift wrap') ||
        value.contains('gift wrapping') ||
        value.contains('تغليف هدايا') ||
        value.contains('تغليف كهدية') ||
        value.contains('تغليف الهدية');
  }

  bool _shouldShowRecommendation(String recommendation) {
    if (_isProductSpecificationsRecommendation(recommendation) &&
        _specificationsAreComplete()) {
      return false;
    }

    // Four or five product photos already provide a strong multi-angle gallery.
    if (_isImageRecommendation(recommendation) && _galleryImageCount >= 4) {
      return false;
    }

    if (_isGiftPackagingRecommendation(recommendation) &&
        _giftPackagingIsAlreadyAdded()) {
      return false;
    }

    return true;
  }

  Widget _buildAiResultCard() {
    final result = _aiResult!;
    final minPrice = result['minimumPrice']?.toString() ?? '-';
    final maxPrice = result['maximumPrice']?.toString() ?? '-';
    final reason = result['priceReason']?.toString().trim() ?? '';
    final scoreText = result['score']?.toString() ?? '0';
    final score = double.tryParse(scoreText)?.clamp(0, 100).toDouble() ?? 0;
    final potential = result['sellingPotential']?.toString() ?? '-';
    final tags =
        (result['tags'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final recommendations = ((result['recommendations'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        [])
        .where(_shouldShowRecommendation)
        .toList();

    final potentialColor = _sellingPotentialColor(potential);
    final badge = score >= 90
        ? t('🏆 موصى به من الذكاء الاصطناعي', '🏆 AI Recommended')
        : score < 60
        ? t('⚠ يحتاج إلى تحسين', '⚠ Needs Improvement')
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Align(
              alignment: widget.isArabic
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: score >= 90
                      ? accent.withValues(alpha: 0.14)
                      : Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: score >= 90
                        ? accent.withValues(alpha: 0.45)
                        : Colors.orange.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.cairo(
                    color: score >= 90 ? accent : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CraftGo AI Analysis',
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      t(
                        'تحليل ذكي لجاهزية المنتج وفرصة بيعه',
                        'Smart analysis of product readiness and selling potential',
                      ),
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildScoreCard(score),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAiMetricCard(
                  icon: Icons.trending_up_rounded,
                  title: t('فرصة البيع', 'Selling Potential'),
                  value: potential,
                  subtitle: t('تقدير المساعد الذكي', 'AI estimate'),
                  valueColor: potentialColor,
                  iconColor: potentialColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: accent, size: 21),
                    const SizedBox(width: 8),
                    Text(
                      t('النطاق السعري المقترح', 'Suggested Price Range'),
                      style: GoogleFonts.cairo(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$minPrice - $maxPrice JD',
                  style: GoogleFonts.cairo(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    reason,
                    style: GoogleFonts.cairo(
                      color: dim,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildAiSectionTitle(
              icon: Icons.sell_outlined,
              title: t('الكلمات المفتاحية', 'Tags'),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) =>
                    Tooltip(
                      message: t('كلمة مفتاحية مقترحة', 'Suggested keyword'),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                t('تم اختيار: $tag', 'Selected: $tag'),
                                style: GoogleFonts.cairo(),
                              ),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.purpleAccent.withValues(
                                  alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.cairo(
                              color: text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
              )
                  .toList(),
            ),
          ],
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAiSectionTitle(
              icon: Icons.lightbulb_outline_rounded,
              title: t('اقتراحات التحسين', 'Recommendations'),
            ),
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Column(
                children: recommendations
                    .map(
                      (item) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.cairo(
                                  color: dim,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            if (_hasRecommendationAction(item)) ...[
                              const SizedBox(width: 6),
                              TextButton.icon(
                                onPressed:
                                _isImprovingDescription || _isAnalyzingProduct
                                    ? null
                                    : () => _handleRecommendationAction(item),
                                icon: _isDescriptionRecommendation(item) &&
                                    _isImprovingDescription
                                    ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.purpleAccent,
                                  ),
                                )
                                    : Icon(
                                  _recommendationActionIcon(item),
                                  size: 15,
                                  color: Colors.purpleAccent,
                                ),
                                label: Text(
                                  _isDescriptionRecommendation(item) &&
                                      _isImprovingDescription
                                      ? t('جاري...', 'Working...')
                                      : _recommendationActionText(item),
                                  style: GoogleFonts.cairo(
                                    color: Colors.purpleAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(double score) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 900),
            builder: (context, value, _) {
              return SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 7,
                      backgroundColor:
                      Colors.purpleAccent.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.purpleAccent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: Colors.purpleAccent,
                        ),
                        Text(
                          '${score.toStringAsFixed(0)}%',
                          style: GoogleFonts.cairo(
                            color: text,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            t('جاهزية المنتج', 'Product Score'),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            t('من 100', 'out of 100'),
            style: GoogleFonts.cairo(color: dim, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Color _sellingPotentialColor(String potential) {
    final normalized = potential.trim().toLowerCase();

    if (normalized.contains('مرتفع') ||
        normalized.contains('عالي') ||
        normalized.contains('high')) {
      return Colors.green;
    }

    if (normalized.contains('منخفض') ||
        normalized.contains('ضعيف') ||
        normalized.contains('low')) {
      return Colors.redAccent;
    }

    return Colors.orange;
  }

  Widget _buildAiMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    Color? valueColor,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor ?? Colors.purpleAccent, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: valueColor ?? text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: dim,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.purpleAccent, size: 20),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ── Helper: text field ──────────────────────────────────────────────
  Widget _buildTextField(TextEditingController controller,
      String label, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
        FocusNode? focusNode,
      }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: text),
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? label : null,
        labelStyle: TextStyle(color: dim),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
    {
      return TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: text),
        decoration: InputDecoration(
          labelText: label.isNotEmpty ? label : null,
          labelStyle: TextStyle(color: dim),
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      );
    }
  }
}

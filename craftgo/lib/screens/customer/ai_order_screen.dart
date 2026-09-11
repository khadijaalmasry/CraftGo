import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../services/api_service.dart';
import '../../services/customer_service.dart';
import 'product_details_page.dart';
import 'artisan_profile_page.dart';

class AIOrderScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const AIOrderScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<AIOrderScreen> createState() => _AIOrderScreenState();
}

class _AIOrderScreenState extends State<AIOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Text input ──────────────────────────────────────────────────────────
  final TextEditingController _textController = TextEditingController();

  // ── Photo input ─────────────────────────────────────────────────────────
  XFile? _selectedImage;

  // ── Sketch input ────────────────────────────────────────────────────────
  List<Offset> _points = [];
  Color _selectedColor = const Color(0xFFD4A017);
  double _strokeWidth = 4.0;
  bool _isDrawing = false;
  final List<List<Offset>> _strokes = [];
  final List<Color> _strokeColors = [];
  final List<double> _strokeWidths = [];

  // Undo/Redo stacks
  final List<List<List<Offset>>> _undoStrokesStack = [];
  final List<List<Color>> _undoColorsStack = [];
  final List<List<double>> _undoWidthsStack = [];
  final List<List<Map<String, dynamic>>> _undoShapesStack = [];
  final List<List<Map<String, dynamic>>> _undoTextsStack = [];
  final List<List<Map<String, dynamic>>> _undoStampsStack = [];

  final List<List<List<Offset>>> _redoStrokesStack = [];
  final List<List<Color>> _redoColorsStack = [];
  final List<List<double>> _redoWidthsStack = [];
  final List<List<Map<String, dynamic>>> _redoShapesStack = [];
  final List<List<Map<String, dynamic>>> _redoTextsStack = [];
  final List<List<Map<String, dynamic>>> _redoStampsStack = [];

  bool _isEraser = false;
  String _selectedDrawingTool =
      'brush'; // 'brush', 'rectangle', 'circle', 'line', 'text', 'stamp_star', 'stamp_heart', 'stamp_flower'
  bool _symmetryEnabled = false;
  bool _gridEnabled = false;
  final List<Map<String, dynamic>> _shapes = [];
  final List<Map<String, dynamic>> _texts = [];
  final List<Map<String, dynamic>> _stamps = [];
  Offset? _currentShapeStart;
  Offset? _currentShapeEnd;

  // ── 3D Viewer State ──────────────────────────────────────────────────────
  String _selected3DShape = 'cube'; // 'cube', 'sphere', 'cylinder', 'ring'
  String _selected3DMaterial = 'gold'; // 'gold', 'silver', 'clay', 'wood'
  double _rotationX = 0.4;
  double _rotationY = 0.6;
  final double _shapeScale = 1.0;
  Color _custom3DColor = const Color(0xFFD4A017);

  // ── Color palette ──────────────────────────────────────────────────────
  final List<Color> _colors = [
    Colors.black,
    Colors.grey,
    Colors.brown,
    const Color(0xFFD4A017), // Gold
    Colors.red,
    Colors.pink,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
  ];

  // API result state
  List<dynamic> _resultProducts = [];
  List<dynamic> _resultArtisans = [];
  String? _resultCategory;
  String? _resultCategoryAr;
  String? _resultPriceRange;
  String? _resultDescription;
  List<String> _resultKeywords = [];
  bool _isLoading = false;

  // Photo Vision AI State
  List<String> _extractedVisionTags = [];
  bool _isAnalyzingVision = false;
  final TextEditingController _visionDescController = TextEditingController();

  // Sketch AI Mockups State
  List<Map<String, dynamic>> _aiMockups = [];
  int? _selectedMockupIndex;
  bool _isGeneratingMockups = false;

  // Canvas RepaintBoundary key for sketch export
  final GlobalKey _sketchKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _visionDescController.dispose();
    super.dispose();
  }

  // ── Theme colors ──────────────────────────────────────────────────────
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

  Color get canvasBackground => const Color(0xFFF8F6F1);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  // ── Save state for undo ──────────────────────────────────────────────
  void _saveStateForUndo() {
    _undoStrokesStack.add(_strokes.map((s) => List<Offset>.from(s)).toList());
    _undoColorsStack.add(List<Color>.from(_strokeColors));
    _undoWidthsStack.add(List<double>.from(_strokeWidths));
    _undoShapesStack
        .add(_shapes.map((s) => Map<String, dynamic>.from(s)).toList());
    _undoTextsStack
        .add(_texts.map((t) => Map<String, dynamic>.from(t)).toList());
    _undoStampsStack
        .add(_stamps.map((s) => Map<String, dynamic>.from(s)).toList());

    _redoStrokesStack.clear();
    _redoColorsStack.clear();
    _redoWidthsStack.clear();
    _redoShapesStack.clear();
    _redoTextsStack.clear();
    _redoStampsStack.clear();
  }

  // ── Text input ──────────────────────────────────────────────────────────
  Widget _buildTextInput() {
    final List<String> suggestions = widget.isArabic
        ? [
            'سجادة صوفية حمراء بنقش تقليدي',
            'فخار إبريق ماء مطعم بالذهب',
            'طقم مجوهرات فضية مع فيروز',
            'لوحة جدارية خط عربي خشبي',
          ]
        : [
            'Red traditional wool carpet',
            'Gold accented pottery pitcher',
            'Silver jewelry set with turquoise',
            'Wooden Arabic calligraphy wall art',
          ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('اكتب وصفاً مفصلاً لما تريد تصنيعه أو البحث عنه',
                'Describe in detail what you want to order or search for'),
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) => GestureDetector(
                onTap: () {
                  setState(() {
                    _textController.text = suggestions[idx];
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        suggestions[idx],
                        style: TextStyle(color: primaryTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              style:
                  TextStyle(color: primaryTextColor, fontSize: 14, height: 1.5),
              decoration: InputDecoration(
                hintText: t(
                  'مثال: أحتاج إلى إبريق فخاري تقليدي منقوش يدويًا بسعة ١ لتر ومزين باللون الأزرق...',
                  'Example: I need a 1L traditional hand-carved pottery pitcher with blue patterns...',
                ),
                hintStyle: TextStyle(
                    color: secondaryTextColor.withValues(alpha: 0.5),
                    fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: _submitRequest,
              icon: const Icon(Icons.auto_awesome, color: Colors.black),
              label: Text(
                t('تحليل واستكشاف المنتجات والحرفيين',
                    'Analyze & Find Products & Artisans'),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo input ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _isAnalyzingVision = true;
      });

      final analysis = await CustomerService.visualSearchBytes(
        await image.readAsBytes(),
        filename: image.name,
      );
      final returnedTags = (analysis?['keywords'] as List?)
          ?.map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _extractedVisionTags = returnedTags ?? <String>[];
        _visionDescController.text =
            (analysis?['description'] as String?) ?? '';
        _isAnalyzingVision = false;
      });
    }
  }

  Widget _buildPhotoInput() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('ارفع صورة مرجعية وسيحللها الذكاء الاصطناعي لاستخراج الكلمات المفتاحية',
                'Upload a photo for AI vision to extract tags & find matching craft items'),
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _pickImage(),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          kIsWeb
                              ? Image.network(
                                  _selectedImage!.path,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_selectedImage!.path),
                                  fit: BoxFit.cover,
                                ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                  _extractedVisionTags.clear();
                                  _visionDescController.clear();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_a_photo_outlined,
                              size: 36, color: accent),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t('اضغط لاختيار صورة من المعرض',
                              'Tap to select an image from gallery'),
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isAnalyzingVision) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: accent, strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    t('جاري تحليل عناصر الصورة بواسطة الذكاء الاصطناعي...',
                        'AI Vision is analyzing image details & keywords...'),
                    style: TextStyle(color: primaryTextColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else if (_extractedVisionTags.isNotEmpty) ...[
            Text(
              t('الكلمات المفتاحية الـمستخرجة (يمكنك تعديلها):',
                  'AI Extracted Vision Tags (Editable):'),
              style: TextStyle(
                color: primaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _extractedVisionTags.map((tag) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _extractedVisionTags.remove(tag);
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode
                          ? const Color(0xFF222F43)
                          : const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.label_outlined, size: 14, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          tag,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: widget.isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _visionDescController,
              style: TextStyle(color: primaryTextColor, fontSize: 13),
              decoration: InputDecoration(
                labelText: t('توضيح إضافي للبحث (اختياري)',
                    'Additional search context (optional)'),
                labelStyle: TextStyle(color: secondaryTextColor),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cardBorderColor),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: _selectedImage != null ? _submitRequest : null,
              icon: const Icon(Icons.image_search, color: Colors.black),
              label: Text(
                t('البحث عن منتجات وحرفيين مشابهين',
                    'Search Similar Products & Artisans'),
                style: TextStyle(
                  color: _selectedImage != null ? Colors.black : Colors.black38,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Color Picker Dialog ──────────────────────────────────────────────
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          t('اختر لوناً', 'Pick a color'),
          style: TextStyle(color: primaryTextColor),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
                _isEraser = false;
              });
            },
            colorPickerWidth: 300,
            pickerAreaHeightPercent: 0.8,
            enableAlpha: false,
            displayThumbColor: true,
            portraitOnly: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t('إغلاق', 'Close'),
              style: TextStyle(color: accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sketch input ────────────────────────────────────────────────────────
  Widget _buildSketchInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PopupMenuButton<String>(
                icon: Icon(Icons.category, color: accent),
                tooltip: t('أدوات الرسم', 'Drawing Tools'),
                onSelected: (tool) {
                  setState(() {
                    _selectedDrawingTool = tool;
                    _isEraser = false;
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'brush',
                      child: Text(t('🖌️ فرشاة حرة', '🖌️ Free Brush'))),
                  PopupMenuItem(
                      value: 'rectangle',
                      child: Text(t('⬜ مستطيل', '⬜ Rectangle'))),
                  PopupMenuItem(
                      value: 'circle', child: Text(t('⭕ دائرة', '⭕ Circle'))),
                  PopupMenuItem(
                      value: 'line',
                      child: Text(t('📏 خط مستقيم', '📏 Straight Line'))),
                  PopupMenuItem(
                      value: 'text',
                      child: Text(t('🔠 إضافة نص', '🔠 Add Text'))),
                  PopupMenuItem(
                      value: 'stamp_star',
                      child: Text(t('⭐ ختم نجمة', '⭐ Stamp Star'))),
                  PopupMenuItem(
                      value: 'stamp_heart',
                      child: Text(t('❤️ ختم قلب', '❤️ Stamp Heart'))),
                  PopupMenuItem(
                      value: 'stamp_flower',
                      child: Text(t('🌸 ختم وردة', '🌸 Stamp Flower'))),
                ],
              ),
              Text(
                _selectedDrawingTool == 'brush'
                    ? t('فرشاة حرة', 'Free Brush')
                    : _selectedDrawingTool == 'rectangle'
                        ? t('مستطيل', 'Rectangle')
                        : _selectedDrawingTool == 'circle'
                            ? t('دائرة', 'Circle')
                            : _selectedDrawingTool == 'line'
                                ? t('خط مستقيم', 'Straight Line')
                                : _selectedDrawingTool == 'text'
                                    ? t('إضافة نص', 'Add Text')
                                    : _selectedDrawingTool.replaceFirst(
                                        'stamp_', 'Stamp '),
                style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.grid_on,
                    color: _gridEnabled ? accent : secondaryTextColor),
                onPressed: () => setState(() => _gridEnabled = !_gridEnabled),
                tooltip: t('شبكة إرشادية', 'Guide Grid'),
              ),
              IconButton(
                icon: Icon(Icons.compare,
                    color: _symmetryEnabled ? accent : secondaryTextColor),
                onPressed: () =>
                    setState(() => _symmetryEnabled = !_symmetryEnabled),
                tooltip: t('تناظر مرآة', 'Mirror Symmetry'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 300,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest.isFinite
                    ? constraints.biggest
                    : const Size(300, 260);

                return Container(
                  decoration: BoxDecoration(
                    color: canvasBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: GestureDetector(
                    onTapDown: (details) {
                      final point =
                          _clampPointToCanvas(details.localPosition, size);
                      if (_selectedDrawingTool == 'text') {
                        _showTextInputDialog(point);
                      } else if (_selectedDrawingTool.startsWith('stamp_')) {
                        setState(() {
                          _saveStateForUndo();
                          _stamps.add({
                            'type':
                                _selectedDrawingTool.replaceFirst('stamp_', ''),
                            'offset': point,
                            'color': _selectedColor,
                            'size': _strokeWidth * 5,
                          });
                        });
                      }
                    },
                    onPanStart: (details) {
                      final point =
                          _clampPointToCanvas(details.localPosition, size);
                      if (_isEraser) {
                        return;
                      }
                      if (_selectedDrawingTool == 'brush') {
                        setState(() {
                          _isDrawing = true;
                          _points = [point];
                        });
                      } else if (_selectedDrawingTool == 'rectangle' ||
                          _selectedDrawingTool == 'circle' ||
                          _selectedDrawingTool == 'line') {
                        setState(() {
                          _currentShapeStart = point;
                          _currentShapeEnd = point;
                        });
                      }
                    },
                    onPanUpdate: (details) {
                      final point =
                          _clampPointToCanvas(details.localPosition, size);
                      if (_isEraser) {
                        _eraseNear(point);
                        return;
                      }
                      if (_selectedDrawingTool == 'brush' && _isDrawing) {
                        setState(() {
                          _points.add(point);
                        });
                      } else if (_selectedDrawingTool == 'rectangle' ||
                          _selectedDrawingTool == 'circle' ||
                          _selectedDrawingTool == 'line') {
                        setState(() {
                          _currentShapeEnd = point;
                        });
                      }
                    },
                    onPanEnd: (details) {
                      if (_isEraser) return;
                      if (_selectedDrawingTool == 'brush' &&
                          _isDrawing &&
                          _points.length > 1) {
                        setState(() {
                          _saveStateForUndo();
                          _strokes.add(List.from(_points));
                          _strokeColors.add(_selectedColor);
                          _strokeWidths.add(_strokeWidth);
                          _points = [];
                          _isDrawing = false;
                        });
                      } else if ((_selectedDrawingTool == 'rectangle' ||
                              _selectedDrawingTool == 'circle' ||
                              _selectedDrawingTool == 'line') &&
                          _currentShapeStart != null &&
                          _currentShapeEnd != null) {
                        setState(() {
                          _saveStateForUndo();
                          _shapes.add({
                            'type': _selectedDrawingTool,
                            'start': _currentShapeStart,
                            'end': _currentShapeEnd,
                            'color': _selectedColor,
                            'width': _strokeWidth,
                          });
                          _currentShapeStart = null;
                          _currentShapeEnd = null;
                        });
                      }
                    },
                    child: RepaintBoundary(
                      key: _sketchKey,
                      child: CustomPaint(
                        painter: _SketchPainter(
                          strokes: _strokes,
                          strokeColors: _strokeColors,
                          strokeWidths: _strokeWidths,
                          currentPoints: _points,
                          currentColor:
                              _isEraser ? Colors.transparent : _selectedColor,
                          currentWidth:
                              _isEraser ? _strokeWidth * 3 : _strokeWidth,
                          isEraser: _isEraser,
                          canvasColor: canvasBackground,
                          shapes: _shapes,
                          texts: _texts,
                          stamps: _stamps,
                          currentShapeStart: _currentShapeStart,
                          currentShapeEnd: _currentShapeEnd,
                          selectedDrawingTool: _selectedDrawingTool,
                          symmetryEnabled: _symmetryEnabled,
                          gridEnabled: _gridEnabled,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _colors.length,
                    separatorBuilder: (context, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final color = _colors[index];
                      final isSelected = color == _selectedColor && !_isEraser;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = color;
                            _isEraser = false;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected ? accent : Colors.transparent,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.indigo,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                      border: Border.all(
                        color: _selectedColor == const Color(0xFFD4A017) &&
                                !_isEraser
                            ? accent
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.colorize,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildToolButton(
                icon: _isEraser ? Icons.brush : Icons.cleaning_services,
                label: _isEraser ? t('رسم', 'Draw') : t('ممحاة', 'Eraser'),
                isActive: _isEraser,
                onTap: () => setState(() => _isEraser = !_isEraser),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.line_weight, color: primaryTextColor, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 1,
                        max: 12,
                        activeColor: accent,
                        inactiveColor: cardBorderColor,
                        onChanged: (v) => setState(() => _strokeWidth = v),
                      ),
                    ),
                    Container(
                      width: 24,
                      alignment: Alignment.center,
                      child: Text(
                        _strokeWidth.round().toString(),
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _buildIconButton(
                icon: Icons.undo,
                onTap: _undoLastStroke,
              ),
              _buildIconButton(
                icon: Icons.redo,
                onTap: _redoLastStroke,
              ),
              _buildIconButton(
                icon: Icons.delete_sweep,
                onTap: _clearCanvas,
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isGeneratingMockups) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: accent, strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t('جاري توليد ٣ نماذج مقترحة بالذكاء الاصطناعي بناءً على رسمك...',
                          'Generating 3 AI concept previews based on your sketch...'),
                      style: TextStyle(color: primaryTextColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (_aiMockups.isNotEmpty) ...[
            Text(
              t('النماذج المقترحة من الذكاء الاصطناعي (اختر النموذج الأنسب):',
                  'AI Generated Concept Mockups (Select preferred option):'),
              style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Scrollbar(
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _aiMockups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, idx) {
                    final mockup = _aiMockups[idx];
                    final isSelected = _selectedMockupIndex == idx;
                    final imageBytes = mockup['imageBytes'] as Uint8List?;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMockupIndex = idx),
                      child: Container(
                        width: 170,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.15)
                              : surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? accent : cardBorderColor,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(
                                  height: 80,
                                  width: double.infinity,
                                  child: Image.memory(
                                    imageBytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 80,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.auto_awesome, color: accent),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.auto_awesome,
                                  size: 14,
                                  color: accent,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    mockup['title'] ?? '',
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mockup['desc'] ?? '',
                              style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 10,
                                  height: 1.2),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _hasSketchInput() ? _generateAIMockups : null,
                  icon: Icon(Icons.auto_awesome, color: accent, size: 16),
                  label: Text(
                    t('توليد ٣ نماذج AI', 'Generate 3 AI Mockups'),
                    style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
                    ),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: _hasSketchInput() ? _submitRequest : null,
                    child: Text(
                      t('البحث واستكشاف النتائج', 'Find Products & Artisans'),
                      style: TextStyle(
                        color:
                            _hasSketchInput() ? Colors.black : Colors.black38,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Offset _clampPointToCanvas(Offset point, Size size) {
    return Offset(
      point.dx.clamp(0.0, size.width).toDouble(),
      point.dy.clamp(0.0, size.height).toDouble(),
    );
  }

  Future<Uint8List> _generateFreeMockupImage(
    String title,
    String subtitle,
    Color baseColor,
    Color accentColor,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const width = 600.0;
    const height = 420.0;

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(width, height),
        [
          baseColor.withValues(alpha: 0.95),
          accentColor.withValues(alpha: 0.72)
        ],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(26),
      ),
      bgPaint,
    );

    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (double x = 0; x < width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), patternPaint);
    }
    for (double y = 0; y < height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(width, y), patternPaint);
    }

    final cardPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(width / 2, height * 0.58),
          width: width * 0.72,
          height: height * 0.44,
        ),
        const Radius.circular(24),
      ),
      cardPaint,
    );

    final itemPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    if (subtitle.toLowerCase().contains('pottery') ||
        subtitle.toLowerCase().contains('clay') ||
        title.toLowerCase().contains('فخاري') ||
        title.toLowerCase().contains('خزف')) {
      final path = Path();
      path.moveTo(width * 0.44, height * 0.24);
      path.quadraticBezierTo(
          width * 0.38, height * 0.24, width * 0.35, height * 0.36);
      path.lineTo(width * 0.35, height * 0.7);
      path.quadraticBezierTo(
          width * 0.35, height * 0.82, width * 0.46, height * 0.82);
      path.lineTo(width * 0.54, height * 0.82);
      path.quadraticBezierTo(
          width * 0.65, height * 0.82, width * 0.65, height * 0.7);
      path.lineTo(width * 0.65, height * 0.36);
      path.quadraticBezierTo(
          width * 0.62, height * 0.24, width * 0.56, height * 0.24);
      path.close();
      canvas.drawPath(path, itemPaint);
      final linePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.8)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(width * 0.42, height * 0.38),
          Offset(width * 0.42, height * 0.64), linePaint);
      canvas.drawLine(Offset(width * 0.58, height * 0.38),
          Offset(width * 0.58, height * 0.64), linePaint);
    } else if (subtitle.toLowerCase().contains('gold') ||
        subtitle.toLowerCase().contains('jewel') ||
        title.toLowerCase().contains('مجوهر') ||
        title.toLowerCase().contains('ذهبي')) {
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10;
      canvas.drawCircle(const Offset(300, 210), 54, ringPaint);
      canvas.drawCircle(const Offset(300, 210), 18, itemPaint);
      canvas.drawLine(Offset(300, 265), Offset(300, 320), ringPaint);
      canvas.drawLine(Offset(255, 288), Offset(345, 288), ringPaint);
    } else {
      final textileBrush = Paint()
        ..color = Colors.white.withValues(alpha: 0.82)
        ..style = PaintingStyle.fill;
      final textilePath = Path();
      textilePath.moveTo(width * 0.34, height * 0.4);
      textilePath.lineTo(width * 0.66, height * 0.4);
      textilePath.lineTo(width * 0.72, height * 0.75);
      textilePath.lineTo(width * 0.28, height * 0.75);
      textilePath.close();
      canvas.drawPath(textilePath, textileBrush);
      final stripePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.75)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      for (double x = width * 0.38; x <= width * 0.62; x += 20) {
        canvas.drawLine(
            Offset(x, height * 0.42), Offset(x, height * 0.73), stripePaint);
      }
      for (double y = height * 0.46; y <= height * 0.7; y += 22) {
        canvas.drawLine(
            Offset(width * 0.32, y), Offset(width * 0.68, y), stripePaint);
      }
    }

    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );
    final subtitleStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 15,
      fontWeight: FontWeight.w500,
    );

    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width * 0.8);
    titlePainter.paint(
        canvas, Offset((width - titlePainter.width) / 2, height * 0.08));

    final subtitlePainter = TextPainter(
      text: TextSpan(text: subtitle, style: subtitleStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width * 0.76);
    subtitlePainter.paint(
      canvas,
      Offset((width - subtitlePainter.width) / 2, height * 0.16),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _generateAIMockups() async {
    final boundary =
        _sketchKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    setState(() {
      _isGeneratingMockups = true;
    });

    try {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not export sketch');
      final sketchBytes = byteData.buffer.asUint8List();
      final variants = widget.isArabic
          ? ['واقعي في استوديو', 'ملون ومزهر', 'فاخر مناسب للمتجر']
          : [
              'realistic studio product photo',
              'colorful with detailed flowers',
              'premium artisan marketplace product photo'
            ];
      final generated = <Map<String, dynamic>>[];
      for (final variant in variants) {
        final bytes = await CustomerService.generateSketchMockup(
          sketchBytes,
          prompt:
              'Create the actual product shown in this drawing. $variant. If the drawing shows a mug with flowers, generate a real mug decorated with those flowers, not a generic craft image.',
        );
        if (bytes != null) {
          generated.add({
            'title': variant,
            'desc': t('صورة مولدة من الرسم', 'Generated from your drawing'),
            'imageBytes': bytes,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _isGeneratingMockups = false;
        _aiMockups = generated;
        _selectedMockupIndex = generated.isEmpty ? null : 0;
      });
    } catch (error) {
      debugPrint('Sketch mockup generation failed: $error');
      if (!mounted) return;
      setState(() => _isGeneratingMockups = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(
            'تعذر توليد الصور. تحقق من اتصال الخادم ومفتاح الذكاء الاصطناعي.',
            'Could not generate images. Check the backend and AI key.',
          )),
        ),
      );
    }
  }

  bool _hasSketchInput() =>
      _strokes.isNotEmpty ||
      _shapes.isNotEmpty ||
      _texts.isNotEmpty ||
      _stamps.isNotEmpty;

  void _showTextInputDialog(Offset offset) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(t('إضافة نص', 'Add Text'),
            style: TextStyle(color: primaryTextColor)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: primaryTextColor),
          decoration: InputDecoration(
            hintText: t('اكتب شيئاً...', 'Type something...'),
            hintStyle: TextStyle(color: secondaryTextColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('إلغاء', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _saveStateForUndo();
                  _texts.add({
                    'text': controller.text,
                    'offset': offset,
                    'color': _selectedColor,
                  });
                });
              }
              Navigator.pop(context);
            },
            child: Text(t('إضافة', 'Add'),
                style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? accent : cardBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.black : primaryTextColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : primaryTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon, color: color ?? primaryTextColor, size: 20),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  void _eraseNear(Offset point) {
    for (int i = _strokes.length - 1; i >= 0; i--) {
      final stroke = _strokes[i];
      for (final p in stroke) {
        if ((p - point).distance < 20) {
          setState(() {
            _saveStateForUndo();
            _strokes.removeAt(i);
            _strokeColors.removeAt(i);
            _strokeWidths.removeAt(i);
          });
          return;
        }
      }
    }
  }

  void _undoLastStroke() {
    if (_undoStrokesStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('لا يوجد إجراء للتراجع', 'Nothing to undo')),
          backgroundColor: accent,
        ),
      );
      return;
    }

    setState(() {
      _redoStrokesStack.add(_strokes.map((s) => List<Offset>.from(s)).toList());
      _redoColorsStack.add(List<Color>.from(_strokeColors));
      _redoWidthsStack.add(List<double>.from(_strokeWidths));
      _redoShapesStack
          .add(_shapes.map((s) => Map<String, dynamic>.from(s)).toList());
      _redoTextsStack
          .add(_texts.map((t) => Map<String, dynamic>.from(t)).toList());
      _redoStampsStack
          .add(_stamps.map((s) => Map<String, dynamic>.from(s)).toList());

      _strokes.clear();
      _strokes.addAll(_undoStrokesStack.last.map((s) => List<Offset>.from(s)));
      _strokeColors.clear();
      _strokeColors.addAll(_undoColorsStack.last);
      _strokeWidths.clear();
      _strokeWidths.addAll(_undoWidthsStack.last);
      _shapes.clear();
      _shapes.addAll(
          _undoShapesStack.last.map((s) => Map<String, dynamic>.from(s)));
      _texts.clear();
      _texts.addAll(
          _undoTextsStack.last.map((t) => Map<String, dynamic>.from(t)));
      _stamps.clear();
      _stamps.addAll(
          _undoStampsStack.last.map((s) => Map<String, dynamic>.from(s)));

      _undoStrokesStack.removeLast();
      _undoColorsStack.removeLast();
      _undoWidthsStack.removeLast();
      _undoShapesStack.removeLast();
      _undoTextsStack.removeLast();
      _undoStampsStack.removeLast();
    });
  }

  void _redoLastStroke() {
    if (_redoStrokesStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('لا يوجد إجراء للإعادة', 'Nothing to redo')),
          backgroundColor: accent,
        ),
      );
      return;
    }

    setState(() {
      _undoStrokesStack.add(_strokes.map((s) => List<Offset>.from(s)).toList());
      _undoColorsStack.add(List<Color>.from(_strokeColors));
      _undoWidthsStack.add(List<double>.from(_strokeWidths));
      _undoShapesStack
          .add(_shapes.map((s) => Map<String, dynamic>.from(s)).toList());
      _undoTextsStack
          .add(_texts.map((t) => Map<String, dynamic>.from(t)).toList());
      _undoStampsStack
          .add(_stamps.map((s) => Map<String, dynamic>.from(s)).toList());

      _strokes.clear();
      _strokes.addAll(_redoStrokesStack.last.map((s) => List<Offset>.from(s)));
      _strokeColors.clear();
      _strokeColors.addAll(_redoColorsStack.last);
      _strokeWidths.clear();
      _strokeWidths.addAll(_redoWidthsStack.last);
      _shapes.clear();
      _shapes.addAll(
          _redoShapesStack.last.map((s) => Map<String, dynamic>.from(s)));
      _texts.clear();
      _texts.addAll(
          _redoTextsStack.last.map((t) => Map<String, dynamic>.from(t)));
      _stamps.clear();
      _stamps.addAll(
          _redoStampsStack.last.map((s) => Map<String, dynamic>.from(s)));

      _redoStrokesStack.removeLast();
      _redoColorsStack.removeLast();
      _redoWidthsStack.removeLast();
      _redoShapesStack.removeLast();
      _redoTextsStack.removeLast();
      _redoStampsStack.removeLast();
    });
  }

  void _clearCanvas() {
    if (_strokes.isEmpty &&
        _shapes.isEmpty &&
        _texts.isEmpty &&
        _stamps.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        title: Text(
          t('مسح الرسمة؟', 'Clear drawing?'),
          style: TextStyle(color: primaryTextColor),
        ),
        content: Text(
          t('هل أنت متأكد من رغبتك في مسح الرسمة؟',
              'Are you sure you want to clear the drawing?'),
          style: TextStyle(color: secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t('إلغاء', 'Cancel'),
              style: TextStyle(color: primaryTextColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _saveStateForUndo();
                _strokes.clear();
                _strokeColors.clear();
                _strokeWidths.clear();
                _shapes.clear();
                _texts.clear();
                _stamps.clear();
                _points.clear();
              });
            },
            child: Text(
              t('مسح', 'Clear'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3D input ──────────────────────────────────────────────────────────────
  Widget _build3DInput() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_in_ar, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                t('معاينة وتعديل ثلاثي الأبعاد تفاعلي',
                    'Interactive 3D Preview'),
                style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t('اسحب بإصبعك لتدوير المجسم ومعاينته من كافة الاتجاهات',
                'Drag your finger to rotate the 3D model'),
            style: TextStyle(color: secondaryTextColor, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            width: double.infinity,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color:
                    widget.isDarkMode ? const Color(0xFF141F32) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _rotationY += details.delta.dx * 0.01;
                    _rotationX -= details.delta.dy * 0.01;
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _Model3DPainter(
                      shape: _selected3DShape,
                      material: _selected3DMaterial,
                      rotationX: _rotationX,
                      rotationY: _rotationY,
                      scale: _shapeScale,
                      customColor: _custom3DColor,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('اختر الشكل الهندسي:', 'Choose Geometry Shape:'),
            style: TextStyle(
                color: primaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _build3DShapeButton('cube', t('مكعب', 'Cube'), Icons.crop_square),
              _build3DShapeButton(
                  'sphere', t('كرة', 'Sphere'), Icons.lens_outlined),
              _build3DShapeButton('cylinder', t('أسطوانة', 'Cylinder'),
                  Icons.crop_din_outlined),
              _build3DShapeButton('ring', t('خاتم', 'Ring'), Icons.trip_origin),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t('اختر اللون:', 'Choose Color:'),
            style: TextStyle(
                color: primaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildColorDot(const Color(0xFFD4A017), 'gold'),
                _buildColorDot(const Color(0xFFB76E79), 'rosegold'),
                _buildColorDot(const Color(0xFFC0C0C0), 'silver'),
                _buildColorDot(const Color(0xFFCD7F32), 'bronze'),
                _buildColorDot(const Color(0xFFCD5C5C), 'clay'),
                _buildColorDot(const Color(0xFF8B4513), 'wood'),
                _buildColorDot(const Color(0xFF708090), 'default'),
                _buildColorDot(const Color(0xFF1565C0), 'blue'),
                _buildColorDot(const Color(0xFF2E7D32), 'green'),
                _buildColorDot(const Color(0xFF6A1B9A), 'purple'),
                _buildColorDot(const Color(0xFFD32F2F), 'red'),
                _buildColorDot(const Color(0xFF37474F), 'dark'),
                _buildColorDot(const Color(0xFFFFFFFF), 'white'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF141F32) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorderColor),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: ColorPickerArea(
                    HSVColor.fromColor(_custom3DColor),
                    (hsv) {
                      setState(() {
                        _custom3DColor = hsv.toColor();
                        _selected3DMaterial = 'custom';
                      });
                    },
                    PaletteType.hsv,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 28,
                  child: ColorPickerSlider(
                    TrackType.hue,
                    HSVColor.fromColor(_custom3DColor),
                    (hsv) {
                      setState(() {
                        _custom3DColor = hsv.toColor();
                        _selected3DMaterial = 'custom';
                      });
                    },
                    displayThumbColor: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _custom3DColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBorderColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _custom3DColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '#${_custom3DColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _selected3DMaterial = 'custom');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selected3DMaterial == 'custom'
                              ? accent
                              : accent.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t('تطبيق', 'Apply'),
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFFF7B500), Color(0xFFD89A00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: _submitRequest,
              icon: const Icon(Icons.view_in_ar, color: Colors.black),
              label: Text(
                t('البحث عن منتجات مشابهة بالشكل والخامة',
                    'Search Products by Shape & Material'),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildColorDot(Color color, String id) {
    final isSelected = _selected3DMaterial == id ||
        (_selected3DMaterial == 'custom' && _custom3DColor == color);
    return GestureDetector(
      onTap: () {
        setState(() {
          _custom3DColor = color;
          _selected3DMaterial = 'custom';
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: isSelected ? 8 : 4,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }

  Widget _build3DShapeButton(String shape, String label, IconData icon) {
    final isSelected = _selected3DShape == shape;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selected3DShape = shape),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? accent
                : (widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? accent : cardBorderColor),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? Colors.black : primaryTextColor,
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : primaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Submit ──────────────────────────────────────────────────────────────
  void _submitRequest() async {
    bool hasText = _textController.text.trim().isNotEmpty;
    bool hasPhoto = _selectedImage != null;
    bool hasSketch = _strokes.isNotEmpty;
    int currentTab = _tabController.index;

    bool isValid = true;
    if (currentTab == 0 && !hasText) isValid = false;
    if (currentTab == 1 && !hasPhoto) isValid = false;
    if (currentTab == 2 && !hasSketch) isValid = false;

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('يرجى إدخال وصف، أو رفع صورة، أو رسم فكرتك',
                'Please enter a description, upload a photo, or draw your idea'),
          ),
          backgroundColor: accent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: accent)),
    );

    try {
      Map<String, dynamic>? result;

      if (currentTab == 1 && hasPhoto) {
        try {
          result = await CustomerService.visualSearchBytes(
            await _selectedImage!.readAsBytes(),
            filename: _selectedImage!.name,
          );
        } catch (_) {}
        result ??= await _analyzeWithText(
          overrideText:
              '${_visionDescController.text.trim()} ${_extractedVisionTags.join(' ')}'
                  .trim(),
        );
      } else if (currentTab == 2 && hasSketch) {
        try {
          final boundary = _sketchKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
          if (boundary != null) {
            final image = await boundary.toImage(pixelRatio: 2.0);
            final byteData =
                await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              result = await CustomerService.visualSearchBytes(
                byteData.buffer.asUint8List(),
                filename: 'sketch.png',
              );
            }
          }
        } catch (_) {}
        if (result == null) {
          debugPrint('Sketch visual search returned no response');
        }
        String sketchText = 'Handmade sketch order';
        if (_selectedMockupIndex != null &&
            _selectedMockupIndex! < _aiMockups.length) {
          sketchText =
              '${_aiMockups[_selectedMockupIndex!]['title']} ${_aiMockups[_selectedMockupIndex!]['desc']}';
        }
        result ??=
            await _analyzeWithText(hasSketch: true, overrideText: sketchText);
      } else if (currentTab == 3) {
        final shapeDesc = '$_selected3DShape made of $_selected3DMaterial';
        result = await _analyzeWithText(overrideText: shapeDesc);
      } else {
        result = await _analyzeWithText();
      }

      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        _isLoading = false;
        _resultProducts = result?['products'] as List? ?? [];
        _resultArtisans = result?['artisans'] as List? ?? [];
        _resultCategory = result?['category'] as String?;
        _resultCategoryAr = result?['categoryAr'] as String?;
        _resultPriceRange = result?['priceRange'] as String?;
        _resultDescription = (result?['description'] ??
            result?['debug']?['description']) as String?;
        _resultKeywords =
            (((result?['keywords'] ?? result?['debug']?['keywords']) as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[]);
      });
      _showResults();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(t('حدث خطأ، حاول مجدداً',
                'An error occurred, please try again'))),
      );
    }
  }

  Future<Map<String, dynamic>?> _analyzeWithText(
      {bool hasSketch = false, String? overrideText}) async {
    final response = await ApiService.post('/ai/analyze-order', body: {
      'text': overrideText ?? _textController.text.trim(),
      'hasImage': _selectedImage != null,
      'hasDrawing': hasSketch,
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    }
    return null;
  }

  void _showResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: cardBorderColor),
          ),
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
                t('نتائج البحث الذكي', 'AI Search Results'),
                style: GoogleFonts.arefRuqaa(
                  color: primaryTextColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_resultCategoryAr != null || _resultCategory != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.isArabic
                        ? (_resultCategoryAr ?? '')
                        : (_resultCategory ?? ''),
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
              if (_resultPriceRange != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${t('النطاق السعري', 'Price Range')}: $_resultPriceRange',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
              if ((_resultDescription ?? '').isNotEmpty ||
                  _resultKeywords.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('AI Debug: ما رأه الذكاء الاصطناعي',
                            'AI Debug: what the AI saw'),
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if ((_resultDescription ?? '').isNotEmpty)
                        Text(
                          _resultDescription!,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      if (_resultKeywords.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _resultKeywords.map((kw) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Text(
                                kw,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: _resultProducts.isEmpty && _resultArtisans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                color: secondaryTextColor, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              t('لم يتم العثور على نتائج مطابقة',
                                  'No matching results found'),
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        children: [
                          if (_resultProducts.isNotEmpty) ...[
                            Text(
                              t('منتجات مشابهة', 'Similar Products'),
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._resultProducts.map((product) {
                              final nameAr =
                                  product['titleAr'] ?? product['nameAr'] ?? '';
                              final nameEn = product['titleEn'] ??
                                  product['nameEn'] ??
                                  nameAr;
                              final price = product['price']?.toString() ?? '?';
                              final imageUrl = product['imageUrl'] as String?;
                              return _ResultProductCard(
                                nameAr: nameAr,
                                nameEn: nameEn,
                                price: '$price JOD',
                                rating: (product['averageRating'] ??
                                        product['rating'] ??
                                        0)
                                    .toString(),
                                imageUrl: imageUrl,
                                isArabic: widget.isArabic,
                                isDarkMode: widget.isDarkMode,
                                rawProduct: product is Map<String, dynamic>
                                    ? product
                                    : Map<String, dynamic>.from(product as Map),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                          if (_resultArtisans.isNotEmpty) ...[
                            Text(
                              t('حرفيون موصى بهم', 'Recommended Artisans'),
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._resultArtisans.map((artisan) {
                              final profile =
                                  artisan['ArtisanProfile'] ?? artisan;
                              final nameAr =
                                  artisan['nameAr'] ?? artisan['name'] ?? '';
                              final nameEn = artisan['nameEn'] ??
                                  artisan['name'] ??
                                  nameAr;
                              final craftAr = profile['craftAr'] ?? '';
                              final craftEn = profile['craftEn'] ?? craftAr;
                              final rating = profile['averageRating'] ??
                                  artisan['rating'] ??
                                  0;
                              final imageUrl =
                                  profile['profileImage'] as String?;
                              return _ResultArtisanCard(
                                nameAr: nameAr,
                                nameEn: nameEn,
                                craftAr: craftAr,
                                craftEn: craftEn,
                                rating: rating.toString(),
                                imageUrl: imageUrl,
                                isArabic: widget.isArabic,
                                isDarkMode: widget.isDarkMode,
                                rawArtisan: artisan is Map<String, dynamic>
                                    ? artisan
                                    : Map<String, dynamic>.from(artisan as Map),
                              );
                            }),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          t('طلب ذكي بالذكاء الاصطناعي', 'AI Smart Order'),
          style: GoogleFonts.arefRuqaa(
            color: primaryTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cardBorderColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: accent,
                unselectedLabelColor: secondaryTextColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: t('نص', 'Text')),
                  Tab(text: t('صورة', 'Photo')),
                  Tab(text: t('رسم', 'Draw')),
                  Tab(text: t('أدوات 3D', '3D')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildTextInput(),
                  _buildPhotoInput(),
                  _buildSketchInput(),
                  _build3DInput(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Result Product Card ──────────────────────────────────────────────────────
class _ResultProductCard extends StatelessWidget {
  final String nameAr, nameEn, price, rating;
  final String? imageUrl;
  final bool isArabic;
  final bool isDarkMode;
  final Map<String, dynamic>? rawProduct;

  const _ResultProductCard({
    required this.nameAr,
    required this.nameEn,
    required this.price,
    required this.rating,
    this.imageUrl,
    required this.isArabic,
    required this.isDarkMode,
    this.rawProduct,
  });

  Color get primaryText => isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryText => isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accent => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (rawProduct != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailsPage(
                product: rawProduct!,
                isArabic: isArabic,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl == null
                  ? Icon(Icons.checkroom_outlined, color: accent)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? nameAr : nameEn,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          Text(
                            rating,
                            style: TextStyle(color: primaryText, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: secondaryText),
          ],
        ),
      ),
    );
  }
}

// ── Result Artisan Card ─────────────────────────────────────────────────────
class _ResultArtisanCard extends StatelessWidget {
  final String nameAr, nameEn, craftAr, craftEn, rating;
  final String? imageUrl;
  final bool isArabic;
  final bool isDarkMode;
  final Map<String, dynamic>? rawArtisan;

  const _ResultArtisanCard({
    required this.nameAr,
    required this.nameEn,
    required this.craftAr,
    required this.craftEn,
    required this.rating,
    this.imageUrl,
    required this.isArabic,
    required this.isDarkMode,
    this.rawArtisan,
  });

  Color get primaryText => isDarkMode ? Colors.white : Colors.black87;
  Color get secondaryText => isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => isDarkMode
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.08);
  Color get surface => isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accent => const Color(0xFFD4A017);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (rawArtisan != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArtisanProfilePage(
                artisan: rawArtisan!,
                isArabic: isArabic,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withValues(alpha: 0.2),
              child: Text(
                (isArabic ? nameAr : nameEn)[0],
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? nameAr : nameEn,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isArabic ? craftAr : craftEn,
                    style: TextStyle(color: secondaryText, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      rating,
                      style: TextStyle(
                          color: primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    if (rawArtisan != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtisanProfilePage(
                            artisan: rawArtisan!,
                            isArabic: isArabic,
                            isDarkMode: isDarkMode,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isArabic ? 'طلب خاص' : 'Order',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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

// ── Sketch Painter ──────────────────────────────────────────────────────────
class _SketchPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Color> strokeColors;
  final List<double> strokeWidths;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;
  final Color canvasColor;

  final List<Map<String, dynamic>> shapes;
  final List<Map<String, dynamic>> texts;
  final List<Map<String, dynamic>> stamps;
  final Offset? currentShapeStart;
  final Offset? currentShapeEnd;
  final String selectedDrawingTool;
  final bool symmetryEnabled;
  final bool gridEnabled;

  const _SketchPainter({
    required this.strokes,
    required this.strokeColors,
    required this.strokeWidths,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    this.isEraser = false,
    required this.canvasColor,
    required this.shapes,
    required this.texts,
    required this.stamps,
    this.currentShapeStart,
    this.currentShapeEnd,
    required this.selectedDrawingTool,
    required this.symmetryEnabled,
    required this.gridEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = canvasColor,
    );

    // Grid
    if (gridEnabled) {
      final gridPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.05)
        ..strokeWidth = 1.0;
      const double stepSize = 30.0;
      for (double x = 0; x < size.width; x += stepSize) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += stepSize) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    Offset mirrorPoint(Offset pt) => Offset(size.width - pt.dx, pt.dy);

    // Strokes
    for (int i = 0; i < strokes.length; i++) {
      final points = strokes[i];
      final color = strokeColors[i];
      final width = strokeWidths[i];
      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int j = 0; j < points.length - 1; j++) {
        canvas.drawLine(points[j], points[j + 1], paint);
        if (symmetryEnabled) {
          canvas.drawLine(
              mirrorPoint(points[j]), mirrorPoint(points[j + 1]), paint);
        }
      }
    }

    // Current stroke
    if (currentPoints.length > 1) {
      final paint = Paint()
        ..color = isEraser ? canvasColor : currentColor
        ..strokeWidth = currentWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int i = 0; i < currentPoints.length - 1; i++) {
        canvas.drawLine(currentPoints[i], currentPoints[i + 1], paint);
        if (symmetryEnabled && !isEraser) {
          canvas.drawLine(mirrorPoint(currentPoints[i]),
              mirrorPoint(currentPoints[i + 1]), paint);
        }
      }
    }

    // Shapes
    for (final shape in shapes) {
      final type = shape['type'] as String;
      final start = shape['start'] as Offset;
      final end = shape['end'] as Offset;
      final color = shape['color'] as Color;
      final width = shape['width'] as double;

      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke;

      void drawSingleShape(Offset st, Offset ed) {
        if (type == 'rectangle') {
          canvas.drawRect(
            Rect.fromPoints(st, ed),
            paint,
          );
        } else if (type == 'circle') {
          final center = Offset((st.dx + ed.dx) / 2, (st.dy + ed.dy) / 2);
          final radius = (st - ed).distance / 2;
          canvas.drawCircle(center, radius, paint);
        } else if (type == 'line') {
          canvas.drawLine(st, ed, paint);
        }
      }

      drawSingleShape(start, end);
      if (symmetryEnabled) {
        drawSingleShape(mirrorPoint(start), mirrorPoint(end));
      }
    }

    // Stamps
    for (final stamp in stamps) {
      final type = stamp['type'] as String;
      final offset = stamp['offset'] as Offset;
      final color = stamp['color'] as Color;
      final size = stamp['size'] as double;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      void drawStamp(Offset pt) {
        if (type == 'star') {
          final path = Path();
          const int points = 5;
          final outerRadius = size / 2;
          final innerRadius = outerRadius * 0.4;
          for (int i = 0; i < points * 2; i++) {
            final angle = i * math.pi / points - math.pi / 2;
            final radius = i % 2 == 0 ? outerRadius : innerRadius;
            final x = pt.dx + radius * math.cos(angle);
            final y = pt.dy + radius * math.sin(angle);
            if (i == 0)
              path.moveTo(x, y);
            else
              path.lineTo(x, y);
          }
          path.close();
          canvas.drawPath(path, paint);
        } else if (type == 'heart') {
          final path = Path();
          final s = size / 2;
          path.moveTo(pt.dx, pt.dy + s * 0.3);
          path.cubicTo(
            pt.dx - s * 0.5,
            pt.dy - s * 0.4,
            pt.dx - s * 1.0,
            pt.dy + s * 0.2,
            pt.dx,
            pt.dy + s * 1.0,
          );
          path.cubicTo(
            pt.dx + s * 1.0,
            pt.dy + s * 0.2,
            pt.dx + s * 0.5,
            pt.dy - s * 0.4,
            pt.dx,
            pt.dy + s * 0.3,
          );
          path.close();
          canvas.drawPath(path, paint);
        } else if (type == 'flower') {
          final petalCount = 6;
          final petalRadius = size / 3;
          for (int i = 0; i < petalCount; i++) {
            final angle = i * 2 * math.pi / petalCount;
            final center = Offset(
              pt.dx + petalRadius * math.cos(angle),
              pt.dy + petalRadius * math.sin(angle),
            );
            canvas.drawCircle(center, petalRadius * 0.6, paint);
          }
          canvas.drawCircle(pt, petalRadius * 0.5, paint);
        }
      }

      drawStamp(offset);
      if (symmetryEnabled) {
        drawStamp(mirrorPoint(offset));
      }
    }

    // Texts
    for (final text in texts) {
      final textStr = text['text'] as String;
      final offset = text['offset'] as Offset;
      final color = text['color'] as Color;
      final style =
          TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold);
      final span = TextSpan(text: textStr, style: style);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, offset);
    }

    // Current shape preview
    if (currentShapeStart != null && currentShapeEnd != null) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentWidth
        ..style = PaintingStyle.stroke;
      final st = currentShapeStart!;
      final ed = currentShapeEnd!;
      if (selectedDrawingTool == 'rectangle') {
        canvas.drawRect(Rect.fromPoints(st, ed), paint);
      } else if (selectedDrawingTool == 'circle') {
        final center = Offset((st.dx + ed.dx) / 2, (st.dy + ed.dy) / 2);
        final radius = (st - ed).distance / 2;
        canvas.drawCircle(center, radius, paint);
      } else if (selectedDrawingTool == 'line') {
        canvas.drawLine(st, ed, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter old) {
    return true;
  }
}

// ── 3D Model Painter ──────────────────────────────────────────────────────
class _Model3DPainter extends CustomPainter {
  final String shape;
  final String material;
  final double rotationX;
  final double rotationY;
  final double scale;
  final Color customColor;

  const _Model3DPainter({
    required this.shape,
    required this.material,
    required this.rotationX,
    required this.rotationY,
    required this.scale,
    this.customColor = const Color(0xFFD4A017),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(centerX, centerY) * 0.8 * scale;

    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Color baseColorDark;
    Color baseColorLight;

    if (material == 'gold') {
      baseColorDark = const Color(0xFF7A5807);
      baseColorLight = const Color(0xFFFFE040);
    } else if (material == 'rosegold') {
      baseColorDark = const Color(0xFF75404B);
      baseColorLight = const Color(0xFFFFB2C1);
    } else if (material == 'silver') {
      baseColorDark = const Color(0xFF5F6E7D);
      baseColorLight = const Color(0xFFF0F4F8);
    } else if (material == 'clay') {
      baseColorDark = const Color(0xFF732E20);
      baseColorLight = const Color(0xFFFFA07A);
    } else if (material == 'wood') {
      baseColorDark = const Color(0xFF422108);
      baseColorLight = const Color(0xFFCD853F);
    } else if (material == 'bronze') {
      baseColorDark = const Color(0xFF523315);
      baseColorLight = const Color(0xFFF5B061);
    } else if (material == 'default') {
      baseColorDark = const Color(0xFF3A3A3A);
      baseColorLight = const Color(0xFFB0BEC5);
    } else if (material == 'custom') {
      final hsl = HSLColor.fromColor(customColor);
      baseColorDark =
          hsl.withLightness((hsl.lightness * 0.4).clamp(0.0, 1.0)).toColor();
      baseColorLight =
          hsl.withLightness((hsl.lightness * 1.4).clamp(0.0, 1.0)).toColor();
    } else {
      baseColorDark = const Color(0xFF523315);
      baseColorLight = const Color(0xFFF5B061);
    }

    Map<String, dynamic> projectWithDepth(double x, double y, double z) {
      double x1 = x * math.cos(rotationY) - z * math.sin(rotationY);
      double z1 = x * math.sin(rotationY) + z * math.cos(rotationY);
      double y2 = y * math.cos(rotationX) - z1 * math.sin(rotationX);
      double z2 = y * math.sin(rotationX) + z1 * math.cos(rotationX);

      double distance = 4.0;
      double fov = 350.0;
      double screenX = centerX + x1 * fov / (distance + z2);
      double screenY = centerY + y2 * fov / (distance + z2);
      return {
        'offset': Offset(screenX, screenY),
        'depth': z2,
      };
    }

    void drawDepthLine(Map<String, dynamic> ptA, Map<String, dynamic> ptB) {
      double avgDepth = (ptA['depth'] + ptB['depth']) / 2;
      double t = (avgDepth + 1.2) / 2.4;
      t = t.clamp(0.0, 1.0);
      paint.color = Color.lerp(baseColorLight, baseColorDark, t)!;
      canvas.drawLine(ptA['offset'], ptB['offset'], paint);
    }

    if (shape == 'cube') {
      final List<List<double>> vertices = [
        [-1, -1, -1],
        [1, -1, -1],
        [1, 1, -1],
        [-1, 1, -1],
        [-1, -1, 1],
        [1, -1, 1],
        [1, 1, 1],
        [-1, 1, 1]
      ];
      final scaled = vertices
          .map((v) => [
                v[0] * radius * 0.007,
                v[1] * radius * 0.007,
                v[2] * radius * 0.007
              ])
          .toList();
      final points =
          scaled.map((v) => projectWithDepth(v[0], v[1], v[2])).toList();

      final List<List<int>> edges = [
        [0, 1],
        [1, 2],
        [2, 3],
        [3, 0],
        [4, 5],
        [5, 6],
        [6, 7],
        [7, 4],
        [0, 4],
        [1, 5],
        [2, 6],
        [3, 7]
      ];

      for (final edge in edges) {
        drawDepthLine(points[edge[0]], points[edge[1]]);
      }
    } else if (shape == 'sphere') {
      const int latSegments = 8;
      const int lonSegments = 12;

      for (int i = 0; i <= latSegments; i++) {
        final double lat = (i * math.pi / latSegments) - math.pi / 2;
        final double r = radius * 0.007 * math.cos(lat);
        final double y = radius * 0.007 * math.sin(lat);

        List<Map<String, dynamic>> circlePoints = [];
        for (int j = 0; j <= lonSegments; j++) {
          final double lon = j * 2 * math.pi / lonSegments;
          final double x = r * math.cos(lon);
          final double z = r * math.sin(lon);
          circlePoints.add(projectWithDepth(x, y, z));
        }
        for (int j = 0; j < circlePoints.length - 1; j++) {
          drawDepthLine(circlePoints[j], circlePoints[j + 1]);
        }
      }

      for (int j = 0; j < lonSegments; j++) {
        final double lon = j * 2 * math.pi / lonSegments;
        List<Map<String, dynamic>> meridianPoints = [];
        for (int i = 0; i <= latSegments; i++) {
          final double lat = (i * math.pi / latSegments) - math.pi / 2;
          final double x = radius * 0.007 * math.cos(lat) * math.cos(lon);
          final double y = radius * 0.007 * math.sin(lat);
          final double z = radius * 0.007 * math.cos(lat) * math.sin(lon);
          meridianPoints.add(projectWithDepth(x, y, z));
        }
        for (int i = 0; i < meridianPoints.length - 1; i++) {
          drawDepthLine(meridianPoints[i], meridianPoints[i + 1]);
        }
      }
    } else if (shape == 'cylinder') {
      const int segments = 16;
      final double halfHeight = radius * 0.007;
      final double r = radius * 0.006;

      List<Map<String, dynamic>> topPoints = [];
      List<Map<String, dynamic>> bottomPoints = [];

      for (int i = 0; i <= segments; i++) {
        final double angle = i * 2 * math.pi / segments;
        final double x = r * math.cos(angle);
        final double z = r * math.sin(angle);
        topPoints.add(projectWithDepth(x, -halfHeight, z));
        bottomPoints.add(projectWithDepth(x, halfHeight, z));
      }

      for (int i = 0; i < segments; i++) {
        drawDepthLine(topPoints[i], topPoints[i + 1]);
        drawDepthLine(bottomPoints[i], bottomPoints[i + 1]);
        if (i % 4 == 0) {
          drawDepthLine(topPoints[i], bottomPoints[i]);
        }
      }
    } else if (shape == 'ring') {
      const int ringSegments = 16;
      const int tubeSegments = 8;
      final double rTube = radius * 0.002;
      final double rRing = radius * 0.006;

      for (int i = 0; i < ringSegments; i++) {
        final double theta = i * 2 * math.pi / ringSegments;
        final double cosTheta = math.cos(theta);
        final double sinTheta = math.sin(theta);

        List<Map<String, dynamic>> tubePoints = [];
        for (int j = 0; j <= tubeSegments; j++) {
          final double phi = j * 2 * math.pi / tubeSegments;
          final double x = (rRing + rTube * math.cos(phi)) * cosTheta;
          final double y = rTube * math.sin(phi);
          final double z = (rRing + rTube * math.cos(phi)) * sinTheta;
          tubePoints.add(projectWithDepth(x, y, z));
        }
        for (int j = 0; j < tubePoints.length - 1; j++) {
          drawDepthLine(tubePoints[j], tubePoints[j + 1]);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Model3DPainter old) {
    return true;
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/customer_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GiftQuizScreen – redesigned with saved lists
// ─────────────────────────────────────────────────────────────────────────────

class GiftQuizScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const GiftQuizScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<GiftQuizScreen> createState() => _GiftQuizScreenState();
}

class _GiftQuizScreenState extends State<GiftQuizScreen> {
  // ── Theme helpers ──────────────────────────────────────────────────
  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);
  Color get border => widget.isDarkMode ? Colors.white12 : Colors.black12;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  // ── Translation maps for ALL option labels ──────────────────────────
  // These maps convert English keys to Arabic translations
  Map<String, String> get _recipientTranslations => {
    'Mother': 'أم',
    'Father': 'أب',
    'Wife/Husband': 'زوج أو زوجة',
    'Friend': 'صديق',
    'Child': 'طفل',
    'Colleague': 'زميل عمل',
  };

  Map<String, String> get _occasionTranslations => {
    'Birthday': 'عيد ميلاد',
    'Anniversary': 'ذكرى سنوية',
    'Graduation': 'تخرج',
    'Wedding': 'عرس',
    'Housewarming': 'بيت جديد',
    'No specific': 'بدون مناسبة محددة',
  };

  Map<String, String> get _budgetTranslations => {
    'Under 20 JD': 'أقل من 20 دينار',
    '20-50 JD': '20 - 50 دينار',
    '50-100 JD': '50 - 100 دينار',
    '100-200 JD': '100 - 200 دينار',
    '200+ JD': 'أكثر من 200 دينار',
    'Any': 'أي ميزانية',
  };

  Map<String, String> get _styleTranslations => {
    'Traditional': 'تقليدي',
    'Modern/Contemporary': 'حديث أو معاصر',
    'Minimalist': 'بسيط',
    'Colorful/Vibrant': 'ملون أو زاهي',
    'Earthy/Natural': 'طبيعي أو ترابي',
    'Luxurious/High-end': 'فاخر أو راق',
  };

  // Helper: translate an option using the provided map
  String translateOption(String option, Map<String, String> map) {
    if (widget.isArabic) {
      return map[option] ?? option; // fallback to English if not found
    }
    return option;
  }

  // ── Saved gift lists ──────────────────────────────────────────────
  final List<Map<String, dynamic>> _savedLists = [];

  @override
  void initState() {
    super.initState();
  }

  void _startNewQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GiftQuizFlowScreen(
          isArabic: widget.isArabic,
          isDarkMode: widget.isDarkMode,
          onSave: (listData) {
            setState(() {
              _savedLists.insert(0, listData);
            });
          },
        ),
      ),
    );
  }

  void _viewList(Map<String, dynamic> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${t('قائمة هدايا', 'Gift List for')} ${list['recipientName']}',
                  style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: dim),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t('${list['items'].length} عنصر', '${list['items'].length} items'),
              style: TextStyle(color: dim, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: list['items'].length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final item = list['items'][i];
                  final isProduct = item['type'] == 'product';
                  return ListTile(
                    leading: Icon(item['image'] ?? Icons.star, color: accent),
                    title: Text(
                      widget.isArabic ? item['nameAr'] : item['nameEn'],
                      style: TextStyle(color: text, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      isProduct
                          ? '${item['price']} JOD'
                          : (widget.isArabic ? item['craftAr'] : item['craftEn']),
                      style: TextStyle(color: dim, fontSize: 12),
                    ),
                    trailing: Icon(
                      isProduct ? Icons.shopping_bag_outlined : Icons.chat_bubble_outline,
                      color: accent,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isProduct
                                ? t('فتح تفاصيل المنتج', 'Opening product details')
                                : t('فتح ملف الحرفي', 'Opening artisan profile'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _renameList(ctx, list);
                    },
                    icon: Icon(Icons.edit_outlined, size: 16, color: accent),
                    label: Text(t('تغيير الاسم', 'Rename'), style: TextStyle(color: accent)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _savedLists.remove(list));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('تم حذف القائمة', 'List deleted'))),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.black, size: 16),
                    label: Text(t('حذف', 'Delete'), style: TextStyle(color: Colors.black)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _renameList(BuildContext context, Map<String, dynamic> list) {
    final controller = TextEditingController(text: list['recipientName']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        title: Text(t('تغيير اسم المستلم', 'Change recipient name'), style: TextStyle(color: text)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: text),
          decoration: InputDecoration(
            hintText: t('اسم المستلم', 'Recipient name'),
            hintStyle: TextStyle(color: dim),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim))),
          TextButton(
            onPressed: () {
              setState(() {
                list['recipientName'] = controller.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('تم التحديث', 'Updated'))),
              );
            },
            child: Text(t('حفظ', 'Save'), style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }

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
            icon: Icon(widget.isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('مساعد الهدايا', 'Gift Assistant'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('قوائم الهدايا المحفوظة', 'My Gift Lists'),
                style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_savedLists.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Center(
                    child: Text(
                      t('لا توجد قوائم محفوظة. ابدأ بإنشاء قائمة جديدة!', 'No saved lists. Start a new one!'),
                      style: TextStyle(color: dim),
                    ),
                  ),
                )
              else
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    itemCount: _savedLists.length,
                    itemBuilder: (ctx, index) {
                      final list = _savedLists[index];
                      return GestureDetector(
                        onTap: () => _viewList(list),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.card_giftcard, color: accent, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      list['recipientName'],
                                      style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          '${list['items'].length} ${t('عنصر', 'items')}',
                                          style: TextStyle(color: dim, fontSize: 12),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _formatDate(list['createdAt']),
                                          style: TextStyle(color: dim, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: dim),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _startNewQuiz,
                  icon: const Icon(Icons.add, color: Colors.black),
                  label: Text(
                    t('إنشاء قائمة جديدة', 'Create New Gift List'),
                    style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return t('اليوم', 'Today');
    if (diff.inDays == 1) return t('أمس', 'Yesterday');
    if (diff.inDays < 7) return '${diff.inDays} ${t('أيام', 'days ago')}';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gift Quiz Flow – separate screen
// ─────────────────────────────────────────────────────────────────────────────

class _GiftQuizFlowScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final Function(Map<String, dynamic>) onSave;

  const _GiftQuizFlowScreen({
    required this.isArabic,
    required this.isDarkMode,
    required this.onSave,
  });

  @override
  State<_GiftQuizFlowScreen> createState() => _GiftQuizFlowScreenState();
}

class _GiftQuizFlowScreenState extends State<_GiftQuizFlowScreen> {
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Step 0: Recipient name
  final TextEditingController _nameController = TextEditingController();

  // Step 1: Who is it for?
  String? _selectedRecipient;
  // ENGLISH KEYS - the display will use translations
  final List<String> _recipientKeys = ['Mother', 'Father', 'Wife/Husband', 'Friend', 'Child', 'Colleague'];
  final TextEditingController _customRecipientController = TextEditingController();

  // Step 2: Occasion
  String? _selectedOccasion;
  final List<String> _occasionKeys = ['Birthday', 'Anniversary', 'Graduation', 'Wedding', 'Housewarming', 'No specific'];
  final TextEditingController _customOccasionController = TextEditingController();

  // Step 3: Budget
  String? _selectedBudget;
  final List<String> _budgetKeys = ['Under 20 JD', '20-50 JD', '50-100 JD', '100-200 JD', '200+ JD', 'Any'];
  final TextEditingController _customBudgetController = TextEditingController();

  // Step 4: Style preferences (multi-select)
  final List<String> _styleKeys = ['Traditional', 'Modern/Contemporary', 'Minimalist', 'Colorful/Vibrant', 'Earthy/Natural', 'Luxurious/High-end'];
  final List<String> _selectedStyles = [];
  final TextEditingController _customStyleController = TextEditingController();

  // ── Translation maps ──────────────────────────────────────────────
  Map<String, String> get _recipientTranslations => {
    'Mother': 'أم',
    'Father': 'أب',
    'Wife/Husband': 'زوج أو زوجة',
    'Friend': 'صديق',
    'Child': 'طفل',
    'Colleague': 'زميل عمل',
  };

  Map<String, String> get _occasionTranslations => {
    'Birthday': 'عيد ميلاد',
    'Anniversary': 'ذكرى سنوية',
    'Graduation': 'تخرج',
    'Wedding': 'عرس',
    'Housewarming': 'بيت جديد',
    'No specific': 'بدون مناسبة محددة',
  };

  Map<String, String> get _budgetTranslations => {
    'Under 20 JD': 'أقل من 20 دينار',
    '20-50 JD': '20 - 50 دينار',
    '50-100 JD': '50 - 100 دينار',
    '100-200 JD': '100 - 200 دينار',
    '200+ JD': 'أكثر من 200 دينار',
    'Any': 'أي ميزانية',
  };

  Map<String, String> get _styleTranslations => {
    'Traditional': 'تقليدي',
    'Modern/Contemporary': 'حديث أو معاصر',
    'Minimalist': 'بسيط',
    'Colorful/Vibrant': 'ملون أو زاهي',
    'Earthy/Natural': 'طبيعي أو ترابي',
    'Luxurious/High-end': 'فاخر أو راق',
  };

  // Helper: translate an option using the provided map
  String translateOption(String option, Map<String, String> map) {
    if (widget.isArabic) {
      return map[option] ?? option;
    }
    return option;
  }

  // ── Results data ──────────────────────────────────────────────────
  final List<Map<String, dynamic>> _products = [
    {
      'nameAr': 'سجادة صوفية مطرزة',
      'nameEn': 'Embroidered Wool Rug',
      'price': 52,
      'image': Icons.checkroom_outlined,
      'reasonAr': 'تتناسب مع الذوق التقليدي وتضفي لمسة أنيقة',
      'reasonEn': 'Matches traditional taste and adds an elegant touch',
    },
    {
      'nameAr': 'خاتم فضة مصنوع يدوياً',
      'nameEn': 'Handmade Silver Ring',
      'price': 35,
      'image': Icons.watch_outlined,
      'reasonAr': 'خيار مثالي لمن يحب المجوهرات الأنيقة',
      'reasonEn': 'Perfect for someone who loves elegant jewelry',
    },
    {
      'nameAr': 'إبريق فخاري تقليدي',
      'nameEn': 'Traditional Clay Pitcher',
      'price': 28,
      'image': Icons.local_cafe_outlined,
      'reasonAr': 'يجمع بين الأصالة والفن، هدية فريدة',
      'reasonEn': 'Combines authenticity and art, a unique gift',
    },
    {
      'nameAr': 'صندوق خشبي محفور',
      'nameEn': 'Carved Wooden Box',
      'price': 60,
      'image': Icons.chair_outlined,
      'reasonAr': 'قطعة فنية تصلح لتخزين المجوهرات أو الهدايا',
      'reasonEn': 'Art piece perfect for storing jewelry or gifts',
    },
    {
      'nameAr': 'وشاح صوف منسوج يدوياً',
      'nameEn': 'Hand-Woven Wool Scarf',
      'price': 22,
      'image': Icons.checkroom_outlined,
      'reasonAr': 'هدية دافئة وأنيقة تناسب جميع الأعمار',
      'reasonEn': 'Warm and elegant gift suitable for all ages',
    },
  ];

  final List<Map<String, dynamic>> _artisans = [
    {
      'nameAr': 'أمجد الخطيب',
      'nameEn': 'Amjad Al-Khateeb',
      'craftAr': 'أعمال الخشب والأثاث',
      'craftEn': 'Woodworking',
      'rating': 4.9,
      'image': Icons.chair_outlined,
      'reasonAr': 'خبرة في صناعة القطع الخشبية الفريدة',
      'reasonEn': 'Expert in unique wooden pieces',
    },
    {
      'nameAr': 'فاطمة محمود',
      'nameEn': 'Fatima Mahmoud',
      'craftAr': 'خياطة وتطريز',
      'craftEn': 'Crochet & Knitting',
      'rating': 4.8,
      'image': Icons.checkroom_outlined,
      'reasonAr': 'تصاميم يدوية تناسب جميع الأذواق',
      'reasonEn': 'Handcrafted designs for all tastes',
    },
    {
      'nameAr': 'إياد الكردي',
      'nameEn': 'Iyad Al-Kurdi',
      'craftAr': 'الفخار والخزف',
      'craftEn': 'Pottery & Ceramics',
      'rating': 5.0,
      'image': Icons.local_cafe_outlined,
      'reasonAr': 'أعمال فخارية أصلية وأنيقة',
      'reasonEn': 'Authentic and elegant pottery',
    },
    {
      'nameAr': 'هنا سلامة',
      'nameEn': 'Hana Salama',
      'craftAr': 'حلي ومجوهرات',
      'craftEn': 'Jewelry & Accessories',
      'rating': 4.7,
      'image': Icons.watch_outlined,
      'reasonAr': 'مجوهرات مصممة خصيصاً لك',
      'reasonEn': 'Custom-designed jewelry',
    },
  ];

  // ── Theme helpers ──────────────────────────────────────────────────
  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white60 : Colors.black54;
  Color get accent => const Color(0xFFD4A017);
  Color get border => widget.isDarkMode ? Colors.white12 : Colors.black12;

  String t(String ar, String en) => widget.isArabic ? ar : en;

  bool get canProceed {
    switch (_currentStep) {
      case 0: return _nameController.text.trim().isNotEmpty;
      case 1: return _selectedRecipient != null || _customRecipientController.text.trim().isNotEmpty;
      case 2: return _selectedOccasion != null || _customOccasionController.text.trim().isNotEmpty;
      case 3: return _selectedBudget != null || _customBudgetController.text.trim().isNotEmpty;
      case 4: return _selectedStyles.isNotEmpty || _customStyleController.text.trim().isNotEmpty;
      default: return true;
    }
  }

  List<dynamic> _realProducts = [];

  void _nextStep() async {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      // Gather answers
      final answers = {
        'recipientName': _nameController.text.trim(),
        'recipientType': _selectedRecipient == 'Other' ? _customRecipientController.text.trim() : _selectedRecipient,
        'occasion': _selectedOccasion == 'Other' ? _customOccasionController.text.trim() : _selectedOccasion,
        'budget': _selectedBudget,
        'styles': _selectedStyles,
      };
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: CircularProgressIndicator(color: accent),
        ),
      );

      final result = await CustomerService.submitGiftQuiz(answers);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result != null && result['products'] != null) {
        setState(() {
          _realProducts = result['products'] as List;
        });
        _showResults();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('فشل الحصول على اقتراحات، يرجى المحاولة لاحقاً', 'Failed to get recommendations, please try again later'))),
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _toggleStyle(String style) {
    setState(() {
      if (_selectedStyles.contains(style)) {
        _selectedStyles.remove(style);
      } else {
        _selectedStyles.add(style);
      }
    });
  }

  void _showResults() {
    final results = [
      ..._realProducts.map((p) => {...p, 'type': 'product'}),
      ..._artisans.map((a) => {...a, 'type': 'artisan'}),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t('اقتراحات الهدايا والحرفيين', 'Gift & Artisan Recommendations'),
                  style: GoogleFonts.cairo(color: text, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: dim),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t('بناءً على اختياراتك، هذه أفضل الهدايا والحرفيين المناسبين:', 'Based on your choices, these are the best gifts and artisans:'),
              style: TextStyle(color: dim, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  // Products section
                  _buildSectionHeader(t('منتجات', 'Products')),
                  const SizedBox(height: 8),
                  ..._products.map((item) => _buildResultCard(item, isProduct: true)),
                  const SizedBox(height: 20),
                  // Artisans section
                  _buildSectionHeader(t('حرفيون', 'Artisans')),
                  const SizedBox(height: 8),
                  ..._artisans.map((item) => _buildResultCard(item, isProduct: false)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(t('إغلاق', 'Close'), style: TextStyle(color: dim)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final savedList = {
                        'id': 'list_${DateTime.now().millisecondsSinceEpoch}',
                        'recipientName': _nameController.text.trim(),
                        'items': results,
                        'createdAt': DateTime.now(),
                      };
                      widget.onSave(savedList);
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t('تم حفظ قائمة الهدايا', 'Gift list saved')),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      t('حفظ القائمة', 'Save List'),
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.cairo(color: text, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildResultCard(dynamic item, {required bool isProduct}) {
    final titleAr = isProduct ? (item['titleAr'] ?? '') : item['nameAr'];
    final titleEn = isProduct ? (item['titleEn'] ?? titleAr) : item['nameEn'];
    final title = t(titleAr, titleEn);

    final String reasonKeyAr = isProduct ? 'يناسب تفضيلاتك' : 'حرفي مميز';
    final String reasonKeyEn = isProduct ? 'Matches preferences' : 'Featured Artisan';
    final reasonAr = item['reasonAr'] ?? reasonKeyAr;
    final reasonEn = item['reasonEn'] ?? reasonKeyEn;
    final reason = t(reasonAr, reasonEn);

    final imageUrl = item['imageUrl'];
    final price = item['price'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isProduct && imageUrl != null && imageUrl.toString().isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Icon(
                      isProduct ? Icons.card_giftcard : Icons.person,
                      color: accent,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (isProduct) ...[
                  Text('${price ?? 0} JOD', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(
                    reason,
                    style: TextStyle(color: dim, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else ...[
                  Text(
                    widget.isArabic ? (item['craftAr'] ?? '') : (item['craftEn'] ?? ''),
                    style: TextStyle(color: dim, fontSize: 11),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text((item['rating'] ?? 0).toString(), style: TextStyle(color: text, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              isProduct ? Icons.shopping_bag_outlined : Icons.chat_bubble_outline,
              color: accent,
              size: 16,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isProduct
                        ? t('فتح تفاصيل المنتج', 'Opening product details')
                        : t('بدء محادثة مع الحرفي', 'Starting chat with artisan'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

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
            icon: Icon(widget.isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            t('مساعد الهدايا', 'Gift Assistant'),
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: border,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4A017)),
              minHeight: 4,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t('الخطوة', 'Step')} ${_currentStep + 1}/$_totalSteps',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildStepContent(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(t('السابق', 'Back'), style: TextStyle(color: dim)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: canProceed ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canProceed ? accent : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _currentStep == _totalSteps - 1
                            ? t('الحصول على الهدايا', 'Get Gifts')
                            : t('متابعة', 'Continue'),
                        style: TextStyle(color: canProceed ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildNameStep();
      case 1:
        return _buildStep(
          title: t('لمن تبحث عن هدية؟', 'Who is the gift for?'),
          keys: _recipientKeys,
          selected: _selectedRecipient,
          onSelect: (v) => setState(() => _selectedRecipient = v),
          customController: _customRecipientController,
          customHint: t('أو اكتب إجابة أخرى', 'Or type another answer'),
          icon: Icons.person_outline,
          translationMap: _recipientTranslations,
        );
      case 2:
        return _buildStep(
          title: t('ما هي المناسبة؟', 'What is the occasion?'),
          keys: _occasionKeys,
          selected: _selectedOccasion,
          onSelect: (v) => setState(() => _selectedOccasion = v),
          customController: _customOccasionController,
          customHint: t('أو اكتب مناسبة أخرى', 'Or type another occasion'),
          icon: Icons.event_outlined,
          translationMap: _occasionTranslations,
        );
      case 3:
        return _buildStep(
          title: t('ما هي ميزانيتك التقريبية؟', 'What is your approximate budget?'),
          keys: _budgetKeys,
          selected: _selectedBudget,
          onSelect: (v) => setState(() => _selectedBudget = v),
          customController: _customBudgetController,
          customHint: t('أو اكتب قيمة أخرى', 'Or type another amount'),
          icon: Icons.attach_money,
          translationMap: _budgetTranslations,
        );
      case 4:
        return _buildMultiSelectStep(
          title: t('ما هي الأذواق التي تفضلها؟', 'What styles do you prefer?'),
          keys: _styleKeys,
          selected: _selectedStyles,
          onToggle: _toggleStyle,
          customController: _customStyleController,
          customHint: t('أو اكتب ذوقاً آخر', 'Or type another style'),
          icon: Icons.palette_outlined,
          translationMap: _styleTranslations,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, color: accent, size: 24),
            const SizedBox(width: 10),
            Text(
              t('أدخل اسم المستلم', 'Enter recipient name'),
              style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          style: TextStyle(color: text, fontSize: 16),
          decoration: InputDecoration(
            hintText: t('مثال: نورا، أحمد، أمي...', 'e.g. Nora, Ahmad, Mom...'),
            hintStyle: TextStyle(color: dim, fontSize: 14),
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent, width: 2),
            ),
            prefixIcon: Icon(Icons.edit_outlined, color: dim),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Text(
          t('سيظهر هذا الاسم في قوائمك المحفوظة', 'This name will appear in your saved lists'),
          style: TextStyle(color: dim, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStep({
    required String title,
    required List<String> keys,
    required String? selected,
    required Function(String) onSelect,
    required TextEditingController customController,
    required String customHint,
    required IconData icon,
    required Map<String, String> translationMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              ...keys.map((key) {
                final isSelected = selected == key;
                // THIS IS WHERE THE TRANSLATION HAPPENS
                final label = translateOption(key, translationMap);
                return GestureDetector(
                  onTap: () => onSelect(key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? accent.withValues(alpha: 0.15) : surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? accent : border, width: isSelected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? accent : border),
                          ),
                          child: isSelected ? Icon(Icons.check, color: accent, size: 14) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label, // <-- TRANSLATED LABEL
                            style: TextStyle(color: text, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // Custom text field (the "Other" option)
              Container(
                margin: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: customController,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    hintText: customHint,
                    hintStyle: TextStyle(color: dim),
                    prefixIcon: Icon(Icons.edit_outlined, color: dim),
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent, width: 2),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectStep({
    required String title,
    required List<String> keys,
    required List<String> selected,
    required Function(String) onToggle,
    required TextEditingController customController,
    required String customHint,
    required IconData icon,
    required Map<String, String> translationMap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          t('اختر كل ما يناسب (اختياري متعدد)', 'Select all that apply (multi-select)'),
          style: TextStyle(color: dim, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: keys.map((key) {
                  final isSelected = selected.contains(key);
                  // THIS IS WHERE THE TRANSLATION HAPPENS
                  final label = translateOption(key, translationMap);
                  return GestureDetector(
                    onTap: () => onToggle(key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? accent : surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isSelected ? accent : border, width: isSelected ? 2 : 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) const Icon(Icons.check, color: Colors.black, size: 14),
                          if (isSelected) const SizedBox(width: 6),
                          Text(
                            label, // <-- TRANSLATED LABEL
                            style: TextStyle(
                              color: isSelected ? Colors.black : text,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Custom text field
              Container(
                margin: const EdgeInsets.only(top: 16),
                child: TextField(
                  controller: customController,
                  style: TextStyle(color: text),
                  decoration: InputDecoration(
                    hintText: customHint,
                    hintStyle: TextStyle(color: dim),
                    prefixIcon: Icon(Icons.edit_outlined, color: dim),
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent, width: 2),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

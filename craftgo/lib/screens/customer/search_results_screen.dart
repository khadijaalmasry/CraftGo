import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'product_details_page.dart';
import '../../services/customer_service.dart';

class SearchResultsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String query;
  final List<dynamic>? initialProducts;
  final bool isGuest;

  const SearchResultsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    required this.query,
    this.initialProducts,
    this.isGuest = false,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  bool _aiModeActive = false;
  List<dynamic> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  Future<void> _fetchResults() async {
    if (widget.initialProducts != null && widget.initialProducts!.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _results = widget.initialProducts!;
        _isLoading = false;
      });
      return;
    }

    final fetched = await CustomerService.fetchProducts(search: widget.query);
    if (!mounted) return;
    setState(() {
      _results = fetched;
      _isLoading = false;
    });
  }

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
    final surface = widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
    final text = widget.isDarkMode ? Colors.white : Colors.black87;
    final dim = widget.isDarkMode ? Colors.white60 : Colors.black54;
    final border = widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final accent = const Color(0xFFD4A017);
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(widget.isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios, color: text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '${t("نتائج البحث عن", "Results for")} "${widget.query}"',
            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.auto_awesome, color: _aiModeActive ? Colors.purpleAccent : dim),
              onPressed: () {
                setState(() {
                  _aiModeActive = !_aiModeActive;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_aiModeActive)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t('الذكاء الاصطناعي يفهم: "${widget.query}" ويقترح منتجات مشابهة 🤖', 'AI understands "${widget.query}" and suggests similar products 🤖'),
                        style: GoogleFonts.cairo(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accent))
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        t("لا توجد نتائج", "No results found"),
                        style: TextStyle(color: dim, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(left: 20, right: 20, bottom: 20, top: _aiModeActive ? 0 : 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final p = _results[index];
                        final titleAr = p["titleAr"] ?? "";
                        final titleEn = p["titleEn"] ?? titleAr;
                        final price = p["price"] ?? 0;
                        final imageUrl = p["imageUrl"];
                        final craftsman = p["Craftsman"];
                        final craftsmanName = craftsman != null ? craftsman["name"] : (t(p["craftsmanAr"] ?? "", p["craftsmanEn"] ?? ""));
                        
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailsPage(
                                  product: p,
                                  isArabic: widget.isArabic,
                                  isDarkMode: widget.isDarkMode,
                                  isGuest: widget.isGuest,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                              boxShadow: widget.isDarkMode ? [] : [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                              ],
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: imageUrl != null && imageUrl.toString().isNotEmpty
                                            ? Image.network(imageUrl, fit: BoxFit.cover)
                                            : Icon(Icons.image_not_supported, color: accent, size: 30),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t(titleAr, titleEn),
                                            style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            craftsmanName,
                                            style: TextStyle(color: dim, fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text("JOD $price", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 14)),
                                              const Spacer(),
                                              Row(
                                                children: [
                                                  Icon(Icons.star, color: accent, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text("4.9", style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 12)),
                                                ],
                                              )
                                            ],
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                                if (_aiModeActive)
                                  Positioned(
                                    top: 0,
                                    right: widget.isArabic ? null : 0,
                                    left: widget.isArabic ? 0 : null,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purpleAccent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        t('🤖 AI اقترح', '🤖 AI Pick'),
                                        style: GoogleFonts.cairo(color: Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

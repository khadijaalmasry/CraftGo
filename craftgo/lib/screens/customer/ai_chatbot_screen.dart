import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/products_service.dart';

class AiChatbotScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final String? productName;
  final double? productPrice;
  final IconData? productIcon;
  final String productId;
  final int quantity;

  const AiChatbotScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    this.productName,
    this.productPrice,
    this.productIcon,
    required this.productId,
    this.quantity = 1,
  });

  @override
  State<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode ? Colors.white12 : Colors.black12;
  Color get accent => const Color(0xFFD4A017);
  double get originalPrice => widget.productPrice ?? 0;
  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'isUser': false,
      'text': widget.productName == null
          ? t('مرحباً! أنا Crafty. كيف أساعدك؟', 'Hello! I am Crafty. How can I help?')
          : t(
        'أهلاً! سأساعدك بتجهيز عرض منطقي لـ «${widget.productName}». السعر الحالي ${originalPrice.toStringAsFixed(0)} دينار. اختر عرضاً سريعاً أو اكتب السعر.',
        'Hi! I will help you prepare a fair offer for “${widget.productName}”. The current price is ${originalPrice.toStringAsFixed(0)} JD. Choose a quick offer or type an amount.',
      ),
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _quickOffer(int discount) {
    final offer = originalPrice * (1 - discount / 100);
    _controller.text = t('أقترح ${offer.toStringAsFixed(0)} دينار', 'I offer ${offer.toStringAsFixed(0)} JD');
    _sendMessage();
  }

  double? _extractAmount(String input) {
    final match = RegExp(r'(\d+(?:[\.,]\d+)?)').firstMatch(input);
    return match == null ? null : double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  Future<void> _sendMessage() async {
    final userText = _controller.text.trim();
    if (userText.isEmpty || _isTyping) return;
    setState(() {
      _messages.add({'isUser': true, 'text': userText});
      _controller.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final offered = _extractAmount(userText);
    String response;
    if (originalPrice > 0 && offered != null) {
      final minimumFair = originalPrice * 0.80;
      final strongOffer = originalPrice * 0.90;
      if (offered >= originalPrice) {
        response = t(
          'العرض يساوي السعر الحالي أو يزيد عنه. الشراء المباشر أنسب، أو جرّب ${strongOffer.toStringAsFixed(0)} دينار.',
          'That is equal to or above the listed price. Buy directly, or try ${strongOffer.toStringAsFixed(0)} JD.',
        );
      } else if (offered < minimumFair) {
        response = t(
          'عرضك ${offered.toStringAsFixed(0)} دينار منخفض لقطعة يدوية. العرض الأقرب للقبول هو ${strongOffer.toStringAsFixed(0)} دينار.',
          'Your ${offered.toStringAsFixed(0)} JD offer is low for a handmade item. A stronger offer is ${strongOffer.toStringAsFixed(0)} JD.',
        );
      } else {
        try {
          await ProductsService.createOffer(
            productId: widget.productId,
            quantity: widget.quantity,
            offeredPrice: offered,
            message: userText,
          );
          response = t(
            'تم إرسال عرضك ${offered.toStringAsFixed(0)} دينار للحرفي ✅ ستصلك نتيجة القبول أو الرفض أو عرض مضاد في طلباتك.',
            'Your ${offered.toStringAsFixed(0)} JD offer was sent to the artisan ✅ You will see an acceptance, rejection, or counter-offer in My Orders.',
          );
        } catch (e) {
          response = t('تعذر إرسال العرض: $e', 'Could not send the offer: $e');
        }
      }
    } else if (originalPrice > 0) {
      response = t('اكتب رقم العرض مثل: 25 دينار.', 'Type an offer amount, for example: 25 JD.');
    } else {
      response = t('اذكر نوع المنتج والميزانية لأساعدك.', 'Tell me the product type and budget so I can help.');
    }
    setState(() {
      _isTyping = false;
      _messages.add({'isUser': false, 'text': response});
    });
    _scrollToBottom();

  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          foregroundColor: text,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Crafty AI', style: GoogleFonts.cairo(color: accent, fontSize: 19, fontWeight: FontWeight.bold)),
              Text(t('مساعد التفاوض', 'Price negotiation assistant'), style: GoogleFonts.cairo(color: dim, fontSize: 10)),
            ],
          ),
        ),
        body: Column(
          children: [
            if (widget.productName != null) _productSummary(),
            if (originalPrice > 0) _quickOffers(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                itemCount: _messages.length,
                itemBuilder: (_, index) {
                  final message = _messages[index];
                  return _messageBubble(message['text'] as String, message['isUser'] == true);
                },
              ),
            ),
            if (_isTyping) Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4A017))),
                const SizedBox(width: 8),
                Text(t('Crafty يحلل العرض...', 'Crafty is reviewing the offer...'), style: GoogleFonts.cairo(color: dim, fontSize: 12)),
              ]),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _productSummary() => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
    child: Row(children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)), child: Icon(widget.productIcon ?? Icons.inventory_2_outlined, color: accent)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.productName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold)),
        Text(t('السعر الحالي', 'Current price'), style: GoogleFonts.cairo(color: dim, fontSize: 11)),
      ])),
      Text('${originalPrice.toStringAsFixed(0)} JD', style: GoogleFonts.cairo(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
    ]),
  );

  Widget _quickOffers() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t('عروض سريعة', 'Quick offers'), style: GoogleFonts.cairo(color: dim, fontSize: 11)),
      const SizedBox(height: 7),
      Row(children: [5, 10, 15].map((discount) => Expanded(child: Padding(
        padding: EdgeInsetsDirectional.only(end: discount == 15 ? 0 : 8),
        child: OutlinedButton(
          onPressed: () => _quickOffer(discount),
          style: OutlinedButton.styleFrom(side: BorderSide(color: accent.withValues(alpha: .7)), foregroundColor: accent, padding: const EdgeInsets.symmetric(vertical: 9)),
          child: Text('-$discount%  ${(originalPrice * (1 - discount / 100)).toStringAsFixed(0)} JD', style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ))).toList()),
    ]),
  );

  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
    decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: border))),
    child: Row(children: [
      Expanded(child: TextField(
        controller: _controller,
        keyboardType: originalPrice > 0 ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.cairo(color: text),
        onSubmitted: (_) => _sendMessage(),
        decoration: InputDecoration(
          hintText: t('اكتب عرضك بالدينار...', 'Enter your offer in JD...'),
          hintStyle: GoogleFonts.cairo(color: dim, fontSize: 12),
          filled: true,
          fillColor: bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      )),
      const SizedBox(width: 10),
      IconButton.filled(onPressed: _isTyping ? null : _sendMessage, style: IconButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black), icon: const Icon(Icons.send_rounded)),
    ]),
  );

  Widget _messageBubble(String value, bool isUser) => Align(
    alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
      decoration: BoxDecoration(
        color: isUser ? accent : surface,
        borderRadius: BorderRadius.circular(16),
        border: isUser ? null : Border.all(color: const Color(0xFFB82BEA).withValues(alpha: .35)),
      ),
      child: Text(value, style: GoogleFonts.cairo(color: isUser ? Colors.black : text, height: 1.5, fontSize: 13)),
    ),
  );
}

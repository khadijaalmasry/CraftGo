import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CraftsmanEventsScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const CraftsmanEventsScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<CraftsmanEventsScreen> createState() => _CraftsmanEventsScreenState();
}

class _CraftsmanEventsScreenState extends State<CraftsmanEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Theme getters
  Color get bg =>
      widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface =>
      widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  // Mock data
  final List<Map<String, dynamic>> _allEvents = [
    {
      'id': '1',
      'nameAr': 'أسبوع الحرف اليدوية بعمّان',
      'nameEn': 'Amman Handmade Week',
      'dateAr': '١-١٥ يوليو ٢٠٢٦',
      'dateEn': 'July 1-15, 2026',
      'locationAr': 'عمّان',
      'locationEn': 'Amman',
      'artisans': 15,
      'maxCapacity': 30,
      'status': 'upcoming',
      'registered': false,
      'invited': false,
      'gradient': [Colors.blue, Colors.green],
    },
    {
      'id': '2',
      'nameAr': 'معرض الصيف الحرفي',
      'nameEn': 'Summer Craft Fair',
      'dateAr': '١٠-٢٠ أغسطس ٢٠٢٦',
      'dateEn': 'Aug 10-20, 2026',
      'locationAr': 'الزرقاء',
      'locationEn': 'Zarqa',
      'artisans': 8,
      'maxCapacity': 20,
      'status': 'upcoming',
      'registered': true,
      'invited': false,
      'gradient': [Colors.orange, Colors.red],
    },
    {
      'id': '3',
      'nameAr': 'معرض الفنون الشعبية',
      'nameEn': 'Folk Arts Fair',
      'dateAr': '٥-١٠ سبتمبر ٢٠٢٦',
      'dateEn': 'Sep 5-10, 2026',
      'locationAr': 'إربد',
      'locationEn': 'Irbid',
      'artisans': 4,
      'maxCapacity': 15,
      'status': 'upcoming',
      'registered': false,
      'invited': true,
      'gradient': [Colors.purple, Colors.blue],
    },
    {
      'id': '4',
      'nameAr': 'معرض الخريف الحرفي',
      'nameEn': 'Autumn Handicraft Expo',
      'dateAr': '١-١٠ أكتوبر ٢٠٢٦',
      'dateEn': 'Oct 1-10, 2026',
      'locationAr': 'عمّان',
      'locationEn': 'Amman',
      'artisans': 12,
      'maxCapacity': 25,
      'status': 'upcoming',
      'registered': true,
      'invited': false,
      'gradient': [Colors.brown, Colors.amber],
    },
    {
      'id': '5',
      'nameAr': 'معرض الشتاء الحرفي',
      'nameEn': 'Winter Craft Bazaar',
      'dateAr': '١-١٥ ديسمبر ٢٠٢٦',
      'dateEn': 'Dec 1-15, 2026',
      'locationAr': 'نابلس',
      'locationEn': 'Nablus',
      'artisans': 6,
      'maxCapacity': 18,
      'status': 'upcoming',
      'registered': false,
      'invited': true,
      'gradient': [Colors.teal, Colors.cyan],
    },
    {
      'id': '6',
      'nameAr': 'معرض الحرف التراثية',
      'nameEn': 'Heritage Crafts Exhibition',
      'dateAr': '١-٧ نوفمبر ٢٠٢٦',
      'dateEn': 'Nov 1-7, 2026',
      'locationAr': 'رام الله',
      'locationEn': 'Ramallah',
      'artisans': 3,
      'maxCapacity': 12,
      'status': 'past',
      'registered': true,
      'invited': false,
      'gradient': [Colors.indigo, Colors.pink],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _discoverEvents =>
      _allEvents.where((e) => !e['registered'] && !e['invited']).toList();
  List<Map<String, dynamic>> get _myEvents =>
      _allEvents.where((e) => e['registered'] == true).toList();
  List<Map<String, dynamic>> get _upcomingEvents =>
      _allEvents.where((e) => e['status'] == 'upcoming').toList();
  List<Map<String, dynamic>> get _invites => _allEvents
      .where((e) => e['invited'] == true && !e['registered'])
      .toList();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: null, // shell provides app bar
        body: Column(
          children: [
            // Custom TabBar inside body
            Container(
              color: surface,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                labelColor: accent,
                unselectedLabelColor: dim,
                indicatorColor: accent,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.cairo(),
                tabs: [
                  Tab(text: t('استكشف', 'Discover')),
                  Tab(text: t('معارضي', 'My Events')),
                  Tab(text: t('القادمة', 'Upcoming')),
                  Tab(text: t('الدعوات', 'Invites')),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildEventList(_discoverEvents, isDiscover: true),
                  _buildEventList(_myEvents, isMyEvents: true),
                  _buildEventList(_upcomingEvents),
                  _buildEventList(_invites, isInvites: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventList(List<Map<String, dynamic>> events,
      {bool isDiscover = false,
      bool isMyEvents = false,
      bool isInvites = false}) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDiscover
                  ? Icons.search_off
                  : isMyEvents
                      ? Icons.event_busy
                      : isInvites
                          ? Icons.mail_outline
                          : Icons.calendar_today,
              size: 48,
              color: dim,
            ),
            const SizedBox(height: 16),
            Text(
              isDiscover
                  ? t('لا توجد معارض للاستكشاف حالياً',
                      'No exhibitions to discover')
                  : isMyEvents
                      ? t('لا توجد معارض مسجلة', 'No registered exhibitions')
                      : isInvites
                          ? t('لا توجد دعوات', 'No invites')
                          : t('لا توجد فعاليات قادمة', 'No upcoming events'),
              style: GoogleFonts.cairo(color: dim, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventCard(event, isInvites: isInvites);
      },
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, {bool isInvites = false}) {
    final name = widget.isArabic ? event['nameAr'] : event['nameEn'];
    final date = widget.isArabic ? event['dateAr'] : event['dateEn'];
    final location =
        widget.isArabic ? event['locationAr'] : event['locationEn'];
    final artisans = event['artisans'];
    final maxCapacity = event['maxCapacity'];
    final gradient = event['gradient'] is List<Color>
        ? (event['gradient'] as List<Color>)
        : const [Color(0xFF1976D2), Color(0xFF009688)];
    final isRegistered = event['registered'] ?? false;
    final isInvited = event['invited'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        shadows: [
                          const Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isRegistered)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t('مسجل', 'Registered'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: dim),
                    const SizedBox(width: 6),
                    Text(date, style: TextStyle(color: dim, fontSize: 13)),
                    const Spacer(),
                    Icon(Icons.location_on, size: 14, color: dim),
                    const SizedBox(width: 6),
                    Text(location, style: TextStyle(color: dim, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      t('$artisans / $maxCapacity حرفي',
                          '$artisans / $maxCapacity artisans'),
                      style: TextStyle(color: dim, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isInvites)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Decline invite
                            setState(() {
                              event['invited'] = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text(t('تم رفض الدعوة', 'Invite declined')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            t('رفض', 'Decline'),
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              event['registered'] = true;
                              event['invited'] = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    t('تم قبول الدعوة ✅', 'Invite accepted ✅')),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            t('قبول', 'Accept'),
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (!isRegistered)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => event['registered'] = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('تم التسجيل بنجاح ✅',
                                'Registered successfully ✅')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        t('سجل الآن', 'Register Now'),
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Show details or cancel registration
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: surface,
                            title:
                                Text(t('إلغاء التسجيل', 'Cancel Registration')),
                            content: Text(
                              t('هل أنت متأكد من إلغاء تسجيلك في هذا المعرض؟',
                                  'Are you sure you want to cancel your registration?'),
                              style: TextStyle(color: dim),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(t('لا', 'No'),
                                    style: TextStyle(color: dim)),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => event['registered'] = false);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(t('تم إلغاء التسجيل',
                                          'Registration cancelled')),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                },
                                child: Text(t('نعم', 'Yes'),
                                    style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon:
                          Icon(Icons.cancel_outlined, color: Colors.redAccent),
                      label: Text(
                        t('إلغاء التسجيل', 'Cancel Registration'),
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../screens/exhibitions/explore_exhibitions_screen.dart';
import '../screens/artisan/craftsman_exhibitions_screen.dart';
import '../screens/admin/admin_exhibition_screen.dart';
import 'chats_list_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/customer/cart_screen.dart';
import '../app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final isAr = appState.isArabic;

    final bg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F6F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subColor = isDark ? const Color(0x66FFFFFF) : const Color(0xFF999999);
    final cardBg = isDark ? const Color(0x0AFFFFFF) : Colors.white;
    final cardBorder =
        isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE5E0D8);
    final gcBg = isDark ? const Color(0x1AE8B84B) : const Color(0x12E8B84B);
    final gcBorder = isDark ? const Color(0x40E8B84B) : const Color(0x33E8B84B);
    final catBorder =
        isDark ? const Color(0x14FFFFFF) : const Color(0xFFE5E0D8);
    final niColor = isDark ? const Color(0x4DFFFFFF) : const Color(0x4D000000);
    final nbBg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F6F0);
    final nbBorder = isDark ? const Color(0x12FFFFFF) : const Color(0x12000000);

    final cats = isAr
        ? ['تطريز', 'نجارة', 'رسم', 'خياطة', 'مجوهرات', 'المزيد']
        : [
            'Embroidery',
            'Woodwork',
            'Painting',
            'Tailoring',
            'Jewelry',
            'More'
          ];
    final icons = [
      Icons.texture,
      Icons.carpenter,
      Icons.brush,
      Icons.content_cut,
      Icons.diamond,
      Icons.more_horiz,
    ];

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu, color: textColor),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: subColor),
              onPressed: () {},
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: bg,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFFE8B84B)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 30,
                      child: Icon(Icons.person,
                          size: 30, color: Color(0xFFE8B84B)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isAr
                          ? 'القائمة السريعة للتقييم'
                          : 'Quick Evaluation Menu',
                      style: GoogleFonts.cairo(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.blue),
                title: Text(isAr
                    ? 'استكشاف المعارض (زبون/حرفي)'
                    : 'Explore Exhibitions'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ExploreExhibitionsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_available, color: Colors.green),
                title:
                    Text(isAr ? 'معارضي (حرفي)' : 'My Exhibitions (Craftsman)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CraftsmanExhibitionsScreen(
                        isArabic: isAr,
                        isDarkMode: isDark,
                        craftsmanId: 'artisan-fatima',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.business_center, color: Colors.purple),
                title: Text(isAr
                    ? 'إدارة المعرض (صاحب المعرض)'
                    : 'Manage Exhibition (Owner)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminExhibitionScreen(
                        isArabic: isAr,
                        isDarkMode: isDark,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.chat_bubble_outline, color: Colors.orange),
                title: Text(isAr ? 'الدردشات (الكل)' : 'Chats (All)'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatsListScreen(
                        currentUserId: 'demo-user',
                        isArabic: isAr,
                        isDarkMode: isDark,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart, color: Colors.teal),
                title: Text(isAr ? 'سلة المشتريات (الزبون)' : 'Shopping Cart'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartScreen(
                        isArabic: isAr,
                        isDarkMode: isDark,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.admin_panel_settings, color: Colors.red),
                title: Text(isAr
                    ? 'لوحة تحكم النظام (Admin)'
                    : 'System Admin Dashboard'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminDashboard(
                        isArabic: isAr,
                        isDarkMode: isDark,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;

              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: isAr
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'أهلاً، ريم' : 'Hello, Reem',
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : 11,
                              color: subColor,
                            ),
                          ),
                          Text(
                            isAr
                                ? 'شو بدك تطلبي اليوم؟'
                                : 'What are you ordering?',
                            style: TextStyle(
                              fontSize: isDesktop ? 22 : 16,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      Stack(
                        children: [
                          Icon(Icons.notifications_outlined,
                              size: 26, color: subColor),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8B84B),
                                shape: BoxShape.circle,
                                border: Border.all(color: bg, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // AI Card
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 18 : 13),
                    decoration: BoxDecoration(
                      color: gcBg,
                      border: Border.all(color: gcBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE8B84B),
                                Color(0xFFC9962A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome,
                              size: 22, color: Color(0xFF0A0A0A)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: isAr
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? 'اطلب بالذكاء الاصطناعي'
                                    : 'Order with AI',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE8B84B),
                                ),
                              ),
                              Text(
                                isAr
                                    ? 'صف فكرتك أو أرفق صورة'
                                    : 'Describe or upload a photo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isAr ? Icons.chevron_left : Icons.chevron_right,
                          color: const Color(0xFFE8B84B),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Categories title
                  Text(
                    isAr ? 'الفئات' : 'Categories',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Categories grid (6 items in 6 columns on desktop, 3 on mobile)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 6 : 3,
                      childAspectRatio: isDesktop ? 1.6 : 1.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: cats.length,
                    itemBuilder: (_, i) => Container(
                      decoration: BoxDecoration(
                        color: i == 0 ? const Color(0x1FE8B84B) : cardBg,
                        border: Border.all(
                          color: i == 0 ? const Color(0x66E8B84B) : catBorder,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icons[i],
                            size: 22,
                            color: i == 0 ? const Color(0xFFE8B84B) : subColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cats[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color:
                                  i == 0 ? const Color(0xFFE8B84B) : subColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Top Rated title
                  Text(
                    isAr ? 'الأعلى تقييماً' : 'Top Rated',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(height: 10),

                  isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              child: _ArtisanCard(
                                initials: isAr ? 'سم' : 'SM',
                                name: isAr ? 'سمر المصري' : 'Samar Al-Masri',
                                sub: isAr
                                    ? 'تطريز · 6 سنوات'
                                    : 'Embroidery · 6 yrs',
                                available: isAr ? 'متاحة' : 'Available',
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textColor: textColor,
                                subColor: subColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ArtisanCard(
                                initials: isAr ? 'خح' : 'KH',
                                name: isAr ? 'خالد الحاج' : 'Khaled Al-Haj',
                                sub: isAr
                                    ? 'نجارة فنية · 10 سنوات'
                                    : 'Woodwork · 10 yrs',
                                available: isAr ? 'متاح' : 'Available',
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                textColor: textColor,
                                subColor: subColor,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _ArtisanCard(
                              initials: isAr ? 'سم' : 'SM',
                              name: isAr ? 'سمر المصري' : 'Samar Al-Masri',
                              sub: isAr
                                  ? 'تطريز · 6 سنوات'
                                  : 'Embroidery · 6 yrs',
                              available: isAr ? 'متاحة' : 'Available',
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              textColor: textColor,
                              subColor: subColor,
                            ),
                            _ArtisanCard(
                              initials: isAr ? 'خح' : 'KH',
                              name: isAr ? 'خالد الحاج' : 'Khaled Al-Haj',
                              sub: isAr
                                  ? 'نجارة فنية · 10 سنوات'
                                  : 'Woodwork · 10 yrs',
                              available: isAr ? 'متاح' : 'Available',
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              textColor: textColor,
                              subColor: subColor,
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),

                  // Theme & Lang toggles
                  Row(
                    children: [
                      Expanded(
                        child: _ActionChip(
                          icon: isDark
                              ? Icons.wb_sunny_rounded
                              : Icons.nightlight_round,
                          label: isDark
                              ? (isAr ? 'وضع فاتح' : 'Light Mode')
                              : (isAr ? 'وضع داكن' : 'Dark Mode'),
                          onTap: () => appState.toggleTheme(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionChip(
                          emoji: '🌐',
                          label: isAr ? 'English' : 'العربية',
                          onTap: () => appState.toggleLanguage(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 70),
                ],
              );

              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 1100 : double.infinity,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: content,
                        ),
                      ),
                    ),
                  ),

                  // Nav bar
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: nbBg,
                      border: Border(top: BorderSide(color: nbBorder)),
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 1100 : double.infinity,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _NavItem(
                              icon: Icons.home_rounded,
                              label: isAr ? 'الرئيسية' : 'Home',
                              isActive: true,
                              color: niColor,
                            ),
                            _NavItem(
                              icon: Icons.search_rounded,
                              label: isAr ? 'استكشاف' : 'Explore',
                              isActive: false,
                              color: niColor,
                            ),
                            _NavItem(
                              icon: Icons.access_time_rounded,
                              label: isAr ? 'طلباتي' : 'Orders',
                              isActive: false,
                              color: niColor,
                            ),
                            _NavItem(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: isAr ? 'رسائل' : 'Messages',
                              isActive: false,
                              color: niColor,
                            ),
                            _NavItem(
                              icon: Icons.person_outline_rounded,
                              label: isAr ? 'حسابي' : 'Profile',
                              isActive: false,
                              color: niColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: isActive ? const Color(0xFFE8B84B) : color),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? const Color(0xFFE8B84B) : color,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ArtisanCard extends StatelessWidget {
  final String initials, name, sub, available;
  final Color cardBg, cardBorder, textColor, subColor;

  const _ArtisanCard({
    required this.initials,
    required this.name,
    required this.sub,
    required this.available,
    required this.cardBg,
    required this.cardBorder,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8B84B), Color(0xFFC9962A)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A0A0A)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                Text(sub, style: TextStyle(fontSize: 10, color: subColor)),
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Text('★★★★★',
                        style:
                            TextStyle(color: Color(0xFFE8B84B), fontSize: 10)),
                    SizedBox(width: 4),
                    Text('4.9',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x26E8B84B),
              border: Border.all(color: const Color(0x4DE8B84B)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              available,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE8B84B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? emoji;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x66E8B84B)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 15, color: const Color(0xFFE8B84B))
            else
              Text(emoji!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE8B84B),
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

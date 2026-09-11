import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../services/api_service.dart';

// Profile screens imports
import '../customer/artisan_profile_page.dart';
import '../customer/customer_public_profile.dart';
import 'exhibition_owner_profile_page.dart';
import 'delivery_person_profile_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AdminUsersScreen — شاشة إدارة وحظر جميع المستخدمين وأدوارهم
// ─────────────────────────────────────────────────────────────────────────────

class AdminUsersScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;

  const AdminUsersScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String _selectedRoleFilter = 'all'; // 'all', 'customer', 'artisan', 'delivery', 'exhibition_owner', 'admin'
  String _searchQuery = '';
  bool _sortNewest = true;

  final TextEditingController _searchController = TextEditingController();

  // Colors
  Color get bg => widget.isDarkMode ? const Color(0xFF0D1420) : const Color(0xFFF5F6F8);
  Color get surface => widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white;
  Color get accent => widget.isDarkMode ? const Color(0xFFD4A017) : const Color(0xFF0D1B33);
  Color get text => widget.isDarkMode ? Colors.white : Colors.black87;
  Color get dim => widget.isDarkMode ? Colors.white70 : Colors.black54;
  Color get border => widget.isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

  String t(String ar, String en) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.get('/admin/users');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> list = body is Map && body['users'] != null ? body['users'] : (body is List ? body : []);
        final formatted = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        if (mounted) {
          setState(() {
            _users = formatted;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = t('فشل تحميل قائمة المستخدمين', 'Failed to load users list');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _toggleUserBan(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null) return;

    final currentSuspended = user['isSuspended'] == true;

    try {
      final res = await ApiService.patch(
        '/admin/users/$userId/status',
        body: {'isSuspended': !currentSuspended},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        setState(() {
          user['isSuspended'] = !currentSuspended;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentSuspended
                  ? t('تم إلغاء حظر الحساب بنجاح', 'User account unblocked successfully')
                  : t('تم حظر وتجميد حساب المستخدم بواسطة الإدارة', 'User account suspended by Admin'),
            ),
            backgroundColor: currentSuspended ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('فشل تغيير حالة الحساب: $e', 'Status update failed: $e')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((u) {
      // Role filter
      final roles = (u['roles'] as List?)?.map((r) => r.toString().toLowerCase()).toList() ?? [];
      final primaryRole = (u['role'] ?? '').toString().toLowerCase();
      if (primaryRole.isNotEmpty && !roles.contains(primaryRole)) {
        roles.add(primaryRole);
      }

      bool matchesRole = _selectedRoleFilter == 'all';
      if (_selectedRoleFilter == 'customer') {
        matchesRole = roles.contains('customer') || roles.contains('client');
      } else if (_selectedRoleFilter == 'artisan') {
        matchesRole = roles.contains('artisan') || roles.contains('craftsman');
      } else if (_selectedRoleFilter == 'delivery') {
        matchesRole = roles.contains('delivery') || roles.contains('driver');
      } else if (_selectedRoleFilter == 'exhibition_owner') {
        matchesRole = roles.contains('exhibition_owner') || roles.contains('organizer');
      } else if (_selectedRoleFilter == 'admin') {
        matchesRole = roles.contains('admin');
      }

      // Search filter
      final q = _searchQuery.toLowerCase();
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final phone = (u['phone'] ?? '').toString().toLowerCase();
      final city = (u['city'] ?? '').toString().toLowerCase();
      final id = (u['id'] ?? '').toString().toLowerCase();

      final matchesSearch = q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          phone.contains(q) ||
          city.contains(q) ||
          id.contains(q);

      return matchesRole && matchesSearch;
    }).toList()
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2020);
        final dateB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2020);
        return _sortNewest ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
      });
  }

  String _formatDate(dynamic input) {
    if (input == null) return '';
    try {
      final dt = DateTime.parse(input.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return input.toString();
    }
  }

  // ── Multi-Role Inspector Sheet ────────────────────────────────────────────
  void _showUserProfileModal(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? '—';
    final email = user['email']?.toString() ?? '—';
    final phone = user['phone']?.toString() ?? '—';
    final city = user['city']?.toString() ?? '—';
    final isSuspended = user['isSuspended'] == true;

    final roles = (user['roles'] as List?)?.map((r) => r.toString().toLowerCase()).toList() ?? [];
    if (user['role'] != null && !roles.contains(user['role'].toString().toLowerCase())) {
      roles.add(user['role'].toString().toLowerCase());
    }

    final bool hasArtisan = roles.contains('artisan') || roles.contains('craftsman');
    final bool hasCustomer = roles.contains('customer') || roles.contains('client') || roles.isEmpty;
    final bool hasDelivery = roles.contains('delivery') || roles.contains('driver');
    final bool hasExhibition = roles.contains('exhibition_owner') || roles.contains('organizer');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: dim.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.cairo(color: text, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: roles.map((r) => _roleBadge(r)).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Info Rows
            _infoRow(Icons.email_outlined, t('البريد الإلكتروني:', 'Email:'), email),
            const SizedBox(height: 6),
            _infoRow(Icons.phone_outlined, t('رقم الهاتف:', 'Phone:'), phone),
            const SizedBox(height: 6),
            _infoRow(Icons.location_city_outlined, t('المدينة:', 'City:'), city),
            const SizedBox(height: 6),
            _infoRow(Icons.calendar_today_outlined, t('تاريخ الانضمام:', 'Joined:'), _formatDate(user['createdAt'])),
            const SizedBox(height: 20),

            Text(
              t('معاينة حسابات وأدوار المستخدم:', 'Inspect Role Profiles:'),
              style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            // Role Profile Buttons Grid
            Column(
              children: [
                if (hasArtisan) ...[
                  _profileButton(
                    icon: Icons.palette_outlined,
                    color: const Color(0xFFD4A017),
                    label: t('معاينة ملف الحرفي / الصانع', 'View Artisan Craftsman Profile'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArtisanProfilePage(
                            artisan: user,
                            isArabic: widget.isArabic,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (hasCustomer) ...[
                  _profileButton(
                    icon: Icons.person_outline,
                    color: Colors.blue,
                    label: t('معاينة الملف العام للزبون', 'View Customer Client Profile'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerPublicProfile(
                            customerId: user['id']?.toString() ?? '',
                            isArabic: widget.isArabic,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (hasExhibition) ...[
                  _profileButton(
                    icon: Icons.event_seat_outlined,
                    color: Colors.purple,
                    label: t('معاينة ملف منظم المعارض', 'View Exhibition Organizer Profile'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExhibitionOwnerProfilePage(
                            owner: user,
                            isArabic: widget.isArabic,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (hasDelivery) ...[
                  _profileButton(
                    icon: Icons.local_shipping_outlined,
                    color: Colors.teal,
                    label: t('معاينة ملف مندوب التوصيل', 'View Delivery Driver Profile'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeliveryPersonProfilePage(
                            driver: user,
                            isArabic: widget.isArabic,
                            isDarkMode: widget.isDarkMode,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Promote to Admin Button
            if (!roles.contains('admin')) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _promoteUserToAdmin(user);
                  },
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Colors.purple),
                  label: Text(
                    t('ترقية المستخدم إلى مدير (Admin)', 'Promote User to Admin'),
                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Ban / Activate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleUserBan(user);
                },
                icon: Icon(isSuspended ? Icons.lock_open : Icons.block, size: 18),
                label: Text(
                  isSuspended ? t('إلغاء حظر وتفعيل الحساب', 'Unblock & Activate User') : t('حظر وتجميد حساب المستخدم', 'Suspend / Ban User Account'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSuspended ? Colors.green : Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Permanent Delete Account Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteUserAccount(user);
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(
                  t('حذف الحساب والبيانات نهائياً', 'Delete User & All Related Data'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promoteUserToAdmin(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('ترقية المستخدم إلى مدير (Admin)', 'Promote User to Admin'),
                style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          t(
            'هل أنت تأكد من ترقية ${user['name']} إلى مدير النظام؟ سيتم توليد رمز أدمن خاص وإرساله فوراً لبريده الإلكتروني (${user['email']}).',
            'Are you sure you want to promote ${user['name']} to Admin? A unique Admin Code will be generated and emailed to (${user['email']}).',
          ),
          style: TextStyle(color: dim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('تأكيد الترقية', 'Confirm Promotion'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiService.post('/admin/users/$userId/promote');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final staffCode = body['adminStaffId'] ?? 'AD-XXXX';

        await _loadUsers();

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text(t('تمت الترقية بنجاح! 🎉', 'Promoted Successfully! 🎉'), style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('تمت ترقية المستخدم إلى أدمن وإرسال الرمز الخاص به عبر البريد الإلكتروني.', 'User is now an Admin. Confidential code sent via email.'),
                  style: TextStyle(color: dim, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent),
                  ),
                  child: Column(
                    children: [
                      Text(t('رمز الأدمن الجديد (Staff Code):', 'New Admin Staff Code:'), style: TextStyle(color: dim, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(staffCode, style: TextStyle(color: accent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('حسناً', 'OK'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('فشل ترقية المستخدم: $e', 'Promotion failed: $e')), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _deleteUserAccount(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('تأكيد حذف الحساب نهائياً', 'Confirm Permanent User Deletion'),
                style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          t(
            'هل أنت متأكد تماماً من رغبتك في حذف حساب "${user['name']}" وكل البيانات المرتبطة به؟\n\nسيؤدي هذا إلى حذف السجلات والطلبات والنزاعات والمنتجات والمراسلات نهائياً ولا يمكن التراجع عن هذا الإجراء.',
            'Are you sure you want to permanently delete "${user['name']}" and all associated data?\n\nThis will remove all orders, disputes, products, profiles, and messages. This action CANNOT be undone.',
          ),
          style: TextStyle(color: dim, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('إلغاء', 'Cancel'), style: TextStyle(color: dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('نعم، احذف نهائياً', 'Yes, Delete Permanently'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiService.delete('/admin/users/$userId');
      if (!mounted) return;

      if (res.statusCode == 200) {
        await _loadUsers();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('تم حذف حساب المستخدم بجميع بياناته بنجاح.', 'User account and all data deleted successfully.')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['error']?.toString() ?? t('فشل حذف الحساب.', 'Failed to delete user.')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('حدث خطأ أثناء الحذف: $e', 'Error deleting user: $e')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _profileButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w600, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.centerRight,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Expanded(child: Text(val, style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _roleBadge(String roleKey) {
    Color color = Colors.blue;
    String label = roleKey;

    switch (roleKey.toLowerCase()) {
      case 'artisan':
      case 'craftsman':
        color = const Color(0xFFD4A017);
        label = t('حرفي', 'Artisan');
        break;
      case 'customer':
      case 'client':
        color = Colors.blue;
        label = t('زبون', 'Customer');
        break;
      case 'delivery':
      case 'driver':
        color = Colors.teal;
        label = t('مندوب توصيل', 'Delivery');
        break;
      case 'exhibition_owner':
      case 'organizer':
        color = Colors.purple;
        label = t('منظم معارض', 'Exhibition Owner');
        break;
      case 'admin':
        color = Colors.redAccent;
        label = t('إدارة', 'Admin');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredUsers;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header title & count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.manage_accounts_rounded, color: accent, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        t('إدارة المستخدمين والحسابات', 'User & Account Management'),
                        style: GoogleFonts.cairo(color: text, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: accent),
                    onPressed: _loadUsers,
                    tooltip: t('تحديث البيانات', 'Refresh Users'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar & Sort Button Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: TextStyle(color: text, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: t('بحث بالاسم، الإيميل، المدينة، الهاتف...', 'Search name, email, phone, city...'),
                        hintStyle: TextStyle(color: dim, fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 20, color: dim),
                        filled: true,
                        fillColor: surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => setState(() => _sortNewest = !_sortNewest),
                    icon: Icon(_sortNewest ? Icons.south : Icons.north, color: accent),
                    tooltip: _sortNewest ? t('الأحدث أولاً', 'Newest first') : t('الأقدم أولاً', 'Oldest first'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Role Filter Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _filterChip('all', t('الكل', 'All')),
                    const SizedBox(width: 8),
                    _filterChip('customer', t('الزبائن', 'Customers')),
                    const SizedBox(width: 8),
                    _filterChip('artisan', t('الحرفيين', 'Artisans')),
                    const SizedBox(width: 8),
                    _filterChip('delivery', t('المندوبين', 'Delivery Drivers')),
                    const SizedBox(width: 8),
                    _filterChip('exhibition_owner', t('منظمي المعارض', 'Exhibition Owners')),
                    const SizedBox(width: 8),
                    _filterChip('admin', t('الإدارة', 'Admins')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Users List
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                const SizedBox(height: 8),
                                Text(_errorMessage!, style: TextStyle(color: dim, fontSize: 13)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: _loadUsers,
                                  style: ElevatedButton.styleFrom(backgroundColor: accent),
                                  child: Text(t('إعادة المحاولة', 'Retry'), style: const TextStyle(color: Colors.black)),
                                ),
                              ],
                            ),
                          )
                        : list.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_search_outlined, size: 48, color: dim.withValues(alpha: 0.4)),
                                    const SizedBox(height: 12),
                                    Text(t('لا يوجد مستخدمون يطابقون خيارات البحث', 'No users found matching filter'), style: GoogleFonts.cairo(color: dim, fontSize: 14)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (ctx, idx) {
                                  final user = list[idx];
                                  final name = user['name']?.toString() ?? '—';
                                  final email = user['email']?.toString() ?? '—';
                                  final phone = user['phone']?.toString() ?? '—';
                                  final city = user['city']?.toString() ?? 'Nablus';
                                  final isSuspended = user['isSuspended'] == true;

                                  final roles = (user['roles'] as List?)?.map((r) => r.toString().toLowerCase()).toList() ?? [];
                                  if (user['role'] != null && !roles.contains(user['role'].toString().toLowerCase())) {
                                    roles.add(user['role'].toString().toLowerCase());
                                  }

                                  return InkWell(
                                    onTap: () => _showUserProfileModal(user),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isSuspended ? Colors.redAccent.withValues(alpha: 0.5) : border),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: accent.withValues(alpha: 0.15),
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                              style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 18),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: GoogleFonts.cairo(color: text, fontWeight: FontWeight.bold, fontSize: 15),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (isSuspended)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.redAccent.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          t('محظور', 'Suspended'),
                                                          style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text('$email • $phone • $city', style: TextStyle(color: dim, fontSize: 11), overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: roles.map((r) => _roleBadge(r)).toList(),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.chevron_right, color: dim),
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
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedRoleFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent : surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accent : border),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: isSelected ? (widget.isDarkMode ? Colors.black : Colors.white) : dim,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

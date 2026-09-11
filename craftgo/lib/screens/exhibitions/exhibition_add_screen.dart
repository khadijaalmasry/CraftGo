import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/location_picker_screen.dart';
import '../../app_state.dart';
import '../../services/exhibitions_service.dart';
import '../../services/cloudinary_service.dart';

class ExhibitionAddScreen extends StatefulWidget {
  final Map<String, dynamic>? existingExhibition;
  final bool isAdminView;

  const ExhibitionAddScreen({
    super.key,
    this.existingExhibition,
    this.isAdminView = false,
  });

  @override
  State<ExhibitionAddScreen> createState() => _ExhibitionAddScreenState();
}

class _ExhibitionAddScreenState extends State<ExhibitionAddScreen> {
  // ── Controllers ──────────────────────────────────────────────────────
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _boothPriceController = TextEditingController();

  // ── Step 1: Basic Info ──────────────────────────────────────────────
  String? _eventType;
  String? _eventTheme;
  String? _targetAudience;
  String? _priceRange;
  bool _isPublic = true;

  final List<String> _eventTypes = [
    'Heritage & Craft',
    'Art Exhibition',
    'Craft Fair',
    'Heritage Festival',
    'Workshop',
    'Pop-up Market',
    'Private Showing',
    'Other',
  ];

  final Map<String, String> _eventThemeLabels = {
    'Traditional': 'تراثي',
    'Modern': 'عصري',
    'Eco/Sustainable': 'بيئي / مستدام',
    'Cultural Heritage': 'التراث الثقافي',
    'Luxury/High-End': 'فاخر',
    'Family-Friendly': 'مناسب للعائلة',
  };

  List<String> get _eventThemes => _eventThemeLabels.keys.toList();

  final List<String> _targetAudiences = [
    'General Public',
    'Collectors',
    'Art Enthusiasts',
    'Families',
    'Professionals',
  ];

  final List<String> _priceRanges = [
    'Free',
    '5-15 JD',
    '10-20 JD',
    '10-25 JD',
    '25-50 JD',
    '50-100 JD',
    '100+ JD',
  ];

  // ── Step 6: Venue Verification ──────────────────────────────────────
  final List<String> _venueTypes = [
    'Public Venue',
    'Private Gallery',
    'Community Center',
    'Private Property',
    'Other',
  ];

  // ── Step 2: Location ────────────────────────────────────────────────
  LatLng? _selectedLocation;
  String? _selectedAddress;

  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _extraDetailsController = TextEditingController();

  bool _useManualLocation = false;

  String get _manualAddress {
    final parts = [
      _streetController.text.trim(),
      _buildingController.text.trim(),
      _cityController.text.trim(),
      _countryController.text.trim(),
    ].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  // ── Step 3: Dates & Times ────────────────────────────────────────────
  final List<Map<String, dynamic>> _selectedDates = [];
  DateTime _calendarMonth = DateTime.now();
  final Set<DateTime> _selectedDateSet = {};

  // ── Step 4: Craft Categories ────────────────────────────────────────
  final List<String> _allCrafts = [
    'Woodworking',
    'Pottery',
    'Jewelry',
    'Textiles',
    'Painting',
    'Calligraphy',
    'Ceramics',
    'Leatherwork',
    'Glass',
    'Metalwork',
    'Digital Art',
    'Other',
  ];
  final Set<String> _selectedCrafts = {};

  // ── Step 5: Booth Setup ──────────────────────────────────────────────
  int _boothRows = 2;
  int _boothColumns = 3;
  double _boothPrice = 0;

  // ── Step 6: Venue Verification ──────────────────────────────────────
  String? _venueType;
  bool _hasPermit = false;
  bool _hasBusinessLicense = false;
  bool _agreeToShareLocation = false;

  final TextEditingController _permitNumberController = TextEditingController();
  final TextEditingController _issuerNameController = TextEditingController();
  final TextEditingController _issuerPhoneController = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;

  // ── NEW: Permit document upload ──────────────────────────────────────
  String? _permitDocumentUrl;
  bool _isUploading = false;

  // ── UI State ──────────────────────────────────────────────────────────
  int _currentStep = 0;
  final int _totalSteps = 7;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingExhibition != null;

  // ── Theme helpers ──────────────────────────────────────────────────
  Color get bg => context.watch<AppState>().isDarkMode
      ? const Color(0xFF0D1420)
      : const Color(0xFFF5F6F8);
  Color get surface => context.watch<AppState>().isDarkMode
      ? const Color(0xFF1C2431)
      : Colors.white;
  Color get text =>
      context.watch<AppState>().isDarkMode ? Colors.white : Colors.black87;
  Color get dim =>
      context.watch<AppState>().isDarkMode ? Colors.white60 : Colors.black54;
  Color get border => context.watch<AppState>().isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.1);
  Color get accent => const Color(0xFFD4A017);

  String t(String ar, String en) =>
      context.watch<AppState>().isArabic ? ar : en;

  // ── Helper to display theme label ──────────────────────────────────
  String _getThemeDisplay() {
    if (_eventTheme == null) return t('غير محدد', 'Not specified');
    final isArabic = context.watch<AppState>().isArabic;
    if (isArabic) {
      return _eventThemeLabels[_eventTheme] ?? _eventTheme!;
    }
    return _eventTheme!;
  }

  bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final str = value.toString().trim().toLowerCase();
    if (str == '1' || str == 'true' || str == 'yes' || str == 'public')
      return true;
    if (str == '0' || str == 'false' || str == 'no' || str == 'private')
      return false;
    return defaultValue;
  }

  // ── Pre‑fill if editing ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (widget.existingExhibition != null) {
      final ex = widget.existingExhibition!;
      _titleController.text = ex['name'] ?? ex['nameEn'] ?? '';
      _descriptionController.text =
          ex['description'] ?? ex['descriptionEn'] ?? '';
      _eventType = ex['eventType'] ?? ex['type'];

      // Theme initialization
      final rawTheme = ex['eventTheme'] ?? ex['theme'];
      if (rawTheme != null && rawTheme.toString().isNotEmpty) {
        final themeStr = rawTheme.toString();
        if (_eventThemeLabels.containsKey(themeStr)) {
          _eventTheme = themeStr;
        } else {
          final match = _eventThemeLabels.entries.firstWhere(
            (e) => e.value == themeStr,
            orElse: () => const MapEntry('', ''),
          );
          _eventTheme = match.key.isNotEmpty ? match.key : themeStr;
        }
      }

      _targetAudience = ex['targetAudience']?.toString();
      _priceRange = ex['priceRange']?.toString();
      _isPublic = _parseBool(ex['isPublic'] ?? ex['is_public'],
          defaultValue: ex['type'] == 'Public' || ex['type'] == null);

      if (ex['latitude'] != null && ex['longitude'] != null) {
        final lat = double.tryParse(ex['latitude'].toString());
        final lng = double.tryParse(ex['longitude'].toString());
        if (lat != null && lng != null) {
          _selectedLocation = LatLng(lat, lng);
        }
      }

      _selectedAddress = ex['location']?.toString() ?? '';
      _useManualLocation =
          _parseBool(ex['manualLocation'] ?? ex['manual_location']);
      _countryController.text = ex['country']?.toString() ?? '';
      _cityController.text = ex['city']?.toString() ?? '';
      _streetController.text = ex['street']?.toString() ?? '';
      _buildingController.text = ex['building']?.toString() ?? '';
      _extraDetailsController.text = ex['extraDetails']?.toString() ?? '';

      // Capacity initialization
      final capVal = ex['capacity'] ?? ex['maxCapacity'] ?? ex['max_capacity'];
      if (capVal != null && capVal.toString().isNotEmpty) {
        _capacityController.text = capVal.toString();
      }

      // Parse dates
      final datesRaw = ex['selectedDates'] ?? ex['dates'];
      if (datesRaw is List && datesRaw.isNotEmpty) {
        _selectedDates.clear();
        _selectedDateSet.clear();
        for (var d in datesRaw) {
          if (d is Map) {
            DateTime? dt;
            if (d['date'] is DateTime) {
              dt = d['date'] as DateTime;
            } else if (d['date'] != null) {
              dt = DateTime.tryParse(d['date'].toString());
            }

            if (dt != null) {
              final dateOnly = DateTime(dt.year, dt.month, dt.day);
              _selectedDateSet.add(dateOnly);

              TimeOfDay startT = const TimeOfDay(hour: 10, minute: 0);
              TimeOfDay endT = const TimeOfDay(hour: 18, minute: 0);

              if (d['start'] is TimeOfDay) {
                startT = d['start'] as TimeOfDay;
              } else if (d['start'] != null) {
                final parts = d['start'].toString().split(':');
                if (parts.length >= 2) {
                  startT = TimeOfDay(
                    hour: int.tryParse(parts[0]) ?? 10,
                    minute: int.tryParse(parts[1]) ?? 0,
                  );
                }
              }

              if (d['end'] is TimeOfDay) {
                endT = d['end'] as TimeOfDay;
              } else if (d['end'] != null) {
                final parts = d['end'].toString().split(':');
                if (parts.length >= 2) {
                  endT = TimeOfDay(
                    hour: int.tryParse(parts[0]) ?? 18,
                    minute: int.tryParse(parts[1]) ?? 0,
                  );
                }
              }

              _selectedDates.add({
                'date': dateOnly,
                'start': startT,
                'end': endT,
              });
            }
          }
        }
      } else if (ex['startDate'] != null && ex['endDate'] != null) {
        final dtStart = DateTime.tryParse(ex['startDate'].toString());
        final dtEnd = DateTime.tryParse(ex['endDate'].toString());
        if (dtStart != null && dtEnd != null) {
          _selectedDates.clear();
          _selectedDateSet.clear();
          for (var d = dtStart;
              !d.isAfter(dtEnd);
              d = d.add(const Duration(days: 1))) {
            final dateOnly = DateTime(d.year, d.month, d.day);
            _selectedDateSet.add(dateOnly);
            _selectedDates.add({
              'date': dateOnly,
              'start': const TimeOfDay(hour: 10, minute: 0),
              'end': const TimeOfDay(hour: 18, minute: 0),
            });
          }
        }
      }

      if (ex['crafts'] != null) {
        try {
          if (ex['crafts'] is List) {
            _selectedCrafts.addAll(
                List<String>.from(ex['crafts'].map((e) => e.toString())));
          }
        } catch (_) {}
      }
      _boothRows = int.tryParse(ex['boothRows']?.toString() ?? '') ?? 2;
      _boothColumns = int.tryParse(ex['boothColumns']?.toString() ?? '') ?? 3;

      // Booth price initialization
      final rawPrice = ex['boothPrice'] ?? ex['booth_price'];
      if (rawPrice != null) {
        _boothPrice = double.tryParse(rawPrice.toString()) ?? 0.0;
        if (_boothPrice > 0) {
          _boothPriceController.text = _boothPrice % 1 == 0
              ? _boothPrice.toInt().toString()
              : _boothPrice.toString();
        } else {
          _boothPriceController.text = '';
        }
      }

      _venueType = ex['venueType']?.toString();
      _hasPermit = _parseBool(ex['hasPermit'] ?? ex['has_permit']);
      _hasBusinessLicense =
          _parseBool(ex['hasBusinessLicense'] ?? ex['has_business_license']);
      _permitNumberController.text = ex['permitNumber']?.toString() ?? '';
      _issuerNameController.text = ex['issuerName']?.toString() ?? '';
      _issuerPhoneController.text = ex['issuerPhone']?.toString() ?? '';
      _issueDate = ex['issueDate'] != null
          ? DateTime.tryParse(ex['issueDate'].toString())
          : null;
      _expiryDate = ex['expiryDate'] != null
          ? DateTime.tryParse(ex['expiryDate'].toString())
          : null;
      _permitDocumentUrl = ex['permitDocumentUrl']?.toString();
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _submitExhibition();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _titleController.text.trim().isNotEmpty &&
            _eventType != null &&
            _eventTheme != null;
      case 1:
        if (_useManualLocation) {
          return _cityController.text.trim().isNotEmpty &&
              _countryController.text.trim().isNotEmpty;
        } else {
          return _selectedAddress != null && _selectedAddress!.isNotEmpty;
        }
      case 2:
        return _selectedDates.isNotEmpty;
      case 3:
        return _selectedCrafts.isNotEmpty;
      case 4:
        return true;
      case 5:
        return _venueType != null;
      case 6:
        return true;
      default:
        return true;
    }
  }

  // ── Submit Exhibition ────────────────────────────────────────────────
  void _submitExhibition() async {
    setState(() => _isSubmitting = true);
    final state = context.read<AppState>();
    final currentUserId = state.userId;

    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('يرجى تسجيل الدخول', 'Please login')),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    final ownerId = widget.isAdminView && widget.existingExhibition != null
        ? widget.existingExhibition!['ownerId']?.toString() ?? currentUserId
        : currentUserId;

    final name = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location =
        _useManualLocation ? _manualAddress : (_selectedAddress ?? 'Bethlehem');

    final capacity = int.tryParse(_capacityController.text.trim()) ?? 50;
    final boothPrice =
        double.tryParse(_boothPriceController.text.trim()) ?? _boothPrice;

    final startDateStr = _getStartDate();
    final endDateStr = _getEndDate();
    final startDate =
        startDateStr.isNotEmpty ? DateTime.tryParse(startDateStr) : null;
    final endDate =
        endDateStr.isNotEmpty ? DateTime.tryParse(endDateStr) : null;

    final selectedDatesJson = _selectedDates.map((d) {
      return {
        'date': (d['date'] as DateTime).toIso8601String(),
        'start': _timeOfDayToString(d['start'] as TimeOfDay),
        'end': _timeOfDayToString(d['end'] as TimeOfDay),
      };
    }).toList();

    // ── Determine status & verified ──────────────────────────────────
    final String finalStatus;
    final bool finalVerified;
    if (_isEditing) {
      finalStatus =
          widget.existingExhibition?['status']?.toString().toLowerCase() ??
              'upcoming';
      finalVerified = widget.existingExhibition?['verified'] ?? false;
    } else {
      finalStatus = 'pending';
      finalVerified = false;
    }

    // ── Gradient must be list of strings ────────────────────────────
    final gradient =
        widget.existingExhibition?['gradient'] ?? _getRandomGradient();
    // Ensure gradient is a List<String> (if it comes from existing, it's already strings)
    List<String> gradientStrings;
    if (gradient is List && gradient.isNotEmpty) {
      if (gradient.first is String) {
        gradientStrings = gradient.cast<String>();
      } else {
        // Fallback: convert to hex
        gradientStrings = _getRandomGradient();
      }
    } else {
      gradientStrings = _getRandomGradient();
    }

    final payload = {
      'ownerId': ownerId,
      'name': name,
      'nameEn': name,
      'description': description,
      'descriptionEn': description,
      'location': location,
      'locationEn': location,
      'eventType': _eventType,
      'eventTheme': _eventTheme,
      'theme': _eventTheme,
      'targetAudience': _targetAudience,
      'priceRange': _priceRange,
      'type': _isPublic ? 'Public' : 'Private',
      'isPublic': _isPublic,
      'country': _countryController.text.trim(),
      'city': _cityController.text.trim(),
      'street': _streetController.text.trim(),
      'building': _buildingController.text.trim(),
      'extraDetails': _extraDetailsController.text.trim(),
      'latitude': _useManualLocation ? null : _selectedLocation?.latitude,
      'longitude': _useManualLocation ? null : _selectedLocation?.longitude,
      'manualLocation': _useManualLocation,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'selectedDates': selectedDatesJson,
      'crafts': _selectedCrafts.toList(),
      'boothRows': _boothRows,
      'boothColumns': _boothColumns,
      'boothPrice': boothPrice,
      'venueType': _venueType,
      'hasPermit': _hasPermit,
      'hasBusinessLicense': _hasBusinessLicense,
      'permitNumber': _permitNumberController.text.trim(),
      'issuerName': _issuerNameController.text.trim(),
      'issuerPhone': _issuerPhoneController.text.trim(),
      'issueDate': _issueDate?.toIso8601String(),
      'expiryDate': _expiryDate?.toIso8601String(),
      'capacity': capacity,
      'maxCapacity': capacity,
      'status': finalStatus,
      'verified': finalVerified,
      'permitDocumentUrl': _permitDocumentUrl,
      'gradient': gradientStrings,
      'imageUrl': widget.existingExhibition?['imageUrl'],
    };

    Map<String, dynamic>? resExhibition;
    if (_isEditing) {
      resExhibition = await ExhibitionsService.updateExhibition(
        widget.existingExhibition!['id'].toString(),
        payload,
      );
    } else {
      resExhibition = await ExhibitionsService.createExhibition(payload);
    }

    if (!mounted) return;

    final exhibition = {
      'id': resExhibition?['id']?.toString() ??
          widget.existingExhibition?['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'nameEn': name,
      'description': description,
      'eventType': _eventType,
      'eventTheme': _eventTheme,
      'theme': _eventTheme,
      'targetAudience': _targetAudience,
      'priceRange': _priceRange,
      'type': _isPublic ? 'Public' : 'Private',
      'isPublic': _isPublic,
      'status': finalStatus,
      'verified': finalVerified,
      'location': location,
      'locationEn': location,
      'latitude': _useManualLocation ? null : _selectedLocation?.latitude,
      'longitude': _useManualLocation ? null : _selectedLocation?.longitude,
      'manualLocation': _useManualLocation,
      'dates': _selectedDates
          .map((d) => {
                'date': d['date'] as DateTime,
                'start': d['start'] as TimeOfDay,
                'end': d['end'] as TimeOfDay,
              })
          .toList(),
      'crafts': _selectedCrafts.toList(),
      'boothRows': _boothRows,
      'boothColumns': _boothColumns,
      'boothPrice': boothPrice,
      'venueType': _venueType,
      'hasPermit': _hasPermit,
      'hasBusinessLicense': _hasBusinessLicense,
      'capacity': capacity,
      'maxCapacity': capacity,
      'country': _countryController.text.trim(),
      'city': _cityController.text.trim(),
      'street': _streetController.text.trim(),
      'building': _buildingController.text.trim(),
      'extraDetails': _extraDetailsController.text.trim(),
      'permitNumber': _permitNumberController.text.trim(),
      'issuerName': _issuerNameController.text.trim(),
      'issuerPhone': _issuerPhoneController.text.trim(),
      'issueDate': _issueDate?.toIso8601String(),
      'expiryDate': _expiryDate?.toIso8601String(),
      'permitDocumentUrl': _permitDocumentUrl,
      'interested': widget.existingExhibition?['interested'] ?? 0,
      'gradient': gradientStrings,
      'startDate': startDateStr,
      'endDate': endDateStr,
      'participants': widget.existingExhibition?['participants'] ??
          _generateMockParticipants(),
    };

    setState(() => _isSubmitting = false);
    Navigator.pop(context, exhibition);
  }

  // ── Helper to convert TimeOfDay to string ──────────────────────────
  String _timeOfDayToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ── Mock participants ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _generateMockParticipants() {
    final total = _boothRows * _boothColumns;
    final names = [
      'أحمد الحداد',
      'سارة الزهراني',
      'محمد العمري',
      'ريم الخالدي'
    ];
    final crafts = ['نجارة', 'مجوهرات', 'فخار', 'نسيج'];
    List<Map<String, dynamic>> participants = [];

    for (int i = 0; i < total; i++) {
      if (i < names.length) {
        participants.add({
          'boothId':
              '${String.fromCharCode(65 + (i ~/ _boothColumns))}${(i % _boothColumns) + 1}',
          'name': names[i % names.length],
          'craft': crafts[i % crafts.length],
          'status': 'confirmed',
        });
      } else {
        participants.add({
          'boothId':
              '${String.fromCharCode(65 + (i ~/ _boothColumns))}${(i % _boothColumns) + 1}',
          'name': null,
          'craft': null,
          'status': 'available',
        });
      }
    }
    return participants;
  }

  String _getStartDate() {
    if (_selectedDates.isEmpty) return '';
    final sorted = _selectedDates.map((d) => d['date'] as DateTime).toList()
      ..sort();
    return DateFormat('yyyy-MM-dd').format(sorted.first);
  }

  String _getEndDate() {
    if (_selectedDates.isEmpty) return '';
    final sorted = _selectedDates.map((d) => d['date'] as DateTime).toList()
      ..sort();
    return DateFormat('yyyy-MM-dd').format(sorted.last);
  }

  // ── Gradient helper: returns list of hex color strings ──────────────
  List<String> _getRandomGradient() {
    final List<List<String>> gradients = [
      ['#1976D2', '#009688'],
      ['#E64A19', '#D32F2F'],
      ['#7B1FA2', '#3F51B5'],
      ['#388E3C', '#00796B'],
      ['#455A64', '#1976D2'],
      ['#FBC02D', '#F57C00'],
    ];
    return gradients[DateTime.now().millisecondsSinceEpoch % gradients.length];
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isArabic = appState.isArabic;

    return Directionality(
      textDirection: isArabic ? ui.TextDirection.rtl : ui.TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
                isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                color: text),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isEditing
                ? t('تعديل المعرض', 'Edit Exhibition')
                : t('إضافة معرض جديد', 'Add New Exhibition'),
            style: GoogleFonts.cairo(
                color: text, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: border,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 4,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${t('الخطوة', 'Step')} ${_currentStep + 1}/$_totalSteps',
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  const Spacer(),
                  Text(_getStepTitle(),
                      style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _buildStepContent(),
                ),
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(t('السابق', 'Back'),
                            style: TextStyle(color: dim)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _canProceed ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canProceed ? accent : Colors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              _currentStep == _totalSteps - 1
                                  ? _isEditing
                                      ? t('تحديث المعرض', 'Update Exhibition')
                                      : t('إنشاء المعرض', 'Create Exhibition')
                                  : t('متابعة', 'Continue'),
                              style: TextStyle(
                                color:
                                    _canProceed ? Colors.black : Colors.white70,
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
      ),
    );
  }

  String _getStepTitle() {
    final titles = [
      t('المعلومات الأساسية', 'Basic Info'),
      t('الموقع', 'Location'),
      t('التواريخ والأوقات', 'Dates & Times'),
      t('التصنيفات الحرفية', 'Craft Categories'),
      t('الأكشاك', 'Booths'),
      t('التحقق من المكان', 'Venue Verification'),
      t('تأكيد المعرض', 'Confirm Exhibition'),
    ];
    return titles[_currentStep];
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildLocationStep();
      case 2:
        return _buildDatesStep();
      case 3:
        return _buildCraftsStep();
      case 4:
        return _buildBoothStep();
      case 5:
        return _buildVenueVerificationStep();
      case 6:
        return _buildConfirmationStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Confirmation Summary ──────────────────────────────────────────
  Widget _buildConfirmationStep() {
    final titleText = _titleController.text.trim();
    final capText = _capacityController.text.trim();
    final themeDisplay = _getThemeDisplay();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t('مراجعة تفاصيل المعرض قبل الإنشاء',
                      'Review exhibition details before creating'),
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSummaryItem(
          icon: Icons.title,
          label: t('العنوان', 'Title'),
          value: titleText.isEmpty ? t('غير محدد', 'Not specified') : titleText,
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.category,
          label: t('النوع', 'Type'),
          value: _eventType ?? t('غير محدد', 'Not specified'),
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.theater_comedy,
          label: t('الموضوع', 'Theme'),
          value: themeDisplay,
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.location_on,
          label: t('الموقع', 'Location'),
          value: _useManualLocation
              ? (_manualAddress.isEmpty
                  ? t('غير محدد', 'Not specified')
                  : _manualAddress)
              : (_selectedAddress ?? t('غير محدد', 'Not specified')),
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.calendar_today,
          label: t('التواريخ', 'Dates'),
          value: _selectedDates.isNotEmpty
              ? '${DateFormat('dd/MM/yyyy').format(_selectedDates.first['date'])} - ${DateFormat('dd/MM/yyyy').format(_selectedDates.last['date'])}'
              : t('غير محدد', 'Not specified'),
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.handyman,
          label: t('الحرف', 'Crafts'),
          value: _selectedCrafts.isNotEmpty
              ? _selectedCrafts.join(', ')
              : t('غير محدد', 'Not specified'),
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.storefront,
          label: t('الأكشاك', 'Booths'),
          value:
              '${_boothRows * _boothColumns} ${t('كشك', 'booths')} (${_boothRows}x$_boothColumns)',
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.verified,
          label: t('نوع المكان', 'Venue Type'),
          value: _venueType ?? t('غير محدد', 'Not specified'),
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.people,
          label: t('العدد الأقصى', 'Max Capacity'),
          value: capText.isEmpty ? t('غير محدد', 'Not specified') : capText,
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
          icon: Icons.public,
          label: t('الرؤية', 'Visibility'),
          value: _isPublic ? t('عام', 'Public') : t('خاص', 'Private'),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFD4A017)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('تأكد من جميع المعلومات قبل إنشاء المعرض. يمكنك تعديلها لاحقاً من صفحة المعرض.',
                      'Please verify all information before creating the exhibition. You can edit it later from the exhibition page.'),
                  style: TextStyle(color: dim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Text(label,
                style: TextStyle(
                    color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                  color: text, fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step builders ──────────────────────────────────────────────────

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(_titleController, t('عنوان المعرض', 'Exhibition Title'),
            hint: t('مثال: معرض الحرف اليدوية السنوي',
                'e.g. Annual Handicraft Fair')),
        const SizedBox(height: 16),
        _buildTextField(_descriptionController, t('الوصف', 'Description'),
            maxLines: 4, hint: t('صف معرضك...', 'Describe your exhibition...')),
        const SizedBox(height: 16),
        _buildDropdown(
          label: t('نوع المعرض', 'Event Type'),
          value: _eventType,
          items: _eventTypes,
          onChanged: (v) => setState(() => _eventType = v),
          hint: t('اختر النوع', 'Select type'),
        ),
        const SizedBox(height: 16),
        _buildLocalizedDropdown(
          label: t('موضوع المعرض', 'Event Theme'),
          value: _eventTheme,
          items: _eventThemes,
          labelMap: _eventThemeLabels,
          onChanged: (v) => setState(() => _eventTheme = v),
          hint: t('اختر الموضوع', 'Select theme'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: t('الجمهور المستهدف', 'Target Audience'),
                value: _targetAudience,
                items: _targetAudiences,
                onChanged: (v) => setState(() => _targetAudience = v),
                hint: t('اختر', 'Select'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                label: t('نطاق السعر', 'Price Range'),
                value: _priceRange,
                items: _priceRanges,
                onChanged: (v) => setState(() => _priceRange = v),
                hint: t('اختر', 'Select'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _capacityController,
          t('العدد الأقصى للحرفيين', 'Max Artisans Capacity'),
          keyboardType: TextInputType.number,
          hint: t('مثال: 20', 'e.g. 20'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(t('عام', 'Public'), style: TextStyle(color: text)),
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    activeThumbColor: accent,
                    activeTrackColor: accent.withValues(alpha: 0.5),
                  ),
                  Text(t('خاص', 'Private'), style: TextStyle(color: text)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationStep() {
    final appState = context.read<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildToggleChip(
              label: t('اختر من الخريطة', 'Pick from Map'),
              selected: !_useManualLocation,
              onTap: () => setState(() => _useManualLocation = false),
            ),
            const SizedBox(width: 8),
            _buildToggleChip(
              label: t('إدخال يدوي', 'Enter Manually'),
              selected: _useManualLocation,
              onTap: () => setState(() => _useManualLocation = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_useManualLocation)
          _buildManualLocationFields()
        else
          _buildMapPicker(appState),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : text,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildManualLocationFields() {
    return Column(
      children: [
        _buildTextField(_countryController, t('الدولة', 'Country'),
            hint: t('مثال: الأردن', 'e.g. Jordan')),
        const SizedBox(height: 12),
        _buildTextField(_cityController, t('المدينة', 'City'),
            hint: t('مثال: عمّان', 'e.g. Amman')),
        const SizedBox(height: 12),
        _buildTextField(_streetController, t('الشارع', 'Street'),
            hint: t('مثال: شارع الرينبو', 'e.g. Rainbow Street')),
        const SizedBox(height: 12),
        _buildTextField(
            _buildingController, t('رقم المبنى / الوحدة', 'Building / Unit'),
            hint: t('اختياري', 'Optional')),
        const SizedBox(height: 12),
        _buildTextField(
            _extraDetailsController, t('تفاصيل إضافية', 'Additional Details'),
            maxLines: 2,
            hint: t('مثال: الطابق الثاني، مقابل البنك',
                'e.g. 2nd floor, opposite the bank')),
      ],
    );
  }

  Widget _buildMapPicker(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('اختر موقع المعرض على الخريطة',
              'Pick the exhibition location on map'),
          style: TextStyle(color: dim, fontSize: 13),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LocationPickerScreen(
                  isArabic: appState.isArabic,
                  isDarkMode: appState.isDarkMode,
                ),
              ),
            );
            if (result != null && mounted) {
              setState(() {
                _selectedLocation = LatLng(
                  result['latitude'],
                  result['longitude'],
                );
                _selectedAddress = result['address'];
              });
            }
          },
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: _selectedAddress == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 40, color: dim),
                        const SizedBox(height: 8),
                        Text(
                          t('اضغط لتحديد الموقع', 'Tap to pick location'),
                          style: TextStyle(color: dim),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child:
                              Icon(Icons.location_on, size: 40, color: accent),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedAddress!,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.white, size: 16),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('يمكنك تغيير الموقع بالضغط على الخريطة',
              'Tap on the map to change location'),
          style:
              TextStyle(color: dim, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildDatesStep() {
    final isArabic = context.watch<AppState>().isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('اختر أيام المعرض', 'Select exhibition days'),
          style:
              TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildMonthCalendar(isArabic),
        const SizedBox(height: 20),
        if (_selectedDates.isNotEmpty) ...[
          Text(
            t('الأيام المحددة مع الأوقات', 'Selected days with times'),
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._selectedDates.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, d MMM yyyy').format(item['date']),
                      style: TextStyle(color: text),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatTime(item['start']),
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold),
                      ),
                      const Text(' - '),
                      Text(
                        _formatTime(item['end']),
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: dim, size: 16),
                    onPressed: () => _editTime(idx),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.redAccent, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedDates.removeAt(idx);
                        _selectedDateSet.remove(item['date']);
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMonthCalendar(bool isArabic) {
    final firstDayOfMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final daysInMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday;
    final offset = startWeekday - 1;

    final monthName = DateFormat('MMMM yyyy').format(_calendarMonth);
    final weekDays = isArabic
        ? ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    List<Widget> dayWidgets = [];
    for (int i = 0; i < offset; i++) {
      dayWidgets.add(Container());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
      final isSelected = _selectedDateSet.contains(date);
      final isToday = DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;

      dayWidgets.add(
        GestureDetector(
          onTap: () => _toggleDate(date),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? accent
                  : (isToday
                      ? accent.withValues(alpha: 0.15)
                      : Colors.transparent),
              border: isToday ? Border.all(color: accent, width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: isSelected ? Colors.black : text,
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _calendarMonth =
                      DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                });
              },
            ),
            Text(
              monthName,
              style: TextStyle(
                  color: text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _calendarMonth =
                      DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.2,
          children: weekDays
              .map((e) => Center(
                    child: Text(
                      e,
                      style: TextStyle(
                          color: dim,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.2,
          children: dayWidgets,
        ),
      ],
    );
  }

  void _toggleDate(DateTime date) {
    final existing = _selectedDates.indexWhere((d) =>
        d['date'].year == date.year &&
        d['date'].month == date.month &&
        d['date'].day == date.day);

    if (existing != -1) {
      setState(() {
        _selectedDates.removeAt(existing);
        _selectedDateSet.remove(date);
      });
    } else {
      setState(() {
        _selectedDates.add({
          'date': date,
          'start': const TimeOfDay(hour: 10, minute: 0),
          'end': const TimeOfDay(hour: 18, minute: 0),
        });
        _selectedDateSet.add(date);
      });
    }
  }

  void _editTime(int index) {
    final item = _selectedDates[index];
    final isArabic = context.read<AppState>().isArabic;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            Text(
              isArabic ? 'اختر وقت البدء' : 'Pick Start Time',
              style: TextStyle(
                  color: text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle:
                        TextStyle(color: text, fontSize: 20),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    item['start'].hour,
                    item['start'].minute,
                  ),
                  onDateTimeChanged: (dateTime) {
                    setState(() {
                      _selectedDates[index]['start'] = TimeOfDay(
                        hour: dateTime.hour,
                        minute: dateTime.minute,
                      );
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArabic ? 'اختر وقت الانتهاء' : 'Pick End Time',
              style: TextStyle(
                  color: text, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle:
                        TextStyle(color: text, fontSize: 20),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    item['end'].hour,
                    item['end'].minute,
                  ),
                  onDateTimeChanged: (dateTime) {
                    setState(() {
                      _selectedDates[index]['end'] = TimeOfDay(
                        hour: dateTime.hour,
                        minute: dateTime.minute,
                      );
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  t('تأكيد', 'Confirm'),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    return '$hour:$minute $period';
  }

  Widget _buildCraftsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('اختر الحرف التي ستعرض في المعرض',
              'Select crafts featured in the exhibition'),
          style:
              TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Text(
          t('اختر كل ما يناسب (اختياري متعدد)',
              'Select all that apply (multi-select)'),
          style: TextStyle(color: dim, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _allCrafts.map((craft) {
            final isSelected = _selectedCrafts.contains(craft);
            final label = t(craft, craft);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCrafts.remove(craft);
                  } else {
                    _selectedCrafts.add(craft);
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? accent : surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? accent : border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check, color: Colors.black, size: 16),
                    if (isSelected) const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.black : text,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_selectedCrafts.isEmpty)
          Text(
            t('لم تختر أي حرفة بعد', 'No crafts selected yet'),
            style: TextStyle(
                color: dim, fontSize: 13, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }

  Widget _buildBoothStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('إعداد الأكشاك', 'Booth Setup'),
          style:
              TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          t('حدد عدد الأكشاك في معرضك',
              'Define the number of booths in your exhibition'),
          style: TextStyle(color: dim, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('الصفوف', 'Rows'), style: TextStyle(color: dim)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (_boothRows > 1) {
                            setState(() => _boothRows--);
                          }
                        },
                      ),
                      Text(
                        '$_boothRows',
                        style: TextStyle(
                            color: text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => _boothRows++),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('الأعمدة', 'Columns'), style: TextStyle(color: dim)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (_boothColumns > 1) {
                            setState(() => _boothColumns--);
                          }
                        },
                      ),
                      Text(
                        '$_boothColumns',
                        style: TextStyle(
                            color: text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => _boothColumns++),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          t('سعر الكشك (اختياري)', 'Booth Price (Optional)'),
          style: TextStyle(color: dim),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _boothPriceController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: text),
                onChanged: (v) {
                  _boothPrice = double.tryParse(v) ?? 0;
                },
                decoration: InputDecoration(
                  hintText: t('مثال: 25', 'e.g. 25'),
                  hintStyle: TextStyle(color: dim),
                  prefixIcon: const Icon(Icons.attach_money),
                  filled: true,
                  fillColor: surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Text(
                'JOD',
                style: TextStyle(color: dim, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('معاينة الأكشاك', 'Booth Preview'),
                style: TextStyle(color: text, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildBoothPreview(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBoothPreview() {
    final total = _boothRows * _boothColumns;
    final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(total, (i) {
        final row = (i ~/ _boothColumns);
        final col = (i % _boothColumns);
        final id = '${letters[row]}${col + 1}';
        return Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              id,
              style: TextStyle(
                  color: accent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      }),
    );
  }

  // ── Venue Verification Step (with document upload) ──────────────────
  Widget _buildVenueVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('نوع المكان', 'Venue Type'),
          style:
              TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _venueTypes.map((type) {
            final selected = _venueType == type;
            final label = t(type, type);
            return GestureDetector(
              onTap: () => setState(() => _venueType = type),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? accent : surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? accent : border,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.black : text,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        if (_venueType != null) ...[
          Text(
            t('التحقق من المكان', 'Venue Verification'),
            style: TextStyle(
                color: text, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            t('لضمان مصداقية المعرض، يرجى توفير المعلومات التالية',
                'To ensure exhibition credibility, please provide the following information'),
            style: TextStyle(color: dim, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.upload_file,
                        color: Color(0xFFD4A017), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      t('رفع وثيقة التصريح', 'Upload Permit Document'),
                      style:
                          TextStyle(color: text, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t('ادعم الوثائق بصيغة PDF أو JPG أو PNG',
                      'Supported formats: PDF, JPG, PNG'),
                  style: TextStyle(color: dim, fontSize: 12),
                ),
                const SizedBox(height: 12),
                // ── Upload Button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () async {
                            // Capture language before async gap
                            final isArabicLocal =
                                context.read<AppState>().isArabic;
                            final picker = ImagePicker();
                            final XFile? file = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (file != null) {
                              setState(() => _isUploading = true);
                              final url = await CloudinaryService.uploadFile(
                                file,
                                resourceType: 'raw',
                              );
                              setState(() => _isUploading = false);
                              if (url != null && mounted) {
                                setState(() => _permitDocumentUrl = url);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isArabicLocal
                                          ? 'تم رفع المستند بنجاح'
                                          : 'Document uploaded successfully',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isArabicLocal
                                          ? 'فشل رفع المستند'
                                          : 'Upload failed',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    icon: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFD4A017)),
                          )
                        : Icon(Icons.attach_file, color: accent, size: 18),
                    label: _permitDocumentUrl != null
                        ? Text(t('تم الرفع ✔', 'Uploaded ✔'),
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold))
                        : Text(
                            t('اختر ملف', 'Choose File'),
                            style: TextStyle(
                                color: accent, fontWeight: FontWeight.bold),
                          ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _permitDocumentUrl != null
                              ? Colors.green
                              : accent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _permitNumberController,
            t('رقم التصريح / الرخصة', 'Permit / License Number'),
            hint: t('مثال: JO-P-2024-12345', 'e.g. JO-P-2024-12345'),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _issuerNameController,
            t('اسم الجهة المصدرة', 'Issuing Authority'),
            hint: t('مثال: أمانة عمّان', 'e.g. Amman Municipality'),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _issuerPhoneController,
            t('رقم هاتف الجهة المصدرة', 'Issuer Phone Number'),
            keyboardType: TextInputType.phone,
            hint: t('مثال: 06 555 1234', 'e.g. 06 555 1234'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField(
                  label: t('تاريخ الإصدار', 'Issue Date'),
                  date: _issueDate,
                  onTap: () => _selectDate(context, (d) => _issueDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePickerField(
                  label: t('تاريخ الانتهاء', 'Expiry Date'),
                  date: _expiryDate,
                  onTap: () => _selectDate(context, (d) => _expiryDate = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_venueType == 'Public Venue') ...[
            _buildVerificationToggle(
              label: t('لدي تصريح من البلدية', 'I have a municipal permit'),
              value: _hasPermit,
              onChanged: (v) => setState(() => _hasPermit = v),
            ),
          ],
          if (_venueType == 'Private Gallery' ||
              _venueType == 'Community Center') ...[
            _buildVerificationToggle(
              label: t('لدي رخصة تجارية', 'I have a business license'),
              value: _hasBusinessLicense,
              onChanged: (v) => setState(() => _hasBusinessLicense = v),
            ),
          ],
          if (_venueType == 'Private Property') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('سيتم التحقق من الملكية عبر نظام تحديد المواقع (GPS) وصور المكان.',
                          'Ownership will be verified via GPS and location photos.'),
                      style:
                          TextStyle(color: Colors.amber.shade800, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildVerificationToggle(
              label: t('أوافق على مشاركة موقعي للتحقق',
                  'I agree to share my location for verification'),
              value: _agreeToShareLocation,
              onChanged: (v) => setState(() => _agreeToShareLocation = v),
            ),
          ],
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFD4A017)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('سيتم مراجعة معرضك من قبل فريق CraftGo خلال 24 ساعة.',
                      'Your exhibition will be reviewed by CraftGo team within 24 hours.'),
                  style: TextStyle(color: dim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: accent,
          activeTrackColor: accent.withValues(alpha: 0.5),
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: text),
          ),
        ),
      ],
    );
  }

  void _selectDate(BuildContext context, Function(DateTime) onSelected) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: accent,
            onPrimary: Colors.black,
          ),
        ),
        child: child!,
      ),
    ).then((date) {
      if (date != null && mounted) {
        setState(() => onSelected(date));
      }
    });
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: dim, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: dim),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    final effectiveItems = List<String>.from(items);
    if (value != null && value.isNotEmpty && !effectiveItems.contains(value)) {
      effectiveItems.insert(0, value);
    }
    final safeValue =
        (value != null && effectiveItems.contains(value)) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: dim, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              dropdownColor: surface,
              hint: Text(hint, style: TextStyle(color: dim)),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: effectiveItems.map((item) {
                final label = t(item, item);
                return DropdownMenuItem(
                  value: item,
                  child: Text(label, style: TextStyle(color: text)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ── Localized dropdown for theme ──────────────────────────────────
  Widget _buildLocalizedDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Map<String, String> labelMap,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    final isArabic = context.watch<AppState>().isArabic;
    final effectiveItems = List<String>.from(items);
    if (value != null && value.isNotEmpty && !effectiveItems.contains(value)) {
      effectiveItems.insert(0, value);
    }
    final safeValue =
        (value != null && effectiveItems.contains(value)) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: dim, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              dropdownColor: surface,
              hint: Text(hint, style: TextStyle(color: dim)),
              icon: const Icon(Icons.keyboard_arrow_down),
              items: effectiveItems.map((key) {
                final display = isArabic ? (labelMap[key] ?? key) : key;
                return DropdownMenuItem(
                  value: key,
                  child: Text(display, style: TextStyle(color: text)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null ? DateFormat('yyyy-MM-dd').format(date) : label,
                style: TextStyle(
                  color: date != null ? text : dim,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: dim),
          ],
        ),
      ),
    );
  }
}

// lib/features/hire_order/screens/location_picker_screen.dart
//
// FREE MAP VERSION:
// Uses OpenStreetMap tiles through flutter_map.
// No Google Maps API key or Google Cloud billing is required.
//
// NOTE:
// We keep google_maps_flutter's LatLng ONLY as the public data type for
// initialLocation so the rest of the existing CraftGo screens do not need
// to be changed. The map itself is NOT Google Maps.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationPickerScreen extends StatefulWidget {
  final bool isArabic;
  final bool isDarkMode;
  final LatLng? initialLocation;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    required this.isArabic,
    required this.isDarkMode,
    this.initialLocation,
    this.initialAddress,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _defaultLocation = LatLng(32.2211, 35.2544);

  late LatLng _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation ?? _defaultLocation;
    _selectedAddress = widget.initialAddress ?? '';

    if (_selectedAddress.isEmpty) {
      _getAddressFromCoords(_selectedLocation);
    }
  }

  osm.LatLng get _osmSelectedLocation => osm.LatLng(
    _selectedLocation.latitude,
    _selectedLocation.longitude,
  );

  Future<void> _getAddressFromCoords(LatLng position) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country,
        ].where((s) => s != null && s!.trim().isNotEmpty).toList();

        setState(() {
          _selectedAddress = parts.isNotEmpty
              ? parts.join(', ')
              : '${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}';
        });
      } else {
        setState(() {
          _selectedAddress =
          '${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedAddress =
          '${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTap(osm.LatLng point) {
    final selected = LatLng(point.latitude, point.longitude);

    setState(() {
      _selectedLocation = selected;
      _selectedAddress =
      '${selected.latitude.toStringAsFixed(6)}, '
          '${selected.longitude.toStringAsFixed(6)}';
    });

    _getAddressFromCoords(selected);
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'latitude': _selectedLocation.latitude,
      'longitude': _selectedLocation.longitude,
      'address': _selectedAddress,
    });
  }

  void _searchLocation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF1C2431) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: widget.isDarkMode ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isArabic ? 'البحث عن موقع' : 'Search Location',
              style: GoogleFonts.cairo(
                color: widget.isDarkMode ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: widget.isArabic
                    ? 'ابحث عن مدينة، شارع، أو منطقة'
                    : 'Search for city, street, or area',
                hintStyle: GoogleFonts.cairo(
                  color: widget.isDarkMode ? Colors.white54 : Colors.black54,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFFD4A017),
                ),
                filled: true,
                fillColor: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.02),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color:
                    widget.isDarkMode ? Colors.white12 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFD4A017),
                    width: 2,
                  ),
                ),
              ),
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
              onSubmitted: (_) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.isArabic
                          ? 'البحث بالاسم غير مفعّل حالياً، اضغط على الخريطة لتحديد الموقع.'
                          : 'Name search is not enabled yet. Tap the map to choose a location.',
                    ),
                    backgroundColor: const Color(0xFFD4A017),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color:
                        widget.isDarkMode ? Colors.white24 : Colors.black12,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.isArabic ? 'إلغاء' : 'Cancel',
                      style: TextStyle(
                        color:
                        widget.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A017),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.isArabic ? 'إغلاق' : 'Close',
                      style: const TextStyle(
                        color: Colors.black,
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection:
      widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF0D1420)
            : const Color(0xFFF5F6F8),
        appBar: AppBar(
          backgroundColor: widget.isDarkMode
              ? const Color(0xFF0D1420)
              : const Color(0xFFF5F6F8),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              widget.isArabic
                  ? Icons.arrow_forward_ios
                  : Icons.arrow_back_ios,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.isArabic ? 'اختر الموقع' : 'Pick Location',
            style: GoogleFonts.cairo(
              color: widget.isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.search,
                color: Color(0xFFD4A017),
              ),
              onPressed: _searchLocation,
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF1C2431)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFD4A017),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD4A017),
                          ),
                        ),
                      ),
                    )
                        : Text(
                      _selectedAddress.isNotEmpty
                          ? _selectedAddress
                          : widget.isArabic
                          ? 'اضغط على الخريطة لتحديد الموقع'
                          : 'Tap on the map to select location',
                      style: GoogleFonts.cairo(
                        color: _selectedAddress.isNotEmpty
                            ? (widget.isDarkMode
                            ? Colors.white
                            : Colors.black87)
                            : (widget.isDarkMode
                            ? Colors.white54
                            : Colors.black54),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _confirmLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A017),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.isArabic ? 'تأكيد' : 'Confirm',
                        style: GoogleFonts.cairo(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _osmSelectedLocation,
                  initialZoom: 14,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, point) => _onTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'craftgo',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _osmSelectedLocation,
                        width: 52,
                        height: 52,
                        child: const Icon(
                          Icons.location_pin,
                          color: Color(0xFFD4A017),
                          size: 48,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SimpleAttributionWidget(
                    source: const Text('OpenStreetMap contributors'),
                    backgroundColor: Colors.white70,
                  ),
                ],
              ),
            ),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF1C2431)
                    : Colors.white,
                border: Border(
                  top: BorderSide(
                    color:
                    widget.isDarkMode ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app,
                    color: Color(0xFFD4A017),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isArabic
                          ? 'اسحب الخريطة أو اضغط لتحديد موقع دقيق'
                          : 'Drag or tap the map to select a precise location',
                      style: GoogleFonts.cairo(
                        color: widget.isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

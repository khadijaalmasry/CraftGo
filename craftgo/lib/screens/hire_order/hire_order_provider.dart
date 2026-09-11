// lib/features/hire_order/providers/hire_order_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class MaterialItem {
  final String name;
  final int quantity;
  final String unit;

  const MaterialItem({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };

  factory MaterialItem.fromJson(Map<String, dynamic> j) => MaterialItem(
    name: (j['name'] ?? '').toString(),
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    unit: (j['unit'] ?? '').toString(),
  );
}

class DailySchedule {
  final int day;
  final List<String> tasks;
  final int hours;

  const DailySchedule({
    required this.day,
    required this.tasks,
    required this.hours,
  });

  Map<String, dynamic> toJson() => {
    'day': day,
    'tasks': tasks,
    'hours': hours,
  };

  factory DailySchedule.fromJson(Map<String, dynamic> j) => DailySchedule(
    day: (j['day'] as num?)?.toInt() ?? 1,
    tasks: List<String>.from(j['tasks'] ?? const []),
    hours: (j['hours'] as num?)?.toInt() ?? 0,
  );
}

class HireArtisanResponse {
  final double dailyRate;
  final double materialCost;
  final List<DailySchedule> schedule;
  final double totalPrice;
  final String notesAr;
  final String notesEn;

  const HireArtisanResponse({
    required this.dailyRate,
    required this.materialCost,
    required this.schedule,
    required this.totalPrice,
    required this.notesAr,
    required this.notesEn,
  });

  factory HireArtisanResponse.fromJson(
      Map<String, dynamic> j, {
        double? fallbackTotal,
      }) {
    final scheduleRaw = j['schedule'];
    final schedule = scheduleRaw is List
        ? scheduleRaw
        .whereType<Map>()
        .map((e) => DailySchedule.fromJson(
      Map<String, dynamic>.from(e),
    ))
        .toList()
        : <DailySchedule>[];

    final dailyRate = (j['dailyRate'] as num?)?.toDouble() ?? 0;
    final materialCost = (j['materialCost'] as num?)?.toDouble() ?? 0;

    return HireArtisanResponse(
      dailyRate: dailyRate,
      materialCost: materialCost,
      schedule: schedule,
      totalPrice: (j['totalPrice'] as num?)?.toDouble() ??
          fallbackTotal ??
          ((dailyRate * schedule.length) + materialCost),
      notesAr: (j['notesAr'] ?? '').toString(),
      notesEn: (j['notesEn'] ?? '').toString(),
    );
  }
}

class HireDailyLog {
  final DateTime date;
  final List<String> tasksCompleted;
  final int hoursWorked;
  final String notes;
  final List<String> images;
  final DateTime createdAt;

  const HireDailyLog({
    required this.date,
    required this.tasksCompleted,
    required this.hoursWorked,
    required this.notes,
    required this.images,
    required this.createdAt,
  });
}

class HireRequest {
  final String id;
  final String customerId;
  final String customerName;
  final String artisanId;
  final String artisanName;
  final String jobDescription;
  final String location;
  final double? locationLat;
  final double? locationLng;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyHours;
  final List<MaterialItem> materials;
  final List<String> toolsRequired;
  final String status;
  final String progressStage;
  final int progressPercent;
  final HireArtisanResponse? artisanResponse;
  final bool contractSigned;
  final DateTime? contractSignedAt;
  final List<HireDailyLog>? dailyLogs;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const HireRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.artisanId,
    required this.artisanName,
    required this.jobDescription,
    required this.location,
    this.locationLat,
    this.locationLng,
    required this.startDate,
    required this.endDate,
    required this.dailyHours,
    required this.materials,
    required this.toolsRequired,
    required this.status,
    this.progressStage = 'work_started',
    this.progressPercent = 0,
    this.artisanResponse,
    this.contractSigned = false,
    this.contractSignedAt,
    this.dailyLogs,
    required this.createdAt,
    this.updatedAt,
  });

  HireRequest copyWith({
    String? status,
    String? progressStage,
    int? progressPercent,
    HireArtisanResponse? artisanResponse,
    bool? contractSigned,
    DateTime? contractSignedAt,
    List<HireDailyLog>? dailyLogs,
    DateTime? updatedAt,
  }) =>
      HireRequest(
        id: id,
        customerId: customerId,
        customerName: customerName,
        artisanId: artisanId,
        artisanName: artisanName,
        jobDescription: jobDescription,
        location: location,
        locationLat: locationLat,
        locationLng: locationLng,
        startDate: startDate,
        endDate: endDate,
        dailyHours: dailyHours,
        materials: materials,
        toolsRequired: toolsRequired,
        status: status ?? this.status,
        progressStage: progressStage ?? this.progressStage,
        progressPercent: progressPercent ?? this.progressPercent,
        artisanResponse: artisanResponse ?? this.artisanResponse,
        contractSigned: contractSigned ?? this.contractSigned,
        contractSignedAt: contractSignedAt ?? this.contractSignedAt,
        dailyLogs: dailyLogs ?? this.dailyLogs,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  bool get isPendingArtisan => status == 'pending_artisan';
  bool get isPendingCustomer => status == 'pending_customer';
  bool get isInProgress => status == 'in_progress' || status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}

// ── Provider ─────────────────────────────────────────────────────────────────

class HireOrderProvider extends ChangeNotifier {
  bool _loading = false;
  String? _error;

  bool get isLoading => _loading;
  String? get error => _error;

  final List<HireRequest> _requests = [];

  List<HireRequest> get requests => List.unmodifiable(_requests);

  List<HireRequest> requestsForCustomer(String customerId) =>
      _requests.where((r) => r.customerId == customerId).toList();

  List<HireRequest> requestsForArtisan(String artisanId) =>
      _requests.where((r) => r.artisanId == artisanId).toList();

  List<HireRequest> get pendingForArtisan =>
      _requests.where((r) => r.status == 'pending_artisan').toList();

  List<HireRequest> get pendingForCustomer =>
      _requests.where((r) => r.status == 'pending_customer').toList();

  HireRequest? findRequest(String id) {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  HireOrderProvider();

  DateTime _date(dynamic value, {DateTime? fallback}) {
    if (value is DateTime) return value;
    if (value != null) {
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed.toLocal();
    }
    return fallback ?? DateTime.now();
  }

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  HireRequest _requestFromJson(
      Map<String, dynamic> j, {
        String fallbackCustomerName = '',
        String fallbackArtisanName = '',
      }) {
    final customer = j['customer'] is Map
        ? Map<String, dynamic>.from(j['customer'] as Map)
        : <String, dynamic>{};

    final artisan = j['artisan'] is Map
        ? Map<String, dynamic>.from(j['artisan'] as Map)
        : <String, dynamic>{};

    final rawMaterials =
        j['requiredMaterials'] ?? j['materials'] ?? const [];
    final materials = rawMaterials is List
        ? rawMaterials.map<MaterialItem>((e) {
      if (e is Map) {
        return MaterialItem.fromJson(
          Map<String, dynamic>.from(e),
        );
      }
      return MaterialItem(
        name: e.toString(),
        quantity: 1,
        unit: '',
      );
    }).toList()
        : <MaterialItem>[];

    final rawTools =
        j['requiredTools'] ?? j['toolsRequired'] ?? const [];
    final tools = rawTools is List
        ? rawTools.map((e) => e.toString()).toList()
        : <String>[];

    HireArtisanResponse? artisanResponse;
    if (j['artisanResponse'] is Map) {
      artisanResponse = HireArtisanResponse.fromJson(
        Map<String, dynamic>.from(j['artisanResponse'] as Map),
        fallbackTotal: _double(j['totalPrice']),
      );
    }

    return HireRequest(
      id: (j['id'] ?? '').toString(),
      customerId: (j['customerId'] ?? '').toString(),
      customerName:
      (customer['name'] ?? j['customerName'] ?? fallbackCustomerName)
          .toString(),
      artisanId: (j['artisanId'] ?? '').toString(),
      artisanName:
      (artisan['name'] ?? j['artisanName'] ?? fallbackArtisanName)
          .toString(),
      jobDescription: (j['jobDescription'] ?? '').toString(),
      location: (j['address'] ?? j['location'] ?? '').toString(),
      locationLat: _double(j['latitude'] ?? j['locationLat']),
      locationLng: _double(j['longitude'] ?? j['locationLng']),
      startDate: _date(j['startDate']),
      endDate: _date(j['endDate']),
      dailyHours:
      (j['dailyHours'] as num?)?.toInt() ??
          int.tryParse(j['dailyHours']?.toString() ?? '') ??
          8,
      materials: materials,
      toolsRequired: tools,
      status: (j['status'] ?? 'pending_artisan').toString(),
      progressStage: (j['progressStage'] ?? 'work_started').toString(),
      progressPercent: (j['progressPercent'] as num?)?.toInt() ??
          int.tryParse(j['progressPercent']?.toString() ?? '') ??
          0,
      artisanResponse: artisanResponse,
      contractSigned: j['contractSigned'] == true,
      contractSignedAt: j['contractSignedAt'] == null
          ? null
          : _date(j['contractSignedAt']),
      dailyLogs: null,
      createdAt: _date(j['createdAt']),
      updatedAt:
      j['updatedAt'] == null ? null : _date(j['updatedAt']),
    );
  }

  Future<void> loadForArtisan(String artisanId) async {
    if (artisanId.trim().isEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get(
        '/hire-orders/requests/artisan/$artisanId',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load hire requests (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> raw =
      decoded is List
          ? decoded
          : (decoded is Map && decoded['requests'] is List
          ? List<dynamic>.from(decoded['requests'])
          : <dynamic>[]);

      _requests.removeWhere((r) => r.artisanId == artisanId);
      _requests.addAll(
        raw
            .whereType<Map>()
            .map(
              (e) => _requestFromJson(
            Map<String, dynamic>.from(e),
          ),
        ),
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ LOAD HIRE REQUESTS FOR ARTISAN ERROR: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadForCustomer(String customerId) async {
    if (customerId.trim().isEmpty) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get(
        '/hire-orders/requests/customer/$customerId',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to load hire requests (${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> raw =
      decoded is List
          ? decoded
          : (decoded is Map && decoded['requests'] is List
          ? List<dynamic>.from(decoded['requests'])
          : <dynamic>[]);

      _requests.removeWhere((r) => r.customerId == customerId);
      _requests.addAll(
        raw
            .whereType<Map>()
            .map(
              (e) => _requestFromJson(
            Map<String, dynamic>.from(e),
          ),
        ),
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ LOAD HIRE REQUESTS FOR CUSTOMER ERROR: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<HireRequest> createJob({
    required String customerId,
    required String customerName,
    required String artisanId,
    required String artisanName,
    required String jobDescription,
    required String location,
    double? locationLat,
    double? locationLng,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyHours,
    required List<MaterialItem> materials,
    required List<String> toolsRequired,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        '/hire-orders/requests',
        body: {
          'artisanId': artisanId,
          'jobDescription': jobDescription,
          'latitude': locationLat,
          'longitude': locationLng,
          'address': location,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'dailyHours': dailyHours,
          'requiredMaterials':
          materials.map((e) => e.toJson()).toList(),
          'requiredTools': toolsRequired,
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode != 201) {
        final message = decoded is Map
            ? (decoded['error'] ?? decoded['message'])
            : null;
        throw Exception(
          message?.toString() ?? 'Failed to submit hire request',
        );
      }

      final rawRequest = decoded is Map && decoded['request'] is Map
          ? Map<String, dynamic>.from(decoded['request'] as Map)
          : <String, dynamic>{};

      final request = _requestFromJson(
        rawRequest,
        fallbackCustomerName: customerName,
        fallbackArtisanName: artisanName,
      );

      _requests.removeWhere((r) => r.id == request.id);
      _requests.insert(0, request);
      notifyListeners();

      return request;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ CREATE HIRE REQUEST ERROR: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> artisanRespond({
    required String requestId,
    required double dailyRate,
    required double materialCost,
    required List<DailySchedule> schedule,
    required String notesAr,
    required String notesEn,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final totalPrice =
          (dailyRate * schedule.length) + materialCost;

      final response = await ApiService.post(
        '/hire-orders/requests/$requestId/respond',
        body: {
          'dailyRate': dailyRate,
          'materialCost': materialCost,
          'schedule': schedule.map((e) => e.toJson()).toList(),
          'notesAr': notesAr,
          'notesEn': notesEn,
          'totalPrice': totalPrice,
        },
      );

      final decoded = jsonDecode(response.body);

      if (response.statusCode != 200) {
        final message = decoded is Map
            ? (decoded['error'] ?? decoded['message'])
            : null;
        throw Exception(
          message?.toString() ?? 'Failed to send hire proposal',
        );
      }

      final rawRequest = decoded is Map && decoded['request'] is Map
          ? Map<String, dynamic>.from(decoded['request'] as Map)
          : null;

      if (rawRequest != null) {
        final updated = _requestFromJson(rawRequest);
        final index = _requests.indexWhere((r) => r.id == requestId);
        if (index != -1) {
          final old = _requests[index];
          _requests[index] = HireRequest(
            id: updated.id,
            customerId: updated.customerId,
            customerName: updated.customerName.isNotEmpty
                ? updated.customerName
                : old.customerName,
            artisanId: updated.artisanId,
            artisanName: updated.artisanName.isNotEmpty
                ? updated.artisanName
                : old.artisanName,
            jobDescription: updated.jobDescription,
            location: updated.location,
            locationLat: updated.locationLat,
            locationLng: updated.locationLng,
            startDate: updated.startDate,
            endDate: updated.endDate,
            dailyHours: updated.dailyHours,
            materials: updated.materials,
            toolsRequired: updated.toolsRequired,
            status: updated.status,
            progressStage: updated.progressStage,
            progressPercent: updated.progressPercent,
            artisanResponse: updated.artisanResponse,
            contractSigned: updated.contractSigned,
            contractSignedAt: updated.contractSignedAt,
            dailyLogs: updated.dailyLogs,
            createdAt: updated.createdAt,
            updatedAt: updated.updatedAt,
          );
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ RESPOND HIRE REQUEST ERROR: $e');
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _patchStatus(
      String id,
      String status, {
        String? progressStage,
        int? progressPercent,
      }) async {
    final body = <String, dynamic>{
      'status': status,
      if (progressStage != null) 'progressStage': progressStage,
      if (progressPercent != null) 'progressPercent': progressPercent,
    };

    final response = await ApiService.patch(
      '/hire-orders/requests/$id/status',
      body: body,
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      final message =
      decoded is Map ? decoded['error'] ?? decoded['message'] : null;
      throw Exception(
        message?.toString() ?? 'Failed to update hire request',
      );
    }

    final rawRequest = decoded is Map && decoded['request'] is Map
        ? Map<String, dynamic>.from(decoded['request'] as Map)
        : null;

    final index = _requests.indexWhere((r) => r.id == id);

    if (index != -1) {
      if (rawRequest != null) {
        final old = _requests[index];
        final updated = _requestFromJson(rawRequest);

        _requests[index] = HireRequest(
          id: updated.id,
          customerId: updated.customerId,
          customerName: updated.customerName.isNotEmpty
              ? updated.customerName
              : old.customerName,
          artisanId: updated.artisanId,
          artisanName: updated.artisanName.isNotEmpty
              ? updated.artisanName
              : old.artisanName,
          jobDescription: updated.jobDescription,
          location: updated.location,
          locationLat: updated.locationLat,
          locationLng: updated.locationLng,
          startDate: updated.startDate,
          endDate: updated.endDate,
          dailyHours: updated.dailyHours,
          materials: updated.materials,
          toolsRequired: updated.toolsRequired,
          status: updated.status,
          progressStage: updated.progressStage,
          progressPercent: updated.progressPercent,
          artisanResponse:
          updated.artisanResponse ?? old.artisanResponse,
          contractSigned:
          updated.contractSigned || old.contractSigned,
          contractSignedAt:
          updated.contractSignedAt ?? old.contractSignedAt,
          dailyLogs: updated.dailyLogs ?? old.dailyLogs,
          createdAt: updated.createdAt,
          updatedAt: updated.updatedAt,
        );
      } else {
        _requests[index] =
            _requests[index].copyWith(status: status);
      }
    }

    notifyListeners();
  }

  Future<void> customerAccept(String id) async {
    await _patchStatus(id, 'in_progress');
  }

  Future<void> customerReject(String id) async {
    await _patchStatus(id, 'cancelled');
  }

  Future<void> customerConfirmCompletion(String id) async {
    await _patchStatus(id, 'completed', progressPercent: 100);
  }

  Future<void> artisanUpdateProgress({
    required String id,
    required String progressStage,
    required int progressPercent,
  }) async {
    final response = await ApiService.patch(
      '/hire-orders/requests/$id/status',
      body: {
        'progressStage': progressStage,
        'progressPercent': progressPercent.clamp(0, 100),
      },
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final message =
      decoded is Map ? decoded['error'] ?? decoded['message'] : null;
      throw Exception(message?.toString() ?? 'Failed to update work progress');
    }

    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index] = _requests[index].copyWith(
        progressStage: progressStage,
        progressPercent: progressPercent.clamp(0, 100).toInt(),
      );
      notifyListeners();
    }
  }

  Future<void> signContract(String id) async {
    await _patchStatus(id, 'in_progress');

    final i = _requests.indexWhere((r) => r.id == id);
    if (i != -1) {
      _requests[i] = _requests[i].copyWith(
        contractSigned: true,
        contractSignedAt: DateTime.now(),
        status: 'in_progress',
      );
      notifyListeners();
    }
  }

  Future<void> simulatePayment(String id) async {
    _loading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 700));
      await signContract(id);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}

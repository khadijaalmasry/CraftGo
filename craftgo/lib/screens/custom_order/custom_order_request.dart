// lib/models/custom_order_request.dart


// ============================================================
// CustomOrderRequest — Customer sends this to artisan
// Artisan responds with ArtisanResponse
// ============================================================

class PriceRow {
  final String labelAr;
  final String labelEn;
  final double amount;

  const PriceRow({
    required this.labelAr,
    required this.labelEn,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'label_ar': labelAr,
    'label_en': labelEn,
    'amount': amount,
  };

  factory PriceRow.fromJson(Map<String, dynamic> j) => PriceRow(
    labelAr: j['label_ar'],
    labelEn: j['label_en'],
    amount: (j['amount'] as num).toDouble(),
  );
}

class ArtisanResponse {
  final List<PriceRow> breakdown;
  final List<String> tasks;
  final DateTime deliveryDate;
  final String notesAr;
  final String notesEn;

  double get total => breakdown.fold(0, (s, r) => s + r.amount);

  const ArtisanResponse({
    required this.breakdown,
    required this.tasks,
    required this.deliveryDate,
    required this.notesAr,
    required this.notesEn,
  });

  Map<String, dynamic> toJson() => {
    'breakdown': breakdown.map((p) => p.toJson()).toList(),
    'tasks': tasks,
    'delivery_date': deliveryDate.toIso8601String(),
    'notes_ar': notesAr,
    'notes_en': notesEn,
  };

  factory ArtisanResponse.fromJson(Map<String, dynamic> j) => ArtisanResponse(
    breakdown: (j['breakdown'] as List).map((p) => PriceRow.fromJson(p)).toList(),
    tasks: List<String>.from(j['tasks']),
    deliveryDate: DateTime.parse(j['delivery_date']),
    notesAr: j['notes_ar'],
    notesEn: j['notes_en'],
  );
}

class CustomOrderRequest {
  final String id;
  final String templateId;
  final String templateTitleAr;
  final String templateTitleEn;
  final String customerId;
  final String customerName;
  final String artisanId;
  final String artisanName;

  // Status lifecycle:
  // draft → pending_artisan → pending_customer → in_progress → completed | rejected | cancelled
  final String status;
  final Map<String, dynamic> filledFields;
  final ArtisanResponse? artisanResponse;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool contractSigned;
  final DateTime? contractSignedAt;

  // Persisted execution progress from backend
  final String? progressStage;
  final int progressPercent;
  final String? deliveryPin;
  final Map<String, dynamic>? deliveryOrder;

  const CustomOrderRequest({
    required this.id,
    required this.templateId,
    required this.templateTitleAr,
    required this.templateTitleEn,
    required this.customerId,
    required this.customerName,
    required this.artisanId,
    required this.artisanName,
    required this.status,
    required this.filledFields,
    this.artisanResponse,
    required this.createdAt,
    this.updatedAt,
    this.contractSigned = false,
    this.contractSignedAt,
    this.progressStage,
    this.progressPercent = 0,
    this.deliveryPin,
    this.deliveryOrder,
  });

  CustomOrderRequest copyWith({
    String? status,
    Map<String, dynamic>? filledFields,
    ArtisanResponse? artisanResponse,
    DateTime? updatedAt,
    bool? contractSigned,
    DateTime? contractSignedAt,
    String? progressStage,
    int? progressPercent,
  }) => CustomOrderRequest(
    id: id,
    templateId: templateId,
    templateTitleAr: templateTitleAr,
    templateTitleEn: templateTitleEn,
    customerId: customerId,
    customerName: customerName,
    artisanId: artisanId,
    artisanName: artisanName,
    status: status ?? this.status,
    filledFields: filledFields ?? this.filledFields,
    artisanResponse: artisanResponse ?? this.artisanResponse,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    contractSigned: contractSigned ?? this.contractSigned,
    contractSignedAt: contractSignedAt ?? this.contractSignedAt,
    progressStage: progressStage ?? this.progressStage,
    progressPercent: progressPercent ?? this.progressPercent,
  );

  bool get isPendingArtisan => status == 'pending_artisan';
  bool get isPendingCustomer => status == 'pending_customer';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
}

// class PriceRow {
//   final String labelAr;
//   final String labelEn;
//   final double amount;
//   const PriceRow({required this.labelAr, required this.labelEn, required this.amount});
// }
//
// class ArtisanResponse {
//   final List<PriceRow> breakdown;
//   final List<String> tasks;
//   final DateTime deliveryDate;
//   final String notesAr;
//   final String notesEn;
//
//   double get total => breakdown.fold(0, (s, r) => s + r.amount);
//
//   const ArtisanResponse({
//     required this.breakdown,
//     required this.tasks,
//     required this.deliveryDate,
//     required this.notesAr,
//     required this.notesEn,
//   });
// }
//
// class CustomOrderRequest {
//   final String id;
//   final String templateId;
//   final String templateTitleAr;
//   final String templateTitleEn;
//   final String customerId;
//   final String customerName;
//   final String artisanId;
//   final String artisanName;
//
//   // status lifecycle:
//   // draft → pending_artisan → pending_customer → in_progress → completed | rejected | cancelled
//   final String status;
//
//   // Customer's filled fields: fieldId → value (String, List<String>, bool, etc.)
//   final Map<String, dynamic> filledFields;
//
//   final ArtisanResponse? artisanResponse;
//   final DateTime createdAt;
//   final DateTime? updatedAt;
//
//   const CustomOrderRequest({
//     required this.id,
//     required this.templateId,
//     required this.templateTitleAr,
//     required this.templateTitleEn,
//     required this.customerId,
//     required this.customerName,
//     required this.artisanId,
//     required this.artisanName,
//     required this.status,
//     required this.filledFields,
//     this.artisanResponse,
//     required this.createdAt,
//     this.updatedAt,
//   });
//
//   CustomOrderRequest copyWith({
//     String? status,
//     Map<String, dynamic>? filledFields,
//     ArtisanResponse? artisanResponse,
//     DateTime? updatedAt,
//   }) => CustomOrderRequest(
//     id: id, templateId: templateId,
//     templateTitleAr: templateTitleAr, templateTitleEn: templateTitleEn,
//     customerId: customerId, customerName: customerName,
//     artisanId: artisanId, artisanName: artisanName,
//     status: status ?? this.status,
//     filledFields: filledFields ?? this.filledFields,
//     artisanResponse: artisanResponse ?? this.artisanResponse,
//     createdAt: createdAt,
//     updatedAt: updatedAt ?? DateTime.now(),
//   );
// }

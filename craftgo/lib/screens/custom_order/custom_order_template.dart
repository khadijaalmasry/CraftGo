// // lib/models/custom_order_template.dart
//
// class TemplateField {
//   final String id;
//   final String type; // text | textarea | dropdown | dimensions | color_picker | number | checkbox | image_upload
//   final String labelAr;
//   final String labelEn;
//   final bool required;
//   final List<String> options; // for dropdown
//   final int maxImages;        // for image_upload
//
//   const TemplateField({
//     required this.id,
//     required this.type,
//     required this.labelAr,
//     required this.labelEn,
//     this.required = false,
//     this.options = const [],
//     this.maxImages = 3,
//   });
//
//   TemplateField copyWith({
//     String? id, String? type, String? labelAr, String? labelEn,
//     bool? required, List<String>? options, int? maxImages,
//   }) => TemplateField(
//     id: id ?? this.id,
//     type: type ?? this.type,
//     labelAr: labelAr ?? this.labelAr,
//     labelEn: labelEn ?? this.labelEn,
//     required: required ?? this.required,
//     options: options ?? this.options,
//     maxImages: maxImages ?? this.maxImages,
//   );
//
//   Map<String, dynamic> toJson() => {
//     'id': id, 'type': type, 'label_ar': labelAr, 'label_en': labelEn,
//     'required': required, 'options': options, 'max_images': maxImages,
//   };
//
//   factory TemplateField.fromJson(Map<String, dynamic> j) => TemplateField(
//     id: j['id'], type: j['type'],
//     labelAr: j['label_ar'] ?? j['label'],
//     labelEn: j['label_en'] ?? j['label'],
//     required: j['required'] ?? false,
//     options: List<String>.from(j['options'] ?? []),
//     maxImages: j['max_images'] ?? 3,
//   );
// }
//
// class CustomOrderTemplate {
//   final String id;
//   final String artisanId;
//   final String artisanName;
//   final String titleAr;
//   final String titleEn;
//   final String categoryAr;
//   final String categoryEn;
//   final String descriptionAr;
//   final String descriptionEn;
//   final double basePrice;
//   final int estimatedDays;
//   final List<TemplateField> fields;
//   final DateTime createdAt;
//
//   const CustomOrderTemplate({
//     required this.id,
//     required this.artisanId,
//     required this.artisanName,
//     required this.titleAr,
//     required this.titleEn,
//     required this.categoryAr,
//     required this.categoryEn,
//     required this.descriptionAr,
//     required this.descriptionEn,
//     required this.basePrice,
//     required this.estimatedDays,
//     required this.fields,
//     required this.createdAt,
//   });
//
//   CustomOrderTemplate copyWith({
//     String? titleAr, String? titleEn, String? descriptionAr, String? descriptionEn,
//     double? basePrice, int? estimatedDays, List<TemplateField>? fields,
//   }) => CustomOrderTemplate(
//     id: id, artisanId: artisanId, artisanName: artisanName,
//     titleAr: titleAr ?? this.titleAr, titleEn: titleEn ?? this.titleEn,
//     categoryAr: categoryAr, categoryEn: categoryEn,
//     descriptionAr: descriptionAr ?? this.descriptionAr,
//     descriptionEn: descriptionEn ?? this.descriptionEn,
//     basePrice: basePrice ?? this.basePrice,
//     estimatedDays: estimatedDays ?? this.estimatedDays,
//     fields: fields ?? this.fields,
//     createdAt: createdAt,
//   );
// }
// ============================================================
// CustomOrderTemplate — Artisan creates this template
// Customers fill it to place a custom order
// ============================================================

// Add these to the existing TemplateField class

class TemplateField {
  final String id;
  final String type; // text, textarea, number, dropdown, dimensions, color_picker,
  // multi_color_picker, checkbox_list, range_slider, date_picker,
  // time_picker, file_upload, toggle, checkbox
  final String labelAr;
  final String labelEn;
  final bool required;
  final List<String> options; // for dropdown
  final int maxImages;        // for image_upload
  final int maxItems;         // for multi_color_picker (max colors)
  final double minValue;      // for range_slider
  final double maxValue;      // for range_slider
  final double defaultValue;  // for range_slider
  final List<String> checklistItems; // for checkbox_list (labels)
  final String unit;          // for dimensions (cm, inches, mm)

  const TemplateField({
    required this.id,
    required this.type,
    required this.labelAr,
    required this.labelEn,
    this.required = false,
    this.options = const [],
    this.maxImages = 3,
    this.maxItems = 10,
    this.minValue = 0,
    this.maxValue = 100,
    this.defaultValue = 50,
    this.checklistItems = const [],
    this.unit = 'cm',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'label_ar': labelAr,
    'label_en': labelEn,
    'required': required,
    'options': options,
    'max_images': maxImages,
    'max_items': maxItems,
    'min_value': minValue,
    'max_value': maxValue,
    'default_value': defaultValue,
    'checklist_items': checklistItems,
    'unit': unit,
  };

  factory TemplateField.fromJson(Map<String, dynamic> j) => TemplateField(
    id: j['id'],
    type: j['type'],
    labelAr: j['label_ar'] ?? j['label'],
    labelEn: j['label_en'] ?? j['label'],
    required: j['required'] ?? false,
    options: List<String>.from(j['options'] ?? []),
    maxImages: j['max_images'] ?? 3,
    maxItems: j['max_items'] ?? 10,
    minValue: j['min_value']?.toDouble() ?? 0,
    maxValue: j['max_value']?.toDouble() ?? 100,
    defaultValue: j['default_value']?.toDouble() ?? 50,
    checklistItems: List<String>.from(j['checklist_items'] ?? []),
    unit: j['unit'] ?? 'cm',
  );
}

class CustomOrderTemplate {
  final String id;
  final String artisanId;
  final String artisanName;
  final String titleAr;
  final String titleEn;
  final String categoryAr;
  final String categoryEn;
  final String descriptionAr;
  final String descriptionEn;
  final double basePrice;
  final int estimatedDays;
  final List<TemplateField> fields;
  final DateTime createdAt;
  final bool isActive;

  const CustomOrderTemplate({
    required this.id,
    required this.artisanId,
    required this.artisanName,
    required this.titleAr,
    required this.titleEn,
    required this.categoryAr,
    required this.categoryEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.basePrice,
    required this.estimatedDays,
    required this.fields,
    required this.createdAt,
    this.isActive = true,
  });

  CustomOrderTemplate copyWith({
    String? titleAr,
    String? titleEn,
    String? descriptionAr,
    String? descriptionEn,
    double? basePrice,
    int? estimatedDays,
    List<TemplateField>? fields,
    bool? isActive,
  }) => CustomOrderTemplate(
    id: id,
    artisanId: artisanId,
    artisanName: artisanName,
    titleAr: titleAr ?? this.titleAr,
    titleEn: titleEn ?? this.titleEn,
    categoryAr: categoryAr,
    categoryEn: categoryEn,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn ?? this.descriptionEn,
    basePrice: basePrice ?? this.basePrice,
    estimatedDays: estimatedDays ?? this.estimatedDays,
    fields: fields ?? this.fields,
    createdAt: createdAt,
    isActive: isActive ?? this.isActive,
  );
}

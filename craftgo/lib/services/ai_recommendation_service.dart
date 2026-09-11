import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math';

// ─── AI Recommendation Engine (Mock Implementation) ───────────────
class AiRecommendationService {
  // In-memory user interactions
  // format: Map<categoryId, score>
  static final Map<String, int> _userInteractions = {};

  static final List<Map<String, dynamic>> _allProducts = [
    {
      "id": "p1",
      "nameAr": "سجادة صوفية مطرزة",
      "nameEn": "Embroidered Wool Rug",
      "price": 52.0,
      "rating": "4.9",
      "icon": Icons.checkroom_outlined,
      "category": "crochet",
      "views": 450,
      "tags": ["popular", "recommended"],
    },
    {
      "id": "p2",
      "nameAr": "إبريق فخاري تقليدي",
      "nameEn": "Traditional Clay Pitcher",
      "price": 28.0,
      "rating": "4.7",
      "icon": Icons.local_cafe_outlined,
      "category": "pottery",
      "views": 1200,
      "tags": ["popular"],
    },
    {
      "id": "p3",
      "nameAr": "خاتم فضة مصنوع يدوياً",
      "nameEn": "Handmade Silver Ring",
      "price": 35.0,
      "rating": "5.0",
      "icon": Icons.watch_outlined,
      "category": "jewelry",
      "views": 320,
      "tags": ["new", "recommended"],
    },
    {
      "id": "p4",
      "nameAr": "صندوق خشبي محفور",
      "nameEn": "Carved Wooden Box",
      "price": 60.0,
      "rating": "4.8",
      "icon": Icons.chair_outlined,
      "category": "wood",
      "views": 210,
      "tags": ["new"],
    },
    {
      "id": "p5",
      "nameAr": "وشاح صوف منسوج يدوياً",
      "nameEn": "Hand-Woven Wool Scarf",
      "price": 22.0,
      "rating": "4.6",
      "icon": Icons.checkroom_outlined,
      "category": "crochet",
      "views": 180,
      "tags": ["recommended"],
    },
    {
      "id": "p6",
      "nameAr": "طقم أكواب خزفية يدوية",
      "nameEn": "Handmade Ceramic Cup Set",
      "price": 42.0,
      "rating": "4.8",
      "icon": Icons.local_cafe_outlined,
      "category": "pottery",
      "views": 850,
      "tags": ["popular", "new"],
    },
    {
      "id": "p7",
      "nameAr": "عقد خرز خشبي",
      "nameEn": "Wooden Bead Necklace",
      "price": 15.0,
      "rating": "4.3",
      "icon": Icons.watch_outlined,
      "category": "jewelry",
      "views": 150,
      "tags": ["new"],
    },
    {
      "id": "p8",
      "nameAr": "طاولة سفرة خشبية",
      "nameEn": "Wooden Dining Table",
      "price": 400.0,
      "rating": "4.9",
      "icon": Icons.table_bar_outlined,
      "category": "wood",
      "views": 90,
      "tags": ["popular"],
    },
    {
      "id": "p9",
      "nameAr": "لوحة جدارية تراثية",
      "nameEn": "Heritage Wall Painting",
      "price": 120.0,
      "rating": "4.7",
      "icon": Icons.brush_outlined,
      "category": "art",
      "views": 310,
      "tags": ["recommended", "new"],
    }
  ];

  // Log an interaction (view = 1, like = 5, purchase = 10)
  static void logInteraction(String category, String type) {
    int points = 0;
    if (type == 'view') points = 1;
    if (type == 'like') points = 5;
    if (type == 'purchase') points = 10;

    _userInteractions[category] = (_userInteractions[category] ?? 0) + points;
    debugPrint("AI Recommendation Engine: Logged $type for category $category. Total score: ${_userInteractions[category]}");
  }

  // Clear tracking (for testing)
  static void clearInteractions() {
    _userInteractions.clear();
  }

  // Get current scores
  static Map<String, int> getScores() => _userInteractions;

  // The 70/30 Recommendation Algorithm
  static List<Map<String, dynamic>> getRecommendations() {
    // 1. If no interactions (Cold Start) -> return globally trending
    if (_userInteractions.isEmpty) {
      final sorted = List<Map<String, dynamic>>.from(_allProducts)
        ..sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
      return sorted.take(6).toList(); // Return top 6 trending
    }

    // 2. User has interactions. Find top categories.
    var sortedCategories = _userInteractions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Top 1 or 2 categories
    List<String> topCategories = sortedCategories.take(2).map((e) => e.key).toList();

    // 70% from top categories (Personalized)
    List<Map<String, dynamic>> personalized = _allProducts
        .where((p) => topCategories.contains(p['category']))
        .toList();
    
    // Shuffle and pick max 4
    personalized.shuffle(Random());
    if (personalized.length > 4) {
      personalized = personalized.sublist(0, 4);
    }

    // 30% from other categories (Exploration/Diversity)
    List<Map<String, dynamic>> others = _allProducts
        .where((p) => !topCategories.contains(p['category']))
        .toList();
    
    // Sort others by global popularity (trending)
    others.sort((a, b) => (b['views'] as int).compareTo(a['views'] as int));
    
    // Pick max 2
    if (others.length > 2) {
      others = others.sublist(0, 2);
    }

    // Combine and shuffle the final feed
    List<Map<String, dynamic>> finalFeed = [...personalized, ...others];
    finalFeed.shuffle(Random());

    return finalFeed;
  }

  // Get all products for standard tag filtering
  static List<Map<String, dynamic>> getAllProducts() {
    return _allProducts;
  }
}

// ??? AI Cart Recommendations ?????????????????????????????????????????????????
// POST /api/ai/cart-recommendations
exports.cartRecommendations = async (req, res) => {
  try {
    const Product = require('../models/Product');
    const User = require('../models/User');
    const Order = require('../models/Order');
    const { Op, Sequelize } = require('sequelize');

    const cartProductIds = Array.isArray(req.body?.cartProductIds) ? req.body.cartProductIds : [];
    const language = req.body?.language || 'en';

    // ?? Case 1: Empty cart ? best sellers ????????????????????????????????????
    if (cartProductIds.length === 0) {
      // Find best sellers by summing completed order quantities
      const bestSellingOrders = await Order.findAll({
        attributes: [
          'productId',
          [Sequelize.fn('SUM', Sequelize.col('quantity')), 'totalSold']
        ],
        where: { status: 'completed' },
        group: ['productId'],
        order: [[Sequelize.literal('totalSold'), 'DESC']],
        limit: 10
      });

      let bestSellerIds = bestSellingOrders.map(o => o.productId);
      
      let pool = [];
      if (bestSellerIds.length > 0) {
        pool = await Product.findAll({
          where: { id: { [Op.in]: bestSellerIds }, isAvailable: true, isPublic: true },
          include: [{ model: User, as: 'Craftsman', attributes: ['id', 'name', 'city'] }]
        });
        
        // Sort pool based on bestSellerIds order
        pool.sort((a, b) => bestSellerIds.indexOf(a.id) - bestSellerIds.indexOf(b.id));
      }

      // If no completed sales, fallback to latest available public products
      if (pool.length === 0) {
        pool = await Product.findAll({
          where: { isAvailable: true, isPublic: true },
          include: [{ model: User, as: 'Craftsman', attributes: ['id', 'name', 'city'] }],
          order: [['createdAt', 'DESC']],
          limit: 4
        });
      }

      const recommendations = pool.map(p => ({
        id: p.id,
        titleAr: p.titleAr,
        titleEn: p.titleEn,
        price: parseFloat(p.price) || 0,
        imageUrl: p.imageUrl,
        category: p.category,
        craftsmanName: p.Craftsman?.name || '',
        reason: language === 'ar' ? '«·√ﬂÀ— „»Ì⁄« „‰ «Œ Ì«— «·„‘ —Ì‰' : 'Top choice by our customers'
      }));

      return res.json({
        success: true,
        mode: 'best_sellers',
        recommendations: recommendations.slice(0, 4)
      });
    }

    // ?? Case 2: Cart has items ? recommend from real DB products ?????????????
    // Fetch all available public products excluding those already in cart
    const candidates = await Product.findAll({
      where: {
        isAvailable: true,
        isPublic: true,
        id: { [Op.notIn]: cartProductIds }
      },
      include: [{ model: User, as: 'Craftsman', attributes: ['id', 'name', 'city'] }]
    });

    if (candidates.length === 0) {
      return res.json({ success: true, mode: 'ai', recommendations: [] });
    }

    // Call Groq
    const hasGroqKey = process.env.GROQ_API_KEY && process.env.GROQ_API_KEY !== 'your_groq_api_key_here' && process.env.GROQ_API_KEY !== 'dummy_key';

    if (!hasGroqKey) {
      // Fallback
      const fallbackRecs = candidates.slice(0, 4).map(p => ({
        id: p.id,
        titleAr: p.titleAr,
        titleEn: p.titleEn,
        price: parseFloat(p.price) || 0,
        imageUrl: p.imageUrl,
        category: p.category,
        craftsmanName: p.Craftsman?.name || '',
        reason: language === 'ar' ? '„ﬁ —Õ ·ﬂ' : 'Suggested for you'
      }));
      return res.json({ success: true, mode: 'ai', recommendations: fallbackRecs });
    }

    const catalog = candidates.map(p => ({
      id: p.id,
      titleAr: p.titleAr,
      titleEn: p.titleEn,
      category: p.category,
    }));

    const prompt = `You are a product recommendation AI for CraftGo, a handmade marketplace.
The user has products in their cart with the following IDs: ${cartProductIds.join(', ')}.
Choose up to 4 highly relevant products from the available catalog to complement their cart.
Language for reason: ${language === 'ar' ? 'Arabic' : 'English'}.

Available Catalog:
${JSON.stringify(catalog)}

RULES:
1. ONLY pick IDs that exist in the catalog above. NEVER invent an ID.
2. Provide a short "reason" why this product complements the cart.
3. Return ONLY a valid JSON array of objects with keys: "id" and "reason".

Example: [{"id": "...", "reason": "..."}]`;

    let aiResults = [];
    try {
      const groq = require('../services/groqService'); // Or where you get groq from
      // wait, the controller already has `const { groq, MODEL_NAME }` at top
      
      const chatCompletion = await global.groq.chat.completions.create({
        messages: [{ role: 'user', content: prompt }],
        model: global.MODEL_NAME || 'llama-3.3-70b-versatile',
        temperature: 0.3,
      });

      const raw = chatCompletion.choices[0]?.message?.content?.trim() || '[]';
      const jsonMatch = raw.match(/\[.*\]/s);
      if (jsonMatch) {
        aiResults = JSON.parse(jsonMatch[0]);
      }
    } catch (groqErr) {
      console.warn('[AI cartRecommendations] Groq call failed:', groqErr.message);
    }

    // Match AI results with real products
    const validIds = new Set(candidates.map(p => p.id));
    const recommendations = [];

    for (const item of aiResults) {
      if (item.id && validIds.has(item.id)) {
        const p = candidates.find(cand => cand.id === item.id);
        if (p) {
          recommendations.push({
            id: p.id,
            titleAr: p.titleAr,
            titleEn: p.titleEn,
            price: parseFloat(p.price) || 0,
            imageUrl: p.imageUrl,
            category: p.category,
            craftsmanName: p.Craftsman?.name || '',
            reason: item.reason || (language === 'ar' ? '„ﬁ —Õ ·ﬂ' : 'Suggested for you')
          });
        }
      }
      if (recommendations.length >= 4) break;
    }

    // If Groq failed or returned nothing valid, fallback
    if (recommendations.length === 0) {
      const fallbackRecs = candidates.slice(0, 4).map(p => ({
        id: p.id,
        titleAr: p.titleAr,
        titleEn: p.titleEn,
        price: parseFloat(p.price) || 0,
        imageUrl: p.imageUrl,
        category: p.category,
        craftsmanName: p.Craftsman?.name || '',
        reason: language === 'ar' ? '„ﬁ —Õ ·ﬂ' : 'Suggested for you'
      }));
      return res.json({ success: true, mode: 'ai', recommendations: fallbackRecs });
    }

    return res.json({
      success: true,
      mode: 'ai',
      recommendations
    });

  } catch (error) {
    console.error('[AI] cartRecommendations ERROR:', error);
    return res.status(500).json({ error: 'Failed to get cart recommendations' });
  }
};

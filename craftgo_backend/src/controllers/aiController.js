const fs = require('fs');
const Groq = require("groq-sdk");
const ExhibitionCraftsman = require('../models/ExhibitionCraftsman');
const User = require('../models/User');

const groq = new Groq({
  apiKey: process.env.GROQ_API_KEY || 'dummy_key'
});
const MODEL_NAME = "openai/gpt-oss-120b";
exports.enhanceProductImage = async (req, res) => {
  try {
    const {
      imageBase64 = '',
        mimeType = 'image/jpeg',
        preset = 'clean',
        productName = 'handmade product',
    } = req.body || {};

    if (!imageBase64 || imageBase64.length < 100) {
      return res.status(400).json({
        error: 'A valid product image is required',
      });
    }

    if (imageBase64.length > 14 * 1024 * 1024) {
      return res.status(413).json({
        error: 'Image is too large',
      });
    }

    const normalizedMimeType =
      mimeType === 'image/jpg' ? 'image/jpeg' : mimeType;

    const allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
    ];

    if (!allowedTypes.includes(normalizedMimeType)) {
      return res.status(400).json({
        error: 'Unsupported image type',
      });
    }

    const apiKey = process.env.GEMINI_API_KEY;

    if (!apiKey) {
      return res.status(503).json({
        error: 'Gemini API key is not configured',
      });
    }

    const presetPrompts = {
      clean: 'Remove the existing background and place the product on a clean soft-white ecommerce studio background with a subtle natural shadow.',

      warm: 'Remove the existing background and place the product in a warm elegant handmade craft studio setting with neutral beige tones and soft daylight.',

      premium: 'Remove the existing background and place the product on a premium dark charcoal studio background with elegant soft lighting and a realistic shadow.',
    };

    const studioInstruction =
      presetPrompts[preset] || presetPrompts.clean;

    const prompt = `
Edit this product photo for a professional marketplace listing.

The item is: ${productName}.

${studioInstruction}

CRITICAL RULES:

- Preserve the exact product.
- Preserve its original shape.
- Preserve the crochet or knitting pattern.
- Preserve its original colors.
- Preserve its proportions and texture.
- Preserve labels and all visible product details.
- Do not invent or duplicate any product parts.
- Do not redesign or replace the product.
- Do not add text, logos, or watermarks.
- Do not add people, hands, or packaging.
- Do not add extra products.
- Center the complete product.
- Keep realistic product edges.
- Improve exposure and sharpness gently.
- Output one polished square product image.
`.trim();

    const endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/' +
      `gemini-2.5-flash-image:generateContent?key=${encodeURIComponent(apiKey)}`;

    const geminiResponse = await fetch(endpoint, {
      method: 'POST',

      headers: {
        'Content-Type': 'application/json',
      },

      body: JSON.stringify({
        contents: [{
          role: 'user',

          parts: [{
              text: prompt,
            },
            {
              inlineData: {
                mimeType: normalizedMimeType,
                data: imageBase64,
              },
            },
          ],
        }, ],

        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE'],
        },
      }),
    });

    const payload = await geminiResponse.json();

    if (!geminiResponse.ok) {
      console.error(
        '[AI Studio] Gemini error:',
        JSON.stringify(payload, null, 2)
      );

      return res.status(502).json({
        error: payload?.error?.message ||
          'Gemini image editing failed',
      });
    }

    const parts =
      payload?.candidates?. [0]?.content?.parts || [];

    const imagePart = parts.find(
      (part) =>
      part.inlineData?.data ||
      part.inline_data?.data
    );

    const generated =
      imagePart?.inlineData ||
      imagePart?.inline_data;

    if (!generated?.data) {
      console.error(
        '[AI Studio] No generated image:',
        JSON.stringify(payload, null, 2)
      );

      return res.status(502).json({
        error: 'AI did not return an edited image',
      });
    }

    return res.json({
      imageBase64: generated.data,

      mimeType: generated.mimeType ||
        generated.mime_type ||
        'image/png',

      preset,
    });
  } catch (error) {
    console.error('[AI Studio] ERROR:', error);

    return res.status(500).json({
      error: 'Failed to enhance product image',
    });
  }
};
exports.generateApology = async (req, res) => {
  try {
    const {
      craftsmanName,
      exhibitionName,
      reason
    } = req.body;

    if (!process.env.GROQ_API_KEY || process.env.GROQ_API_KEY === 'your_groq_api_key_here') {
      // Fallback if no real API key is set
      return res.json({
        message: 'Dear Management,\n\nI sincerely apologize, but due to ' + reason + ', I will not be able to attend the ' + exhibitionName + ' exhibition.\n\nBest regards,\n' + craftsmanName
      });
    }

    const prompt = `Write a professional and polite apology letter from a craftsman named ${craftsmanName} to the management of ${exhibitionName}. The reason for absence is: ${reason}. Keep it brief, professional, and do not include placeholders like [Date]. Return only the text.`;

    const chatCompletion = await groq.chat.completions.create({
      messages: [{
        role: "user",
        content: prompt
      }],
      model: MODEL_NAME,
    });

    const text = chatCompletion.choices[0]?.message?.content || "";

    res.json({
      message: text.trim()
    });
  } catch (error) {
    console.error('AI Error:', error);
    res.status(500).json({
      error: 'Failed to generate apology message'
    });
  }
};

exports.matchStandby = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.params;

    // Fetch all craftsmen on standby for this exhibition
    const standbyList = await ExhibitionCraftsman.findAll({
      where: {
        exhibitionId,
        status: 'standby'
      },
      include: [{
        model: User
      }]
    });

    if (!standbyList || standbyList.length === 0) {
      return res.json({
        message: 'No craftsmen on standby list.'
      });
    }

    // AI Logic Simulation: In a real advanced scenario, we'd pass all profiles to Gemini to pick the best.
    // For now, we simulate AI matching by sorting based on a mock "Commitment Score" and Standby Rank.
    // Assuming each standby entry has a standbyRank property (1, 2, 3...)

    // Sort by rank ascending (1 is best)
    const sortedList = standbyList.sort((a, b) => a.standbyRank - b.standbyRank);
    const topCandidate = sortedList[0];

    res.json({
      message: 'AI successfully matched the best replacement candidate.',
      candidate: {
        id: topCandidate.User.id,
        name: topCandidate.User.name,
        rank: topCandidate.standbyRank
      }
    });

  } catch (error) {
    console.error('Matching Error:', error);
    res.status(500).json({
      error: 'Failed to match standby candidate'
    });
  }
};

exports.validateBio = async (req, res) => {
  try {
    const {
      bio,
      craftCategory,
      language
    } = req.body;
    const lang = language || 'ar';
    const isAr = lang === 'ar';

    if (!bio || bio.trim().length < 10) {
      return res.json({
        approved: false,
        feedback: isAr ? 'النبذة قصيرة جداً. يرجى كتابة وصف أكثر تفصيلاً.' : 'Bio is too short. Please write a more detailed description.'
      });
    }

    // Fallback if no real API key
    if (!process.env.GROQ_API_KEY || process.env.GROQ_API_KEY === 'your_groq_api_key_here') {
      const hasOffensiveWords = /(spam|كلام فاضي|إهانة)/i.test(bio);
      if (hasOffensiveWords) {
        return res.json({
          approved: false,
          feedback: isAr ? 'النبذة تحتوي على محتوى غير مناسب. يرجى إعادة الصياغة.' : 'Bio contains inappropriate content. Please rewrite it.'
        });
      }
      return res.json({
        approved: true,
        feedback: isAr ? 'النبذة مناسبة ومهنية.' : 'Bio looks professional and appropriate.'
      });
    }

    const feedbackLang = isAr ? 'Arabic' : 'English';
    const prompt = `
You are a content moderation assistant for a craftsmen marketplace platform called CraftGo.
A craftsman in the category "${craftCategory}" wrote the following bio:

"${bio}"

Please evaluate this bio and respond ONLY with a valid JSON object in the following format:
{
  "approved": true or false,
  "feedback": "brief feedback in ${feedbackLang}, max 2 sentences"
}

IMPORTANT: The feedback MUST be written in ${feedbackLang.toUpperCase()} only.

Approve the bio if it:
- Is relevant to crafts or the given category
- Is professional and respectful
- Does not contain spam, offensive language, or unrelated content

Reject it if it:
- Contains offensive or inappropriate content
- Is completely unrelated to crafts
- Is spam or nonsense

Respond ONLY with valid JSON, no other text.
`;

    const chatCompletion = await groq.chat.completions.create({
      messages: [{
        role: "user",
        content: prompt
      }],
      model: MODEL_NAME,
      response_format: {
        type: "json_object"
      }
    });

    const text = chatCompletion.choices[0]?.message?.content?.trim() || "";

    // Extract JSON from the response
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[0]);
      return res.json(parsed);
    }

    // If AI response couldn't be parsed, default to approved
    return res.json({
      approved: true,
      feedback: isAr ? 'النبذة تبدو مناسبة.' : 'Bio looks appropriate.'
    });

  } catch (error) {
    // Fail open — don't block user if AI fails
    res.json({
      approved: true,
      feedback: ''
    });
  }
};

exports.generateBio = async (req, res) => {
  try {
    const {
      craftCategory,
      experience,
      specializations
    } = req.body;

    const language = req.body.language || 'ar'; // Default to Arabic

    if (!process.env.GROQ_API_KEY || process.env.GROQ_API_KEY === 'your_groq_api_key_here') {
      const clayStr = (specializations && specializations.length > 0) ? ` باستخدام ${specializations.join(' و ')}` : '';
      if (language === 'en') {
        const clayEn = (specializations && specializations.length > 0) ? ` using ${specializations.join(' and ')}` : '';
        return res.json({
          bio: `I am a craftsman specializing in ${craftCategory} with ${experience || 0} years of experience. I pay great attention to detail and strive to deliver unique pieces of high quality${clayEn}.`
        });
      }
      return res.json({
        bio: `أنا حرفي متخصص في ${craftCategory} مع خبرة تمتد لـ ${experience || 0} سنوات. أهتم جداً بالتفاصيل وأسعى لتقديم قطع فنية مميزة تعكس الجودة العالية${clayStr}.`
      });
    }

    const langText = language === 'en' ? 'English' : 'Arabic';
    const firstPerson = language === 'en' ? '"I"' : '"أنا"';
    let prompt = `Write a professional bio STRICTLY IN ${langText.toUpperCase()} LANGUAGE for a craftsman in the category "${craftCategory}".\n`;
    if (experience) {
      prompt += `They have ${experience} years of experience.\n`;
    }
    if (specializations && specializations.length > 0) {
      prompt += `They specialize in using the following materials/types: ${specializations.join(', ')}.\n`;
    }
    prompt += `Keep it professional, engaging, around 200 characters, written in the first person (${firstPerson}), and do not include placeholders like [Name]. Make this bio unique, creative, and different from typical boilerplate bios. You MUST return the text ONLY in ${langText.toUpperCase()} language. No other languages are allowed.`;

    console.log("SENDING PROMPT TO GROQ:", prompt);

    const chatCompletion = await groq.chat.completions.create({
      messages: [{
          role: "system",
          content: `You are a professional copywriter. You MUST write ONLY in ${langText.toUpperCase()} language. Never use Arabic unless explicitly requested.`
        },
        {
          role: "user",
          content: prompt
        }
      ],
      model: MODEL_NAME,
      temperature: 0.9,
    });

    const text = chatCompletion.choices[0]?.message?.content?.trim() || "";

    res.json({
      bio: text
    });
  } catch (error) {
    console.error('AI Error (Generate Bio):', error);
    res.status(500).json({
      error: 'Failed to generate caption'
    });
  }
};

// ─── Visual Search (Image to Products) ──────────────────────────────────────
const {
  GoogleGenerativeAI
} = require("@google/generative-ai");

exports.visualSearch = async (req, res) => {
  try {
    const file = req.file;
    if (!file) {
      return res.status(400).json({
        error: 'No image uploaded for visual search'
      });
    }

    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({
      model: "gemini-2.5-flash"
    });

    const imageData = fs.readFileSync(file.path).toString("base64");

    const prompt = `
You are an artisan product recognition assistant.\na) Look at the image and identify the object and its visible visual traits.
b) Return ONLY valid JSON in this exact shape:
{
  "description": "short phrase like 'red knitted sweater' or 'red crochet sweater'",
  "keywords": ["red", "knitted", "sweater"]
}
Rules:
- Keep the description simple and human-readable.
- Prefer a material/type phrase such as knitted, crochet, wool, ceramic, wood, silver, cotton, embroidered.
- Use English keywords because the search system matches English and Arabic product text.
- Do not include code fences or extra text.
`;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          data: imageData,
          mimeType: file.mimetype
        }
      }
    ]);
    const response = await result.response;
    const rawText = response.text().trim();

    let parsed = null;
    try {
      const cleaned = rawText.replace(/```json|```/gi, '').trim();
      parsed = JSON.parse(cleaned);
    } catch (_) {
      parsed = null;
    }

    let keywords = [];
    let description = 'handmade craft item';

    if (parsed && typeof parsed === 'object') {
      if (typeof parsed.description === 'string' && parsed.description.trim()) {
        description = parsed.description.trim();
      }
      if (Array.isArray(parsed.keywords)) {
        keywords = parsed.keywords.map(k => String(k).trim()).filter(Boolean);
      } else if (typeof parsed.keywords === 'string') {
        keywords = parsed.keywords.split(',').map(k => k.trim()).filter(Boolean);
      }
    }

    if (keywords.length === 0) {
      const fallback = rawText
        .replace(/\s*[,;|]\s*/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();
      keywords = fallback ?
        fallback.split(' ').map(k => k.trim()).filter(k => k.length > 2) : ['handmade'];
    }

    if (!description || description === 'handmade craft item') {
      description = keywords.join(' ') || 'handmade craft item';
    }

    const Product = require('../models/Product');
    const User = require('../models/User');
    const {
      Op
    } = require('sequelize');

    const likeConditions = keywords.flatMap(kw => [{
        titleAr: {
          [Op.like]: `%${kw}%`
        }
      },
      {
        titleEn: {
          [Op.like]: `%${kw}%`
        }
      },
      {
        description: {
          [Op.like]: `%${kw}%`
        }
      },
      {
        category: {
          [Op.like]: `%${kw}%`
        }
      }
    ]);

    const products = await Product.findAll({
      where: {
        [Op.or]: likeConditions.length ? likeConditions : [{
          titleEn: {
            [Op.like]: '%handmade%'
          }
        }]
      },
      include: [{
        model: User,
        as: 'Craftsman',
        attributes: ['id', 'name', 'city']
      }],
      limit: 10
    });

    res.json({
      description,
      keywords,
      debug: {
        source: 'gemini-2.5-flash',
        raw: rawText,
        description,
        keywords,
      },
      products
    });
  } catch (error) {
    console.error('Visual Search Error:', error);
    res.status(500).json({
      error: 'Failed to process visual search'
    });
  }
};

// ─── Sketch to Generated Mockup ────────────────────────────────────────────
exports.generateSketchMockup = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        error: 'No sketch uploaded'
      });
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      return res.status(503).json({
        error: 'Gemini API key is not configured'
      });
    }

    const prompt = String(req.body?.prompt || '').trim() ||
      'Turn this hand-drawn product concept into a realistic handmade craft product image.';
    const endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/' +
      `gemini-2.5-flash-image:generateContent?key=${encodeURIComponent(apiKey)}`;
    const imageBase64 = fs.readFileSync(req.file.path).toString('base64');

    const geminiResponse = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        contents: [{
          role: 'user',
          parts: [{
              text: `${prompt}\n\nUse the uploaded drawing as the product design reference. Preserve the identifiable object, decorations, arrangement, and flower details from the drawing. Create one polished, realistic product image on a clean studio background. Do not add text, labels, logos, people, or unrelated objects.`,
            },
            {
              inlineData: {
                mimeType: req.file.mimetype,
                data: imageBase64,
              },
            },
          ],
        }],
        generationConfig: {
          responseModalities: ['TEXT', 'IMAGE']
        },
      }),
    });

    const payload = await geminiResponse.json();
    if (!geminiResponse.ok) {
      console.error('[AI Mockup] Gemini error:', JSON.stringify(payload));
      return res.status(502).json({
        error: payload?.error?.message || 'Gemini image generation failed',
      });
    }

    const parts = payload?.candidates?. [0]?.content?.parts || [];
    const imagePart = parts.find((part) =>
      part.inlineData?.data || part.inline_data?.data
    );
    const generated = imagePart?.inlineData || imagePart?.inline_data;
    if (!generated?.data) {
      return res.status(502).json({
        error: 'AI did not return a generated image'
      });
    }

    return res.json({
      imageBase64: generated.data,
      mimeType: generated.mimeType || generated.mime_type || 'image/png',
      source: 'gemini-2.5-flash-image',
    });
  } catch (error) {
    console.error('[AI Mockup] ERROR:', error);
    return res.status(500).json({
      error: 'Failed to generate sketch mockup'
    });
  }
};

// ─── Gift Quiz Recommendations ──────────────────────────────────────────────
exports.giftQuiz = async (req, res) => {
  try {
    const {
      answers
    } = req.body;
    if (!answers || Object.keys(answers).length === 0) {
      return res.status(400).json({
        error: 'Quiz answers are required'
      });
    }

    const prompt = `Based on these gift recipient answers: ${JSON.stringify(answers)}, suggest 3 broad Arabic product categories or keywords for a handmade gift. Reply ONLY with comma-separated Arabic keywords (like "خزفيات", "خشب", "تطريز").`;

    const chatCompletion = await groq.chat.completions.create({
      messages: [{
        role: "user",
        content: prompt
      }],
      model: MODEL_NAME,
    });

    const text = chatCompletion.choices[0]?.message?.content || "هدايا";
    const keywords = text.split(',').map(k => k.trim()).filter(k => k.length > 0);

    const Product = require('../models/Product');
    const User = require('../models/User');
    const {
      Op
    } = require('sequelize');

    const likeConditions = keywords.map(kw => ({
      [Op.or]: [{
          titleAr: {
            [Op.like]: `%${kw}%`
          }
        },
        {
          description: {
            [Op.like]: `%${kw}%`
          }
        },
        {
          category: {
            [Op.like]: `%${kw}%`
          }
        }
      ]
    }));

    const products = await Product.findAll({
      where: {
        [Op.or]: likeConditions
      },
      include: [{
        model: User,
        as: 'Craftsman',
        attributes: ['id', 'name', 'city']
      }],
      limit: 10
    });

    res.json({
      keywords,
      products
    });
  } catch (error) {
    console.error('Gift Quiz Error:', error);
    res.status(500).json({
      error: 'Failed to get gift recommendations'
    });
  }
};

exports.suggestCapacities = async (req, res) => {
  try {
    const {
      description,
      totalCapacity
    } = req.body;

    // Simulate AI for now (or fallback if quota exceeded)
    // In a real scenario we'd send the description to Gemini and ask for JSON allocation.

    const lowerDesc = (description || '').toLowerCase();

    // Smart Fallback Simulation:
    let suggestion = {};
    if (lowerDesc.includes('فخار') || lowerDesc.includes('طين') || lowerDesc.includes('pottery')) {
      suggestion = {
        'Pottery & Ceramics': Math.floor(totalCapacity * 0.5),
        'Crochet & Knitting': Math.floor(totalCapacity * 0.3),
        'Jewelry & Accessories': Math.floor(totalCapacity * 0.2)
      };
    } else if (lowerDesc.includes('خياط') || lowerDesc.includes('تطريز') || lowerDesc.includes('knitting')) {
      suggestion = {
        'Crochet & Knitting': Math.floor(totalCapacity * 0.6),
        'Jewelry & Accessories': Math.floor(totalCapacity * 0.3),
        'Pottery & Ceramics': Math.floor(totalCapacity * 0.1)
      };
    } else {
      // Even distribution
      const third = Math.floor(totalCapacity / 3);
      suggestion = {
        'Crochet & Knitting': third,
        'Pottery & Ceramics': third,
        'Jewelry & Accessories': totalCapacity - (third * 2)
      };
    }

    res.json({
      success: true,
      message: 'تم توليد التوزيع الذكي بنجاح بناءً على وصف المعرض',
      suggestion
    });
  } catch (error) {
    console.error('AI Suggestion Error:', error);
    res.status(500).json({
      error: 'Failed to suggest capacities'
    });
  }
};

exports.analyzeDemand = async (req, res) => {
  try {
    // Simulate AI Demand Analysis
    // Real implementation would analyze all active craftsmen in DB vs active exhibitions

    res.json({
      success: true,
      analysis: 'استناداً إلى بيانات السوق الحالية: هناك إقبال كبير جداً على "الخياطة والتطريز" في منطقتك، ننصحك بتوفير مقاعد كافية لهم لضمان نجاح المعرض.'
    });
  } catch (error) {
    console.error('AI Demand Error:', error);
    res.status(500).json({
      error: 'Failed to analyze demand'
    });
  }
};

exports.screenCandidates = async (req, res) => {
  try {
    const {
      craftsmenList
    } = req.body;

    if (!craftsmenList || craftsmenList.length === 0) {
      return res.json({
        success: true,
        rankedList: []
      });
    }

    // Simulate AI Screening
    // Real AI would evaluate bios, portfolios, and ratings.
    // We simulate by sorting them based on bio length (longer bio = more professional) for demo purposes.

    const rankedList = [...craftsmenList].sort((a, b) => {
      const bioA = a.bio ? a.bio.length : 0;
      const bioB = b.bio ? b.bio.length : 0;
      return bioB - bioA; // Descending
    }).map((c, index) => ({
      ...c,
      aiScore: Math.max(95 - (index * 5), 60), // Mock score 95, 90, 85...
      aiRecommendation: index === 0 ? 'مرشح ممتاز - خبرة قوية' : (index === 1 ? 'مرشح جيد جداً' : 'مرشح مقبول')
    }));

    res.json({
      success: true,
      rankedList
    });
  } catch (error) {
    console.error('AI Screening Error:', error);
    res.status(500).json({
      error: 'Failed to screen candidates'
    });
  }
};

// ─── AI Order Analysis (KEY FEATURE for Committee) ──────────────────────────
// POST /api/ai/analyze-order
// Body: { text?, hasImage?, hasDrawing?, imageDescription? }
// Returns: { category, categoryAr, priceRange, artisans[], products[] }
exports.analyzeOrder = async (req, res) => {
  try {
    const {
      text = '', hasImage = false, hasDrawing = false, imageDescription = ''
    } = req.body || {};

    const User = require('../models/User');
    const Product = require('../models/Product');
    const {
      Op
    } = require('sequelize');

    const combinedInput = `${text} ${imageDescription}`.trim().toLowerCase();
    const extractedKeywords = Array.from(new Set(
      combinedInput
      .split(/[^a-zA-Z\u0621-\u064A0-9]+/)
      .map(s => s.trim())
      .filter(s => s.length > 2)
      .slice(0, 10)
    ));
    const debugDescription =
      extractedKeywords.length > 0 ?
      extractedKeywords.join(' ') :
      (text || imageDescription || 'handmade craft item');

    // ── Keyword-based category detection ──────────────────────────
    const categoryRules = [{
        keywords: ['خشب', 'طاولة', 'كرسي', 'أثاث', 'نجارة', 'wood', 'table', 'chair', 'furniture', 'wooden'],
        category: 'Woodworking',
        categoryAr: 'أعمال الخشب والأثاث',
        priceMin: 60,
        priceMax: 200
      },
      {
        keywords: ['فخار', 'خزف', 'طين', 'إبريق', 'صحن', 'طقم', 'pottery', 'ceramic', 'clay', 'plate', 'pitcher', 'bowl'],
        category: 'Pottery & Ceramics',
        categoryAr: 'فخار وخزف',
        priceMin: 20,
        priceMax: 80
      },
      {
        keywords: ['مجوهرات', 'خاتم', 'سنسال', 'أسوار', 'فضة', 'ذهب', 'خرز', 'jewelry', 'ring', 'necklace', 'bracelet', 'silver', 'gold', 'bead'],
        category: 'Jewelry & Accessories',
        categoryAr: 'مجوهرات وإكسسوارات',
        priceMin: 15,
        priceMax: 100
      },
      {
        keywords: ['لوحة', 'رسم', 'جداري', 'فن تشكيلي', 'art', 'painting', 'canvas', 'wall art'],
        category: 'Painting & Fine Art',
        categoryAr: 'رسم وفن تشكيلي',
        priceMin: 80,
        priceMax: 300
      },
      {
        keywords: ['تطريز', 'نسيج', 'سجادة', 'وشاح', 'خياطة', 'صوف', 'embroidery', 'crochet', 'rug', 'scarf', 'textile', 'wool', 'knit'],
        category: 'Textiles & Embroidery',
        categoryAr: 'أعمال النسيج والتطريز',
        priceMin: 25,
        priceMax: 90
      },
    ];

    let matched = null;
    for (const rule of categoryRules) {
      if (rule.keywords.some(kw => combinedInput.includes(kw))) {
        matched = rule;
        break;
      }
    }

    // Optional Gemini AI classification fallback
    if (!matched && process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY.length > 10 && combinedInput.length > 3) {
      try {
        const {
          GoogleGenerativeAI
        } = require("@google/generative-ai");
        const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({
          model: 'gemini-1.5-flash'
        });
        const prompt = `
You are a classification assistant for CraftGo, a handmade crafts marketplace.
A customer submitted a custom order request:
"${combinedInput}"

Classify this into EXACTLY ONE of these categories:
- Woodworking
- Pottery & Ceramics  
- Jewelry & Accessories
- Textiles & Embroidery
- Painting & Fine Art

Respond ONLY with a valid JSON object:
{ "category": "<category name>", "categoryAr": "<Arabic translation>", "priceMin": <number>, "priceMax": <number> }
No other text.`;

        const result = await model.generateContent(prompt);
        const text_r = result.response.text().trim();
        const jsonMatch = text_r.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0]);
          matched = {
            ...parsed,
            keywords: []
          };
        }
      } catch (aiErr) {
        console.warn('Gemini classify failed, using default fallback:', aiErr.message);
      }
    }

    // Default fallback
    if (!matched) {
      matched = {
        category: 'Textiles & Embroidery',
        categoryAr: 'أعمال النسيج والتطريز',
        priceMin: hasImage || hasDrawing ? 35 : 25,
        priceMax: hasImage || hasDrawing ? 95 : 70,
      };
    }

    // Price boost if image or drawing provided
    const priceBoost = (hasImage ? 10 : 0) + (hasDrawing ? 15 : 0);
    const priceRange = `${matched.priceMin + priceBoost} JOD - ${matched.priceMax + priceBoost} JOD`;

    // Input source label
    let inputSource;
    if (hasImage && hasDrawing && text) inputSource = 'Text + Image + Drawing';
    else if (hasImage && text) inputSource = 'Text + Image';
    else if (hasDrawing && text) inputSource = 'Text + Drawing';
    else if (hasImage) inputSource = 'Reference Image';
    else if (hasDrawing) inputSource = 'Hand Drawing';
    else inputSource = 'Text Description';

    // Extract search terms for keyword matching
    const searchTerms = combinedInput
      .split(/\s+/)
      .map(t => t.trim())
      .filter(t => t.length > 2);

    // Fetch matching artisans from DB
    let artisans = [];
    try {
      artisans = await User.findAll({
        where: {
          role: 'craftsman'
        },
        attributes: ['id', 'name', 'city', 'profileImage'],
        limit: 4,
      });
    } catch (_) {
      artisans = [];
    }

    // Fetch matching products from DB based on Category & Keywords
    let products = [];
    try {
      const searchConditions = [{
        category: matched.category
      }];

      searchTerms.forEach(term => {
        searchConditions.push({
          titleAr: {
            [Op.like]: `%${term}%`
          }
        });
        searchConditions.push({
          titleEn: {
            [Op.like]: `%${term}%`
          }
        });
        searchConditions.push({
          description: {
            [Op.like]: `%${term}%`
          }
        });
      });

      products = await Product.findAll({
        where: {
          [Op.or]: searchConditions
        },
        include: [{
          model: User,
          as: 'Craftsman',
          attributes: ['name', 'city']
        }],
        limit: 6,
      });
    } catch (_) {
      products = [];
    }

    // Dynamic AI product mockups tailored specifically to the customer prompt
    const promptKeywords = text || imageDescription || matched.categoryAr;
    const encodedPrompt = encodeURIComponent(`handmade ${promptKeywords} craft art product`);

    const aiCustomProducts = [{
        id: 'ai-gen-1',
        titleAr: `قطع صُنعت بناءً على طلبك (${matched.categoryAr})`,
        titleEn: `Custom ${matched.category} Craft`,
        price: (matched.priceMin + priceBoost).toFixed(2),
        rating: '4.9',
        category: matched.category,
        imageUrl: `https://pollinations.ai/p/${encodedPrompt}%20detailed%20artisan%20work?width=500&height=500&seed=11&nologo=true`,
        Craftsman: {
          name: 'ورشة إبداعية متخصصة',
          city: 'رام الله'
        }
      },
      {
        id: 'ai-gen-2',
        titleAr: `نموذج مطعّم بخامات طبيعية`,
        titleEn: `Natural Material Custom Piece`,
        price: (matched.priceMax - 5).toFixed(2),
        rating: '4.8',
        category: matched.category,
        imageUrl: `https://pollinations.ai/p/${encodedPrompt}%20rustic%20authentic%20handcrafted?width=500&height=500&seed=22&nologo=true`,
        Craftsman: {
          name: 'استوديو الحرف التراثية',
          city: 'القدس'
        }
      }
    ];

    // Combine matched DB products with tailored AI generated product concepts
    const combinedProducts = [...products, ...aiCustomProducts];

    return res.json({
      success: true,
      inputSource,
      category: matched.category,
      categoryAr: matched.categoryAr,
      priceRange,
      artisans,
      products: combinedProducts,
      keywords: extractedKeywords,
      description: debugDescription,
      debug: {
        source: 'keyword-classifier',
        inputSource,
        description: debugDescription,
        keywords: extractedKeywords,
      },
    });
  } catch (error) {
    console.error('AI Order Analysis Error:', error);
    // Always return 200 with fallback data so frontend never crashes
    return res.json({
      success: true,
      category: 'Textiles & Embroidery',
      categoryAr: 'أعمال النسيج والتطريز',
      priceRange: '25 JOD - 75 JOD',
      artisans: [],
      products: [],
    });
  }
};

// ─── Real Demand Analysis using DB ─────────────────────────────────────────
exports.analyzeDemand = async (req, res) => {
  try {
    const UserInteraction = require('../models/UserInteraction');
    const Product = require('../models/Product');
    const {
      Sequelize
    } = require('sequelize');

    // Count interactions grouped by product category
    const results = await UserInteraction.findAll({
      attributes: [
        [Sequelize.col('Product.category'), 'category'],
        [Sequelize.fn('SUM', Sequelize.col('score')), 'totalScore'],
        [Sequelize.fn('COUNT', Sequelize.col('UserInteraction.id')), 'interactions'],
      ],
      include: [{
        model: Product,
        attributes: []
      }],
      group: ['Product.category'],
      order: [
        [Sequelize.fn('SUM', Sequelize.col('score')), 'DESC']
      ],
      raw: true,
    });

    const topCategory = results[0]?.category || 'Textiles & Embroidery';

    const arabicCategoryMap = {
      'Woodworking': 'أعمال الخشب',
      'Pottery & Ceramics': 'الفخار والخزف',
      'Jewelry & Accessories': 'المجوهرات',
      'Textiles & Embroidery': 'الخياطة والتطريز',
      'Painting & Fine Art': 'الفن التشكيلي',
    };
    const topAr = arabicCategoryMap[topCategory] || topCategory;

    res.json({
      success: true,
      topCategory,
      topCategoryAr: topAr,
      breakdown: results,
      analysis: results.length > 0 ?
        `بناءً على بيانات التفاعل الحقيقية: هناك إقبال كبير جداً على "${topAr}" في منصتك. ننصح بتوفير مقاعد كافية لهم لضمان نجاح المعرض.` : 'لا توجد بيانات تفاعل بعد. ستظهر التحليلات بعد بدء تفاعل المستخدمين مع المنتجات.',
    });
  } catch (error) {
    console.error('AI Demand Error:', error);
    res.status(500).json({
      error: 'Failed to analyze demand'
    });
  }
};
// ─── CraftGo AI Product Assistant ───────────────────────────────────────────
// POST /api/ai/product-assistant
// Body: { title, category, materials, dimensions, colors, language, hasImage }

// ─────────────────────────────────────────────────────────────────────────────
// CraftGo AI Product Assistant
// POST /api/ai/product-assistant
// ─────────────────────────────────────────────────────────────────────────────

exports.productAssistant = async (req, res) => {
  try {
    const {
      title = '',
        category = '',
        materials = [],
        dimensions = '',
        colors = '',
        language = 'ar',
        description = '',
        hasImage = false,
        imageCount = 0,
    } = req.body || {};

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Normalize input
    // ─────────────────────────────────────────────────────────────────────────

    const cleanTitle = String(title || '').trim();
    const cleanCategory = String(category || '').trim();
    const cleanDescription = String(description || '').trim();
    const cleanDimensions = String(dimensions || '').trim();
    const cleanColors = String(colors || '').trim();

    const materialList = Array.isArray(materials) ?
      materials
      .map((item) => String(item || '').trim())
      .filter(Boolean) :
      String(materials || '')
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean);

    const productImageCount = Math.max(
      0,
      Math.min(
        5,
        Number(imageCount) || (hasImage ? 1 : 0)
      )
    );

    if (!cleanTitle) {
      return res.status(400).json({
        error: 'Product title is required',
      });
    }

    if (!cleanCategory) {
      return res.status(400).json({
        error: 'Product category is required',
      });
    }

    const isArabic = language === 'ar';

    const outputLanguage =
      isArabic ? 'Arabic' : 'English';

    const normalizedTitle =
      cleanTitle.toLowerCase();

    const normalizedCategory =
      cleanCategory.toLowerCase();

    const normalizedMaterials =
      materialList
      .join(' ')
      .toLowerCase();

    const combinedProductText = [
      normalizedTitle,
      normalizedCategory,
      normalizedMaterials,
      cleanDescription.toLowerCase(),
    ].join(' ');

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Category base price
    //
    // This is only a GUIDE for Groq.
    // It is no longer the final forced price.
    // ─────────────────────────────────────────────────────────────────────────

    const categoryRules = [{
        keys: [
          'pottery',
          'ceramic',
          'فخار',
          'خزف',
        ],
        base: 26,
      },
      {
        keys: [
          'jewelry',
          'مجوهر',
        ],
        base: 38,
      },
      {
        keys: [
          'wood',
          'خشب',
        ],
        base: 42,
      },
      {
        keys: [
          'glass',
          'زجاج',
        ],
        base: 36,
      },
      {
        keys: [
          'metal',
          'metals',
          'معادن',
          'معدن',
        ],
        base: 48,
      },
      {
        keys: [
          'leather',
          'جلد',
        ],
        base: 44,
      },
      {
        keys: [
          'embroidery',
          'تطريز',
        ],
        base: 28,
      },
      {
        keys: [
          'sewing',
          'خياطة',
        ],
        base: 25,
      },
      {
        keys: [
          'paper',
          'ورق',
        ],
        base: 18,
      },
      {
        keys: [
          'stone',
          'حجر',
        ],
        base: 40,
      },
    ];

    let calculatedPrice = 28;

    for (const rule of categoryRules) {
      if (
        rule.keys.some(
          (key) =>
          normalizedCategory.includes(key) ||
          combinedProductText.includes(key)
        )
      ) {
        calculatedPrice = rule.base;
        break;
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Product-specific adjustments
    //
    // THIS is what makes:
    // cup != bowl != vase != plate != earrings != necklace, etc.
    // ─────────────────────────────────────────────────────────────────────────

    const typeRules = [
      // POTTERY / CERAMIC
      {
        words: [
          'espresso cup',
          'coffee cup',
          'cup',
          'mug',
          'فنجان',
          'كوب',
        ],
        adjustment: -4,
        type: 'Ceramic Cup',
      },

      {
        words: [
          'serving bowl',
          'bowl',
          'زبدية',
          'وعاء',
        ],
        adjustment: 1,
        type: 'Serving Bowl',
      },

      {
        words: [
          'vase',
          'مزهرية',
          'فازة',
        ],
        adjustment: 8,
        type: 'Decorative Vase',
      },

      {
        words: [
          'plate',
          'decorative plate',
          'طبق',
          'صحن',
        ],
        adjustment: 2,
        type: 'Ceramic Plate',
      },

      {
        words: [
          'teapot',
          'tea pot',
          'إبريق',
        ],
        adjustment: 10,
        type: 'Teapot',
      },

      {
        words: [
          'candle holder',
          'شمعدان',
          'حامل شموع',
        ],
        adjustment: 4,
        type: 'Candle Holder',
      },

      {
        words: [
          'planter',
          'plant pot',
          'flower pot',
          'أصيص',
        ],
        adjustment: 5,
        type: 'Planter',
      },

      {
        words: [
          'serving tray',
          'tray',
          'صينية',
        ],
        adjustment: 6,
        type: 'Serving Tray',
      },

      // JEWELRY
      {
        words: [
          'earring',
          'earrings',
          'قرط',
          'أقراط',
        ],
        adjustment: -2,
        type: 'Earrings',
      },

      {
        words: [
          'necklace',
          'عقد',
          'قلادة',
        ],
        adjustment: 6,
        type: 'Necklace',
      },

      {
        words: [
          'bracelet',
          'سوار',
          'اسوار',
        ],
        adjustment: 2,
        type: 'Bracelet',
      },

      {
        words: [
          'brooch',
          'بروش',
        ],
        adjustment: 1,
        type: 'Brooch',
      },

      {
        words: [
          'ring',
          'خاتم',
        ],
        adjustment: -1,
        type: 'Ring',
      },

      // WOOD
      {
        words: [
          'drawer',
          'drawer chest',
          'chest',
          'أدراج',
          'خزانة',
        ],
        adjustment: 10,
        type: 'Drawer Chest',
      },

      {
        words: [
          'box',
          'صندوق',
        ],
        adjustment: 3,
        type: 'Decorative Box',
      },

      {
        words: [
          'table',
          'طاولة',
        ],
        adjustment: 20,
        type: 'Table',
      },

      {
        words: [
          'chair',
          'كرسي',
        ],
        adjustment: 18,
        type: 'Chair',
      },

      // TEXTILES
      {
        words: [
          'blanket',
          'بطانية',
        ],
        adjustment: 12,
        type: 'Blanket',
      },

      {
        words: [
          'cardigan',
          'كارديغان',
        ],
        adjustment: 8,
        type: 'Cardigan',
      },

      {
        words: [
          'sweater',
          'كنزة',
        ],
        adjustment: 7,
        type: 'Sweater',
      },

      {
        words: [
          'bag',
          'handbag',
          'حقيبة',
          'شنطة',
        ],
        adjustment: 5,
        type: 'Handmade Bag',
      },
    ];

    let detectedProductType =
      cleanTitle || cleanCategory;

    // Apply ONLY the strongest / first specific match.
    for (const rule of typeRules) {
      const found =
        rule.words.some(
          (word) =>
          normalizedTitle.includes(word)
        );

      if (found) {
        calculatedPrice += rule.adjustment;
        detectedProductType = rule.type;
        break;
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Quality / craftsmanship adjustments
    // ─────────────────────────────────────────────────────────────────────────

    const craftsmanshipRules = [{
        words: [
          'hand-painted',
          'hand painted',
          'handpainted',
          'مرسوم يدوياً',
          'مرسوم يدوي',
        ],
        amount: 4,
      },

      {
        words: [
          'handmade',
          'handcrafted',
          'يدوي',
          'مصنوع يدوياً',
        ],
        amount: 3,
      },

      {
        words: [
          'calligraphy',
          'خط عربي',
        ],
        amount: 5,
      },

      {
        words: [
          'carved',
          'engraved',
          'منحوت',
          'محفور',
        ],
        amount: 6,
      },

      {
        words: [
          'vintage',
          'antique',
          'عتيق',
        ],
        amount: 3,
      },

      {
        words: [
          'custom',
          'customized',
          'personalized',
          'مخصص',
        ],
        amount: 5,
      },

      {
        words: [
          'detailed',
          'intricate',
          'تفاصيل دقيقة',
        ],
        amount: 3,
      },

      {
        words: [
          'set',
          'طقم',
        ],
        amount: 4,
      },
    ];

    for (const rule of craftsmanshipRules) {
      if (
        rule.words.some(
          (word) =>
          combinedProductText.includes(word)
        )
      ) {
        calculatedPrice += rule.amount;
      }
    }

    // Prevent craft words from stacking too aggressively.
    calculatedPrice = Math.max(
      5,
      calculatedPrice
    );

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Materials adjustments
    // ─────────────────────────────────────────────────────────────────────────

    if (materialList.length > 1) {
      calculatedPrice +=
        Math.min(
          materialList.length - 1,
          4
        );
    }

    const premiumMaterialRules = [{
        words: [
          'silver',
          'sterling silver',
          'فضة',
        ],
        amount: 6,
      },

      {
        words: [
          'gold',
          'ذهب',
        ],
        amount: 10,
      },

      {
        words: [
          'natural wood',
          'solid wood',
          'خشب طبيعي',
        ],
        amount: 4,
      },

      {
        words: [
          'leather',
          'جلد طبيعي',
        ],
        amount: 5,
      },

      {
        words: [
          'glass',
          'زجاج',
        ],
        amount: 2,
      },
    ];

    for (const rule of premiumMaterialRules) {
      if (
        rule.words.some(
          (word) =>
          normalizedMaterials.includes(word) ||
          combinedProductText.includes(word)
        )
      ) {
        calculatedPrice += rule.amount;
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Dimension / size adjustment
    // ─────────────────────────────────────────────────────────────────────────

    const dimensionNumbers =
      cleanDimensions
      .match(/\d+(?:\.\d+)?/g)
      ?.map(Number)
      .filter(Number.isFinite) || [];

    const largestDimension =
      dimensionNumbers.length ?
      Math.max(...dimensionNumbers) :
      0;

    if (largestDimension >= 100) {
      calculatedPrice += 25;
    } else if (largestDimension >= 70) {
      calculatedPrice += 15;
    } else if (largestDimension >= 50) {
      calculatedPrice += 9;
    } else if (largestDimension >= 35) {
      calculatedPrice += 5;
    } else if (largestDimension >= 25) {
      calculatedPrice += 3;
    } else if (
      largestDimension > 0 &&
      largestDimension <= 8
    ) {
      calculatedPrice -= 2;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Deterministic fallback guide
    // ─────────────────────────────────────────────────────────────────────────

    const guidedPrice = Math.max(
      5,
      Math.round(calculatedPrice)
    );

    const guidedMinimumPrice =
      Math.max(
        5,
        Math.round(guidedPrice * 0.82)
      );

    const guidedMaximumPrice =
      Math.max(
        guidedPrice,
        Math.round(guidedPrice * 1.22)
      );

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Product type detection for recommendations
    // ─────────────────────────────────────────────────────────────────────────

    const isJewelry =
      normalizedCategory.includes('jewelry') ||
      normalizedCategory.includes('مجوهر') ||
      combinedProductText.includes('earring') ||
      combinedProductText.includes('necklace') ||
      combinedProductText.includes('bracelet') ||
      combinedProductText.includes('brooch') ||
      combinedProductText.includes('ring') ||
      combinedProductText.includes('قرط') ||
      combinedProductText.includes('عقد') ||
      combinedProductText.includes('سوار') ||
      combinedProductText.includes('بروش');

    const isWood =
      normalizedCategory.includes('wood') ||
      combinedProductText.includes('wood') ||
      combinedProductText.includes('خشب');

    const isMetal =
      normalizedCategory.includes('metal') ||
      combinedProductText.includes('metal') ||
      combinedProductText.includes('silver') ||
      combinedProductText.includes('gold') ||
      combinedProductText.includes('معدن') ||
      combinedProductText.includes('فضة') ||
      combinedProductText.includes('ذهب');

    const isTextile =
      normalizedCategory.includes('sewing') ||
      normalizedCategory.includes('embroidery') ||
      combinedProductText.includes('crochet') ||
      combinedProductText.includes('knit') ||
      combinedProductText.includes('thread') ||
      combinedProductText.includes('fabric') ||
      combinedProductText.includes('خياطة') ||
      combinedProductText.includes('تطريز') ||
      combinedProductText.includes('كروشيه') ||
      combinedProductText.includes('خيط') ||
      combinedProductText.includes('قماش');

    const isPottery =
      normalizedCategory.includes('pottery') ||
      combinedProductText.includes('ceramic') ||
      combinedProductText.includes('clay') ||
      combinedProductText.includes('فخار') ||
      combinedProductText.includes('خزف') ||
      combinedProductText.includes('طين');

    const isGlass =
      normalizedCategory.includes('glass') ||
      combinedProductText.includes('glass') ||
      combinedProductText.includes('زجاج');

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Smart recommendations
    // ─────────────────────────────────────────────────────────────────────────

    const buildSmartRecommendations = (
      descriptionForRecommendations = cleanDescription
    ) => {
      const recommendations = [];

      const add = (text) => {
        const value =
          String(text || '').trim();

        if (!value) return;

        const lower =
          value.toLowerCase();

        const banned = [
          'certificate',
          'certification',
          'warranty',
          'guarantee',
          'authenticity',
          'شهادة',
          'ضمان',
        ];

        if (
          banned.some(
            (word) =>
            lower.includes(word)
          )
        ) {
          return;
        }

        if (
          !recommendations.some(
            (item) =>
            item.toLowerCase() === lower
          )
        ) {
          recommendations.push(value);
        }
      };

      if (productImageCount === 0) {
        add(
          isArabic ?
          'أضف صورة واضحة وعالية الجودة للمنتج.' :
          'Add a clear high-quality product image.'
        );
      } else if (productImageCount === 1) {
        add(
          isArabic ?
          'أضف صوراً إضافية من زوايا مختلفة.' :
          'Add more product images from different angles.'
        );
      }

      if (!cleanDimensions) {
        add(
          isArabic ?
          'أضف أبعاد المنتج لمساعدة العميل على فهم حجمه.' :
          'Add product dimensions to help customers understand its size.'
        );
      }

      if (!cleanColors) {
        add(
          isArabic ?
          'أضف الألوان المتوفرة للمنتج.' :
          'Add the available product colors.'
        );
      }

      if (materialList.length === 0) {
        add(
          isArabic ?
          'أضف تفاصيل المواد المستخدمة.' :
          'Add details about the materials used.'
        );
      }

      if (
        String(descriptionForRecommendations || '')
        .trim()
        .length < 90
      ) {
        add(
          isArabic ?
          'أضف وصفاً أكثر تفصيلاً للمواد والحرفية ومميزات المنتج.' :
          'Add a detailed description of the materials, craftsmanship, and main product features.'
        );
      }

      if (isPottery || isGlass) {
        add(
          isArabic ?
          'أضف تعليمات واضحة للعناية والاستخدام الآمن.' :
          'Provide clear care and safe-use instructions.'
        );

        if (!cleanDimensions) {
          add(
            isArabic ?
            'وضّح الأبعاد أو السعة إذا كان المنتج يستخدم للتقديم أو التخزين.' :
            'Clarify dimensions or capacity when the product is intended for serving or storage.'
          );
        } else {
          add(
            isArabic ?
            'أضف معلومات عن التغليف وطريقة التعامل مع القطعة لحمايتها أثناء النقل.' :
            'Add packaging and handling details to help protect the ceramic piece.'
          );
        }
      }

      if (isJewelry) {
        add(
          isArabic ?
          'أضف تعليمات بسيطة للعناية بالقطعة.' :
          'Provide simple care instructions for the piece.'
        );

        add(
          isArabic ?
          'وضّح إذا كان يمكن تخصيص اللون أو المقاس أو التصميم.' :
          'Clarify whether color, size, or design details can be customized.'
        );
      }

      if (isWood) {
        add(
          isArabic ?
          'أضف تعليمات العناية بالخشب للحفاظ على جودة المنتج.' :
          'Provide care instructions for the wood material.'
        );
      }

      if (isMetal) {
        add(
          isArabic ?
          'أضف تعليمات العناية بالمعدن للحفاظ على التشطيب.' :
          'Provide care instructions to maintain the metal finish.'
        );
      }

      if (isTextile) {
        add(
          isArabic ?
          'أضف تعليمات الغسيل والعناية بالقماش أو الخيوط.' :
          'Provide washing and care instructions for the fabric or thread.'
        );
      }

      if (productImageCount >= 2) {
        add(
          isArabic ?
          'تأكد أن الصور توضح أهم التفاصيل من زوايا مفيدة.' :
          'Ensure the images clearly show important details from useful angles.'
        );
      }

      add(
        isArabic ?
        'استخدم كلمات مفتاحية مرتبطة بنوع المنتج ومواده لتحسين ظهوره.' :
        'Use relevant keywords related to the product type and materials for better visibility.'
      );

      return recommendations.slice(0, 3);
    };

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Calculate completeness score fallback
    // ─────────────────────────────────────────────────────────────────────────

    const completenessChecks = [
      cleanTitle.length > 0,
      cleanCategory.length > 0,
      materialList.length > 0,
      cleanDimensions.length > 0,
      cleanColors.length > 0,
      cleanDescription.length >= 70,
      productImageCount >= 1,
      productImageCount >= 2,
      productImageCount >= 3,
    ];

    const completenessCount =
      completenessChecks.filter(Boolean).length;

    let fallbackScore = 55;

    if (completenessCount >= 9) {
      fallbackScore = 90;
    } else if (completenessCount >= 8) {
      fallbackScore = 85;
    } else if (completenessCount >= 7) {
      fallbackScore = 80;
    } else if (completenessCount >= 6) {
      fallbackScore = 72;
    } else if (completenessCount >= 5) {
      fallbackScore = 65;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Fallback if Groq unavailable
    // ─────────────────────────────────────────────────────────────────────────

    const groqAvailable =
      process.env.GROQ_API_KEY &&
      process.env.GROQ_API_KEY !==
      'your_groq_api_key_here' &&
      process.env.GROQ_API_KEY !==
      'dummy_key';

    if (!groqAvailable) {
      const materialsText =
        materialList.length > 0 ?
        materialList.join(', ') :
        isArabic ?
        'مواد مختارة بعناية' :
        'carefully selected materials';

      return res.json({
        description: isArabic ?
          `${cleanTitle} قطعة يدوية ضمن فئة ${cleanCategory}، صُنعت باستخدام ${materialsText}. تتميز بتفاصيل حرفية وتصميم مناسب للاستخدام أو الديكور.` : `${cleanTitle} is a handcrafted piece in the ${cleanCategory} category, made using ${materialsText}. It features thoughtful artisan details and a distinctive design suitable for practical or decorative use.`,

        suggestedPrice: guidedPrice,
        minimumPrice: guidedMinimumPrice,
        maximumPrice: guidedMaximumPrice,

        priceReason: isArabic ?
          `تم تقدير السعر بناءً على نوع المنتج (${detectedProductType}) والفئة والمواد والأبعاد ومستوى العمل اليدوي.` : `The price was estimated from the product type (${detectedProductType}), category, materials, dimensions, and expected handmade effort.`,

        tags: [
            detectedProductType,
            cleanCategory,
            ...(materialList.slice(0, 2)),
            isArabic ? 'يدوي' : 'Handmade',
          ]
          .filter(Boolean)
          .slice(0, 5),

        score: fallbackScore,

        sellingPotential: fallbackScore >= 88 ?
          isArabic ?
          'مرتفع' :
          'High' : fallbackScore >= 65 ?
          isArabic ?
          'متوسط' :
          'Medium' : isArabic ?
          'منخفض' : 'Low',

        recommendations: buildSmartRecommendations(),
      });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 12. Let GROQ perform final intelligent pricing
    //
    // Unlike the old version:
    // Groq is now allowed to return its own price.
    //
    // But we give it a sensible CraftGo guide so it doesn't return absurd values.
    // ─────────────────────────────────────────────────────────────────────────

    const prompt = `
You are CraftGo's senior handmade-product pricing and listing expert.

Analyze ONE handmade product independently.

IMPORTANT:
Do not reuse a generic category price.
A vase, bowl, coffee cup, plate, necklace, brooch, drawer chest, etc. must be evaluated as different product types.

PRODUCT DATA

Title:
${cleanTitle}

Detected product type:
${detectedProductType}

Category:
${cleanCategory}

Materials:
${materialList.join(', ') || 'Not provided'}

Dimensions:
${cleanDimensions || 'Not provided'}

Colors:
${cleanColors || 'Not provided'}

Description:
${cleanDescription || 'Not provided'}

Number of product images:
${productImageCount}

Currency:
JOD

CraftGo deterministic guide:
- guide price: ${guidedPrice} JOD
- guide minimum: ${guidedMinimumPrice} JOD
- guide maximum: ${guidedMaximumPrice} JOD

Use this guide only as a sanity reference.

YOU must decide the final suggested price based on:
1. exact product type
2. handmade effort
3. hand-painted / carved / detailed work
4. materials
5. product dimensions
6. whether it is functional or decorative
7. complexity of craftsmanship
8. listing completeness

You do NOT have live market price access.
Do not claim that you checked current market prices.

The final AI price does NOT have to equal the CraftGo guide price.

However, keep the final suggested price reasonably close to the guide unless product details justify a difference.

Return ONLY valid JSON:

{
  "description": "professional product description in ${outputLanguage}, around 60-100 words",
  "suggestedPrice": 0,
  "minimumPrice": 0,
  "maximumPrice": 0,
  "priceReason": "brief explanation in ${outputLanguage}",
  "tags": ["tag1", "tag2", "tag3", "tag4", "tag5"],
  "score": 0,
  "sellingPotential": "Low, Medium, High, or Very High translated to ${outputLanguage}"
}

RULES

- suggestedPrice must be a positive number.
- minimumPrice <= suggestedPrice.
- suggestedPrice <= maximumPrice.
- minimumPrice, suggestedPrice and maximumPrice must be integers.
- Score must be an integer from 0 to 100.
- Multiple clear images improve listing quality.
- Missing information reduces listing quality.
- Do not invent certifications.
- Do not invent warranties.
- Do not invent awards.
- Do not invent materials that are not provided.
- Do not generate recommendations.
- Write ALL user-facing text only in ${outputLanguage}.

LANGUAGE RULES:
- If outputLanguage is English, every generated word must be in English.
- Never use Arabic script inside English output.
- If any input value is Arabic, translate its meaning naturally into English before using it.
- The description must be entirely in ${outputLanguage}.
- The priceReason must be entirely in ${outputLanguage}.
- Every tag must be entirely in ${outputLanguage}.
- sellingPotential must be entirely in ${outputLanguage}.
- Do not copy Arabic material names, category names, or other Arabic input directly into English generated text.
- Never mix two languages in the same generated field.

LISTING COMPLETENESS RULES:
- Your job is to GENERATE the final product description.
- Do NOT penalize the listing merely because "Current description" was empty before this analysis.
- Evaluate description completeness using the description YOU generate in this response.
- If dimensions are provided above, do NOT say dimensions are missing.
- If materials are provided above, do NOT say materials are missing.
- If colors are provided above, do NOT say colors are missing.
- If product images are provided above, do NOT say product images are missing.
- priceReason must explain the price only; it must not complain about missing description information.

- Return JSON only.
`.trim();

    // ─────────────────────────────────────────────────────────────────────────
    // 13. Groq request
    // ─────────────────────────────────────────────────────────────────────────

    const chatCompletion =
      await groq.chat.completions.create({
        messages: [{
            role: 'system',
            content: `You are a precise handmade marketplace pricing and listing expert. ` +
              `You evaluate every product individually. ` +
              `Never reuse the same price simply because two products share a category. ` +
              `Respond only with valid JSON. ` +
              `You MUST write every user-facing generated field entirely in ${outputLanguage}. ` +
              (isArabic ?
                `Use Arabic only. Do not mix English sentences into generated Arabic content. ` :
                `Use English only. NEVER output Arabic script in description, priceReason, tags, or sellingPotential. Translate Arabic input terms into natural English before using them. `) +
              `Do not penalize an empty incoming description because generating the final description is part of your task. ` +
              `Never claim that materials, dimensions, colors, or images are missing when they were supplied in the product data.`,
          },
          {
            role: 'user',
            content: prompt,
          },
        ],

        model: MODEL_NAME,

        response_format: {
          type: 'json_object',
        },

        // Slight variation in reasoning while remaining stable.
        temperature: 0.25,
      });

    const content =
      chatCompletion.choices?. [0]
      ?.message
      ?.content
      ?.trim() || '{}';

    let parsed;

    try {
      parsed = JSON.parse(content);
    } catch (parseError) {
      console.error(
        'Product Assistant JSON parse error:',
        content
      );

      throw new Error(
        'Invalid JSON returned by AI'
      );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 14. Validate AI pricing
    // ─────────────────────────────────────────────────────────────────────────

    let aiSuggested =
      Math.round(
        Number(parsed.suggestedPrice)
      );

    let aiMinimum =
      Math.round(
        Number(parsed.minimumPrice)
      );

    let aiMaximum =
      Math.round(
        Number(parsed.maximumPrice)
      );

    // Absolute sanity limits based on CraftGo guide.
    const safeLowerBound =
      Math.max(
        5,
        Math.round(
          guidedMinimumPrice * 0.70
        )
      );

    const safeUpperBound =
      Math.max(
        guidedMaximumPrice,
        Math.round(
          guidedMaximumPrice * 1.40
        )
      );

    if (
      !Number.isFinite(aiSuggested) ||
      aiSuggested <= 0
    ) {
      aiSuggested = guidedPrice;
    }

    aiSuggested =
      Math.max(
        safeLowerBound,
        Math.min(
          safeUpperBound,
          aiSuggested
        )
      );

    if (
      !Number.isFinite(aiMinimum) ||
      aiMinimum <= 0
    ) {
      aiMinimum =
        Math.round(
          aiSuggested * 0.82
        );
    }

    if (
      !Number.isFinite(aiMaximum) ||
      aiMaximum <= 0
    ) {
      aiMaximum =
        Math.round(
          aiSuggested * 1.22
        );
    }

    aiMinimum =
      Math.max(
        5,
        Math.min(
          aiMinimum,
          aiSuggested
        )
      );

    aiMaximum =
      Math.max(
        aiSuggested,
        aiMaximum
      );

    // Prevent an absurdly wide range.
    const maximumAllowedRange =
      Math.max(
        aiSuggested + 5,
        Math.round(
          aiSuggested * 1.35
        )
      );

    aiMaximum =
      Math.min(
        aiMaximum,
        maximumAllowedRange
      );

    // ─────────────────────────────────────────────────────────────────────────
    // 15. Validate score
    // ─────────────────────────────────────────────────────────────────────────

    let score =
      Math.round(
        Number(parsed.score)
      );

    if (!Number.isFinite(score)) {
      score = fallbackScore;
    }

    score =
      Math.max(
        0,
        Math.min(
          100,
          score
        )
      );

    // Keep score consistent with actual completeness.
    if (completenessCount >= 9) {
      score = Math.max(score, 88);
    } else if (completenessCount >= 8) {
      score = Math.max(score, 84);
    } else if (completenessCount >= 7) {
      score = Math.max(score, 80);
    } else if (completenessCount >= 6) {
      score = Math.max(score, 72);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 16. Validate tags
    // ─────────────────────────────────────────────────────────────────────────

    const tags =
      Array.isArray(parsed.tags) ?
      parsed.tags
      .map(
        (tag) =>
        String(tag || '').trim()
      )
      .filter(Boolean)
      .filter((tag) => {
        const lower =
          tag.toLowerCase();

        return ![
          'suggested keyword',
          'keyword',
          'tag',
        ].includes(lower);
      })
      .slice(0, 5) : [];

    // ─────────────────────────────────────────────────────────────────────────
    // 17. Selling potential
    // ─────────────────────────────────────────────────────────────────────────

    let sellingPotential =
      String(
        parsed.sellingPotential || ''
      ).trim();

    if (!sellingPotential) {
      sellingPotential =
        score >= 90 ?
        isArabic ?
        'مرتفع جداً' :
        'Very High' :
        score >= 80 ?
        isArabic ?
        'مرتفع' :
        'High' :
        score >= 60 ?
        isArabic ?
        'متوسط' :
        'Medium' :
        isArabic ?
        'منخفض' :
        'Low';
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 18. Final response
    // ─────────────────────────────────────────────────────────────────────────


    // ─────────────────────────────────────────────────────────────────────────
    // Final generated description
    // ─────────────────────────────────────────────────────────────────────────

    let finalDescription =
      String(
        parsed.description ||
        cleanDescription ||
        cleanTitle
      ).trim();

    // Safety check: English mode must never contain Arabic script.
    const containsArabic =
      /[\u0600-\u06FF]/.test(finalDescription);

    if (!isArabic && containsArabic) {
      console.warn(
        'AI returned mixed Arabic/English description. Rewriting in English...'
      );

      try {
        const rewriteResponse =
          await groq.chat.completions.create({
            messages: [{
                role: 'system',
                content: 'You are an English product copywriter. ' +
                  'Rewrite the supplied product description entirely in natural English. ' +
                  'Translate any Arabic words into English. ' +
                  'Do not add new facts. ' +
                  'Do not use Arabic script. ' +
                  'Return only the rewritten description.',
              },
              {
                role: 'user',
                content: finalDescription,
              },
            ],

            model: MODEL_NAME,
            temperature: 0.1,
          });

        const rewritten =
          rewriteResponse.choices?. [0]
          ?.message
          ?.content
          ?.trim();

        if (
          rewritten &&
          !/[\u0600-\u06FF]/.test(rewritten)
        ) {
          finalDescription = rewritten;
        }
      } catch (rewriteError) {
        console.warn(
          'Description language cleanup failed:',
          rewriteError.message
        );
      }
    }

    // Build recommendations AFTER the final AI description exists.
    const finalRecommendations =
      buildSmartRecommendations(finalDescription);








    return res.json({
      description: finalDescription,

      suggestedPrice: aiSuggested,

      minimumPrice: aiMinimum,

      maximumPrice: aiMaximum,

      priceReason: String(
        parsed.priceReason ||
        (
          isArabic ?
          `تم تقدير السعر بناءً على نوع المنتج (${detectedProductType}) والمواد والأبعاد والتفاصيل الحرفية.` :
          `The price was estimated from the product type (${detectedProductType}), materials, dimensions, and craftsmanship.`
        )
      ).trim(),

      tags,

      score,

      sellingPotential,

      recommendations: finalRecommendations,

      // Useful for debugging.
      pricingMeta: {
        detectedProductType,
        craftGoGuidePrice: guidedPrice,
        craftGoGuideMin: guidedMinimumPrice,
        craftGoGuideMax: guidedMaximumPrice,
        aiPricingUsed: true,
      },
    });
  } catch (error) {
    console.error(
      'AI Product Assistant Error:',
      error
    );

    return res.status(500).json({
      error: 'Failed to analyze product',
      details: error.message,
    });
  }
};


exports.verifyIdImage = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        message: 'No image provided for verification'
      });
    }

    if (
      !process.env.GROQ_API_KEY ||
      process.env.GROQ_API_KEY === 'your_groq_api_key_here'
    ) {
      // Mock success if no API key
      const fileUrl =
        `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

      return res.json({
        message: 'Image verified (mock)',
        url: fileUrl,
        verificationData: {
          isBlurred: false,
          brightnessScore: 8,
          isIdInFrame: true,
          qualityScore: 9,
          aiRecommendation: 'Suitable for review',
          reason: ''
        }
      });
    }

    // Convert image to base64
    const imageAsBase64 =
      fs.readFileSync(req.file.path, 'base64');

    // Call Groq Vision Model
    let chatCompletion;

    try {
      chatCompletion = await groq.chat.completions.create({
        messages: [{
          role: "user",
          content: [{
              type: "text",
              text: `Analyze this National ID image. Return a JSON object with the following exact fields:
  - "isBlurred" (boolean): true if the text on the ID is too blurry or out of focus to read.
  - "brightnessScore" (number 1-10): 1 is completely dark, 10 is too bright/glaring, 5-8 is good.
  - "isIdInFrame" (boolean): true if the ID card is fully visible and not significantly cut off.
  - "qualityScore" (number 1-10): overall quality of the photo for ID verification purposes.
  - "aiRecommendation" (string): MUST be exactly one of: "Suitable for review", "Retake recommended", "Poor quality". If isBlurred is true or isIdInFrame is false, it MUST NOT be "Suitable for review".
  - "reason" (string): explanation of why it is poor quality or needs retake. Empty string if suitable.
  Ensure the response is strictly valid JSON with no markdown formatting or extra text.`
            },
            {
              type: "image_url",
              image_url: {
                url: `data:${req.file.mimetype};base64,${imageAsBase64}`,
              },
            },
          ],
        }, ],

        model: "llama-3.2-90b-vision-preview",

        response_format: {
          type: "json_object"
        },

        temperature: 0.2,
      });

    } catch (apiError) {
      console.warn(
        "Groq Vision API failed (model might be missing or decommissioned), falling back to mock:",
        apiError.message
      );

      const fileUrl =
        `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

      return res.json({
        message: 'Image verified (Fallback Mock - Groq Vision Unavailable)',
        url: fileUrl,

        verificationData: {
          isBlurred: false,
          brightnessScore: 8,
          isIdInFrame: true,
          qualityScore: 9,
          aiRecommendation: 'Suitable for review',
          reason: 'Groq Vision models are currently unavailable, using mock validation.'
        }
      });
    }

    const content =
      chatCompletion.choices[0]?.message?.content || '{}';

    let aiResponse;

    try {
      aiResponse = JSON.parse(content);
    } catch (e) {
      console.error(
        'Failed to parse AI JSON response:',
        content
      );

      aiResponse = {
        isBlurred: false,
        brightnessScore: 5,
        isIdInFrame: true,
        qualityScore: 5,
        aiRecommendation: 'Suitable for review',
        reason: 'Fallback due to parsing error'
      };
    }

    if (
      aiResponse.aiRecommendation !== 'Suitable for review'
    ) {
      // Delete the bad image
      fs.unlinkSync(req.file.path);

      return res.status(400).json({
        message: aiResponse.reason ||
          'Image quality is too poor. Please retake the photo.',

        verificationData: aiResponse
      });
    }

    // If successful, return the URL
    const fileUrl =
      `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

    res.status(200).json({
      message: 'Image verified successfully',
      url: fileUrl,
      verificationData: aiResponse
    });

  } catch (error) {
    console.error(
      'Verify ID Error:',
      error
    );

    // If the error is with the AI or anything else, delete file to prevent junk
    if (
      req.file &&
      fs.existsSync(req.file.path)
    ) {
      fs.unlinkSync(req.file.path);
    }

    res.status(500).json({
      message: 'Error verifying image quality: ' +
        error.message
    });
  }
};


exports.improveDescription = async (req, res) => {
  try {
    const {
      title = '',
        category = '',
        materials = [],
        dimensions = '',
        colors = '',
        currentDescription = '',
        language = 'ar',
    } = req.body;

    const outputLanguage =
      language === 'ar' ? 'Arabic' : 'English';

    const prompt = `
You are an expert copywriter for handmade products.

Improve the following product description.

Product Title:
${title}

Category:
${category}

Materials:
${Array.isArray(materials) ? materials.join(', ') : materials}

Dimensions:
${dimensions}

Colors:
${colors}

Current Description:
${currentDescription}

Rules:
- Rewrite professionally.
- Make it attractive for customers.
- Keep it between 80 and 120 words.
- Return ONLY the improved description.
- Write only in ${outputLanguage}.
`;

    const chatCompletion = await groq.chat.completions.create({
      model: MODEL_NAME,
      temperature: 0.6,
      messages: [{
          role: "system",
          content: "You are a professional e-commerce copywriter."
        },
        {
          role: "user",
          content: prompt
        }
      ]
    });

    const improved =
      chatCompletion.choices[0]?.message?.content?.trim();

    res.json({
      description: improved,
    });

  } catch (error) {
    console.error(error);

    res.status(500).json({
      error: "Failed to improve description"
    });
  }
};
exports.generateStoryCaption = async (req, res) => {
  try {
    const {
      topic = '',
        productName = '',
        category = '',
        details = '',
        language = 'ar',
    } = req.body || {};

    const cleanTopic = String(topic).trim();
    const cleanProductName = String(productName).trim();
    const cleanCategory = String(category).trim();
    const cleanDetails = String(details).trim();

    const isArabic = language === 'ar';
    const outputLanguage = isArabic ? 'Arabic' : 'English';

    if (
      !cleanTopic &&
      !cleanProductName &&
      !cleanCategory &&
      !cleanDetails
    ) {
      return res.status(400).json({
        error: isArabic ?
          'يرجى إدخال فكرة أو تفاصيل للقصة' : 'Please provide a topic or story details',
      });
    }

    const subject =
      cleanProductName ||
      cleanTopic ||
      cleanCategory ||
      cleanDetails;

    // نص احتياطي إذا لم يكن مفتاح Groq موجودًا
    if (
      !process.env.GROQ_API_KEY ||
      process.env.GROQ_API_KEY === 'your_groq_api_key_here' ||
      process.env.GROQ_API_KEY === 'dummy_key'
    ) {
      const caption = isArabic ?
        `✨ يسعدني أن أشارككم أحدث أعمالي اليدوية: ${subject}. صُنعت بعناية واهتمام بكل تفصيل، ويسعدني معرفة رأيكم بها 🤍 #صناعة_يدوية #كرافت_جو` :
        `✨ I am happy to share my latest handmade creation: ${subject}. Made with care and attention to every detail. I would love to hear your thoughts 🤍 #Handmade #CraftGo`;

      return res.status(200).json({
        caption
      });
    }

    const prompt = `
You are a professional social-media copywriter for CraftGo,
a marketplace for handmade products.

Create one short and attractive story caption.

Topic: ${cleanTopic || 'Not provided'}
Product name: ${cleanProductName || 'Not provided'}
Category: ${cleanCategory || 'Not provided'}
Details: ${cleanDetails || 'Not provided'}

STRICT LANGUAGE RULES:

${
  isArabic
    ? `
- Write the entire caption in Arabic only.
- Do not use any English words.
- Use natural and clear Arabic suitable for social media.
- The only English word allowed is the brand name CraftGo.
`
    : `
- Write the entire caption in English only.
- Do not use any Arabic words.
- Use natural and clear English suitable for social media.
`
}

OTHER RULES:

- Write between 1 and 3 short sentences.
- Do not invent prices, discounts, materials, or availability.
- Add no more than 2 suitable emojis.
- Add no more than 2 hashtags.
- Do not use quotation marks.
- Do not add explanations or labels.
- Return only the final caption.
`;

    const chatCompletion = await groq.chat.completions.create({
      model: MODEL_NAME,
      temperature: 0.7,
      max_tokens: 180,
      messages: [{
          role: 'system',
          content: isArabic ?
            'اكتب النص كاملًا باللغة العربية فقط، ولا تستخدم كلمات إنجليزية باستثناء اسم CraftGo.' : 'Write the entire caption in English only. Never include Arabic words.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
    });

    const caption =
      chatCompletion.choices[0]?.message?.content?.trim() || '';

    if (!caption) {
      return res.status(502).json({
        error: isArabic ?
          'تعذر إنشاء نص للقصة' : 'Could not generate a story caption',
      });
    }

    return res.status(200).json({
      caption
    });
  } catch (error) {
    console.error('AI Story Caption Error:', error);

    return res.status(500).json({
      error: 'Failed to generate story caption',
    });
  }
};
// ─────────────────────────────────────────────────────────────
// AI Artisan Account Assessment using Groq
// POST /api/ai/artisan-account-assessment
// ─────────────────────────────────────────────────────────────

exports.assessArtisanAccount = async (req, res) => {
  try {
    const {
      name = '',
        email = '',
        phone = '',
        city = '',
        category = '',
        bio = '',
        experienceYears = 0,

        priceRange = '',
        specializations = [],

        portfolioImages = [],

        trustedHands = false,

        idFrontUrl = '',
        idBackUrl = '',

        language = 'en',
    } = req.body || {};

    const isArabic =
      language === 'ar';

    const outputLanguage =
      isArabic ? 'Arabic' : 'English';

    const wantsTrustedHands =
      trustedHands === true ||
      String(trustedHands).toLowerCase() === 'true';

    // ─────────────────────────────────────────────
    // Normalize data
    // ─────────────────────────────────────────────

    const portfolioList =
      Array.isArray(portfolioImages) ?
      portfolioImages
      .map((value) => String(value || '').trim())
      .filter(Boolean) : [];

    const specializationList =
      Array.isArray(specializations) ?
      specializations
      .map((value) => String(value || '').trim())
      .filter(Boolean) : [];

    const hasIdFront =
      String(idFrontUrl || '').trim().length > 0;

    const hasIdBack =
      String(idBackUrl || '').trim().length > 0;

    const bioLength =
      String(bio || '').trim().length;

    const years =
      Number(experienceYears) || 0;

    const profileComplete =
      Boolean(String(name).trim()) &&
      Boolean(String(city).trim()) &&
      Boolean(String(category).trim());

    // ─────────────────────────────────────────────
    // Deterministic score
    //
    // STANDARD:
    // Basic 15
    // Bio 20
    // Experience 10
    // Portfolio 55
    // Total 100
    //
    // TRUSTED HANDS:
    // Basic 15
    // Bio 15
    // Experience 10
    // Portfolio 35
    // ID 25
    // Total 100
    // ─────────────────────────────────────────────

    let baselineScore = 0;

    // Basic data — 15
    if (profileComplete) {
      baselineScore += 10;
    }

    if (String(email).includes('@')) {
      baselineScore += 3;
    }

    if (String(phone).trim().length >= 7) {
      baselineScore += 2;
    }

    // Bio
    if (wantsTrustedHands) {
      // Max 15
      if (bioLength >= 120) {
        baselineScore += 15;
      } else if (bioLength >= 50) {
        baselineScore += 11;
      } else if (bioLength >= 20) {
        baselineScore += 6;
      }
    } else {
      // Standard max 20
      if (bioLength >= 120) {
        baselineScore += 20;
      } else if (bioLength >= 50) {
        baselineScore += 15;
      } else if (bioLength >= 20) {
        baselineScore += 8;
      }
    }

    // Experience — 10
    if (years >= 5) {
      baselineScore += 10;
    } else if (years >= 2) {
      baselineScore += 7;
    } else if (years > 0) {
      baselineScore += 4;
    }

    // Portfolio
    if (wantsTrustedHands) {
      // Max 35
      if (portfolioList.length >= 4) {
        baselineScore += 35;
      } else if (portfolioList.length >= 2) {
        baselineScore += 28;
      } else if (portfolioList.length === 1) {
        baselineScore += 18;
      }
    } else {
      // Standard account — portfolio is the main trust evidence
      // Max 55
      if (portfolioList.length >= 4) {
        baselineScore += 55;
      } else if (portfolioList.length >= 2) {
        baselineScore += 45;
      } else if (portfolioList.length === 1) {
        baselineScore += 35;
      }
    }

    // National ID is scored ONLY for Trusted Hands
    if (wantsTrustedHands) {
      if (hasIdFront && hasIdBack) {
        baselineScore += 25;
      } else if (hasIdFront || hasIdBack) {
        baselineScore += 12;
      }
    }

    baselineScore =
      Math.max(
        0,
        Math.min(100, baselineScore),
      );

    // ─────────────────────────────────────────────
    // Strengths / warnings fallback
    // ─────────────────────────────────────────────

    const fallbackStrengths = [];
    const fallbackWarnings = [];

    if (profileComplete) {
      fallbackStrengths.push(
        isArabic ?
        'بيانات الحساب الأساسية مكتملة' :
        'Core account information is complete',
      );
    }

    if (bioLength >= 50) {
      fallbackStrengths.push(
        isArabic ?
        'النبذة المهنية مناسبة' :
        'Professional bio is adequate',
      );
    }

    if (years >= 2) {
      fallbackStrengths.push(
        isArabic ?
        'تم توضيح الخبرة المهنية' :
        'Relevant professional experience was provided',
      );
    }

    if (specializationList.length > 0) {
      fallbackStrengths.push(
        isArabic ?
        'تم تحديد المواد أو التخصصات التي يعمل بها الحرفي' :
        'Craft materials or specializations were provided',
      );
    }

    if (priceRange) {
      fallbackStrengths.push(
        isArabic ?
        'تم تحديد نطاق سعري للأعمال' :
        'A typical price range was provided',
      );
    }

    if (portfolioList.length >= 2) {
      fallbackStrengths.push(
        isArabic ?
        'تم رفع عدة نماذج أعمال' :
        'Multiple portfolio samples were uploaded',
      );
    } else if (portfolioList.length === 1) {
      fallbackStrengths.push(
        isArabic ?
        'تم رفع نموذج عمل واحد للمراجعة' :
        'One portfolio sample was uploaded for review',
      );
    }

    if (
      wantsTrustedHands &&
      hasIdFront &&
      hasIdBack
    ) {
      fallbackStrengths.push(
        isArabic ?
        'تم إرفاق الهوية المطلوبة لشارة الأيدي الموثوقة' :
        'The ID required for Trusted Hands was provided',
      );
    }

    // Portfolio IS required
    if (portfolioList.length === 0) {
      fallbackWarnings.push(
        isArabic ?
        'لم يتم رفع أي صور أعمال' :
        'No portfolio samples were uploaded',
      );
    } else if (portfolioList.length === 1) {
      fallbackWarnings.push(
        isArabic ?
        'يفضل إضافة أكثر من نموذج عمل لزيادة الثقة' :
        'More portfolio samples would provide stronger evidence',
      );
    }

    // ID warning ONLY when requesting Trusted Hands
    if (wantsTrustedHands) {
      if (!hasIdFront && !hasIdBack) {
        fallbackWarnings.push(
          isArabic ?
          'تم طلب شارة الأيدي الموثوقة ولكن لم يتم إرفاق الهوية' :
          'Trusted Hands was requested but no ID was uploaded',
        );
      } else if (!hasIdFront || !hasIdBack) {
        fallbackWarnings.push(
          isArabic ?
          'مستندات الهوية المطلوبة لشارة الأيدي الموثوقة غير مكتملة' :
          'The ID documents for Trusted Hands are incomplete',
        );
      }
    }

    if (bioLength < 50) {
      fallbackWarnings.push(
        isArabic ?
        'النبذة المهنية قصيرة' :
        'Professional bio is short',
      );
    }

    // ─────────────────────────────────────────────
    // Labels
    // ─────────────────────────────────────────────

    const fallbackLabel =
      baselineScore >= 85 ?
      (
        isArabic ?
        'ثقة ممتازة' :
        'Excellent trust'
      ) :
      baselineScore >= 70 ?
      (
        isArabic ?
        'ثقة جيدة' :
        'Good trust'
      ) :
      baselineScore >= 50 ?
      (
        isArabic ?
        'يحتاج مراجعة' :
        'Needs review'
      ) :
      (
        isArabic ?
        'ثقة منخفضة' :
        'Low trust'
      );

    const fallbackRecommendation =
      baselineScore >= 85 ?
      (
        isArabic ?
        'موصى بالموافقة بعد المراجعة البشرية' :
        'Recommended for approval after human review'
      ) :
      baselineScore >= 70 ?
      (
        isArabic ?
        'مناسب للموافقة بعد مراجعة سريعة' :
        'Suitable for approval after a quick review'
      ) :
      baselineScore >= 50 ?
      (
        isArabic ?
        'مراجعة يدوية مطلوبة قبل الموافقة' :
        'Manual review is recommended before approval'
      ) :
      (
        isArabic ?
        'يفضل استكمال البيانات قبل الموافقة' :
        'Additional account evidence is recommended before approval'
      );

    const verificationText =
      wantsTrustedHands ?
      (
        isArabic ?
        'الحساب يطلب شارة الأيدي الموثوقة، لذلك يتم احتساب الهوية ضمن التقييم.' :
        'The account requested Trusted Hands, so ID documents are included in the assessment.'
      ) :
      (
        isArabic ?
        'هذا حساب قياسي، لذلك الهوية الوطنية اختيارية ولا تؤثر سلباً على التقييم.' :
        'This is a Standard account, so National ID is optional and does not reduce the score.'
      );

    const fallbackResult = {
      success: true,

      source: 'rules-fallback',

      score: baselineScore,

      confidence: 75,

      label: fallbackLabel,

      recommendation: fallbackRecommendation,

      strengths: fallbackStrengths,

      warnings: fallbackWarnings,

      verificationType: wantsTrustedHands ?
        'trusted_hands' : 'standard',

      profileAnalysis: isArabic ?
        `تم تقييم اكتمال الملف والخبرة ونماذج الأعمال. ${verificationText}` : `The assessment considers profile completeness, experience, and portfolio evidence. ${verificationText}`,

      imageAssessment: {
        portfolioImageCount: portfolioList.length,

        idRequired: wantsTrustedHands,

        idFrontUploaded: hasIdFront,

        idBackUploaded: hasIdBack,

        note: wantsTrustedHands ?
          (
            isArabic ?
            'الهوية مطلوبة فقط لأن المستخدم اختار Trusted Hands. جودة صورة الهوية يتم فحصها عند الرفع.' :
            'ID is required because this user requested Trusted Hands. ID image quality is checked during upload.'
          ) : (
            isArabic ?
            'هذا حساب قياسي. عدم رفع الهوية لا يعتبر نقصاً. يتم التركيز على بيانات الحساب ونماذج الأعمال.' :
            'This is a Standard account. Missing ID is not considered a deficiency; profile and portfolio evidence are reviewed instead.'
          ),
      },
    };

    // ─────────────────────────────────────────────
    // No Groq key → deterministic fallback
    // ─────────────────────────────────────────────

    if (
      !process.env.GROQ_API_KEY ||
      process.env.GROQ_API_KEY ===
      'your_groq_api_key_here' ||
      process.env.GROQ_API_KEY ===
      'dummy_key'
    ) {
      return res.json(
        fallbackResult,
      );
    }

    // ─────────────────────────────────────────────
    // Groq assessment
    // ─────────────────────────────────────────────

    const prompt = `
You are CraftGo's senior trust and safety reviewer for a handmade marketplace.

Evaluate this pending artisan account using ONLY the supplied facts.

ACCOUNT TYPE:
${wantsTrustedHands ? 'TRUSTED HANDS' : 'STANDARD'}

IMPORTANT POLICY:
${
  wantsTrustedHands
    ? '- This applicant requested Trusted Hands. ID documentation is therefore expected and may affect the trust score.'
    : '- This applicant selected a Standard account. National ID is OPTIONAL. Missing ID MUST NOT reduce the score and MUST NOT appear as a warning.'
}

Applicant:
- Name: ${name || 'Not provided'}
- Email: ${email || 'Not provided'}
- Phone: ${phone || 'Not provided'}
- City: ${city || 'Not provided'}
- Craft category: ${category || 'Not provided'}
- Experience: ${years} years
- Bio: ${bio || 'Not provided'}
- Price range: ${priceRange || 'Not provided'}
- Materials / specializations: ${
      specializationList.length
        ? specializationList.join(', ')
        : 'Not provided'
    }
- Portfolio sample count: ${portfolioList.length}
- ID front uploaded: ${hasIdFront ? 'Yes' : 'No'}
- ID back uploaded: ${hasIdBack ? 'Yes' : 'No'}

CraftGo deterministic baseline score:
${baselineScore}/100

Return ONLY this JSON shape:

{
  "score": 0,
  "confidence": 0,
  "label": "short label in ${outputLanguage}",
  "recommendation": "short recommendation in ${outputLanguage}",
  "strengths": [
    "strength in ${outputLanguage}"
  ],
  "warnings": [
    "warning in ${outputLanguage}"
  ],
  "profileAnalysis": "2-4 sentences in ${outputLanguage}",
  "imageAssessment": {
    "note": "short explanation in ${outputLanguage}"
  }
}

STRICT RULES:

- score must be an integer from 0 to 100.
- confidence must be an integer from 0 to 100.
- Keep score within 12 points of the deterministic baseline.
- Portfolio is required for artisan approval.
- One portfolio image is acceptable but limited evidence.
- Two or more portfolio images are stronger evidence.
- For a STANDARD account, missing National ID must NOT reduce score.
- For a STANDARD account, never warn about missing ID.
- For TRUSTED HANDS, ID documentation is expected.
- Do not claim that you visually inspected image pixels.
- The human administrator makes the final decision.
- Write all user-facing text in ${outputLanguage}.
- Return JSON only.
- No Markdown.
`;

    const chatCompletion =
      await groq.chat.completions.create({
        model: MODEL_NAME,

        temperature: 0.2,

        response_format: {
          type: 'json_object',
        },

        messages: [{
            role: 'system',

            content: `You are a precise marketplace trust and safety analyst. ` +
              `Follow CraftGo verification policy exactly. ` +
              `Respond only with valid JSON. ` +
              `Write all user-facing content in ${outputLanguage}.`,
          },

          {
            role: 'user',
            content: prompt,
          },
        ],
      });

    const content =
      chatCompletion
      .choices?. [0]
      ?.message
      ?.content
      ?.trim() || '{}';

    let parsed;

    try {
      parsed =
        JSON.parse(content);
    } catch (error) {
      console.error(
        'Failed to parse Groq artisan assessment:',
        content,
      );

      return res.json(
        fallbackResult,
      );
    }

    let score =
      Math.round(
        Number(parsed.score) ||
        baselineScore,
      );

    // Do not allow AI to wander far away
    const minimumAllowed =
      Math.max(
        0,
        baselineScore - 12,
      );

    const maximumAllowed =
      Math.min(
        100,
        baselineScore + 12,
      );

    score =
      Math.max(
        minimumAllowed,
        Math.min(
          maximumAllowed,
          score,
        ),
      );

    const confidence =
      Math.max(
        0,
        Math.min(
          100,
          Math.round(
            Number(parsed.confidence) ||
            75,
          ),
        ),
      );

    let warnings =
      Array.isArray(parsed.warnings) ?
      parsed.warnings
      .slice(0, 5)
      .map(String) :
      fallbackWarnings;

    // Extra protection:
    // Standard accounts must never be warned about missing ID.
    if (!wantsTrustedHands) {
      warnings =
        warnings.filter((warning) => {
          const lower =
            String(warning)
            .toLowerCase();

          return !(
            lower.includes('id') ||
            lower.includes('identity') ||
            lower.includes('national') ||
            lower.includes('هوية')
          );
        });
    }

    return res.json({
      success: true,

      source: 'groq',

      score,

      confidence,

      label: String(
        parsed.label ||
        fallbackLabel,
      ),

      recommendation: String(
        parsed.recommendation ||
        fallbackRecommendation,
      ),

      strengths: Array.isArray(parsed.strengths) ?
        parsed.strengths
        .slice(0, 5)
        .map(String) : fallbackStrengths,

      warnings,

      verificationType: wantsTrustedHands ?
        'trusted_hands' : 'standard',

      profileAnalysis: String(
        parsed.profileAnalysis ||
        fallbackResult.profileAnalysis,
      ),

      imageAssessment: {
        portfolioImageCount: portfolioList.length,

        idRequired: wantsTrustedHands,

        idFrontUploaded: hasIdFront,

        idBackUploaded: hasIdBack,

        note: String(
          parsed.imageAssessment?.note ||
          fallbackResult.imageAssessment.note,
        ),
      },
    });
  } catch (error) {
    console.error(
      'Artisan AI assessment error:',
      error,
    );

    return res.status(500).json({
      error: 'Failed to assess artisan account',

      details: error.message,
    });
  }
};
// ─────────────────────────────────────────────────────────────
// AI Cart Recommendations
// POST /api/ai/cart-recommendations
// ─────────────────────────────────────────────────────────────
exports.cartRecommendations = async (req, res) => {
  try {
    const Product = require('../models/Product');
    const Order = require('../models/Order');
    const User = require('../models/User');
    const {
      Op,
      fn,
      col
    } = require('sequelize');

    const {
      cartProductIds = [],
        language = 'en',
    } = req.body || {};

    const cleanCartIds = Array.isArray(cartProductIds) ?
      cartProductIds
      .map(id => String(id).trim())
      .filter(Boolean) : [];

    const isArabic = language === 'ar';

    console.log(
      '[AI CART] cartProductIds:',
      cleanCartIds
    );

    // =========================================================
    // CASE 1: EMPTY CART → REAL BEST SELLERS
    // =========================================================
    if (cleanCartIds.length === 0) {
      const salesRows = await Order.findAll({
        attributes: [
          'productId',
          [
            fn('SUM', col('quantity')),
            'totalSold'
          ],
        ],
        where: {
          status: 'completed',
        },
        group: ['productId'],
        order: [
          [
            fn('SUM', col('quantity')),
            'DESC'
          ],
        ],
        limit: 4,
        raw: true,
      });

      if (!salesRows || salesRows.length === 0) {
        return res.json({
          success: true,
          mode: 'best_sellers',
          recommendations: [],
          message: isArabic ?
            'لا توجد مبيعات مكتملة كافية بعد.' : 'No completed sales yet.',
        });
      }

      const bestSellerIds = salesRows
        .map(row => row.productId)
        .filter(Boolean);

      const products = await Product.findAll({
        where: {
          id: {
            [Op.in]: bestSellerIds,
          },
          isPublic: true,
          isAvailable: true,
        },
        include: [{
          model: User,
          as: 'Craftsman',
          attributes: [
            'id',
            'name',
            'city',
          ],
        }, ],
      });

      // Keep the same ranking as SUM(quantity)
      const salesMap = {};

      for (const row of salesRows) {
        salesMap[String(row.productId)] =
          Number(row.totalSold) || 0;
      }

      products.sort(
        (a, b) =>
        (salesMap[String(b.id)] || 0) -
        (salesMap[String(a.id)] || 0)
      );

      const recommendations = products.map(product => ({
        id: product.id,
        titleAr: product.titleAr,
        titleEn: product.titleEn,
        price: Number(product.price),
        imageUrl: product.imageUrl,
        category: product.category,
        craftsmanName: product.Craftsman?.name || '',
        totalSold: salesMap[String(product.id)] || 0,
        reason: isArabic ?
          'من أكثر المنتجات مبيعًا على CraftGo' : 'One of the best-selling products on CraftGo',
      }));

      return res.json({
        success: true,
        mode: 'best_sellers',
        recommendations,
      });
    }

    // =========================================================
    // CASE 2: CART HAS PRODUCTS → AI RECOMMENDATIONS
    // =========================================================

    const cartProducts = await Product.findAll({
      where: {
        id: {
          [Op.in]: cleanCartIds,
        },
      },
    });

    if (!cartProducts.length) {
      return res.status(400).json({
        success: false,
        error: 'No valid cart products found',
      });
    }

    // Categories currently inside the cart
    const cartCategories = [
      ...new Set(
        cartProducts
        .map(p => p.category)
        .filter(Boolean)
      ),
    ];

    // First preference:
    // products related to cart categories
    let candidates = await Product.findAll({
      where: {
        id: {
          [Op.notIn]: cleanCartIds,
        },

        isPublic: true,
        isAvailable: true,

        ...(cartCategories.length > 0 ? {
          category: {
            [Op.in]: cartCategories,
          },
        } : {}),
      },

      include: [{
        model: User,
        as: 'Craftsman',
        attributes: [
          'id',
          'name',
          'city',
        ],
      }, ],

      limit: 12,
    });

    // If same-category products are too few,
    // broaden to other real marketplace products.
    if (candidates.length < 4) {
      candidates = await Product.findAll({
        where: {
          id: {
            [Op.notIn]: cleanCartIds,
          },
          isPublic: true,
          isAvailable: true,
        },

        include: [{
          model: User,
          as: 'Craftsman',
          attributes: [
            'id',
            'name',
            'city',
          ],
        }, ],

        limit: 15,
      });
    }

    if (!candidates.length) {
      return res.json({
        success: true,
        mode: 'ai',
        recommendations: [],
      });
    }

    const candidateData = candidates.map(p => ({
      id: String(p.id),
      titleAr: p.titleAr,
      titleEn: p.titleEn,
      category: p.category,
      materials: p.materials,
      colors: p.colors,
      price: Number(p.price),
      craftsmanName: p.Craftsman?.name || '',
    }));

    const cartData = cartProducts.map(p => ({
      id: String(p.id),
      titleAr: p.titleAr,
      titleEn: p.titleEn,
      category: p.category,
      materials: p.materials,
      colors: p.colors,
      price: Number(p.price),
    }));

    const hasGroqKey =
      process.env.GROQ_API_KEY &&
      process.env.GROQ_API_KEY !==
      'your_groq_api_key_here' &&
      process.env.GROQ_API_KEY !==
      'dummy_key';

    let selectedIds = [];
    let reasonsById = {};

    // =========================================================
    // REAL GROQ
    // =========================================================
    if (hasGroqKey) {
      try {
        const prompt = `
You are the recommendation engine for CraftGo,
a marketplace for real handmade products.

The customer's current cart is:

${JSON.stringify(cartData, null, 2)}

These are the ONLY real products currently
available for recommendation:

${JSON.stringify(candidateData, null, 2)}

Choose up to 4 products that best complement
the items already in the customer's cart.

Consider:
- category compatibility
- materials
- colors
- price range
- usefulness together
- product variety

CRITICAL RULES:
- You MUST choose only from the candidate list.
- NEVER invent a product.
- NEVER invent an ID.
- NEVER return a product already in the cart.
- Return IDs exactly as provided.
- Reason must be short.
- Write reasons in ${
          isArabic ? 'Arabic' : 'English'
        }.

Return ONLY valid JSON:

{
  "recommendations": [
    {
      "id": "real candidate id",
      "reason": "short recommendation reason"
    }
  ]
}
`;

        const chatCompletion =
          await groq.chat.completions.create({
            model: MODEL_NAME,

            messages: [{
                role: 'system',
                content: 'You are a precise marketplace recommendation engine. Never invent products or IDs.',
              },
              {
                role: 'user',
                content: prompt,
              },
            ],

            response_format: {
              type: 'json_object',
            },

            temperature: 0.25,
          });

        const raw =
          chatCompletion.choices[0]
          ?.message
          ?.content
          ?.trim() || '{}';

        console.log(
          '[AI CART] Groq response:',
          raw
        );

        const parsed = JSON.parse(raw);

        const aiRecommendations =
          Array.isArray(parsed.recommendations) ?
          parsed.recommendations : [];

        const validCandidateIds =
          new Set(
            candidateData.map(p => p.id)
          );

        for (const item of aiRecommendations) {
          const id =
            String(item.id || '').trim();

          // Security: accept IDs only if
          // they truly exist in our candidate list
          if (
            id &&
            validCandidateIds.has(id) &&
            !selectedIds.includes(id)
          ) {
            selectedIds.push(id);

            reasonsById[id] =
              String(
                item.reason || ''
              ).trim();
          }

          if (selectedIds.length >= 4) {
            break;
          }
        }
      } catch (groqError) {
        console.error(
          '[AI CART] Groq failed:',
          groqError.message
        );
      }
    }

    // =========================================================
    // SAFE FALLBACK
    // If Groq fails → real DB products only
    // =========================================================
    if (selectedIds.length === 0) {
      const averageCartPrice =
        cartProducts.reduce(
          (sum, p) =>
          sum + Number(p.price || 0),
          0
        ) / cartProducts.length;

      const sortedCandidates = [...candidates].sort(
        (a, b) => {
          const aSameCategory =
            cartCategories.includes(
              a.category
            ) ?
            1 :
            0;

          const bSameCategory =
            cartCategories.includes(
              b.category
            ) ?
            1 :
            0;

          if (
            aSameCategory !==
            bSameCategory
          ) {
            return (
              bSameCategory -
              aSameCategory
            );
          }

          const aDifference =
            Math.abs(
              Number(a.price) -
              averageCartPrice
            );

          const bDifference =
            Math.abs(
              Number(b.price) -
              averageCartPrice
            );

          return (
            aDifference -
            bDifference
          );
        }
      );

      selectedIds =
        sortedCandidates
        .slice(0, 4)
        .map(p => String(p.id));

      for (const id of selectedIds) {
        reasonsById[id] = isArabic ?
          'منتج حقيقي مناسب لمحتويات سلتك' :
          'A real product that complements your cart';
      }
    }

    // Preserve AI ranking order
    const candidateMap = new Map(
      candidates.map(p => [
        String(p.id),
        p,
      ])
    );

    const recommendations =
      selectedIds
      .map(id => {
        const product =
          candidateMap.get(id);

        if (!product) return null;

        return {
          id: String(product.id),

          titleAr: product.titleAr,

          titleEn: product.titleEn,

          price: Number(product.price),

          imageUrl: product.imageUrl,

          category: product.category,

          craftsmanName: product.Craftsman?.name ||
            '',

          reason: reasonsById[id] || '',
        };
      })
      .filter(Boolean);

    return res.json({
      success: true,
      mode: 'ai',
      recommendations,
    });

  } catch (error) {
    console.error(
      '[AI CART] ERROR:',
      error
    );

    return res.status(500).json({
      success: false,
      error: 'Failed to generate cart recommendations',
      details: error.message,
    });
  }
};
// ─────────────────────────────────────────────────────────────────────────────
// Artisan Dashboard AI Insights
// POST /api/ai/artisan-dashboard-insights
// Uses the logged-in artisan from req.user.id.
// All metrics are calculated from the real database.
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Artisan Dashboard AI Insights
// POST /api/ai/artisan-dashboard-insights
// Combines product orders with completed Hire / On-Site Escrow transactions.
// ─────────────────────────────────────────────────────────────────────────────
exports.artisanDashboardInsights = async (req, res) => {
  try {
    const artisanId = req.user?.id;
    const language = req.body?.language === 'ar' ? 'ar' : 'en';
    const isArabic = language === 'ar';

    if (!artisanId) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized',
      });
    }

    const Product = require('../models/Product');
    const Order = require('../models/Order');
    const PaymentTransaction = require('../models/PaymentTransaction');
    const UserInteraction = require('../models/UserInteraction');
    const {
      Op
    } = require('sequelize');

    // ─────────────────────────────────────────────────────────────────────
    // 1. Products
    // ─────────────────────────────────────────────────────────────────────
    const products = await Product.findAll({
      where: {
        craftsmanId: artisanId,
      },
      attributes: [
        'id',
        'titleAr',
        'titleEn',
        'category',
        'price',
        'isPublic',
        'isAvailable',
      ],
    });

    const productIds = products.map((product) => product.id);

    // ─────────────────────────────────────────────────────────────────────
    // 2. Normal product orders
    // ─────────────────────────────────────────────────────────────────────
    const orders = await Order.findAll({
      where: {
        craftsmanId: artisanId,
      },
      attributes: [
        'id',
        'productId',
        'status',
        'totalAmount',
        'quantity',
        'createdAt',
      ],
    });

    const completedProductOrders = orders.filter(
      (order) => order.status === 'completed'
    );

    const pendingOrders = orders.filter(
      (order) => order.status === 'pending'
    );

    const acceptedOrders = orders.filter(
      (order) => order.status === 'accepted'
    );

    const inProgressOrders = orders.filter(
      (order) => order.status === 'in_progress'
    );

    const cancelledOrders = orders.filter(
      (order) => order.status === 'cancelled'
    );

    const productEarnings = completedProductOrders.reduce(
      (sum, order) => sum + Number(order.totalAmount || 0),
      0
    );

    const totalSoldUnits = completedProductOrders.reduce(
      (sum, order) => sum + Number(order.quantity || 1),
      0
    );

    // ─────────────────────────────────────────────────────────────────────
    // 3. Completed Hire / On-Site transactions
    //
    // Only released Escrow transactions are counted as available earnings.
    // ─────────────────────────────────────────────────────────────────────
    const releasedHireTransactions =
      await PaymentTransaction.findAll({
        where: {
          artisanId,
          paymentStatus: 'succeeded',
          escrowStatus: 'released',
        },
        attributes: [
          'id',
          'hireRequestId',
          'grossAmount',
          'artisanAmount',
          'releasedAt',
        ],
      });

    const heldHireTransactions =
      await PaymentTransaction.findAll({
        where: {
          artisanId,
          paymentStatus: 'succeeded',
          escrowStatus: 'held',
        },
        attributes: [
          'id',
          'hireRequestId',
          'grossAmount',
          'artisanAmount',
        ],
      });

    const completedHireOrders =
      releasedHireTransactions.length;

    const activeHireOrders =
      heldHireTransactions.length;

    const hireEarnings = releasedHireTransactions.reduce(
      (sum, transaction) =>
      sum + Number(transaction.artisanAmount || 0),
      0
    );

    const heldHireEarnings = heldHireTransactions.reduce(
      (sum, transaction) =>
      sum + Number(transaction.artisanAmount || 0),
      0
    );

    const unifiedCompletedOrders =
      completedProductOrders.length + completedHireOrders;

    const unifiedEarnings =
      productEarnings + hireEarnings;

    // ─────────────────────────────────────────────────────────────────────
    // 4. Product interactions
    // ─────────────────────────────────────────────────────────────────────
    let interactions = [];

    if (productIds.length > 0) {
      interactions = await UserInteraction.findAll({
        where: {
          productId: {
            [Op.in]: productIds,
          },
        },
        attributes: [
          'productId',
          'interactionType',
          'score',
          'quantity',
        ],
      });
    }

    const views = interactions.filter(
      (interaction) =>
      interaction.interactionType === 'view'
    );

    const likes = interactions.filter(
      (interaction) =>
      interaction.interactionType === 'like'
    );

    const carts = interactions.filter(
      (interaction) =>
      interaction.interactionType === 'cart'
    );

    const follows = interactions.filter(
      (interaction) =>
      interaction.interactionType === 'follow'
    );

    const purchases = interactions.filter(
      (interaction) =>
      interaction.interactionType === 'purchase'
    );

    const totalViews = views.reduce(
      (sum, interaction) =>
      sum + Number(interaction.score || 1),
      0
    );

    const totalLikes = likes.length;

    const totalCartAdds = carts.reduce(
      (sum, interaction) =>
      sum + Number(interaction.quantity || 1),
      0
    );

    const totalFollows = follows.length;
    const totalPurchaseInteractions = purchases.length;

    // Product conversion rate only
    const conversionRate =
      totalViews > 0 ?
      Number(
        (
          (completedProductOrders.length / totalViews) *
          100
        ).toFixed(1)
      ) :
      0;

    // ─────────────────────────────────────────────────────────────────────
    // 5. Product performance
    // ─────────────────────────────────────────────────────────────────────
    const productPerformance = products.map((product) => {
      const productInteractions = interactions.filter(
        (interaction) =>
        String(interaction.productId) === String(product.id)
      );

      const productOrders = completedProductOrders.filter(
        (order) =>
        String(order.productId) === String(product.id)
      );

      const productViews = productInteractions
        .filter(
          (interaction) =>
          interaction.interactionType === 'view'
        )
        .reduce(
          (sum, interaction) =>
          sum + Number(interaction.score || 1),
          0
        );

      const productLikes = productInteractions.filter(
        (interaction) =>
        interaction.interactionType === 'like'
      ).length;

      const productCartAdds = productInteractions
        .filter(
          (interaction) =>
          interaction.interactionType === 'cart'
        )
        .reduce(
          (sum, interaction) =>
          sum + Number(interaction.quantity || 1),
          0
        );

      const soldUnits = productOrders.reduce(
        (sum, order) =>
        sum + Number(order.quantity || 1),
        0
      );

      const revenue = productOrders.reduce(
        (sum, order) =>
        sum + Number(order.totalAmount || 0),
        0
      );

      return {
        id: product.id,

        title: language === 'ar' ?
          product.titleAr ||
          product.titleEn ||
          'بدون اسم' : product.titleEn ||
          product.titleAr ||
          'Untitled',

        category: product.category || '',
        price: Number(product.price || 0),
        views: productViews,
        likes: productLikes,
        cartAdds: productCartAdds,
        completedOrders: productOrders.length,
        soldUnits,
        revenue,
        isPublic: product.isPublic !== false,
        isAvailable: product.isAvailable !== false,
      };
    });

    // ─────────────────────────────────────────────────────────────────────
    // 6. Best product
    // ─────────────────────────────────────────────────────────────────────
    const sortedPerformance = [...productPerformance].sort(
      (a, b) => {
        if (b.soldUnits !== a.soldUnits) {
          return b.soldUnits - a.soldUnits;
        }

        if (b.revenue !== a.revenue) {
          return b.revenue - a.revenue;
        }

        if (b.views !== a.views) {
          return b.views - a.views;
        }

        if (b.cartAdds !== a.cartAdds) {
          return b.cartAdds - a.cartAdds;
        }

        return b.likes - a.likes;
      }
    );

    const bestProduct =
      sortedPerformance.length > 0 ?
      sortedPerformance[0] :
      null;

    // ─────────────────────────────────────────────────────────────────────
    // 7. Amount of available data
    // ─────────────────────────────────────────────────────────────────────
    let dataLevel = 'limited';

    if (
      totalViews >= 10 ||
      unifiedCompletedOrders >= 3 ||
      interactions.length >= 15
    ) {
      dataLevel = 'growing';
    }

    if (
      totalViews >= 50 ||
      unifiedCompletedOrders >= 10 ||
      interactions.length >= 60
    ) {
      dataLevel = 'strong';
    }

    // ─────────────────────────────────────────────────────────────────────
    // 8. Unified real metrics
    // ─────────────────────────────────────────────────────────────────────
    const metrics = {
      products: products.length,

      publicProducts: products.filter(
        (product) => product.isPublic !== false
      ).length,

      availableProducts: products.filter(
        (product) => product.isAvailable !== false
      ).length,

      views: totalViews,
      likes: totalLikes,
      cartAdds: totalCartAdds,
      follows: totalFollows,
      purchaseInteractions: totalPurchaseInteractions,

      totalOrders: orders.length +
        completedHireOrders +
        activeHireOrders,

      pendingOrders: pendingOrders.length,
      acceptedOrders: acceptedOrders.length,

      inProgressOrders: inProgressOrders.length + activeHireOrders,

      completedOrders: unifiedCompletedOrders,
      cancelledOrders: cancelledOrders.length,

      productCompletedOrders: completedProductOrders.length,

      hireCompletedOrders: completedHireOrders,

      activeHireOrders: activeHireOrders,

      soldUnits: totalSoldUnits,

      earnings: Number(unifiedEarnings.toFixed(2)),

      productEarnings: Number(productEarnings.toFixed(2)),

      hireEarnings: Number(hireEarnings.toFixed(2)),

      heldHireEarnings: Number(heldHireEarnings.toFixed(2)),

      conversionRate,
    };

    // ─────────────────────────────────────────────────────────────────────
    // 9. Fallback based on real database data
    // ─────────────────────────────────────────────────────────────────────
    const buildFallback = () => {
      const highlights = [];
      const recommendations = [];

      if (unifiedCompletedOrders > 0) {
        highlights.push(
          isArabic ?
          `لديك ${unifiedCompletedOrders} طلب مكتمل بإجمالي أرباح ${unifiedEarnings.toFixed(2)} دينار.` :
          `You have ${unifiedCompletedOrders} completed order(s), generating ${unifiedEarnings.toFixed(2)} JOD.`
        );
      }

      if (completedHireOrders > 0) {
        highlights.push(
          isArabic ?
          `أكملت ${completedHireOrders} طلب Hire / On-Site، وبلغت حصتك المحررة ${hireEarnings.toFixed(2)} دينار.` :
          `You completed ${completedHireOrders} Hire / On-Site order(s), releasing ${hireEarnings.toFixed(2)} JOD to you.`
        );
      }

      if (activeHireOrders > 0) {
        highlights.push(
          isArabic ?
          `لديك ${activeHireOrders} طلب Hire قيد التنفيذ، وحصتك المحمية في Escrow هي ${heldHireEarnings.toFixed(2)} دينار.` :
          `You have ${activeHireOrders} Hire order(s) in progress, with ${heldHireEarnings.toFixed(2)} JOD protected in Escrow.`
        );
      }

      if (totalViews > 0) {
        highlights.push(
          isArabic ?
          `حصلت منتجاتك على ${totalViews} مشاهدة حقيقية حتى الآن.` :
          `Your products have received ${totalViews} real view(s) so far.`
        );
      }

      if (bestProduct && bestProduct.soldUnits > 0) {
        highlights.push(
          isArabic ?
          `${bestProduct.title} هو المنتج الأفضل أداءً حاليًا.` :
          `${bestProduct.title} is currently your best-performing product.`
        );
      }

      if (products.length === 0) {
        recommendations.push(
          isArabic ?
          'أضف أول منتج حتى يبدأ النظام بقياس أداء المنتجات.' :
          'Add your first product so CraftGo can begin measuring product performance.'
        );
      } else if (products.length < 3) {
        recommendations.push(
          isArabic ?
          'إضافة منتجات أخرى قد تساعدك على زيادة الظهور والوصول إلى عملاء جدد.' :
          'Adding more products may increase your visibility and help you reach new customers.'
        );
      }

      if (totalViews < 10) {
        recommendations.push(
          isArabic ?
          'بيانات المشاهدات ما زالت محدودة؛ حسّن صور المنتجات وعناوينها لجذب زيارات أكثر.' :
          'View data is still limited; improve your product photos and titles to attract more visits.'
        );
      }

      if (totalCartAdds === 0 && totalViews > 0) {
        recommendations.push(
          isArabic ?
          'هناك مشاهدات دون إضافات للسلة؛ راجع الأسعار والأوصاف والصور.' :
          'You have views but no cart additions; review your prices, descriptions, and photos.'
        );
      }

      if (
        unifiedCompletedOrders > 0 &&
        totalViews > 0
      ) {
        recommendations.push(
          isArabic ?
          'استمر في متابعة الخدمات والمنتجات الأفضل أداءً وأضف عروضًا مشابهة.' :
          'Continue monitoring your best-performing services and products, and consider adding similar offers.'
        );
      }

      if (highlights.length === 0) {
        highlights.push(
          isArabic ?
          'بدأ النظام بجمع بيانات الأداء الخاصة بحسابك.' :
          'CraftGo has started collecting performance data for your account.'
        );
      }

      if (recommendations.length === 0) {
        recommendations.push(
          isArabic ?
          'استمر في إضافة منتجات عالية الجودة وتفعيل خدمات Hire / On-Site.' :
          'Keep adding high-quality products and offering Hire / On-Site services.'
        );
      }

      return {
        success: true,
        source: 'data_fallback',
        dataLevel,
        metrics,
        bestProduct,

        summary: isArabic ?
          `لديك ${products.length} منتج، و${totalViews} مشاهدة، و${unifiedCompletedOrders} طلب مكتمل بإجمالي أرباح ${unifiedEarnings.toFixed(2)} دينار. تتضمن النتائج ${completedHireOrders} طلب Hire / On-Site مكتمل.` : `You have ${products.length} product(s), ${totalViews} view(s), and ${unifiedCompletedOrders} completed order(s), generating ${unifiedEarnings.toFixed(2)} JOD. This includes ${completedHireOrders} completed Hire / On-Site order(s).`,

        performanceLabel: unifiedCompletedOrders > 0 ?
          isArabic ?
          'بداية واعدة' :
          'Promising Start' : isArabic ?
          'مرحلة جمع البيانات' : 'Building Data',

        highlights: highlights.slice(0, 3),

        recommendations: recommendations.slice(0, 3),
      };
    };

    // ─────────────────────────────────────────────────────────────────────
    // 10. Check Groq API key
    // ─────────────────────────────────────────────────────────────────────
    const hasGroqKey =
      process.env.GROQ_API_KEY &&
      process.env.GROQ_API_KEY !==
      'your_groq_api_key_here' &&
      process.env.GROQ_API_KEY !== 'dummy_key';

    if (!hasGroqKey) {
      console.warn(
        '[AI Dashboard Insights] No valid GROQ_API_KEY. Using real-data fallback.'
      );

      return res.status(200).json(
        buildFallback()
      );
    }

    // ─────────────────────────────────────────────────────────────────────
    // 11. Send unified real data to Groq
    // ─────────────────────────────────────────────────────────────────────
    const outputLanguage =
      isArabic ? 'Arabic' : 'English';

    const aiInput = {
      metrics,
      dataLevel,
      bestProduct,
      productPerformance,
    };

    const prompt = `
You are CraftGo's artisan business analytics assistant.

Analyze ONLY the REAL database data supplied below.

The metrics combine:
1. Normal product sales from the Orders table.
2. Completed Hire / On-Site jobs from released Escrow transactions.
3. Active Hire / On-Site jobs from held Escrow transactions.

Important financial definitions:
- earnings: total available artisan earnings.
- productEarnings: earnings from completed product sales.
- hireEarnings: artisan share from released Hire / On-Site Escrow.
- heldHireEarnings: artisan share still protected in Escrow.
- Platform commission is not included in artisan earnings.

Never invent:
- additional sales
- additional Hire jobs
- additional earnings
- additional views
- customers
- ratings
- unsupported market trends

If data is limited, clearly state that the sample is limited.

Real artisan analytics data:

${JSON.stringify(aiInput, null, 2)}

Write all user-facing text in ${outputLanguage} only.

Return ONLY one valid JSON object:

{
  "summary": "short useful performance summary",
  "performanceLabel": "short performance label",
  "highlights": [
    "fact-based highlight",
    "fact-based highlight"
  ],
  "recommendations": [
    "specific actionable recommendation",
    "specific actionable recommendation",
    "specific actionable recommendation"
  ]
}

Rules:
- The summary must contain no more than 3 short sentences.
- The performance label must be concise.
- Highlights must contain between 1 and 3 items.
- Recommendations must contain between 2 and 3 practical actions.
- Mention Hire / On-Site performance when hireCompletedOrders is greater than 0.
- Do not count held Escrow as available earnings.
- Mention the best product only if the supplied data supports it.
- If views are low, clearly state that the sample is limited.
- If completedOrders is 0, do not mention successful sales.
- If earnings is 0, do not imply that revenue was generated.
- Do not use Markdown.
- Do not return any text outside the JSON object.
`;

    try {
      const chatCompletion =
        await groq.chat.completions.create({
          model: MODEL_NAME,

          temperature: 0.3,

          response_format: {
            type: 'json_object',
          },

          messages: [{
              role: 'system',
              content: `You are a precise marketplace analytics assistant. ` +
                `Use only supplied data and write all user-facing text in ${outputLanguage}.`,
            },
            {
              role: 'user',
              content: prompt,
            },
          ],
        });

      const raw =
        chatCompletion.choices[0]
        ?.message
        ?.content
        ?.trim() || '{}';

      const parsed = JSON.parse(raw);

      const highlights =
        Array.isArray(parsed.highlights) ?
        parsed.highlights
        .map(String)
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 3) : [];

      const recommendations =
        Array.isArray(parsed.recommendations) ?
        parsed.recommendations
        .map(String)
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 3) : [];

      if (
        !parsed.summary ||
        !parsed.performanceLabel
      ) {
        throw new Error(
          'Invalid Groq dashboard insight response'
        );
      }

      return res.status(200).json({
        success: true,
        source: 'groq',
        dataLevel,
        metrics,
        bestProduct,
        summary: String(parsed.summary).trim(),
        performanceLabel: String(parsed.performanceLabel).trim(),
        highlights: highlights.length > 0 ?
          highlights : buildFallback().highlights,
        recommendations: recommendations.length > 0 ?
          recommendations : buildFallback().recommendations,
      });
    } catch (groqError) {
      console.error(
        '[AI Dashboard Insights] Groq failed:',
        groqError.message
      );

      return res.status(200).json(
        buildFallback()
      );
    }
  } catch (error) {
    console.error(
      '[AI Dashboard Insights] ERROR:',
      error
    );

    return res.status(500).json({
      success: false,
      error: 'Failed to generate artisan dashboard insights',
      details: error.message,
    });
  }
};
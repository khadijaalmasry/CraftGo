const Product = require('../models/Product');
const User = require('../models/User');
const Review = require('../models/Review');
const UserInteraction = require('../models/UserInteraction');
const { Sequelize } = require('sequelize');

const Op = Sequelize.Op;

const editableFields = [
  'titleAr',
  'titleEn',
  'description',
  'materials',
  'dimensions',
  'colors',
  'price',
  'category',
  'imageUrl',

  // NEW
  'images',
  'aiAnalysis',

  'isPublic',
  'isAvailable',
];

// ============================================================
// POST /api/products
// ============================================================

exports.createProduct = async (req, res) => {
  try {
    const {
      craftsmanId,
      titleAr,
      titleEn,
      description,
      materials,
      dimensions,
      colors,
      price,
      category,
      imageUrl,

      // NEW
      images = [],
      aiAnalysis = null,

      isPublic = true,
    } = req.body;

    if (!craftsmanId || !titleAr || !titleEn || price === undefined) {
      return res.status(400).json({
        error: 'craftsmanId, titleAr, titleEn and price are required',
      });
    }

    if (req.user.id !== craftsmanId && req.user.role !== 'admin') {
      return res.status(403).json({
        error:
          'Forbidden: you can only add products to your own account',
      });
    }

    const numericPrice = Number(price);

    if (!Number.isFinite(numericPrice) || numericPrice <= 0) {
      return res.status(400).json({
        error: 'Price must be greater than zero',
      });
    }

    const product = await Product.create({
      craftsmanId,

      titleAr: titleAr.trim(),
      titleEn: titleEn.trim(),

      description: description?.trim() || '',
      materials: materials?.trim() || '',
      dimensions: dimensions?.trim() || '',
      colors: colors?.trim() || '',

      price: numericPrice,

      category: category?.trim() || '',

      imageUrl: imageUrl || null,

      // Save gallery images.
      // Maximum = 5 product images.
      images: Array.isArray(images)
        ? images.slice(0, 5)
        : [],

      // Save latest AI analysis.
      aiAnalysis:
        aiAnalysis &&
        typeof aiAnalysis === 'object'
          ? aiAnalysis
          : null,

      isPublic: Boolean(isPublic),
      isAvailable: true,
    });

    return res.status(201).json({
      message: 'Product created successfully',
      product,
    });
  } catch (error) {
    console.error('Error creating product:', error);

    return res.status(500).json({
      error: 'Failed to create product',
      details: error.message,
    });
  }
};

// ============================================================
// Helper
// Enrich products with:
// averageRating
// likesCount
// ordersCount
// isFavorite
// isInCart
// ============================================================

async function enrichProducts(products, userId) {
  if (!products || products.length === 0) {
    return [];
  }

  const productIds = products.map((p) => p.id);

  const [
    likeInteractions,
    cartInteractions,
    purchaseInteractions,
    reviews,
  ] = await Promise.all([
    UserInteraction.findAll({
      where: {
        productId: {
          [Op.in]: productIds,
        },
        interactionType: 'like',
      },

      attributes: [
        'productId',
        'userId',
      ],
    }),

    UserInteraction.findAll({
      where: {
        productId: {
          [Op.in]: productIds,
        },
        interactionType: 'cart',
      },

      attributes: [
        'productId',
        'userId',
      ],
    }),

    UserInteraction.findAll({
      where: {
        productId: {
          [Op.in]: productIds,
        },
        interactionType: 'purchase',
      },

      attributes: [
        'productId',
      ],
    }),

    Review.findAll({
      where: {
        artisanId: {
          [Op.in]: products
            .map((p) => p.craftsmanId)
            .filter(Boolean),
        },
      },

      attributes: [
        'artisanId',
        'rating',
      ],
    }),
  ]);

  // ------------------------------------------------------------
  // Likes
  // ------------------------------------------------------------

  const likeMap = {};
  const likerSet = {};

  likeInteractions.forEach((interaction) => {
    likeMap[interaction.productId] =
      (likeMap[interaction.productId] || 0) + 1;

    if (!likerSet[interaction.productId]) {
      likerSet[interaction.productId] = new Set();
    }

    likerSet[interaction.productId].add(
      interaction.userId
    );
  });

  // ------------------------------------------------------------
  // Cart
  // ------------------------------------------------------------

  const cartSet = {};

  cartInteractions.forEach((interaction) => {
    if (!cartSet[interaction.productId]) {
      cartSet[interaction.productId] = new Set();
    }

    cartSet[interaction.productId].add(
      interaction.userId
    );
  });

  // ------------------------------------------------------------
  // Purchases
  // ------------------------------------------------------------

  const ordersMap = {};

  purchaseInteractions.forEach((interaction) => {
    ordersMap[interaction.productId] =
      (ordersMap[interaction.productId] || 0) + 1;
  });

  // ------------------------------------------------------------
  // Rating per artisan
  // ------------------------------------------------------------

  const ratingMap = {};

  reviews.forEach((review) => {
    if (!ratingMap[review.artisanId]) {
      ratingMap[review.artisanId] = {
        sum: 0,
        count: 0,
      };
    }

    ratingMap[review.artisanId].sum += Number(
      review.rating || 0
    );

    ratingMap[review.artisanId].count += 1;
  });

  // ------------------------------------------------------------
  // Final enriched products
  // ------------------------------------------------------------

  return products.map((product) => {
    const plain = product.toJSON
      ? product.toJSON()
      : { ...product };

    const artisanRating =
      ratingMap[plain.craftsmanId];

    const avgRating =
      artisanRating &&
      artisanRating.count > 0
        ? Number(
            (
              artisanRating.sum /
              artisanRating.count
            ).toFixed(1)
          )
        : null;

    return {
      ...plain,

      averageRating: avgRating,

      likesCount:
        likeMap[plain.id] || 0,

      ordersCount:
        ordersMap[plain.id] || 0,

      isFavorite: userId
        ? likerSet[plain.id]?.has(userId) ||
          false
        : false,

      isInCart: userId
        ? cartSet[plain.id]?.has(userId) ||
          false
        : false,
    };
  });
}

// ============================================================
// GET /api/products
// ============================================================

exports.getAllProducts = async (req, res) => {
  try {
    const {
      category,
      sort,
      search,
      materials,
      crafts,
      minPrice,
      maxPrice,
      minRating,
      deliveryTime,
      ecoFriendly,
    } = req.query;

    const userId =
      req.user?.id || null;

    // ------------------------------------------------------------
    // WHERE
    // ------------------------------------------------------------

    const whereClause = {
      isPublic: true,
      isAvailable: true,
    };

    if (category) {
      whereClause.category = category;
    }

    if (materials) {
      const materialList = materials
        .split(',')
        .map((m) => m.trim())
        .filter(Boolean);

      if (materialList.length > 0) {
        whereClause.materials = {
          [Op.or]: materialList.map(
            (material) => ({
              [Op.like]: `%${material}%`,
            })
          ),
        };
      }
    }

    if (minPrice || maxPrice) {
      whereClause.price = {};

      if (minPrice) {
        whereClause.price[Op.gte] =
          Number(minPrice);
      }

      if (maxPrice) {
        whereClause.price[Op.lte] =
          Number(maxPrice);
      }
    }

    if (search) {
      const term = `%${search}%`;

      whereClause[Op.or] = [
        {
          titleAr: {
            [Op.like]: term,
          },
        },

        {
          titleEn: {
            [Op.like]: term,
          },
        },

        {
          description: {
            [Op.like]: term,
          },
        },

        {
          category: {
            [Op.like]: term,
          },
        },

        {
          materials: {
            [Op.like]: term,
          },
        },
      ];
    }

    // ------------------------------------------------------------
    // ORDER
    // ------------------------------------------------------------

    let orderClause = [
      ['createdAt', 'DESC'],
    ];

    if (sort === 'oldest') {
      orderClause = [
        ['createdAt', 'ASC'],
      ];
    } else if (sort === 'price_low') {
      orderClause = [
        ['price', 'ASC'],
      ];
    } else if (sort === 'price_high') {
      orderClause = [
        ['price', 'DESC'],
      ];
    }

    // ------------------------------------------------------------
    // Eco-friendly
    // ------------------------------------------------------------

    if (ecoFriendly === 'true') {
      const ecoTerm = '%eco%';

      const ecoClause = [
        {
          description: {
            [Op.like]: ecoTerm,
          },
        },

        {
          materials: {
            [Op.like]: ecoTerm,
          },
        },

        {
          titleAr: {
            [Op.like]: '%صديق للبيئة%',
          },
        },

        {
          titleEn: {
            [Op.like]: ecoTerm,
          },
        },
      ];

      if (whereClause[Op.or]) {
        whereClause[Op.and] = [
          {
            [Op.or]:
              whereClause[Op.or],
          },

          {
            [Op.or]:
              ecoClause,
          },
        ];

        delete whereClause[Op.or];
      } else {
        whereClause[Op.or] =
          ecoClause;
      }
    }

    // ------------------------------------------------------------
    // Delivery time
    // ------------------------------------------------------------

    if (deliveryTime) {
      const dtWhere = {
        description: {
          [Op.like]:
            `%${deliveryTime}%`,
        },
      };

      if (whereClause[Op.and]) {
        whereClause[Op.and].push(
          dtWhere
        );
      } else if (whereClause[Op.or]) {
        whereClause[Op.and] = [
          {
            [Op.or]:
              whereClause[Op.or],
          },

          dtWhere,
        ];

        delete whereClause[Op.or];
      } else {
        Object.assign(
          whereClause,
          dtWhere
        );
      }
    }

    // ------------------------------------------------------------
    // Query
    // ------------------------------------------------------------

    const products =
      await Product.findAll({
        where: whereClause,

        include: [
          {
            model: User,
            as: 'Craftsman',

            attributes: [
              'id',
              'name',
              'city',
              'profileImage',
            ],
          },
        ],

        order: orderClause,
      });

    let enriched =
      await enrichProducts(
        products,
        userId
      );

    // ------------------------------------------------------------
    // Minimum rating
    // ------------------------------------------------------------

    if (
      minRating &&
      Number(minRating) > 0
    ) {
      const threshold =
        Number(minRating);

      enriched =
        enriched.filter(
          (product) =>
            product.averageRating !==
              null &&
            product.averageRating >=
              threshold
        );
    }

    // ------------------------------------------------------------
    // Crafts
    // ------------------------------------------------------------

    if (crafts) {
      const craftList = crafts
        .split(',')
        .map((craft) =>
          craft
            .trim()
            .toLowerCase()
        )
        .filter(Boolean);

      if (craftList.length > 0) {
        enriched =
          enriched.filter(
            (product) => {
              const cat = (
                product.category || ''
              ).toLowerCase();

              return craftList.some(
                (craft) =>
                  cat.includes(craft)
              );
            }
          );
      }
    }

    // ------------------------------------------------------------
    // Special sorting
    // ------------------------------------------------------------

    if (sort === 'most_liked') {
      enriched.sort(
        (a, b) =>
          b.likesCount -
          a.likesCount
      );
    } else if (
      sort === 'recommended' ||
      sort === 'rating'
    ) {
      enriched.sort((a, b) => {
        if (
          a.averageRating === null &&
          b.averageRating === null
        ) {
          return 0;
        }

        if (
          a.averageRating === null
        ) {
          return 1;
        }

        if (
          b.averageRating === null
        ) {
          return -1;
        }

        return (
          b.averageRating -
          a.averageRating
        );
      });
    }

    return res.json(enriched);
  } catch (error) {
    console.error(
      'getAllProducts error:',
      error
    );

    return res.status(500).json({
      error:
        'Failed to fetch products',
    });
  }
};

// ============================================================
// GET /api/products/:id
// ============================================================

exports.getProductById = async (
  req,
  res
) => {
  try {
    const userId =
      req.user?.id || null;

    const product =
      await Product.findByPk(
        req.params.id,
        {
          include: [
            {
              model: User,
              as: 'Craftsman',

              attributes: [
                'id',
                'name',
                'city',
                'profileImage',
              ],
            },
          ],
        }
      );

    if (!product) {
      return res.status(404).json({
        error:
          'Product not found',
      });
    }

    const [enriched] =
      await enrichProducts(
        [product],
        userId
      );

    return res.json(enriched);
  } catch (error) {
    console.error(
      'getProductById error:',
      error
    );

    return res.status(500).json({
      error:
        'Failed to fetch product',
    });
  }
};

// ============================================================
// GET /api/products/craftsman/:craftsmanId
// ============================================================

exports.getProductsByCraftsman =
  async (req, res) => {
    try {
      const userId =
        req.user?.id || null;

      const products = await Product.findAll({
  where: {
    craftsmanId: req.params.craftsmanId,
    isAvailable: true,
  },

          include: [
            {
              model: User,
              as: 'Craftsman',

              attributes: [
                'id',
                'name',
                'city',
                'profileImage',
              ],
            },
          ],
        });

      const enriched =
        await enrichProducts(
          products,
          userId
        );

      return res.json(enriched);
    } catch (error) {
      console.error(
        'getProductsByCraftsman error:',
        error
      );

      return res.status(500).json({
        error:
          'Failed to fetch craftsman products',
      });
    }
  };

// ============================================================
// PUT /api/products/:id
// ============================================================

exports.updateProduct = async (
  req,
  res
) => {
  try {
    const product =
      await Product.findByPk(
        req.params.id
      );

    if (!product) {
      return res.status(404).json({
        error:
          'Product not found',
      });
    }

    if (
      product.craftsmanId !==
        req.user.id &&
      req.user.role !== 'admin'
    ) {
      return res.status(403).json({
        error:
          'Forbidden: not your product',
      });
    }

    // ----------------------------------------------------------
    // Update allowed fields
    // ----------------------------------------------------------

    for (
      const field of editableFields
    ) {
      if (
        req.body[field] !==
        undefined
      ) {
        product[field] =
          req.body[field];
      }
    }

    // ----------------------------------------------------------
    // Validate images
    // ----------------------------------------------------------

    if (
      req.body.images !== undefined
    ) {
      if (
        !Array.isArray(
          req.body.images
        )
      ) {
        return res.status(400).json({
          error:
            'images must be an array',
        });
      }

      product.images =
        req.body.images
          .filter(
            (image) =>
              typeof image ===
                'string' &&
              image.trim().length >
                0
          )
          .map((image) =>
            image.trim()
          )
          .slice(0, 5);
    }

    // ----------------------------------------------------------
    // Validate AI analysis
    // ----------------------------------------------------------

    if (
      req.body.aiAnalysis !==
      undefined
    ) {
      if (
        req.body.aiAnalysis ===
        null
      ) {
        product.aiAnalysis = null;
      } else if (
        typeof req.body.aiAnalysis ===
          'object' &&
        !Array.isArray(
          req.body.aiAnalysis
        )
      ) {
        product.aiAnalysis =
          req.body.aiAnalysis;
      } else {
        return res.status(400).json({
          error:
            'aiAnalysis must be an object or null',
        });
      }
    }

    // ----------------------------------------------------------
    // Validate price
    // ----------------------------------------------------------

    if (
      req.body.price !== undefined
    ) {
      const numericPrice =
        Number(req.body.price);

      if (
        !Number.isFinite(
          numericPrice
        ) ||
        numericPrice <= 0
      ) {
        return res.status(400).json({
          error:
            'Price must be greater than zero',
        });
      }

      product.price =
        numericPrice;
    }

    await product.save();

    return res.json({
      message:
        'Product updated',
      product,
    });
  } catch (error) {
    console.error(
      'Error updating product:',
      error
    );

    return res.status(500).json({
      error:
        'Failed to update product',
      details:
        error.message,
    });
  }
};

// ============================================================
// DELETE /api/products/:id
// ============================================================

exports.deleteProduct = async (req, res) => {
  try {
    const product = await Product.findByPk(req.params.id);

    if (!product) {
      return res.status(404).json({
        error: 'Product not found',
      });
    }

    // Only owner or admin can delete/hide the product
    if (
      product.craftsmanId !== req.user.id &&
      req.user.role !== 'admin'
    ) {
      return res.status(403).json({
        error: 'Forbidden: not your product',
      });
    }

    // SOFT DELETE:
    // Keep the product in DB to preserve orders/history,
    // but remove it from the artisan's active products/store.
    product.isAvailable = false;

    if ('isPublic' in product.dataValues) {
      product.isPublic = false;
    }

    await product.save();

    return res.json({
      message: 'Product deleted successfully',
      softDeleted: true,
      productId: product.id,
    });
  } catch (error) {
    console.error('Error deleting product:', error);

    return res.status(500).json({
      error: 'Failed to delete product',
      details: error.message,
    });
  }
};

// ============================================================
// GET /api/products/recommendations/:userId
// 70/30 AI recommendations
// ============================================================

exports.getRecommendations =
  async (req, res) => {
    try {
      const { userId } =
        req.params;

      const requestingUserId =
        req.user?.id || null;

      // --------------------------------------------------------
      // User interactions
      // --------------------------------------------------------

      const interactions =
        await UserInteraction.findAll({
          where: {
            userId,
          },

          include: [
            {
              model: Product,
              attributes: [
                'category',
              ],
            },
          ],
        });

      // --------------------------------------------------------
      // Category scores
      // --------------------------------------------------------

      const categoryScores = {};

      interactions.forEach(
        (interaction) => {
          const cat =
            interaction.Product
              ?.category;

          if (cat) {
            categoryScores[cat] =
              (categoryScores[cat] ||
                0) +
              interaction.score;
          }
        }
      );

      const topCategories =
        Object.keys(
          categoryScores
        )
          .sort(
            (a, b) =>
              categoryScores[b] -
              categoryScores[a]
          )
          .slice(0, 3);

      let recommended = [];

      // --------------------------------------------------------
      // Personalized + exploration
      // --------------------------------------------------------

      if (
        topCategories.length > 0
      ) {
        const personalized =
          await Product.findAll({
            where: {
              category: {
                [Op.in]:
                  topCategories,
              },

              isAvailable: true,
              isPublic: true,
            },

            include: [
              {
                model: User,
                as: 'Craftsman',

                attributes: [
                  'id',
                  'name',
                  'city',
                  'profileImage',
                ],
              },
            ],

            limit: 10,

            order:
              Sequelize.literal(
                'RANDOM()'
              ),
          });

        const exploration =
          await Product.findAll({
            where: {
              category: {
                [Op.notIn]:
                  topCategories,
              },

              isAvailable: true,
              isPublic: true,
            },

            include: [
              {
                model: User,
                as: 'Craftsman',

                attributes: [
                  'id',
                  'name',
                  'city',
                  'profileImage',
                ],
              },
            ],

            limit: 4,

            order:
              Sequelize.literal(
                'RANDOM()'
              ),
          });

        recommended = [
          ...personalized,
          ...exploration,
        ];

        recommended.sort(
          () =>
            Math.random() - 0.5
        );
      } else {
        recommended =
          await Product.findAll({
            where: {
              isAvailable: true,
              isPublic: true,
            },

            include: [
              {
                model: User,
                as: 'Craftsman',

                attributes: [
                  'id',
                  'name',
                  'city',
                  'profileImage',
                ],
              },
            ],

            limit: 14,

            order: [
              [
                'createdAt',
                'DESC',
              ],
            ],
          });
      }

      const enriched =
        await enrichProducts(
          recommended,
          requestingUserId
        );

      return res.json(enriched);
    } catch (error) {
      console.error(
        'getRecommendations error:',
        error
      );

      return res.status(500).json({
        error:
          'Failed to fetch recommendations',
      });
    }
  };
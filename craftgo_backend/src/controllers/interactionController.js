const {
  Op
} = require('sequelize');
const UserInteraction = require('../models/UserInteraction');
const Product = require('../models/Product');
const User = require('../models/User');
const Exhibition = require('../models/Exhibition');

exports.logInteraction = async (req, res) => {
  try {
    const {
      productId,
      interactionType,
      type,
      targetId
    } = req.body;
    const userId = req.user.id;

    // Handle unfavorite/unfollow sent by frontend logic
    if (type === 'unfavorite_craftsman' || type === 'unfavorite_product') {
      const interaction = await UserInteraction.findOne({
        where: {
          userId,
          productId: targetId
        }
      });
      if (interaction) await interaction.destroy();
      return res.status(200).json({
        message: 'Removed successfully'
      });
    }

    if (!productId || !interactionType) {
      return res.status(400).json({
        error: 'Missing required fields'
      });
    }

    const product = await Product.findByPk(productId);
    if (!product) {
      return res.status(404).json({
        error: 'Product not found'
      });
    }

    if (interactionType === 'cart') {
      if (product.isPublic === false || product.isAvailable === false) {
        return res.status(400).json({
          error: 'This product is not available for purchase.'
        });
      }
    }

    if (interactionType === 'unlike' || interactionType === 'unfollow') {
      const typeToRemove = interactionType === 'unlike' ? 'like' : 'follow';
      const interaction = await UserInteraction.findOne({
        where: {
          userId,
          productId,
          interactionType: typeToRemove
        }
      });
      if (interaction) await interaction.destroy();
      return res.status(200).json({
        message: 'Removed successfully'
      });
    }

    let score = 1;
    switch (interactionType) {
      case 'view':
        score = 1;
        break;
      case 'like':
        score = 5;
        break;
      case 'follow':
        score = 10;
        break;
      case 'cart':
        score = 10;
        break;
      case 'purchase':
        score = 20;
        break;
      default:
        return res.status(400).json({
          error: 'Invalid interaction type'
        });
    }

    // Prevent duplicate likes/follows/cart per user per product
    if (interactionType === 'like' || interactionType === 'follow' || interactionType === 'cart') {
      const [interaction, created] = await UserInteraction.findOrCreate({
        where: {
          userId,
          productId,
          interactionType
        },
        defaults: {
          score,
          quantity: 1
        },
      });
      if (!created && interactionType === 'cart') {
        interaction.quantity += 1;
        await interaction.save();
      }
      return res.status(created ? 201 : 200).json(interaction);
    }

    const interaction = await UserInteraction.create({
      userId,
      productId,
      interactionType,
      score,
    });

    res.status(201).json(interaction);
  } catch (error) {
    console.error('[logInteraction] ERROR:', error);
    res.status(500).json({
      error: error.message
    });
  }
};

exports.getUserInteractions = async (req, res) => {
  try {
    const userId = req.user.id;
    const interactions = await UserInteraction.findAll({
      where: {
        userId
      },
      include: [{
        model: Product,
        include: [{
          model: User,
          as: 'Craftsman',
          attributes: ['name']
        }]
      }],
      order: [
        ['createdAt', 'DESC']
      ]
    });
    res.json(interactions);
  } catch (error) {
    console.error('[getUserInteractions] ERROR:', error);
    res.status(500).json({
      error: 'Failed to fetch interactions'
    });
  }
};

exports.deleteInteraction = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const userId = req.user.id;
    const interaction = await UserInteraction.findOne({
      where: {
        id,
        userId
      }
    });
    if (!interaction) return res.status(404).json({
      error: 'Interaction not found'
    });
    await interaction.destroy();
    res.json({
      message: 'Interaction deleted'
    });
  } catch (error) {
    console.error('[deleteInteraction] ERROR:', error);
    res.status(500).json({
      error: 'Failed to delete interaction'
    });
  }
};

exports.updateInteraction = async (req, res) => {
  try {
    const {
      id
    } = req.params;
    const {
      quantity
    } = req.body;
    const userId = req.user.id;
    const interaction = await UserInteraction.findOne({
      where: {
        id,
        userId,
        interactionType: 'cart'
      }
    });
    if (!interaction) return res.status(404).json({
      error: 'Cart item not found'
    });

    if (quantity !== undefined) {
      if (!Number.isInteger(quantity) || quantity < 1 || quantity > 999) {
        return res.status(400).json({
          error: 'Quantity must be an integer between 1 and 999'
        });
      }
      interaction.quantity = quantity;
    }
    await interaction.save();
    res.json({
      success: true,
      message: 'Cart quantity updated',
      interaction
    });
  } catch (error) {
    console.error('[updateInteraction] ERROR:', error);
    res.status(500).json({
      error: 'Failed to update interaction'
    });
  }
};

exports.clearCart = async (req, res) => {
  try {
    const userId = req.user.id;
    await UserInteraction.destroy({
      where: {
        userId,
        interactionType: 'cart'
      }
    });
    res.json({
      message: 'Cart cleared successfully'
    });
  } catch (error) {
    console.error('[clearCart] ERROR:', error);
    res.status(500).json({
      error: 'Failed to clear cart'
    });
  }
};

// ── Exhibition Interest ─────────────────────────────────────────────────────

/**
 * POST /api/interactions/exhibition
 * Toggle interest (favorite) status for an exhibition
 * Body: { exhibitionId }
 */
exports.toggleExhibitionInterest = async (req, res) => {
  try {
    const {
      exhibitionId
    } = req.body;
    const userId = req.user.id;

    if (!exhibitionId) {
      return res.status(400).json({
        error: 'exhibitionId is required'
      });
    }

    // Verify exhibition exists
    const exhibition = await Exhibition.findByPk(exhibitionId);
    if (!exhibition) {
      return res.status(404).json({
        error: 'Exhibition not found'
      });
    }

    // Check if already interested (using exhibitionId)
    const existing = await UserInteraction.findOne({
      where: {
        userId,
        exhibitionId,
        interactionType: 'exhibition',
      },
    });

    if (existing) {
      await existing.destroy();
      return res.json({
        success: true,
        interested: false,
        message: 'Exhibition removed from interests',
      });
    }

    // Create new interaction (with exhibitionId)
    await UserInteraction.create({
      userId,
      exhibitionId,
      interactionType: 'exhibition',
      score: 10,
      quantity: 1,
    });

    return res.status(201).json({
      success: true,
      interested: true,
      message: 'Exhibition added to interests',
    });
  } catch (error) {
    console.error('[toggleExhibitionInterest] ERROR:', error);
    return res.status(500).json({
      error: error.message
    });
  }
};

/**
 * GET /api/interactions/exhibitions
 * Get all exhibitions the user is interested in
 */
exports.getInterestedExhibitions = async (req, res) => {
  try {
    const userId = req.user.id;

    const interactions = await UserInteraction.findAll({
      where: {
        userId,
        interactionType: 'exhibition',
        exhibitionId: {
          [Op.ne]: null
        },
      },
    });

    if (interactions.length === 0) {
      return res.json({
        success: true,
        exhibitions: []
      });
    }

    const exhibitionIds = interactions.map((i) => i.exhibitionId);

    const exhibitions = await Exhibition.findAll({
      where: {
        id: {
          [Op.in]: exhibitionIds
        },
      },
      include: [{
        model: User,
        as: 'Owner',
        attributes: ['id', 'name', 'email'],
      }],
      order: [
        ['startDate', 'ASC']
      ],
    });

    return res.json({
      success: true,
      exhibitions
    });
  } catch (error) {
    console.error('[getInterestedExhibitions] ERROR:', error);
    return res.status(500).json({
      error: error.message
    });
  }
};
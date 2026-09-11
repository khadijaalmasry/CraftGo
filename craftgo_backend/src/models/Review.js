const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const User = require('./User');
const Order = require('./Order');
const CustomOrderRequest = require('./CustomOrderRequest');
const HireRequest = require('./HireRequest');

const Review = sequelize.define('Review', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },

  artisanId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },

  customerId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },

  // Direction of the review:
  // customer_to_artisan = customer rates artisan
  // artisan_to_customer = artisan rates customer
  direction: {
    type: DataTypes.ENUM(
      'customer_to_artisan',
      'artisan_to_customer'
    ),
    allowNull: false,
    defaultValue: 'customer_to_artisan',
  },

  // Ready-Made order
  orderId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: {
      model: Order,
      key: 'id',
    },
  },

  // Custom Order
  customOrderRequestId: {
    type: DataTypes.UUID,
    allowNull: true,
  },

  // Hire / On-Site Order
  hireRequestId: {
    type: DataTypes.UUID,
    allowNull: true,
  },

  rating: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 5,
    },
  },

  commentAr: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  commentEn: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  createdAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

// =====================================================
// User Associations
// =====================================================

User.hasMany(Review, {
  foreignKey: 'artisanId',
  as: 'artisanReviews',
});

Review.belongsTo(User, {
  foreignKey: 'artisanId',
  as: 'artisan',
});

User.hasMany(Review, {
  foreignKey: 'customerId',
  as: 'customerReviews',
});

Review.belongsTo(User, {
  foreignKey: 'customerId',
  as: 'customer',
});

// =====================================================
// Ready-Made Associations
// =====================================================

Order.hasMany(Review, {
  foreignKey: 'orderId',
});

Review.belongsTo(Order, {
  foreignKey: 'orderId',
});

// =====================================================
// Custom Order Associations
// =====================================================

CustomOrderRequest.hasMany(Review, {
  foreignKey: 'customOrderRequestId',
  as: 'reviews',
  constraints: false,
});

Review.belongsTo(CustomOrderRequest, {
  foreignKey: 'customOrderRequestId',
  as: 'customOrderRequest',
  constraints: false,
});

// =====================================================
// Hire / On-Site Associations
// =====================================================

HireRequest.hasMany(Review, {
  foreignKey: 'hireRequestId',
  as: 'reviews',
  constraints: false,
});

Review.belongsTo(HireRequest, {
  foreignKey: 'hireRequestId',
  as: 'hireRequest',
  constraints: false,
});

module.exports = Review;
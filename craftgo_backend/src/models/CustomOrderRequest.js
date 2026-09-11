const {
  DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const CustomOrderTemplate = require('./CustomOrderTemplate');

const CustomOrderRequest = sequelize.define('CustomOrderRequest', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },

  templateId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: CustomOrderTemplate,
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

  artisanId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },

  status: {
    type: DataTypes.ENUM(
      'pending_artisan',
      'pending_customer',
      'in_progress',
      'completed',
      'rejected',
      'cancelled'
    ),
    defaultValue: 'pending_artisan',
  },

  filledFields: {
    type: DataTypes.JSON,
    defaultValue: {},
  },

  artisanResponse: {
    type: DataTypes.JSON,
    allowNull: true,
  },

  contractSigned: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },

  contractSignedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },

  progressStage: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  deliveryAddress: {
    type: DataTypes.STRING,
    allowNull: true,
  },

  customerPhone: {
    type: DataTypes.STRING,
    allowNull: true,
  },


  progressPercent: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
    validate: {
      min: 0,
      max: 100,
    },
  },
  stripePaymentIntentId: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  paymentStatus: {
    type: DataTypes.ENUM('unpaid', 'paid', 'failed'),
    defaultValue: 'unpaid',
  },
  paidAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

// Associations
CustomOrderTemplate.hasMany(CustomOrderRequest, {
  foreignKey: 'templateId',
  as: 'requests',
});

CustomOrderRequest.belongsTo(CustomOrderTemplate, {
  foreignKey: 'templateId',
  as: 'template',
});

User.hasMany(CustomOrderRequest, {
  foreignKey: 'customerId',
  as: 'customerCustomRequests',
});

CustomOrderRequest.belongsTo(User, {
  foreignKey: 'customerId',
  as: 'customer',
});

User.hasMany(CustomOrderRequest, {
  foreignKey: 'artisanId',
  as: 'artisanCustomRequests',
});

CustomOrderRequest.belongsTo(User, {
  foreignKey: 'artisanId',
  as: 'artisan',
});

module.exports = CustomOrderRequest;
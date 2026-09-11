const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const HireRequest = sequelize.define('HireRequest', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
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

  jobDescription: {
    type: DataTypes.TEXT,
    allowNull: false,
  },

  latitude: {
    type: DataTypes.DOUBLE,
    allowNull: false,
  },

  longitude: {
    type: DataTypes.DOUBLE,
    allowNull: false,
  },

  address: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  extraDetails: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  startDate: {
    type: DataTypes.DATE,
    allowNull: false,
  },

  endDate: {
    type: DataTypes.DATE,
    allowNull: false,
  },

  dailyHours: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 8,
  },

  requiredMaterials: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: [],
  },

  requiredTools: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: [],
  },

  status: {
    type: DataTypes.ENUM(
      'pending_artisan',
      'pending_customer',
      'in_progress',
      'completed',
      'cancelled'
    ),
    allowNull: false,
    defaultValue: 'pending_artisan',
  },

  artisanResponse: {
    type: DataTypes.JSON,
    allowNull: true,
  },

  totalPrice: {
    type: DataTypes.DOUBLE,
    allowNull: true,
  },

  progressStage: {
    type: DataTypes.STRING,
    allowNull: true,
  },

  progressPercent: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },

  completedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
});

// Customer relation
User.hasMany(HireRequest, {
  foreignKey: 'customerId',
  as: 'hireRequestsAsCustomer',
});

HireRequest.belongsTo(User, {
  foreignKey: 'customerId',
  as: 'customer',
});

// Artisan relation
User.hasMany(HireRequest, {
  foreignKey: 'artisanId',
  as: 'hireRequestsAsArtisan',
});

HireRequest.belongsTo(User, {
  foreignKey: 'artisanId',
  as: 'artisan',
});

module.exports = HireRequest;
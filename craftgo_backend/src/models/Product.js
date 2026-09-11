const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const Product = sequelize.define('Product', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },

  craftsmanId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id',
    },
  },

  titleAr: {
    type: DataTypes.STRING,
    allowNull: false,
  },

  titleEn: {
    type: DataTypes.STRING,
    allowNull: false,
  },

  description: {
    type: DataTypes.TEXT,
  },

  materials: {
    type: DataTypes.STRING,
  },

  dimensions: {
    type: DataTypes.STRING,
  },

  colors: {
    type: DataTypes.STRING,
  },

  price: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
  },

  category: {
    type: DataTypes.STRING,
  },

  imageUrl: {
    type: DataTypes.STRING,
  },

  // Main image + additional product images
  images: {
    type: DataTypes.JSON,
    allowNull: false,
    defaultValue: [],
  },

  // Save the latest CraftGo AI analysis
  // so it appears again when Edit Product is opened.
  aiAnalysis: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: null,
  },

  isPublic: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  },

  isAvailable: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  },
});

User.hasMany(Product, { foreignKey: 'craftsmanId' });
Product.belongsTo(User, {
  foreignKey: 'craftsmanId',
  as: 'Craftsman',
});

module.exports = Product;
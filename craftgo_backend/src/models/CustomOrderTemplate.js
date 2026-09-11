const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const CustomOrderTemplate = sequelize.define('CustomOrderTemplate', {
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
  titleAr: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  titleEn: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  categoryAr: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  categoryEn: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  descriptionAr: {
    type: DataTypes.TEXT,
  },
  descriptionEn: {
    type: DataTypes.TEXT,
  },
  basePrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: false,
    defaultValue: 0.0,
  },
  estimatedDays: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1,
  },
  fields: {
    type: DataTypes.JSON, // array of field descriptors
    defaultValue: [],
  },
});

// Associations
User.hasMany(CustomOrderTemplate, { foreignKey: 'artisanId', as: 'artisanTemplates' });
CustomOrderTemplate.belongsTo(User, { foreignKey: 'artisanId', as: 'artisan' });

module.exports = CustomOrderTemplate;

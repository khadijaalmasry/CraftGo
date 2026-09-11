const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const Product = require('./Product');

const ProductOffer = sequelize.define('ProductOffer', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  productId: { type: DataTypes.UUID, allowNull: false, references: { model: Product, key: 'id' } },
  customerId: { type: DataTypes.UUID, allowNull: false, references: { model: User, key: 'id' } },
  craftsmanId: { type: DataTypes.UUID, allowNull: false, references: { model: User, key: 'id' } },
  quantity: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1 },
  originalUnitPrice: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  offeredUnitPrice: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
  counterUnitPrice: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
  acceptedUnitPrice: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
  message: { type: DataTypes.TEXT, allowNull: true },
  status: {
    type: DataTypes.ENUM('pending', 'countered', 'accepted', 'rejected', 'cancelled', 'paid'),
    allowNull: false,
    defaultValue: 'pending',
  },
  expiresAt: { type: DataTypes.DATE, allowNull: false },
});

ProductOffer.belongsTo(Product, { foreignKey: 'productId', as: 'product' });
ProductOffer.belongsTo(User, { foreignKey: 'customerId', as: 'customer' });
ProductOffer.belongsTo(User, { foreignKey: 'craftsmanId', as: 'craftsman' });
Product.hasMany(ProductOffer, { foreignKey: 'productId', as: 'offers' });

module.exports = ProductOffer;

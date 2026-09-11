const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const FavoriteArtisan = sequelize.define('FavoriteArtisan', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  userId: {
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
}, {
  indexes: [
    {
      unique: true,
      fields: ['userId', 'artisanId'],
    },
  ],
});

// Associations
User.hasMany(FavoriteArtisan, { foreignKey: 'userId', as: 'userFavorites' });
FavoriteArtisan.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(FavoriteArtisan, { foreignKey: 'artisanId', as: 'artisanFavoritedBy' });
FavoriteArtisan.belongsTo(User, { foreignKey: 'artisanId', as: 'artisan' });

module.exports = FavoriteArtisan;

const {
    DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const ArtisanProfile = require('./ArtisanProfile');

const PortfolioItem = sequelize.define('PortfolioItem', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    artisanProfileId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
            model: ArtisanProfile,
            key: 'id'
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
    descriptionAr: {
        type: DataTypes.TEXT,
    },
    descriptionEn: {
        type: DataTypes.TEXT,
    },
    imageUrl: {
        type: DataTypes.STRING,
    },
    createdAt: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW,
    },
});

ArtisanProfile.hasMany(PortfolioItem, {
    foreignKey: 'artisanProfileId'
});
PortfolioItem.belongsTo(ArtisanProfile, {
    foreignKey: 'artisanProfileId'
});

module.exports = PortfolioItem;
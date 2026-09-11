const {
    DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const ArtisanProfile = sequelize.define('ArtisanProfile', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    userId: {
        type: DataTypes.UUID,
        allowNull: false,
        unique: true,
        references: {
            model: User,
            key: 'id'
        },
    },
    bio: {
        type: DataTypes.TEXT,
    },
    bioAr: {
        type: DataTypes.TEXT,
        allowNull: true,
    },

    bioEn: {
        type: DataTypes.TEXT,
        allowNull: true,
    },

    primaryCategoryAr: {
        type: DataTypes.STRING,
        allowNull: true,
    },

    primaryCategoryEn: {
        type: DataTypes.STRING,
        allowNull: true,
    },

    bannerImage: {
        type: DataTypes.TEXT,
        allowNull: true,
    },
    experienceYears: {
        type: DataTypes.INTEGER,
        defaultValue: 0,
    },
    primaryCategory: {
        type: DataTypes.STRING,
    },
    additionalCategories: {
        type: DataTypes.JSON, // array of strings
        defaultValue: [],
    },
    isVerified: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
    },
    trustedHands: {
        type: DataTypes.BOOLEAN,
        defaultValue: false,
    },
    priceRange: {
        type: DataTypes.STRING, // e.g., "50-200"
    },
    specializations: {
        type: DataTypes.JSON, // array of strings
        defaultValue: [],
    },
    idVerificationDetails: {
        type: DataTypes.JSON,
        allowNull: true,
    },
});

// Associations
User.hasOne(ArtisanProfile, {
    foreignKey: 'userId'
});
ArtisanProfile.belongsTo(User, {
    foreignKey: 'userId'
});

module.exports = ArtisanProfile;
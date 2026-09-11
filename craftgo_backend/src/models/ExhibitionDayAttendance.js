const {
    DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const Exhibition = require('./Exhibition');
const User = require('./User');

const ExhibitionDayAttendance = sequelize.define('ExhibitionDayAttendance', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    exhibitionId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
            model: Exhibition,
            key: 'id',
        },
    },
    craftsmanId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
            model: User,
            key: 'id',
        },
    },
    date: {
        type: DataTypes.DATEONLY, // e.g. '2026-07-01'
        allowNull: false,
    },
    isPresent: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
    },
    absenceReason: {
        type: DataTypes.STRING,
        allowNull: true,
    },
}, {
    indexes: [{
        unique: true,
        fields: ['exhibitionId', 'craftsmanId', 'date'],
    }, ],
});

// Associations
Exhibition.hasMany(ExhibitionDayAttendance, {
    foreignKey: 'exhibitionId',
    as: 'dailyAttendance',
});
ExhibitionDayAttendance.belongsTo(Exhibition, {
    foreignKey: 'exhibitionId',
    as: 'exhibition',
});

User.hasMany(ExhibitionDayAttendance, {
    foreignKey: 'craftsmanId',
    as: 'dailyAttendance',
});
ExhibitionDayAttendance.belongsTo(User, {
    foreignKey: 'craftsmanId',
    as: 'craftsman',
});

module.exports = ExhibitionDayAttendance;
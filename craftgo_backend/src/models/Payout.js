const {
    DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const Payout = sequelize.define('Payout', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    driverId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
            model: User,
            key: 'id'
        },
    },
    amount: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
    },
    currency: {
        type: DataTypes.STRING(3),
        defaultValue: 'JOD',
    },
    stripeTransferId: {
        type: DataTypes.STRING,
        allowNull: true,
    },
    status: {
        type: DataTypes.ENUM('pending', 'completed', 'failed'),
        defaultValue: 'pending',
    },
    requestedAt: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW,
    },
    completedAt: {
        type: DataTypes.DATE,
        allowNull: true,
    },
    failureReason: {
        type: DataTypes.TEXT,
        allowNull: true,
    },
});

Payout.belongsTo(User, {
    foreignKey: 'driverId',
    as: 'driver'
});
User.hasMany(Payout, {
    foreignKey: 'driverId',
    as: 'payouts'
});

module.exports = Payout;
const {
    DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const PaymentBundle = sequelize.define('PaymentBundle', {
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
            key: 'id'
        },
    },
    orderIds: {
        type: DataTypes.JSON,
        allowNull: false,
        defaultValue: [],
    },
    deliveryOrderIds: {
        type: DataTypes.JSON,
        allowNull: false,
        defaultValue: [],
    },
    currency: {
        type: DataTypes.STRING(3),
        allowNull: false,
        defaultValue: 'JOD',
    },
    grossAmount: {
        type: DataTypes.DECIMAL(12, 3),
        allowNull: false,
        defaultValue: 0,
    },
    stripeCheckoutSessionId: {
        type: DataTypes.STRING,
        allowNull: true,
    },
    paymentStatus: {
        type: DataTypes.ENUM('created', 'paid', 'failed'),
        defaultValue: 'created',
    },
    paidAt: {
        type: DataTypes.DATE,
        allowNull: true
    },
});

module.exports = PaymentBundle;
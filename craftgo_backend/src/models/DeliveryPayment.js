const {
    DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const DeliveryOrder = require('./DeliveryOrder');

const DeliveryPayment = sequelize.define('DeliveryPayment', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
    },
    deliveryOrderId: {
        type: DataTypes.UUID,
        allowNull: false,
        unique: true,
        references: {
            model: DeliveryOrder,
            key: 'id'
        },
    },
    customerId: {
        type: DataTypes.UUID,
        allowNull: false,
        references: {
            model: User,
            key: 'id'
        },
    },
    driverId: {
        type: DataTypes.UUID,
        allowNull: true,
        references: {
            model: User,
            key: 'id'
        },
    },
    currency: {
        type: DataTypes.STRING(3),
        allowNull: false,
        defaultValue: 'JOD'
    },
    grossAmount: {
        type: DataTypes.DECIMAL(12, 3),
        allowNull: false
    },
    platformCommissionRate: {
        type: DataTypes.DECIMAL(5, 2),
        allowNull: false,
        defaultValue: 0
    },
    platformCommission: {
        type: DataTypes.DECIMAL(12, 3),
        allowNull: false,
        defaultValue: 0
    },
    driverAmount: {
        type: DataTypes.DECIMAL(12, 3),
        allowNull: false,
        defaultValue: 0
    },
    stripePaymentIntentId: {
        type: DataTypes.STRING,
        allowNull: true,
        unique: true
    },
    stripeTransferId: {
        type: DataTypes.STRING,
        allowNull: true,
        unique: true
    },
    paymentStatus: {
        type: DataTypes.ENUM('created', 'processing', 'succeeded', 'failed', 'refunded'),
        allowNull: false,
        defaultValue: 'created',
    },
    escrowStatus: {
        type: DataTypes.ENUM('unpaid', 'held', 'released', 'refunded'),
        allowNull: false,
        defaultValue: 'unpaid',
    },
    paidAt: {
        type: DataTypes.DATE,
        allowNull: true
    },
    releasedAt: {
        type: DataTypes.DATE,
        allowNull: true
    },
    failureMessage: {
        type: DataTypes.TEXT,
        allowNull: true
    },
});

DeliveryOrder.hasOne(DeliveryPayment, {
    foreignKey: 'deliveryOrderId',
    as: 'payment'
});
DeliveryPayment.belongsTo(DeliveryOrder, {
    foreignKey: 'deliveryOrderId',
    as: 'deliveryOrder'
});
DeliveryPayment.belongsTo(User, {
    foreignKey: 'customerId',
    as: 'customer'
});
DeliveryPayment.belongsTo(User, {
    foreignKey: 'driverId',
    as: 'driver'
});

module.exports = DeliveryPayment;
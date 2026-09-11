const {
  DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const Product = require('./Product');

const DeliveryOrder = sequelize.define('DeliveryOrder', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  orderCode: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },
  customerId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id'
    },
  },
  craftsmanId: {
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
  productId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: {
      model: Product,
      key: 'id'
    },
  },
  productOrderId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: {
      model: 'Orders',
      key: 'id',
    },
  },

  // Item Specifications
  orderType: {
    type: DataTypes.ENUM('ready_made', 'custom_made'),
    defaultValue: 'ready_made',
  },
  customSpecifications: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  // Logistics & Status Tracking
  status: {
    type: DataTypes.ENUM(
      'available',
      'active',
      'delivered',
      'completed',
      'cancelled',
      'undelivered',
      'returned'
    ),
    defaultValue: 'available',
  },

  // Issue & Cancellation Details
  issueType: {
    type: DataTypes.ENUM(
      'none',
      'item_broken',
      'incorrect_order',
      'customer_unreachable',
      'wrong_address',
      'other'
    ),
    defaultValue: 'none',
  },
  issueNotes: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  issuePhotoUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  cancelledBy: {
    type: DataTypes.ENUM('customer', 'craftsman', 'driver', 'admin'),
    allowNull: true,
  },
  cancelReason: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  customOrderId: {
    type: DataTypes.STRING,
    allowNull: true,
  },

  // Add deliveryPin field to DeliveryOrder schema
  deliveryPin: {
    type: DataTypes.STRING(4),
    allowNull: false,
    defaultValue: () => Math.floor(1000 + Math.random() * 9000).toString(), // Generates random 4-digit PIN
  },

  qrCodeData: {
    type: DataTypes.TEXT,
    allowNull: true,
  },

  // Delivery Addresses & Specs
  pickupAddress: {
    type: DataTypes.STRING,
    allowNull: false
  },
  pickupPhone: {
    type: DataTypes.STRING,
    allowNull: true
  },
  dropoffAddress: {
    type: DataTypes.STRING,
    allowNull: false
  },
  customerPhone: {
    type: DataTypes.STRING,
    allowNull: true
  },
  earningAmount: {
    type: DataTypes.DECIMAL(10, 2),
    defaultValue: 0.00
  },
  distanceKm: {
    type: DataTypes.FLOAT,
    defaultValue: 0.0
  },
  weightKg: {
    type: DataTypes.FLOAT,
    defaultValue: 0.0
  },
  isFragile: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  postedAt: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  dueAt: {
    type: DataTypes.DATE,
    allowNull: true
  },
  deliveredAt: {
    type: DataTypes.DATE,
    allowNull: true
  },
  relatedOrderIds: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  relatedCustomOrderIds: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  isClearedByArtisan: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  rating: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  reviewComment: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
  reviewedByRole: {
    type: DataTypes.STRING,
    allowNull: true,
  },
});

// Associations
DeliveryOrder.belongsTo(User, {
  as: 'customer',
  foreignKey: 'customerId'
});
DeliveryOrder.belongsTo(User, {
  as: 'craftsman',
  foreignKey: 'craftsmanId'
});
DeliveryOrder.belongsTo(User, {
  as: 'driver',
  foreignKey: 'driverId'
});
DeliveryOrder.belongsTo(Product, {
  as: 'product',
  foreignKey: 'productId'
});

module.exports = DeliveryOrder;

// const { DataTypes } = require('sequelize');
// const sequelize = require('../config/database');
// const User = require('./User');
// const Order = require('./Order');

// const DeliveryOrder = sequelize.define('DeliveryOrder', {
//   id: {
//     type: DataTypes.UUID,
//     defaultValue: DataTypes.UUIDV4,
//     primaryKey: true,
//   },
//   orderCode: {
//     type: DataTypes.STRING,
//     allowNull: false,
//     unique: true,
//   },
//   orderId: {
//     type: DataTypes.UUID,
//     allowNull: true,
//     references: { model: Order, key: 'id' },
//   },
//   driverId: {
//     type: DataTypes.UUID,
//     allowNull: true,
//     references: { model: User, key: 'id' },
//   },
//   customerId: {
//     type: DataTypes.UUID,
//     allowNull: true,
//     references: { model: User, key: 'id' },
//   },
//   craftsmanId: {
//     type: DataTypes.UUID,
//     allowNull: true,
//     references: { model: User, key: 'id' },
//   },
//   productName: {
//     type: DataTypes.STRING,
//     allowNull: false,
//   },
//   productNameEn: {
//     type: DataTypes.STRING,
//     allowNull: true,
//   },
//   pickupAddress: {
//     type: DataTypes.STRING,
//     allowNull: false,
//   },
//   pickupAddressEn: {
//     type: DataTypes.STRING,
//     allowNull: true,
//   },
//   dropoffAddress: {
//     type: DataTypes.STRING,
//     allowNull: false,
//   },
//   dropoffAddressEn: {
//     type: DataTypes.STRING,
//     allowNull: true,
//   },
//   postedAt: {
//     type: DataTypes.DATE,
//     defaultValue: DataTypes.NOW,
//   },
//   dueAt: {
//     type: DataTypes.DATE,
//     allowNull: true,
//   },
//   distanceKm: {
//     type: DataTypes.DECIMAL(10, 2),
//     defaultValue: 1.0,
//   },
//   earningAmount: {
//     type: DataTypes.DECIMAL(10, 2),
//     allowNull: false,
//   },
//   weightKg: {
//     type: DataTypes.DECIMAL(10, 2),
//     defaultValue: 1.0,
//   },
//   isFragile: {
//     type: DataTypes.BOOLEAN,
//     defaultValue: false,
//   },
//   status: {
//     type: DataTypes.ENUM('available', 'active', 'upcoming', 'completed', 'cancelled'),
//     defaultValue: 'available',
//   },
//   customerName: {
//     type: DataTypes.STRING,
//     allowNull: true,
//   },
//   customerNameEn: {
//     type: DataTypes.STRING,
//     allowNull: true,
//   },
//   customerPhone: {
//     type: DataTypes.STRING,
//     allowNull: true,
//   },
//   pickupPhone: {
//     type: DataTypes.STRING,
//     allowNull: true,
//   },
//   deliveredAt: {
//     type: DataTypes.DATE,
//     allowNull: true,
//   },
//   notes: {
//     type: DataTypes.TEXT,
//     allowNull: true,
//   },
//   rating: {
//     type: DataTypes.FLOAT,
//     allowNull: true,
//   },
// });

// User.hasMany(DeliveryOrder, { foreignKey: 'driverId', as: 'driverDeliveries' });
// DeliveryOrder.belongsTo(User, { foreignKey: 'driverId', as: 'driver' });

// User.hasMany(DeliveryOrder, { foreignKey: 'customerId', as: 'customerDeliveries' });
// DeliveryOrder.belongsTo(User, { foreignKey: 'customerId', as: 'customer' });

// Order.hasOne(DeliveryOrder, { foreignKey: 'orderId', as: 'deliveryOrder' });
// DeliveryOrder.belongsTo(Order, { foreignKey: 'orderId', as: 'baseOrder' });

// module.exports = DeliveryOrder;
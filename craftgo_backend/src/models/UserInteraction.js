const {
  DataTypes,
  Op
} = require('sequelize');
const sequelize = require('../config/database');

const UserInteraction = sequelize.define('UserInteraction', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: 'Users', // ✅ string table name
      key: 'id'
    }
  },
  productId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: {
      model: 'Products', // ✅ string table name
      key: 'id'
    }
  },
  exhibitionId: {
    type: DataTypes.UUID,
    allowNull: true,
    references: {
      model: 'Exhibitions', // ✅ string table name
      key: 'id'
    }
  },
  interactionType: {
    type: DataTypes.ENUM('view', 'like', 'cart', 'purchase', 'follow', 'exhibition'),
    allowNull: false,
  },
  score: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1
  },
  quantity: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 1
  },
}, {
  indexes: [{
      unique: true,
      fields: ['userId', 'productId', 'interactionType'],
      where: {
        interactionType: ['like', 'cart', 'follow'],
        productId: {
          [Op.ne]: null
        }
      },
      name: 'unique_user_product_interaction_type',
    },
    {
      unique: true,
      fields: ['userId', 'exhibitionId', 'interactionType'],
      where: {
        interactionType: 'exhibition',
        exhibitionId: {
          [Op.ne]: null
        }
      },
      name: 'unique_user_exhibition_interaction',
    },
  ],
});

// Relationships (optional, but keep for associations)
const User = require('./User');
const Product = require('./Product');
const Exhibition = require('./Exhibition');

User.hasMany(UserInteraction, {
  foreignKey: 'userId'
});
UserInteraction.belongsTo(User, {
  foreignKey: 'userId'
});

Product.hasMany(UserInteraction, {
  foreignKey: 'productId'
});
UserInteraction.belongsTo(Product, {
  foreignKey: 'productId'
});

Exhibition.hasMany(UserInteraction, {
  foreignKey: 'exhibitionId'
});
UserInteraction.belongsTo(Exhibition, {
  foreignKey: 'exhibitionId'
});

module.exports = UserInteraction;
// const { DataTypes } = require('sequelize');
// const sequelize = require('../config/database');
// const User = require('./User');
// const Product = require('./Product');
// const Exhibition = require('./Exhibition'); // ← new import

// const UserInteraction = sequelize.define('UserInteraction', {
//   id: {
//     type: DataTypes.UUID,
//     defaultValue: DataTypes.UUIDV4,
//     primaryKey: true
//   },
//   userId: {
//     type: DataTypes.UUID,
//     allowNull: false,
//     references: {
//       model: User,
//       key: 'id'
//     }
//   },
//   // ── productId is now nullable ──
//   productId: {
//     type: DataTypes.UUID,
//     allowNull: true,  // ← changed from false to true
//     references: {
//       model: Product,
//       key: 'id'
//     }
//   },
//   // ── NEW: exhibitionId ──
//   exhibitionId: {
//     type: DataTypes.UUID,
//     allowNull: true,
//     references: {
//       model: Exhibition,
//       key: 'id'
//     }
//   },
//   interactionType: {
//     type: DataTypes.ENUM('view', 'like', 'cart', 'purchase', 'follow', 'exhibition'),
//     allowNull: false,
//   },
//   score: {
//     type: DataTypes.INTEGER,
//     allowNull: false,
//     defaultValue: 1
//   },
//   quantity: {
//     type: DataTypes.INTEGER,
//     allowNull: false,
//     defaultValue: 1
//   },
// }, {
//   // Unique constraint: prevent duplicate like/cart/follow per user per product OR exhibition
//   indexes: [
//     {
//       unique: true,
//       fields: ['userId', 'productId', 'interactionType'],
//       where: {
//         interactionType: ['like', 'cart', 'follow'],
//         productId: { [Op.ne]: null }
//       },
//       name: 'unique_user_product_interaction_type',
//     },
//     {
//       unique: true,
//       fields: ['userId', 'exhibitionId', 'interactionType'],
//       where: {
//         interactionType: 'exhibition',
//         exhibitionId: { [Op.ne]: null }
//       },
//       name: 'unique_user_exhibition_interaction',
//     },
//   ],
// });

// // Relationships
// User.hasMany(UserInteraction, { foreignKey: 'userId' });
// UserInteraction.belongsTo(User, { foreignKey: 'userId' });

// Product.hasMany(UserInteraction, { foreignKey: 'productId' });
// UserInteraction.belongsTo(Product, { foreignKey: 'productId' });

// Exhibition.hasMany(UserInteraction, { foreignKey: 'exhibitionId' });
// UserInteraction.belongsTo(Exhibition, { foreignKey: 'exhibitionId' });

// module.exports = UserInteraction;
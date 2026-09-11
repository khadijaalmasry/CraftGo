const {
  DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const Chat = sequelize.define('Chat', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  participant1Id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  participant1Role: {
    type: DataTypes.ENUM('customer', 'craftsman', 'admin', 'exhibition_owner', 'driver'),
    allowNull: false,
  },
  participant2Id: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  participant2Role: {
    type: DataTypes.ENUM('customer', 'craftsman', 'admin', 'exhibition_owner', 'driver'),
    allowNull: false,
  },
  orderId: {
    type: DataTypes.UUID,
    allowNull: true,
  },
  lastMessage: {
    type: DataTypes.TEXT,
  },
});

// ── Associations ───────────────────────────────────────────────────────────
// We need to associate with User but we have two possible participant columns.
// We'll create two associations per participant.
Chat.belongsTo(User, {
  foreignKey: 'participant1Id',
  as: 'participant1'
});
Chat.belongsTo(User, {
  foreignKey: 'participant2Id',
  as: 'participant2'
});

User.hasMany(Chat, {
  foreignKey: 'participant1Id',
  as: 'chatsAsParticipant1'
});
User.hasMany(Chat, {
  foreignKey: 'participant2Id',
  as: 'chatsAsParticipant2'
});

module.exports = Chat;
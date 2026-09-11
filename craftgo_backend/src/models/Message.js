const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const Chat = require('./Chat');
const User = require('./User');

const Message = sequelize.define('Message', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  chatId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: Chat, key: 'id' },
  },
  senderId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: { model: User, key: 'id' },
  },
  content: { type: DataTypes.TEXT, allowNull: false },
  isRead: { type: DataTypes.BOOLEAN, defaultValue: false },
});

// ── Associations ──────────────────────────────────────────────────────────
Chat.hasMany(Message, { foreignKey: 'chatId', as: 'messages' });
Message.belongsTo(Chat, { foreignKey: 'chatId', as: 'chat' });

User.hasMany(Message, { foreignKey: 'senderId', as: 'sentMessages' });
Message.belongsTo(User, { foreignKey: 'senderId', as: 'sender' });

module.exports = Message;
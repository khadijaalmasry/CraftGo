const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');
const Exhibition = require('./Exhibition');

const ExhibitionCraftsman = sequelize.define('ExhibitionCraftsman', {
  id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
  exhibitionId: { type: DataTypes.UUID, allowNull: false, references: { model: Exhibition, key: 'id' } },
  craftsmanId: { type: DataTypes.UUID, allowNull: false, references: { model: User, key: 'id' } },
  craftCategory: { type: DataTypes.STRING, allowNull: true }, // e.g. 'Pottery', 'Jewelry'

  // ── Booth & Payment ──────────────────────────────────────────────
  boothId: { type: DataTypes.STRING, allowNull: true },            // e.g. 'A1', 'B2'
  boothPrice: { type: DataTypes.DECIMAL(10, 2), allowNull: true }, // e.g. 25.00
  hasPaid: { type: DataTypes.BOOLEAN, defaultValue: false },
  paymentReference: { type: DataTypes.STRING, allowNull: true },   // e.g. 'TXN-98471203'

  // ── Registration Status ──────────────────────────────────────────
  // 'pending'   → participation request sent, awaiting owner approval
  // 'standby'   → registered but capacity full, waiting for a spot
  // 'confirmed' → approved & booth assigned
  // 'rejected'  → denied by owner
  // 'cancelled' → craftsman reported absence or voluntarily withdrew
  status: {
    type: DataTypes.ENUM('pending', 'standby', 'confirmed', 'rejected', 'cancelled'),
    defaultValue: 'standby',
  },
  standbyRank: { type: DataTypes.INTEGER, allowNull: true },
  rejectionReason: { type: DataTypes.STRING, allowNull: true },

  // ── Absence Reporting ────────────────────────────────────────────
  reportedAbsence: { type: DataTypes.BOOLEAN, defaultValue: false },
  absenceReason: { type: DataTypes.STRING, allowNull: true },   // e.g. 'sick', 'emergency'
  absenceApology: { type: DataTypes.TEXT, allowNull: true },    // AI-generated apology text
});

// Many-to-Many
User.belongsToMany(Exhibition, { through: ExhibitionCraftsman, foreignKey: 'craftsmanId' });
Exhibition.belongsToMany(User, { through: ExhibitionCraftsman, foreignKey: 'exhibitionId' });

// Direct associations for eager loading in controller queries
Exhibition.hasMany(ExhibitionCraftsman, { foreignKey: 'exhibitionId', as: 'ExhibitionCraftsmen' });
ExhibitionCraftsman.belongsTo(Exhibition, { foreignKey: 'exhibitionId', as: 'Exhibition' });
ExhibitionCraftsman.belongsTo(User, { foreignKey: 'craftsmanId', as: 'Craftsman' });

module.exports = ExhibitionCraftsman;
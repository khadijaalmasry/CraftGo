const {
  DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const Exhibition = sequelize.define('Exhibition', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  ownerId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id'
    }
  },

  // ── Basic Info ───────────────────────────────────────────────────
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  nameEn: {
    type: DataTypes.STRING,
    allowNull: true
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  descriptionEn: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  location: {
    type: DataTypes.STRING,
    allowNull: false
  },
  locationEn: {
    type: DataTypes.STRING,
    allowNull: true
  },

  // ── Additional metadata ────────────────────────────────────────
  eventType: {
    type: DataTypes.STRING,
    allowNull: true
  },
  eventTheme: {
    type: DataTypes.STRING,
    allowNull: true
  },
  targetAudience: {
    type: DataTypes.STRING,
    allowNull: true
  },
  priceRange: {
    type: DataTypes.STRING,
    allowNull: true
  },
  isPublic: {
    type: DataTypes.BOOLEAN,
    defaultValue: true
  },

  // ── Address parts ──────────────────────────────────────────────
  country: {
    type: DataTypes.STRING,
    allowNull: true
  },
  city: {
    type: DataTypes.STRING,
    allowNull: true
  },
  street: {
    type: DataTypes.STRING,
    allowNull: true
  },
  building: {
    type: DataTypes.STRING,
    allowNull: true
  },
  extraDetails: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  latitude: {
    type: DataTypes.DOUBLE,
    allowNull: true
  },
  longitude: {
    type: DataTypes.DOUBLE,
    allowNull: true
  },
  manualLocation: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },

  // ── Dates & Times ──────────────────────────────────────────────
  startDate: {
    type: DataTypes.DATE,
    allowNull: true
  },
  endDate: {
    type: DataTypes.DATE,
    allowNull: true
  },
  selectedDates: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: []
  }, // [{date, start, end}]

  // ── Crafts ──────────────────────────────────────────────────────
  crafts: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: []
  }, // array of strings

  // ── Booth setup ─────────────────────────────────────────────────
  boothRows: {
    type: DataTypes.INTEGER,
    allowNull: true,
    defaultValue: 2
  },
  boothColumns: {
    type: DataTypes.INTEGER,
    allowNull: true,
    defaultValue: 3
  },
  boothPrice: {
    type: DataTypes.DECIMAL(10, 2),
    allowNull: true,
    defaultValue: 0.00
  },

  // ── Venue verification ──────────────────────────────────────────
  venueType: {
    type: DataTypes.STRING,
    allowNull: true
  },
  permitDocumentUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  hasPermit: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  hasBusinessLicense: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  permitNumber: {
    type: DataTypes.STRING,
    allowNull: true
  },
  issuerName: {
    type: DataTypes.STRING,
    allowNull: true
  },
  issuerPhone: {
    type: DataTypes.STRING,
    allowNull: true
  },
  issueDate: {
    type: DataTypes.DATE,
    allowNull: true
  },
  expiryDate: {
    type: DataTypes.DATE,
    allowNull: true
  },

  verified: {
    type: DataTypes.BOOLEAN,
    allowNull: true
  },

  featured: {
    type: DataTypes.BOOLEAN,
    allowNull: true
  },



  // ── Status & capacity ────────────────────────────────────────────
  status: {
    type: DataTypes.ENUM('upcoming', 'active', 'past', 'pending', 'rejected', 'suspended'),
    defaultValue: 'upcoming'
  },
  capacity: {
    type: DataTypes.INTEGER,
    allowNull: false
  },
  categoryCapacities: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: {}
  },
  isFull: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },

  // ── Booth Layout ─────────────────────────────────────────────────
  boothLayout: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: []
  },

  // ── Image ──────────────────────────────────────────────────────
  imageUrl: {
    type: DataTypes.STRING,
    allowNull: true
  },
  gradient: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: ["#1976D2", "#009688"]
  },
});

// Relationships
User.hasMany(Exhibition, {
  foreignKey: 'ownerId'
});
Exhibition.belongsTo(User, {
  foreignKey: 'ownerId',
  as: 'Owner'
});

module.exports = Exhibition;
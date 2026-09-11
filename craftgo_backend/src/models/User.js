const {
  DataTypes
} = require('sequelize');

const sequelize = require('../config/database');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },

  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },

  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },

  password: {
    type: DataTypes.STRING,
    allowNull: false,
  },

  phone: {
    type: DataTypes.STRING,
  },

  city: {
    type: DataTypes.STRING,
  },

  location: {
    type: DataTypes.STRING,
  },

  bio: {
    type: DataTypes.TEXT,
  },

  bankName: {
    type: DataTypes.STRING,
  },

  accountTitle: {
    type: DataTypes.STRING,
  },

  iban: {
    type: DataTypes.STRING,
  },

  profileImage: {
    type: DataTypes.STRING,
    allowNull: true,
  },

  bannerImage: {
    type: DataTypes.STRING,
    allowNull: true,
  },

  otpCode: {
    type: DataTypes.STRING,
  },

  otpExpiresAt: {
    type: DataTypes.BIGINT,
  },

  adminStaffId: {
    type: DataTypes.STRING,
    allowNull: true,
  },

  isSuspended: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
});

module.exports = User;
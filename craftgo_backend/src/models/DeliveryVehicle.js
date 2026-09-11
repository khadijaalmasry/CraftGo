const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const User = require('./User');

const DeliveryVehicle = sequelize.define('DeliveryVehicle', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  driverId: {
    type: DataTypes.UUID,
    allowNull: false,
    unique: true,
    references: { model: User, key: 'id' },
  },
  make: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'Skoda',
  },
  model: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'Octavia',
  },
  year: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: '2018',
  },
  color: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'أبيض',
  },
  colorEn: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'White',
  },
  licensePlate: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'ABC 1234',
  },
  type: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'سيارة',
  },
  typeEn: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: 'Car',
  },
  capacity: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: '500 كجم',
  },
  capacityEn: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: '500 kg',
  },
  photoUrl: {
    type: DataTypes.STRING,
    allowNull: true,
  },
});

User.hasOne(DeliveryVehicle, { foreignKey: 'driverId', as: 'deliveryVehicle' });
DeliveryVehicle.belongsTo(User, { foreignKey: 'driverId', as: 'driver' });

module.exports = DeliveryVehicle;

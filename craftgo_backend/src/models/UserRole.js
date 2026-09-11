const {
    DataTypes
} = require('sequelize');
const sequelize = require('../config/database');

const UserRole = sequelize.define('UserRole', {
    userId: {
        type: DataTypes.UUID,
        primaryKey: true,
    },
    roleId: {
        type: DataTypes.INTEGER,
        primaryKey: true,
    },
}, {
    timestamps: false,
});

module.exports = UserRole;
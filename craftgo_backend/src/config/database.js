const { Sequelize } = require('sequelize');

const sequelize = new Sequelize({
  dialect: 'sqlite',
  storage: './craftgo.sqlite',
  logging: false, // Set to console.log to see SQL queries
});

module.exports = sequelize;
require('dotenv').config();

const { DataTypes } = require('sequelize');
const sequelize = require('./src/config/database');

async function syncReviewHireColumn() {
  try {
    await sequelize.authenticate();

    const queryInterface = sequelize.getQueryInterface();
    const table = await queryInterface.describeTable('Reviews');

    if (!table.hireRequestId) {
      console.log('Adding Reviews.hireRequestId ...');

      await queryInterface.addColumn('Reviews', 'hireRequestId', {
        type: DataTypes.UUID,
        allowNull: true,
      });

      console.log('Reviews.hireRequestId added successfully.');
    } else {
      console.log('Reviews.hireRequestId already exists.');
    }

    console.log('Review table is ready for Hire / On-Site reviews.');
  } catch (error) {
    console.error('Failed to update Review table:', error);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

syncReviewHireColumn();
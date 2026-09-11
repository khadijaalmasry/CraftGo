const sequelize = require('./src/config/database');

async function run() {
  try {
    await sequelize.authenticate();
    console.log('Database connected.');

    const queryInterface = sequelize.getQueryInterface();

    const table = await queryInterface.describeTable('Reviews');

    if (!table.customOrderRequestId) {
      await queryInterface.addColumn(
        'Reviews',
        'customOrderRequestId',
        {
          type: require('sequelize').DataTypes.UUID,
          allowNull: true,
        }
      );

      console.log('Added column: customOrderRequestId');
    } else {
      console.log('customOrderRequestId already exists.');
    }

    console.log('Review migration completed.');
  } catch (error) {
    console.error('Migration failed:', error);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

run();
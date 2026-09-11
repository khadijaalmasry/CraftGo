const sequelize = require('./src/config/database');

async function addReviewDirectionColumn() {
  try {
    const queryInterface = sequelize.getQueryInterface();

    const table = await queryInterface.describeTable('Reviews');

    if (!table.direction) {
      await queryInterface.addColumn('Reviews', 'direction', {
        type: require('sequelize').DataTypes.STRING,
        allowNull: false,
        defaultValue: 'customer_to_artisan',
      });

      console.log('✅ direction column added to Reviews table');
    } else {
      console.log('ℹ️ direction column already exists');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to add direction column:', error);
    process.exit(1);
  }
}

addReviewDirectionColumn();
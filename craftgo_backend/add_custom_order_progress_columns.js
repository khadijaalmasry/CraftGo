const { DataTypes } = require('sequelize');
const sequelize = require('./src/config/database');

async function addColumnIfMissing(
  queryInterface,
  tableName,
  columnName,
  definition
) {
  const description =
    await queryInterface.describeTable(tableName);

  if (!description[columnName]) {
    await queryInterface.addColumn(
      tableName,
      columnName,
      definition
    );

    console.log(`Added column: ${columnName}`);
  } else {
    console.log(
      `Column already exists: ${columnName}`
    );
  }
}

async function run() {
  try {
    await sequelize.authenticate();

    const queryInterface =
      sequelize.getQueryInterface();

    const tableName = 'CustomOrderRequests';

    await addColumnIfMissing(
      queryInterface,
      tableName,
      'progressStage',
      {
        type: DataTypes.STRING,
        allowNull: true,
      }
    );

    await addColumnIfMissing(
      queryInterface,
      tableName,
      'progressPercent',
      {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0,
      }
    );

    console.log(
      'Custom order progress columns are ready.'
    );
  } catch (error) {
    console.error(
      'Migration failed:',
      error
    );

    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

run();
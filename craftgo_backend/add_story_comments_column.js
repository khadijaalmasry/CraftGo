'use strict';

const sequelize =
  require('./src/config/database');


async function migrate() {
  try {
    await sequelize.authenticate();

    console.log(
      '✅ Database connected',
    );


    const [columns] =
      await sequelize.query(
        'PRAGMA table_info(stories);',
      );


    if (
      !Array.isArray(columns) ||
      columns.length === 0
    ) {
      console.log(
        'ℹ️ stories table does not exist yet.',
      );

      console.log(
        'Start the server once so Sequelize can create it.',
      );

      return;
    }


    const hasComments =
      columns.some(
        (
          column,
        ) =>
          column.name ===
          'comments',
      );


    if (!hasComments) {
      await sequelize.query(
        "ALTER TABLE stories ADD COLUMN comments TEXT NOT NULL DEFAULT '[]';",
      );

      console.log(
        '✅ Added stories.comments column',
      );
    } else {
      console.log(
        '✅ stories.comments already exists',
      );
    }


    console.log(
      '✅ Story interaction migration completed',
    );
  } catch (error) {
    console.error(
      '❌ Story migration failed:',
      error,
    );

    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}


migrate();
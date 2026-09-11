const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'craftgo.sqlite');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
  db.run(
    `ALTER TABLE Orders ADD COLUMN customerPhone TEXT`,
    (error) => {
      if (error) {
        if (error.message.includes('duplicate column name')) {
          console.log('customerPhone column already exists.');
        } else {
          console.error('Failed to add customerPhone column:', error.message);
        }
      } else {
        console.log('customerPhone column added successfully to Orders table.');
      }
    }
  );
});

db.close((error) => {
  if (error) {
    console.error('Failed to close database:', error.message);
  } else {
    console.log('Database update finished.');
  }
});

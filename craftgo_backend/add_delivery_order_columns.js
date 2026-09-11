const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'craftgo.sqlite');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
  db.run(
    `ALTER TABLE DeliveryOrders ADD COLUMN productOrderId TEXT`,
    (error) => {
      if (error) {
        if (error.message.includes('duplicate column name')) {
          console.log('productOrderId column already exists.');
        } else {
          console.error('Failed to add productOrderId column:', error.message);
        }
      } else {
        console.log('productOrderId column added successfully to DeliveryOrders table.');
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

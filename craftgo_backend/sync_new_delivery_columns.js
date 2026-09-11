const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'craftgo.sqlite');
const db = new sqlite3.Database(dbPath);

db.serialize(() => {
  db.run(`ALTER TABLE DeliveryOrders ADD COLUMN relatedOrderIds TEXT`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding relatedOrderIds:', err.message);
    } else {
      console.log('relatedOrderIds column checked/added.');
    }
  });

  db.run(`ALTER TABLE DeliveryOrders ADD COLUMN relatedCustomOrderIds TEXT`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding relatedCustomOrderIds:', err.message);
    } else {
      console.log('relatedCustomOrderIds column checked/added.');
    }
  });

  db.run(`ALTER TABLE DeliveryOrders ADD COLUMN isClearedByArtisan TINYINT DEFAULT 0`, (err) => {
    if (err && !err.message.includes('duplicate column')) {
      console.error('Error adding isClearedByArtisan:', err.message);
    } else {
      console.log('isClearedByArtisan column checked/added.');
    }
  });
});

db.close(() => {
  console.log('Database migration finished.');
});

const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.resolve(process.cwd(), 'craftgo.sqlite');
console.log('Database path:', dbPath);
const db = new sqlite3.Database(dbPath);

db.run(
  'ALTER TABLE Chats ADD COLUMN orderId TEXT',
  (error) => {
    if (error) {
      if (error.message.includes('duplicate column name')) {
        console.log('orderId column already exists.');
      } else {
        console.error('Failed to add orderId:', error.message);
      }
    } else {
      console.log('orderId column added successfully.');
    }

    db.close();
  },
);
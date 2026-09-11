const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'craftgo.sqlite');
const db = new sqlite3.Database(dbPath);

const columns = [
  ['materials', 'TEXT'],
  ['dimensions', 'TEXT'],
  ['colors', 'TEXT'],
  ['isPublic', 'INTEGER DEFAULT 1'],
  ['isAvailable', 'INTEGER DEFAULT 1'],
];

db.serialize(() => {
  columns.forEach(([name, type]) => {
    db.run(
      `ALTER TABLE Products ADD COLUMN ${name} ${type}`,
      (error) => {
        if (error) {
          if (error.message.includes('duplicate column name')) {
            console.log(`${name} already exists.`);
          } else {
            console.error(`Failed to add ${name}:`, error.message);
          }
        } else {
          console.log(`${name} added successfully.`);
        }
      },
    );
  });
});

db.close((error) => {
  if (error) {
    console.error('Failed to close database:', error.message);
  } else {
    console.log('Database update finished.');
  }
});
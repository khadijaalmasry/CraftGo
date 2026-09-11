const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'craftgo.sqlite');
const db = new sqlite3.Database(dbPath);

const columnsToAdd = [
  { name: 'productOrderId', type: 'TEXT' },
  { name: 'deliveryPin', type: 'TEXT' },
  { name: 'qrCodeData', type: 'TEXT' },
  { name: 'customSpecifications', type: 'TEXT' },
  { name: 'issueType', type: 'TEXT' },
  { name: 'issueNotes', type: 'TEXT' },
  { name: 'issuePhotoUrl', type: 'TEXT' },
  { name: 'cancelledBy', type: 'TEXT' },
  { name: 'cancelReason', type: 'TEXT' },
  { name: 'pickupPhone', type: 'TEXT' },
  { name: 'customerPhone', type: 'TEXT' },
  { name: 'orderType', type: 'TEXT' },
];

db.all(`PRAGMA table_info(DeliveryOrders);`, (err, rows) => {
  if (err) {
    console.error('Error fetching table info:', err.message);
    return;
  }
  const existing = new Set(rows.map((r) => r.name));
  let pending = 0;
  
  columnsToAdd.forEach((col) => {
    if (!existing.has(col.name)) {
      pending++;
      db.run(`ALTER TABLE DeliveryOrders ADD COLUMN ${col.name} ${col.type}`, (aErr) => {
        if (aErr) {
          console.error(`Failed to add ${col.name}:`, aErr.message);
        } else {
          console.log(`Added column ${col.name} to DeliveryOrders.`);
        }
        pending--;
        if (pending === 0) db.close();
      });
    } else {
      console.log(`Column ${col.name} already exists.`);
    }
  });

  if (pending === 0) db.close();
});

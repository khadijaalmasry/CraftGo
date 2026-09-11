const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('craftgo.sqlite');

db.all(`
  SELECT r.name 
  FROM UserRoles ur
  JOIN Roles r ON ur.roleId = r.id
  JOIN Users u ON ur.userId = u.id
  WHERE u.email = 'MaramSalmeyeh1@gmail.com'
`, (err, rows) => {
  if (err) console.error(err);
  else console.log(rows);
  db.close();
});

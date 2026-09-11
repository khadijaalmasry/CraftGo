const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('craftgo.sqlite');

// First find the user ID
db.get("SELECT id FROM Users WHERE email='MaramSalmeyeh1@gmail.com'", (err, user) => {
  if (err) return console.error(err);
  if (!user) return console.log('User not found');
  
  // Now update the ArtisanProfile
  db.run("UPDATE ArtisanProfiles SET isVerified = 1 WHERE userId = ?", [user.id], function(err) {
    if (err) return console.error(err);
    console.log(`Updated ${this.changes} row(s). Account approved!`);
    db.close();
  });
});

const sequelize = require('./src/config/database');
const User = require('./src/models/User');
const Role = require('./src/models/Role');
const UserRole = require('./src/models/UserRole');
const ArtisanProfile = require('./src/models/ArtisanProfile');
const PortfolioItem = require('./src/models/PortfolioItem');
const Review = require('./src/models/Review');
const Product = require('./src/models/Product');
const Exhibition = require('./src/models/Exhibition');
const ExhibitionCraftsman = require('./src/models/ExhibitionCraftsman');
const Order = require('./src/models/Order');
const Chat = require('./src/models/Chat');
const Message = require('./src/models/Message');
const UserInteraction = require('./src/models/UserInteraction');
const DeliveryProfile = require('./src/models/DeliveryProfile');
const DeliveryVehicle = require('./src/models/DeliveryVehicle');
const DeliveryOrder = require('./src/models/DeliveryOrder');
const DeliveryIssue = require('./src/models/DeliveryIssue');
const ExhibitionDayAttendance = require('./src/models/ExhibitionDayAttendance');
const bcrypt = require('bcryptjs');

async function seedExhibitionAndDelivery() {
  try {
    console.log('🔄 Syncing database tables safely...');
    await sequelize.sync();
    
    // Safely ensure missing columns in sqlite without throwing
    const safeAddColumn = async (table, col, type) => {
      try {
        await sequelize.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${col}\` ${type};`);
      } catch (_) {}
    };
    await safeAddColumn('DeliveryProfiles', 'verificationStatus', 'VARCHAR(255) DEFAULT "verified"');
    await safeAddColumn('DeliveryProfiles', 'isSuspended', 'TINYINT(1) DEFAULT 0');
    await safeAddColumn('DeliveryProfiles', 'idCardUrl', 'VARCHAR(255)');
    await safeAddColumn('DeliveryProfiles', 'facePhotoUrl', 'VARCHAR(255)');
    await safeAddColumn('DeliveryProfiles', 'permitUrl', 'VARCHAR(255)');

    // Safe column additions for Exhibitions table
    const exCols = [
      ['nameEn', 'VARCHAR(255)'], ['descriptionEn', 'TEXT'], ['locationEn', 'VARCHAR(255)'],
      ['eventType', 'VARCHAR(255)'], ['eventTheme', 'VARCHAR(255)'], ['targetAudience', 'VARCHAR(255)'], ['priceRange', 'VARCHAR(255)'],
      ['isPublic', 'TINYINT(1) DEFAULT 1'], ['country', 'VARCHAR(255)'], ['city', 'VARCHAR(255)'], ['street', 'VARCHAR(255)'], ['building', 'VARCHAR(255)'],
      ['extraDetails', 'TEXT'], ['latitude', 'FLOAT'], ['longitude', 'FLOAT'],
      ['manualLocation', 'VARCHAR(255)'], ['startDate', 'VARCHAR(255)'], ['endDate', 'VARCHAR(255)'],
      ['selectedDates', 'TEXT'], ['crafts', 'TEXT'],
      ['boothRows', 'INTEGER DEFAULT 4'], ['boothColumns', 'INTEGER DEFAULT 5'], ['boothPrice', 'DECIMAL(10,2) DEFAULT 50.00'],
      ['venueType', 'VARCHAR(255)'], ['permitDocumentUrl', 'VARCHAR(255)'], ['hasPermit', 'TINYINT(1) DEFAULT 0'],
      ['hasBusinessLicense', 'TINYINT(1) DEFAULT 0'], ['permitNumber', 'VARCHAR(255)'], ['issuerName', 'VARCHAR(255)'],
      ['issuerPhone', 'VARCHAR(255)'], ['issueDate', 'VARCHAR(255)'], ['expiryDate', 'VARCHAR(255)'],
      ['verified', 'TINYINT(1) DEFAULT 1'], ['featured', 'TINYINT(1) DEFAULT 1'], ['status', 'VARCHAR(255) DEFAULT "upcoming"'],
      ['capacity', 'INTEGER DEFAULT 1000'], ['categoryCapacities', 'TEXT'], ['isFull', 'TINYINT(1) DEFAULT 0'],
      ['boothLayout', 'TEXT'], ['imageUrl', 'VARCHAR(255)'], ['gradient', 'VARCHAR(255)']
    ];
    for (const [col, type] of exCols) {
      await safeAddColumn('Exhibitions', col, type);
    }
    console.log('✅ Table sync & column safety complete.');

    const hashedPassword = await bcrypt.hash('123456', 10);

    // ── 1. Ensure Roles ───────────────────────────────────────────────────
    console.log('🔑 Ensuring roles exist...');
    const rolesToEnsure = ['customer', 'artisan', 'exhibition_owner', 'admin', 'delivery'];
    const roleMap = {};
    for (const rName of rolesToEnsure) {
      let role = await Role.findOne({ where: { name: rName } });
      if (!role) {
        role = await Role.create({ name: rName });
        console.log(`  + Created role: ${rName}`);
      }
      roleMap[rName] = role;
    }

    // ── 2. Ensure Delivery User ───────────────────────────────────────────
    let deliveryUser = await User.findOne({ where: { email: 'delivery@craftgo.com' } });
    if (!deliveryUser) {
      console.log('👤 Creating sample delivery driver user...');
      deliveryUser = await User.create({
        name: 'Sami Sweidan',
        email: 'delivery@craftgo.com',
        password: hashedPassword,
        city: 'Ramallah',
        phone: '0599000111',
      });
      await UserRole.create({ userId: deliveryUser.id, roleId: roleMap.delivery.id });
    }

    // ── 3. Ensure Delivery Profile & Vehicle ──────────────────────────────
    let deliveryProfile = await DeliveryProfile.findOne({ where: { driverId: deliveryUser.id } });
    if (!deliveryProfile) {
      console.log('🚚 Creating delivery profile & vehicle...');
      deliveryProfile = await DeliveryProfile.create({
        driverId: deliveryUser.id,
        isVerified: true,
        verificationStatus: 'verified',
        isOnline: true,
        rating: 4.8,
        totalDeliveries: 42,
        todayEarnings: 35.0,
      });

      await DeliveryVehicle.create({
        driverId: deliveryUser.id,
        deliveryProfileId: deliveryProfile.id,
        vehicleType: 'Car',
        make: 'Hyundai',
        model: 'Elantra',
        year: 2021,
        licensePlate: '7-1234-99',
        isVerified: true,
      });
    }

    // ── 4. Ensure Exhibition Owner & Exhibition ───────────────────────────
    let exhibitionOwner = await User.findOne({ where: { email: 'exhibition@craftgo.com' } });
    if (!exhibitionOwner) {
      console.log('🏛️ Creating exhibition owner user...');
      exhibitionOwner = await User.create({
        name: 'Beit Jala Arts Center',
        email: 'exhibition@craftgo.com',
        password: hashedPassword,
        city: 'Bethlehem',
        phone: '0599111222',
      });
      await UserRole.create({ userId: exhibitionOwner.id, roleId: roleMap.exhibition_owner.id });
    }

    let sampleExhibition = await Exhibition.findOne({ where: { ownerId: exhibitionOwner.id } });
    if (!sampleExhibition) {
      console.log('🎪 Creating sample exhibition...');
      sampleExhibition = await Exhibition.create({
        ownerId: exhibitionOwner.id,
        name: 'معرض الحرف التراثية الفلسطينية',
        nameEn: 'Palestinian Heritage Crafts Exhibition',
        description: 'معرض سنوي يجمع أفضل الحرفيين التراثيين لعرض المنتجات الخشبية والمطرزات والفخار.',
        descriptionEn: 'Annual exhibition showcasing the finest Palestinian heritage artisans.',
        location: 'مركز بيت جالا الثقافي، بيت لحم',
        locationEn: 'Beit Jala Cultural Center, Bethlehem',
        eventType: 'Heritage & Craft',
        isPublic: true,
        city: 'Bethlehem',
        startDate: new Date(Date.now() + 86400000 * 3).toISOString().split('T')[0],
        endDate: new Date(Date.now() + 86400000 * 7).toISOString().split('T')[0],
        boothRows: 4,
        boothColumns: 5,
        boothPrice: 50.0,
        venueType: 'Indoor Hall',
        capacity: 1000,
        status: 'upcoming',
        verified: true,
        featured: true,
        boothLayout: Array.from({ length: 20 }, (_, i) => ({
          id: `booth_${i + 1}`,
          number: i + 1,
          row: Math.floor(i / 5) + 1,
          col: (i % 5) + 1,
          price: 50.0,
          status: i < 3 ? 'booked' : 'available',
        })),
      });
    }

    console.log('🎉 Safe incremental database seeding completed successfully!');
  } catch (error) {
    console.error('❌ Error in safe seeding:', error);
  }
}

seedExhibitionAndDelivery();

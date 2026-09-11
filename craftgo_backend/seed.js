const sequelize = require('./src/config/database');
const User = require('./src/models/User');
const Role = require('./src/models/Role');
const UserRole = require('./src/models/UserRole');
const Product = require('./src/models/Product');
const Exhibition = require('./src/models/Exhibition');
const ExhibitionCraftsman = require('./src/models/ExhibitionCraftsman');
const Order = require('./src/models/Order');
const Chat = require('./src/models/Chat');
const Message = require('./src/models/Message');
const UserInteraction = require('./src/models/UserInteraction');
const ArtisanProfile = require('./src/models/ArtisanProfile'); // NEW
const PortfolioItem = require('./src/models/PortfolioItem'); // NEW
const Review = require('./src/models/Review'); // NEW
const bcrypt = require('bcryptjs');

async function seedDatabase() {
  try {
    console.log('🔄 Syncing database tables...');
    await sequelize.sync({
      force: true
    });

    const hashedPassword = await bcrypt.hash('123456', 10);

    // ── 1. Create Roles ─────────────────────────────────────────────────────
    console.log('🔑 Creating roles...');
    const [customerRole, artisanRole, exhibitionOwnerRole, adminRole] = await Promise.all([
      Role.create({
        name: 'customer'
      }),
      Role.create({
        name: 'artisan'
      }),
      Role.create({
        name: 'exhibition_owner'
      }),
      Role.create({
        name: 'admin'
      }),
    ]);

    // ── 2. Create Users ────────────────────────────────────────────────────
    console.log('👤 Seeding Users...');

    const admin = await User.create({
      name: 'Admin User',
      email: 'admin@craftgo.com',
      password: hashedPassword,
      city: 'Ramallah',
    });

    const craftsman1 = await User.create({
      name: 'Ahmad Al-Khateeb',
      email: 'craftsman@craftgo.com',
      password: hashedPassword,
      city: 'Nablus',
    });

    const craftsman2 = await User.create({
      name: 'Salma Haddad',
      email: 'salma@craftgo.com',
      password: hashedPassword,
      city: 'Hebron',
    });

    const craftsman3 = await User.create({
      name: 'Rami Qasim',
      email: 'rami@craftgo.com',
      password: hashedPassword,
      city: 'Ramallah',
    });

    const craftsman4 = await User.create({
      name: 'Fatima Barakat',
      email: 'fatima@craftgo.com',
      password: hashedPassword,
      city: 'Bethlehem',
    });

    const customer = await User.create({
      name: 'Tariq Al-Nabulsi',
      email: 'customer@craftgo.com',
      password: hashedPassword,
      city: 'Jerusalem',
    });

    const delivery = await User.create({
      name: 'Sami Sweidan',
      email: 'delivery@craftgo.com',
      password: hashedPassword,
      city: 'Ramallah',
    });

    const exhibitionOwner = await User.create({
      name: 'Beit Jala Arts Center',
      email: 'exhibition@craftgo.com',
      password: hashedPassword,
      city: 'Bethlehem',
    });

    // ── 3. Assign Roles ────────────────────────────────────────────────────
    console.log('📝 Assigning roles...');

    await UserRole.bulkCreate([{
        userId: admin.id,
        roleId: adminRole.id
      },
      {
        userId: admin.id,
        roleId: customerRole.id
      },
    ]);

    for (const craftUser of [craftsman1, craftsman2, craftsman3, craftsman4]) {
      await UserRole.bulkCreate([{
          userId: craftUser.id,
          roleId: artisanRole.id
        },
        {
          userId: craftUser.id,
          roleId: customerRole.id
        },
      ]);
    }

    await UserRole.create({
      userId: customer.id,
      roleId: customerRole.id
    });
    await UserRole.create({
      userId: delivery.id,
      roleId: customerRole.id
    });
    await UserRole.bulkCreate([{
        userId: exhibitionOwner.id,
        roleId: exhibitionOwnerRole.id
      },
      {
        userId: exhibitionOwner.id,
        roleId: customerRole.id
      },
    ]);

    // ── 4. Create Artisan Profiles ────────────────────────────────────────
    console.log('🎨 Creating artisan profiles...');

    // Craftsman 1: Ahmad – Pottery & Ceramics
    const profile1 = await ArtisanProfile.create({
      userId: craftsman1.id,
      bio: 'خبير في صناعة الفخار والخزف اليدوي بتقنيات تقليدية وفنية عالية. أقدم قطعاً فريدة تجمع بين الأصالة والجودة.',
      bioEn: 'Expert in traditional and artistic pottery and ceramics. I offer unique pieces that combine authenticity and quality.',
      experienceYears: 12,
      primaryCategory: 'Pottery & Ceramics',
      additionalCategories: ['Sculpture', 'Tile Making'],
      isVerified: true,
      trustedHands: true,
      priceRange: '50-300',
      specializations: ['Hand-thrown pottery', 'Glaze techniques', 'Kiln firing'],
    });

    // Craftsman 2: Salma – Woodworking
    const profile2 = await ArtisanProfile.create({
      userId: craftsman2.id,
      bio: 'حرفي متخصص في الأعمال الخشبية الدقيقة، من الأثاث الكلاسيكي إلى التحف الفنية. استخدم أخشاب الزيتون والجوز المحلية.',
      bioEn: 'Craftsman specializing in fine woodworking, from classic furniture to artistic pieces. I use local olive and walnut wood.',
      experienceYears: 8,
      primaryCategory: 'Woodworking',
      additionalCategories: ['Furniture', 'Sculpture'],
      isVerified: true,
      trustedHands: false,
      priceRange: '100-500',
      specializations: ['Olive wood carving', 'Inlay work', 'Custom furniture'],
    });

    // Craftsman 3: Rami – Jewelry & Accessories
    const profile3 = await ArtisanProfile.create({
      userId: craftsman3.id,
      bio: 'مصمم مجوهرات محترف، أعمل بالفضة والذهب والخرز التقليدي. أقدم تصاميم عصرية مستوحاة من التراث الفلسطيني.',
      bioEn: 'Professional jewelry designer working with silver, gold, and traditional beads. I offer modern designs inspired by Palestinian heritage.',
      experienceYears: 6,
      primaryCategory: 'Jewelry & Accessories',
      additionalCategories: ['Beadwork', 'Metal Smithing'],
      isVerified: true,
      trustedHands: false,
      priceRange: '30-450',
      specializations: ['Silver smithing', 'Bead weaving', 'Custom rings'],
    });

    // Craftsman 4: Fatima – Crochet & Knitting (standby)
    const profile4 = await ArtisanProfile.create({
      userId: craftsman4.id,
      bio: 'أخصائية في الكروشيه والتريكو، أصنع قطعاً فريدة من الملابس والإكسسوارات والحُلى المنزلية. كل قطعة مصنوعة بعناية وحب.',
      bioEn: 'Crochet and knitting specialist, creating unique clothing, accessories, and home decor. Each piece is made with care and love.',
      experienceYears: 5,
      primaryCategory: 'Crochet & Knitting',
      additionalCategories: ['Accessories', 'Home Decor'],
      isVerified: false,
      trustedHands: false,
      priceRange: '20-150',
      specializations: ['Crochet garments', 'Amigurumi', 'Knitted blankets'],
    });

    // ── 5. Portfolio Items ────────────────────────────────────────────────
    console.log('🖼️ Adding portfolio items...');

    // Ahmad's portfolio (pottery)
    await PortfolioItem.create({
      artisanProfileId: profile1.id,
      titleAr: 'مزهرية فخار مطعمة بالزجاج',
      titleEn: 'Glass-inlaid Clay Vase',
      descriptionAr: 'مزهرية فخار يدوية مطعمة بقطع زجاجية ملونة، تم حرقها في فرن تقليدي بدرجة حرارة عالية.',
      descriptionEn: 'Handmade clay vase inlaid with colorful glass pieces, fired in a traditional kiln at high temperature.',
      imageUrl: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=500',
    });

    await PortfolioItem.create({
      artisanProfileId: profile1.id,
      titleAr: 'طبق فخار بخزف مزخرف',
      titleEn: 'Decorative Ceramic Plate',
      descriptionAr: 'طبق خزفي مزخرف بنقوش فلسطينية تقليدية. مناسب للاستخدام اليومي أو للعرض.',
      descriptionEn: 'Ceramic plate decorated with traditional Palestinian patterns. Suitable for daily use or display.',
      imageUrl: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=500',
    });

    // Salma's portfolio (woodworking)
    await PortfolioItem.create({
      artisanProfileId: profile2.id,
      titleAr: 'تحفة خشب زيتون منحوتة يدوياً',
      titleEn: 'Hand-carved Olive Wood Sculpture',
      descriptionAr: 'منحوتة فنية من خشب الزيتون المستخرج من أراضي فلسطين، تم تشكيلها يدوياً بأدوات تقليدية.',
      descriptionEn: 'Artistic sculpture from olive wood sourced from Palestinian lands, hand-shaped using traditional tools.',
      imageUrl: 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=500',
    });

    await PortfolioItem.create({
      artisanProfileId: profile2.id,
      titleAr: 'طاولة قهوة عثمانية من الجوز',
      titleEn: 'Ottoman Walnut Coffee Table',
      descriptionAr: 'طاولة قهوة مصممة على الطراز العثماني، مصنوعة من خشب الجوز الطبيعي مع تفاصيل دقيقة.',
      descriptionEn: 'Coffee table designed in Ottoman style, made from natural walnut wood with fine details.',
      imageUrl: 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=500',
    });

    // Rami's portfolio (jewelry)
    await PortfolioItem.create({
      artisanProfileId: profile3.id,
      titleAr: 'عقد فضة بحجر عقيق طبيعي',
      titleEn: 'Silver Necklace with Natural Agate',
      descriptionAr: 'عقد من الفضة عيار 925 مع حجر عقيق طبيعي، تصميم عصري مستوحى من الجمال الطبيعي.',
      descriptionEn: '925 silver necklace with natural agate stone, modern design inspired by natural beauty.',
      imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=500',
    });

    await PortfolioItem.create({
      artisanProfileId: profile3.id,
      titleAr: 'سوار خرز فلسطيني تقليدي',
      titleEn: 'Traditional Palestinian Bead Bracelet',
      descriptionAr: 'سوار مصنوع يدوياً من الخرز الملون بتصميم تقليدي يمثل التراث الفلسطيني.',
      descriptionEn: 'Handmade bracelet from colorful beads with a traditional design representing Palestinian heritage.',
      imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=500',
    });

    // Fatima's portfolio (crochet)
    await PortfolioItem.create({
      artisanProfileId: profile4.id,
      titleAr: 'بطانية كروشيه صوفية دافئة',
      titleEn: 'Warm Crochet Wool Blanket',
      descriptionAr: 'بطانية صوفية كروشيه مصنوعة يدوياً من صوف طبيعي، دافئة ومثالية لأيام الشتاء.',
      descriptionEn: 'Handmade wool crochet blanket from natural wool, warm and perfect for winter days.',
      imageUrl: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=500',
    });

    // ── 6. Reviews ──────────────────────────────────────────────────────────
    console.log('⭐ Seeding reviews...');

    // Reviews for Ahmad (craftsman1)
    await Review.create({
      artisanId: craftsman1.id,
      customerId: customer.id,
      orderId: null, // not linked to specific order
      rating: 5,
      commentAr: 'أفضل حرفي فخار في المنطقة! عمل رائع وجودة عالية جداً.',
      commentEn: 'Best pottery artisan in the region! Excellent work and very high quality.',
    });

    await Review.create({
      artisanId: craftsman1.id,
      customerId: customer.id,
      orderId: null,
      rating: 4,
      commentAr: 'جيد جداً، لكن كان يحتاج إلى وقت أطول قليلاً.',
      commentEn: 'Very good, but took a bit longer than expected.',
    });

    // Reviews for Salma (craftsman2)
    await Review.create({
      artisanId: craftsman2.id,
      customerId: customer.id,
      orderId: null,
      rating: 5,
      commentAr: 'قطعة خشبية رائعة جداً، تفاصيل دقيقة وجودة ممتازة.',
      commentEn: 'Amazing wooden piece, fine details and excellent quality.',
    });

    await Review.create({
      artisanId: craftsman2.id,
      customerId: customer.id,
      orderId: null,
      rating: 5,
      commentAr: 'تعامل راقٍ جداً، أنصح به بشدة.',
      commentEn: 'Very professional dealing, highly recommended.',
    });

    // Reviews for Rami (craftsman3)
    await Review.create({
      artisanId: craftsman3.id,
      customerId: customer.id,
      orderId: null,
      rating: 4,
      commentAr: 'تصميم جميل، لكن السعر مرتفع قليلاً.',
      commentEn: 'Beautiful design, but a bit pricey.',
    });

    await Review.create({
      artisanId: craftsman3.id,
      customerId: customer.id,
      orderId: null,
      rating: 5,
      commentAr: 'أفضل صائغ فضة في رام الله، عمل مذهل!',
      commentEn: 'Best silversmith in Ramallah, amazing work!',
    });

    // Reviews for Fatima (craftsman4)
    await Review.create({
      artisanId: craftsman4.id,
      customerId: customer.id,
      orderId: null,
      rating: 5,
      commentAr: 'بطانية الكروشيه دافئة جداً، شكراً فاطمة!',
      commentEn: 'The crochet blanket is so warm, thank you Fatima!',
    });

    await Review.create({
      artisanId: craftsman4.id,
      customerId: customer.id,
      orderId: null,
      rating: 4,
      commentAr: 'جيد جداً، لكن التسليم تأخر قليلاً.',
      commentEn: 'Very good, but delivery was a bit late.',
    });

    // ── Products ──────────────────────────────────────────────────────────────
    console.log('🛍️  Seeding Products...');

    const product1 = await Product.create({
      titleAr: 'مزهرية فخار يدوية',
      titleEn: 'Handcrafted Clay Vase',
      description: 'Traditional Palestinian clay vase crafted with natural pottery techniques. Glazed with earthy olive-green tones.',
      price: 120.00,
      category: 'Pottery & Ceramics',
      imageUrl: 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=500',
      craftsmanId: craftsman1.id,
    });

    const product2 = await Product.create({
      titleAr: 'تحفة خشب زيتون',
      titleEn: 'Olive Wood Sculpture',
      description: 'Carved from authentic West Bank olive tree branches. Each piece is unique.',
      price: 250.00,
      category: 'Woodworking',
      imageUrl: 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=500',
      craftsmanId: craftsman2.id,
    });

    const product3 = await Product.create({
      titleAr: 'عقد خرز تقليدي',
      titleEn: 'Traditional Beaded Necklace',
      description: 'Handmade beaded necklace with Palestinian geometric patterns in blue and white.',
      price: 85.00,
      category: 'Jewelry & Accessories',
      imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=500',
      craftsmanId: craftsman3.id,
    });

    // ── Exhibitions ──────────────────────────────────────────────────────────
    console.log('🎪 Seeding Exhibitions...');

    const exhibition1 = await Exhibition.create({
      name: 'Heritage & Craft Expo 2026',
      description: 'Annual fair bringing together top traditional artisans from across Palestine. Celebrate the rich heritage of Palestinian handicrafts with pottery, weaving, woodwork, and more.',
      location: 'Bethlehem Cultural Hall',
      startDate: new Date('2026-08-10'),
      endDate: new Date('2026-08-15'),
      ownerId: exhibitionOwner.id,
      capacity: 3,
      categoryCapacities: {
        'Pottery & Ceramics': 2,
        'Jewelry & Accessories': 1
      },
      status: 'upcoming',
      boothLayout: [{
          id: 'A1',
          price: 25.00,
          description: 'Main hall corner — highest foot traffic'
        },
        {
          id: 'A2',
          price: 25.00,
          description: 'Main hall center'
        },
        {
          id: 'B1',
          price: 20.00,
          description: 'Side wing — medium traffic'
        },
        {
          id: 'B2',
          price: 20.00,
          description: 'Side wing'
        },
        {
          id: 'C1',
          price: 15.00,
          description: 'Outdoor area'
        },
      ],
      isFull: false,
    });

    const exhibition2 = await Exhibition.create({
      name: 'Jerusalem Artisan Market 2026',
      description: 'Exclusive artisan market in the heart of Jerusalem. Limited booths for a curated experience. Features Palestinian embroidery, ceramics, and olive wood works.',
      location: 'Jerusalem Arts Center, Old City',
      startDate: new Date('2026-09-05'),
      endDate: new Date('2026-09-07'),
      ownerId: exhibitionOwner.id,
      capacity: 2,
      status: 'upcoming',
      boothLayout: [{
          id: 'P1',
          price: 35.00,
          description: 'Premium center booth'
        },
        {
          id: 'P2',
          price: 30.00,
          description: 'Corner booth'
        },
      ],
      isFull: true,
    });

    const exhibition3 = await Exhibition.create({
      name: 'Nablus Summer Craft Fair',
      description: 'Showcasing the finest crafts from the Nablus region. Pottery, soap, and traditional Palestinian food products.',
      location: 'Nablus City Park',
      startDate: new Date('2026-07-20'),
      endDate: new Date('2026-07-30'),
      ownerId: exhibitionOwner.id,
      capacity: 10,
      status: 'active',
      boothLayout: [],
      isFull: false,
    });

    // ── Exhibition Craftsman Registrations ──────────────────────────────────
    console.log('📝 Seeding Exhibition Registrations...');

    await ExhibitionCraftsman.create({
      exhibitionId: exhibition1.id,
      craftsmanId: craftsman1.id,
      craftCategory: 'Pottery & Ceramics',
      boothId: 'A1',
      boothPrice: 25.00,
      hasPaid: true,
      paymentReference: 'TXN-88110001',
      status: 'confirmed',
    });

    await ExhibitionCraftsman.create({
      exhibitionId: exhibition1.id,
      craftsmanId: craftsman2.id,
      craftCategory: 'Woodworking',
      boothId: 'A2',
      boothPrice: 25.00,
      hasPaid: true,
      paymentReference: 'TXN-88110002',
      status: 'confirmed',
    });

    await ExhibitionCraftsman.create({
      exhibitionId: exhibition1.id,
      craftsmanId: craftsman3.id,
      craftCategory: 'Jewelry & Accessories',
      boothId: null,
      boothPrice: null,
      hasPaid: false,
      status: 'standby',
      standbyRank: 1,
    });

    await ExhibitionCraftsman.create({
      exhibitionId: exhibition2.id,
      craftsmanId: craftsman1.id,
      craftCategory: 'Pottery & Ceramics',
      boothId: 'P1',
      boothPrice: 35.00,
      hasPaid: true,
      paymentReference: 'TXN-77220001',
      status: 'confirmed',
    });

    await ExhibitionCraftsman.create({
      exhibitionId: exhibition2.id,
      craftsmanId: craftsman2.id,
      craftCategory: 'Woodworking',
      boothId: 'P2',
      boothPrice: 30.00,
      hasPaid: true,
      paymentReference: 'TXN-77220002',
      status: 'confirmed',
    });

    await ExhibitionCraftsman.create({
      exhibitionId: exhibition2.id,
      craftsmanId: craftsman4.id,
      craftCategory: 'Jewelry & Accessories',
      boothId: null,
      boothPrice: null,
      hasPaid: false,
      status: 'standby',
      standbyRank: 1,
    });

    await ExhibitionCraftsman.create({
      exhibitionId: exhibition3.id,
      craftsmanId: craftsman1.id,
      craftCategory: 'Pottery & Ceramics',
      boothId: null,
      boothPrice: null,
      hasPaid: false,
      status: 'confirmed',
    });

    // ── Orders ───────────────────────────────────────────────────────────────
    console.log('📦 Seeding Orders...');

    await Order.create({
      customerId: customer.id,
      craftsmanId: craftsman1.id,
      productId: product1.id,
      totalAmount: 120.00,
      status: 'pending',
      shippingAddress: 'Old City, Jerusalem',
    });

    await Order.create({
      customerId: customer.id,
      craftsmanId: craftsman2.id,
      productId: product2.id,
      totalAmount: 250.00,
      status: 'processing',
      shippingAddress: 'Ramallah, West Bank',
    });

    await Order.create({
      customerId: customer.id,
      craftsmanId: craftsman1.id,
      productId: product1.id,
      totalAmount: 120.00,
      status: 'completed',
      shippingAddress: 'Old City, Jerusalem',
    });

    await Order.create({
      customerId: customer.id,
      craftsmanId: craftsman2.id,
      productId: product2.id,
      totalAmount: 250.00,
      status: 'completed',
      shippingAddress: 'Ramallah, West Bank',
    });

    // ── Chats & Messages ────────────────────────────────────────────────
    console.log('💬 Seeding Chats & Messages...');

    const chat = await Chat.create({
      customerId: customer.id,
      craftsmanId: craftsman1.id,
      lastMessage: 'Hello, is this clay vase available for custom color requests?',
    });

    await Message.create({
      chatId: chat.id,
      senderId: customer.id,
      content: 'Hello, is this clay vase available for custom color requests?',
    });

    await Message.create({
      chatId: chat.id,
      senderId: craftsman1.id,
      content: 'Welcome! Yes, I can customize the glaze color for you. What color do you have in mind?',
    });

    // ── User Interactions ───────────────────────────────────────────────
    console.log('👁️  Seeding User Interactions...');

    await UserInteraction.create({
      userId: customer.id,
      productId: product1.id,
      interactionType: 'view',
      score: 1,
    });

    await UserInteraction.create({
      userId: customer.id,
      productId: product2.id,
      interactionType: 'view',
      score: 1,
    });

    await UserInteraction.create({
      userId: customer.id,
      productId: product1.id,
      interactionType: 'like',
      score: 2,
    });

    await UserInteraction.create({
      userId: customer.id,
      productId: product1.id,
      interactionType: 'view',
      score: 1,
    });

    await UserInteraction.create({
      userId: customer.id,
      productId: product1.id,
      interactionType: 'view',
      score: 1,
    });

    await UserInteraction.create({
      userId: customer.id,
      productId: product1.id,
      interactionType: 'like',
      score: 2,
    });

    // ── Done ─────────────────────────────────────────────────────────────────
    console.log('\n✅ ALL TABLES SEEDED SUCCESSFULLY!');
    console.log('\n─────────────────────────────────────────────────────────────');
    console.log('  Test Credentials (Password: 123456)');
    console.log('─────────────────────────────────────────────────────────────');
    console.log('  Craftsman 1:      craftsman@craftgo.com   (Ahmad)  → roles: customer, artisan');
    console.log('  Craftsman 2:      salma@craftgo.com       (Salma)  → roles: customer, artisan');
    console.log('  Craftsman 3:      rami@craftgo.com        (Rami)   → roles: customer, artisan');
    console.log('  Craftsman 4:      fatima@craftgo.com      (Fatima) → roles: customer, artisan');
    console.log('  Customer:         customer@craftgo.com              → roles: customer');
    console.log('  Exhibition Owner: exhibition@craftgo.com            → roles: customer, exhibition_owner');
    console.log('  Admin:            admin@craftgo.com                 → roles: customer, admin');
    console.log('─────────────────────────────────────────────────────────────');
    console.log('\n  Artisan Profiles:');
    console.log('  • Ahmad:   Pottery & Ceramics (verified, trusted)');
    console.log('  • Salma:   Woodworking (verified)');
    console.log('  • Rami:    Jewelry & Accessories (verified)');
    console.log('  • Fatima:  Crochet & Knitting (pending verification)');
    console.log('\n  Portfolio Items: 2 per artisan (total 8)');
    console.log('  Reviews: 8 reviews across all artisans');
    console.log('─────────────────────────────────────────────────────────────');
    console.log('\n  Exhibition Test Scenarios:');
    console.log('  • Exhibition 1 (Heritage Expo): 2/3 full, craftsman3 on standby');
    console.log('  • Exhibition 2 (Jerusalem Market): 2/2 FULL, fatima on standby');
    console.log('    → Log in as craftsman1, report absence on Exhibition 2');
    console.log('      → Fatima auto-promotes to confirmed!');
    console.log('  • Exhibition 3 (Nablus Fair): active, craftsman1 attending');
    console.log('─────────────────────────────────────────────────────────────\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error during database seed:', error);
    process.exit(1);
  }
}

seedDatabase();
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const sequelize = require('./src/config/database');
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');
const http = require('http');
const {
  Server
} = require('socket.io');
const jwt = require('jsonwebtoken');

// Models
const User = require('./src/models/User');
const Exhibition = require('./src/models/Exhibition');
const ExhibitionCraftsman =
  require('./src/models/ExhibitionCraftsman');
const Product = require('./src/models/Product');
const Order = require('./src/models/Order');
const Chat = require('./src/models/Chat');
const Message = require('./src/models/Message');
const Notification = require('./src/models/Notification');
const UserInteraction =
  require('./src/models/UserInteraction');
const Role = require('./src/models/Role');
const UserRole = require('./src/models/UserRole');
const ArtisanProfile =
  require('./src/models/ArtisanProfile');
const PortfolioItem =
  require('./src/models/PortfolioItem');
const Review = require('./src/models/Review');
const CustomOrderTemplate =
  require('./src/models/CustomOrderTemplate');
const CustomOrderRequest =
  require('./src/models/CustomOrderRequest');
const Story = require('./src/models/Story');
const DeliveryOrder =
  require('./src/models/DeliveryOrder');
const DeliveryProfile =
  require('./src/models/DeliveryProfile');
const DeliveryVehicle =
  require('./src/models/DeliveryVehicle');
const ExhibitionDayAttendance =
  require('./src/models/ExhibitionDayAttendance');
const HireRequest =
  require('./src/models/HireRequest');
const PaymentTransaction =
  require('./src/models/PaymentTransaction');
const OrderDispute =
  require('./src/models/OrderDispute');
const Payout = require('./src/models/Payout');
// Routes loaded early
const adminRoutes =
  require('./src/routes/adminRoutes');
const uploadRoutes =
  require('./src/routes/uploadRoutes');
const notificationRoutes =
  require('./src/routes/notificationRoutes');

// Load environment variables
dotenv.config();

const JWT_SECRET =
  (
    process.env.JWT_SECRET ||
    'super_secret_key_craftgo'
  ).trim();

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Make Socket.io available to controllers
app.set('io', io);

app.use(cors());

// Stripe needs the original raw body to verify webhook signatures.
// This route must be registered BEFORE express.json().
const paymentController =
  require('./src/controllers/paymentController');

// Keep both webhook URLs so an older Stripe Workbench
// configuration continues working during the demo.
app.post(
  [
    '/api/payments/webhook',
    '/api/payments/stripe/webhook'
  ],
  express.raw({
    type: 'application/json'
  }),
  paymentController.stripeWebhook
);

app.use(
  express.json({
    limit: '15mb'
  })
);

app.use(
  express.urlencoded({
    extended: true,
    limit: '15mb'
  })
);

// Serve uploaded images
const path = require('path');

app.use(
  '/uploads',
  express.static(
    path.join(__dirname, 'uploads')
  )
);


const swaggerOptions = {
  definition: {
    openapi: '3.0.0',

    info: {
      title: 'CraftGo API',
      version: '1.0.0',
      description: 'API Documentation for CraftGo Backend',
    },

    servers: [{
      url: 'http://localhost:5000',
      url: 'http://10.171.233.229:5000',
    }, ],
  },

  apis: [
    './src/routes/*.js'
  ],
};

const swaggerDocs =
  swaggerJsdoc(swaggerOptions);

app.use(
  '/api-docs',
  swaggerUi.serve,
  swaggerUi.setup(swaggerDocs)
);

// route imports
const authRoutes =
  require('./src/routes/authRoutes');

const hireOrderRoutes =
  require('./src/routes/hireOrderRoutes');

const paymentRoutes =
  require('./src/routes/paymentRoutes');

const exhibitionRoutes =
  require('./src/routes/exhibitionRoutes');

const aiRoutes =
  require('./src/routes/aiRoutes');

const productRoutes =
  require('./src/routes/productRoutes');

const orderRoutes =
  require('./src/routes/orderRoutes');

const chatRoutes =
  require('./src/routes/chatRoutes');

const interactionRoutes =
  require('./src/routes/interactionRoutes');

const craftsmanRoutes =
  require('./src/routes/craftsmanRoutes');

const customOrderRoutes =
  require('./src/routes/customOrderRoutes');

const storyRoutes =
  require('./src/routes/storyRoutes');

const deliveryRoutes =
  require('./src/routes/deliveryRoutes');

const reviewRoutes =
  require('./src/routes/reviewRoutes');

const productOfferRoutes =
  require('./src/routes/productOfferRoutes');

const disputeRoutes =
  require('./src/routes/disputeRoutes');
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// API Route Registration
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

app.use(
  '/api/auth',
  authRoutes
);

app.use(
  '/api/exhibitions',
  exhibitionRoutes
);

app.use(
  '/api/hire-orders',
  hireOrderRoutes
);

app.use(
  '/api/payments',
  paymentRoutes
);

app.use(
  '/api/ai',
  aiRoutes
);

app.use(
  '/api/products',
  productRoutes
);

app.use(
  '/api/orders',
  orderRoutes
);

app.use(
  '/api/chats',
  chatRoutes
);

const adminDeliveryRoutes = require('./src/routes/adminDeliveryRoutes');

app.use(
  '/api/admin/delivery',
  adminDeliveryRoutes
);

app.use(
  '/api/admin',
  adminRoutes
);

app.use(
  '/api/upload',
  uploadRoutes
);

app.use(
  '/api/notifications',
  notificationRoutes
);

app.use(
  '/api/interactions',
  interactionRoutes
);

app.use(
  '/api/custom-orders',
  customOrderRoutes
);

app.use(
  '/api/stories',
  storyRoutes
);

app.use(
  '/api/delivery',
  deliveryRoutes
);

app.use(
  '/api/reviews',
  reviewRoutes
);
app.use(
  '/api/product-offers',
  productOfferRoutes
);

app.use(
  '/api/disputes',
  disputeRoutes
);

// Craftsman request logging
app.use(
  '/api/craftsman',
  (req, res, next) => {
    console.log(
      `${req.method} ${req.originalUrl}`
    );

    next();
  }
);

// Keep all URL formats supported (/api/craftsman, /api/craftsmen, /api/artisan, /api/artisans)
app.use(
  '/api/craftsman',
  craftsmanRoutes
);

app.use(
  '/api/craftsmen',
  craftsmanRoutes
);

app.use(
  '/api/artisan',
  craftsmanRoutes
);

app.use(
  '/api/artisans',
  craftsmanRoutes
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Socket.io â€” JWT Authenticated Real-Time Chat
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

io.use((socket, next) => {
  const token =
    socket.handshake.auth?.token;

  if (!token) {
    return next(
      new Error(
        'Authentication error: no token.'
      )
    );
  }

  try {
    const decoded =
      jwt.verify(
        token,
        JWT_SECRET
      );

    socket.userId =
      decoded.id;

    next();

  } catch (error) {
    next(
      new Error(
        'Authentication error: invalid token.'
      )
    );
  }
});

io.on(
  'connection',
  (socket) => {
    console.log(
      `Socket connected: ${socket.id} (userId: ${socket.userId})`
    );

    // Customer or artisan joins a chat room
    socket.on(
      'joinChat',
      async (chatId) => {
        try {
          const chat =
            await Chat.findByPk(chatId);

          if (!chat) {
            return socket.emit(
              'error', {
                message: 'Chat not found.'
              }
            );
          }

          const isParticipant =
            String(chat.participant1Id) === String(socket.userId) ||
            String(chat.participant2Id) === String(socket.userId) ||
            String(chat.customerId) === String(socket.userId) ||
            String(chat.craftsmanId) === String(socket.userId);

          if (!isParticipant) {
            return socket.emit(
              'error', {
                message: 'Access denied to this chat.'
              }
            );
          }

          socket.join(chatId);

          console.log(
            `Socket ${socket.id} joined chat ${chatId}`
          );

        } catch (error) {
          console.error(
            'joinChat error:',
            error
          );
        }
      }
    );

    /*
      Messages are stored through:

      POST /api/chats/:chatId/messages

      The REST controller emits the newMessage event
      after saving, so messages are not saved twice here.
    */

    socket.on(
      'disconnect',
      () => {
        console.log(
          `Socket disconnected: ${socket.id}`
        );
      }
    );
  }
);

// Basic Route

app.get(
  '/',
  (req, res) => {
    res.json({
      message: 'Welcome to CraftGo API. Go to /api-docs for documentation.'
    });
  }
);

// Always return JSON for unknown API routes. This prevents Flutter from
// receiving an HTML 404 page and failing with "Unexpected token '<'".
app.use('/api', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'API route not found',
    method: req.method,
    path: req.originalUrl
  });
});

// Final error handler. Keep this after all routes and middleware.
app.use((error, req, res, next) => {
  console.error(
    `[Unhandled API error] ${req.method} ${req.originalUrl}:`,
    error
  );

  if (res.headersSent) {
    return next(error);
  }

  res.status(error.status || error.statusCode || 500).json({
    success: false,
    error: error.message || 'Internal server error'
  });
});

const PORT =
  process.env.PORT || 5000;

User.belongsToMany(
  Role, {
    through: UserRole,
    foreignKey: 'userId'
  }
);

Role.belongsToMany(
  User, {
    through: UserRole,
    foreignKey: 'roleId'
  }
);

// Story â†” User
Story.belongsTo(
  User, {
    foreignKey: 'artisanId',
    as: 'artisan'
  }
);

User.hasMany(
  Story, {
    foreignKey: 'artisanId',
    as: 'stories'
  }
);

async function ensureDbColumns() {
  try {
    const queryInterface = sequelize.getQueryInterface();
    const tableInfo = await queryInterface.describeTable('ExhibitionCraftsmans');
    if (!tableInfo.rejectionReason) {
      await sequelize.query('ALTER TABLE ExhibitionCraftsmans ADD COLUMN rejectionReason TEXT;');
      console.log('Added missing rejectionReason column to ExhibitionCraftsmans table');
    }
  } catch (err) {
    console.error('ensureDbColumns check:', err.message);
  }

  try {
    const queryInterface = sequelize.getQueryInterface();
    const delTableInfo = await queryInterface.describeTable('DeliveryOrders');
    if (!delTableInfo.relatedOrderIds) {
      await sequelize.query('ALTER TABLE DeliveryOrders ADD COLUMN relatedOrderIds TEXT;');
      console.log('Added missing relatedOrderIds column to DeliveryOrders table');
    }
    if (!delTableInfo.relatedCustomOrderIds) {
      await sequelize.query('ALTER TABLE DeliveryOrders ADD COLUMN relatedCustomOrderIds TEXT;');
      console.log('Added missing relatedCustomOrderIds column to DeliveryOrders table');
    }
    if (!delTableInfo.isClearedByArtisan) {
      await sequelize.query('ALTER TABLE DeliveryOrders ADD COLUMN isClearedByArtisan TINYINT DEFAULT 0;');
      console.log('Added missing isClearedByArtisan column to DeliveryOrders table');
    }
    if (!delTableInfo.rating) {
      await sequelize.query('ALTER TABLE DeliveryOrders ADD COLUMN rating INTEGER;');
      console.log('Added missing rating column to DeliveryOrders table');
    }
    if (!delTableInfo.reviewComment) {
      await sequelize.query('ALTER TABLE DeliveryOrders ADD COLUMN reviewComment TEXT;');
      console.log('Added missing reviewComment column to DeliveryOrders table');
    }
    if (!delTableInfo.reviewedByRole) {
      await sequelize.query('ALTER TABLE DeliveryOrders ADD COLUMN reviewedByRole TEXT;');
      console.log('Added missing reviewedByRole column to DeliveryOrders table');
    }
  } catch (err) {
    console.error('ensureDbColumns DeliveryOrders check:', err.message);
  }

  try {
    const queryInterface = sequelize.getQueryInterface();
    const chatTableInfo = await queryInterface.describeTable('Chats');
    if (!chatTableInfo.participant1Id || chatTableInfo.customerId) {
      console.log('Migrating Chats table structure...');
      await sequelize.query('PRAGMA foreign_keys = OFF;');
      await sequelize.query('ALTER TABLE Chats RENAME TO Chats_old;');
      await Chat.sync({ force: true });
      await sequelize.query(`
        INSERT INTO Chats (id, participant1Id, participant1Role, participant2Id, participant2Role, orderId, lastMessage, createdAt, updatedAt)
        SELECT 
          id, 
          COALESCE(participant1Id, customerId) AS participant1Id,
          COALESCE(participant1Role, 'customer') AS participant1Role,
          COALESCE(participant2Id, craftsmanId) AS participant2Id,
          COALESCE(participant2Role, 'craftsman') AS participant2Role,
          orderId, 
          lastMessage, 
          createdAt, 
          updatedAt
        FROM Chats_old;
      `);
      await sequelize.query('DROP TABLE Chats_old;');
      await sequelize.query('PRAGMA foreign_keys = ON;');
      console.log('Chats table structure successfully migrated');
    }
  } catch (err) {
    console.error('ensureDbColumns Chats check:', err.message);
  }

  try {
    const [msgsSql] = await sequelize.query("SELECT sql FROM sqlite_master WHERE name='Messages';");
    if (msgsSql && msgsSql[0] && msgsSql[0].sql && msgsSql[0].sql.includes('Chats_old')) {
      console.log('Fixing Messages foreign key reference...');
      await sequelize.query('PRAGMA foreign_keys = OFF;');
      await sequelize.query('ALTER TABLE Messages RENAME TO Messages_old;');
      await Message.sync({ force: true });
      await sequelize.query('INSERT INTO Messages SELECT * FROM Messages_old;');
      await sequelize.query('DROP TABLE Messages_old;');
      await sequelize.query('PRAGMA foreign_keys = ON;');
      console.log('Messages table foreign keys successfully fixed');
    }
  } catch (err) {
    console.error('ensureDbColumns Messages check:', err.message);
  }
}

sequelize
  .sync({
    alter: false
  })
  .then(async () => {
    console.log(
      'Database synced'
    );
    await ensureDbColumns();

    server.listen(
      PORT,
      () => {
        console.log(
          `Server running on port ${PORT}`
        );
      }
    );
  })
  .catch((error) => {
    console.error(
      'Failed to sync db:',
      error
    );
  });
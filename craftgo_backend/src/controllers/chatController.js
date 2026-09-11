const {
  Op
} = require('sequelize');
const Chat = require('../models/Chat');
const Message = require('../models/Message');
const User = require('../models/User');
const Order = require('../models/Order');
const Product = require('../models/Product');
const Notification = require('../models/Notification');

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function _findChatForUser(chatId, userId) {
  const chat = await Chat.findByPk(chatId);
  if (!chat) throw {
    status: 404,
    error: 'Chat not found.'
  };
  if (chat.participant1Id !== userId && chat.participant2Id !== userId) {
    throw {
      status: 403,
      error: 'Access denied. You are not a member of this chat.'
    };
  }
  return chat;
}

function _handleError(res, err) {
  if (err && err.status) return res.status(err.status).json({
    error: err.error
  });
  console.error('[chatController]', err);
  res.status(500).json({
    error: 'Internal server error.'
  });
}

// ─── POST /api/chats ─────────────────────────────────────────────────────────
// Create or return existing chat between two users of any role.
exports.createOrGetChat = async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;
    const {
      otherUserId,
      otherUserRole,
      orderId
    } = req.body;

    if (!otherUserId) {
      return res.status(400).json({
        error: 'otherUserId is required.'
      });
    }
    if (userId === otherUserId) {
      return res.status(400).json({
        error: 'Cannot create a chat with yourself.'
      });
    }
    if (!otherUserRole) {
      return res.status(400).json({
        error: 'otherUserRole is required.'
      });
    }

    // Verify the other user exists
    const otherUser = await User.findByPk(otherUserId, {
      attributes: ['id', 'name']
    });
    if (!otherUser) return res.status(404).json({
      error: 'User not found.'
    });

    // If orderId supplied, verify that both users are involved in that order
    if (orderId) {
      const order = await Order.findByPk(orderId);
      if (!order) return res.status(404).json({
        error: 'Order not found.'
      });
      // Check if either user is customer or craftsman of the order
      const involved = [order.customerId, order.craftsmanId].map(id => String(id));
      if (!involved.includes(String(userId)) || !involved.includes(String(otherUserId))) {
        return res.status(403).json({
          error: 'Order does not involve both users.'
        });
      }
    }

    // Determine participant order to maintain consistency (e.g., smaller ID first)
    // We'll sort by ID to ensure uniqueness regardless of who initiates.
    const p1Id = userId < otherUserId ? userId : otherUserId;
    const p2Id = userId < otherUserId ? otherUserId : userId;
    const p1Role = userId < otherUserId ? userRole : otherUserRole;
    const p2Role = userId < otherUserId ? otherUserRole : userRole;

    const whereClause = {
      participant1Id: p1Id,
      participant2Id: p2Id,
    };
    if (orderId) whereClause.orderId = orderId;

    let chat = await Chat.findOne({
      where: whereClause
    });
    if (!chat) {
      chat = await Chat.create({
        participant1Id: p1Id,
        participant1Role: p1Role,
        participant2Id: p2Id,
        participant2Role: p2Role,
        orderId: orderId || null,
      });
    }

    // Return with participants
    const full = await Chat.findByPk(chat.id, {
      include: [{
          model: User,
          as: 'participant1',
          attributes: ['id', 'name', 'profileImage']
        },
        {
          model: User,
          as: 'participant2',
          attributes: ['id', 'name', 'profileImage']
        },
      ],
    });

    const formatted = _formatChat(full.toJSON(), userId);
    res.status(201).json(formatted);
  } catch (err) {
    _handleError(res, err);
  }
};

function _formatChat(c, userId) {
  const p1 = c.participant1;
  const p2 = c.participant2;

  let otherUser = null;
  if (p1 && String(p1.id) === String(userId)) {
    otherUser = p2;
  } else if (p2 && String(p2.id) === String(userId)) {
    otherUser = p1;
  } else {
    otherUser = p2 || p1;
  }

  const customerObj = c.participant1Role === 'customer' ? p1 : (c.participant2Role === 'customer' ? p2 : null);
  const craftsmanObj = c.participant1Role === 'craftsman' ? p1 : (c.participant2Role === 'craftsman' ? p2 : null);

  return {
    ...c,
    otherUser,
    otherUserName: otherUser?.name ?? '',
    avatar: otherUser?.profileImage ?? null,
    name: otherUser?.name ?? '',
    customer: customerObj,
    craftsman: craftsmanObj,
    Customer: customerObj,
    Craftsman: craftsmanObj,
  };
}

// ─── GET /api/chats ──────────────────────────────────────────────────────────
// Return all chats where req.user is participant1 or participant2.
exports.getMyChats = async (req, res) => {
  try {
    const userId = req.user.id;

    const chats = await Chat.findAll({
      where: {
        [Op.or]: [{
          participant1Id: userId
        }, {
          participant2Id: userId
        }],
      },
      include: [{
          model: User,
          as: 'participant1',
          attributes: ['id', 'name', 'profileImage']
        },
        {
          model: User,
          as: 'participant2',
          attributes: ['id', 'name', 'profileImage']
        },
      ],
      order: [
        ['updatedAt', 'DESC']
      ],
    });

    // Enrich with lastMessage + unreadCount
    const enriched = await Promise.all(
      chats.map(async (chat) => {
        const c = chat.toJSON();

        const lastMsg = await Message.findOne({
          where: {
            chatId: c.id
          },
          order: [
            ['createdAt', 'DESC']
          ],
          attributes: ['id', 'content', 'senderId', 'createdAt'],
        });

        const unreadCount = await Message.count({
          where: {
            chatId: c.id,
            senderId: {
              [Op.ne]: userId
            },
            isRead: false
          },
        });

        let orderData = null;
        if (c.orderId) {
          orderData = await Order.findByPk(c.orderId, {
            attributes: ['id', 'status', 'totalAmount'],
            include: [{
              model: Product,
              attributes: ['titleAr', 'titleEn'],
              required: false
            }],
          });
        }

        return _formatChat({
          ...c,
          order: orderData,
          lastMessage: lastMsg,
          unreadCount,
        }, userId);
      })
    );

    // Sort by lastMessage time or updatedAt
    enriched.sort((a, b) => {
      const aTime = a.lastMessage?.createdAt ?? a.updatedAt;
      const bTime = b.lastMessage?.createdAt ?? b.updatedAt;
      return new Date(bTime) - new Date(aTime);
    });

    res.json(enriched);
  } catch (err) {
    _handleError(res, err);
  }
};

// ─── GET /api/chats/:chatId/messages ─────────────────────────────────────────
exports.getMessages = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      chatId
    } = req.params;
    await _findChatForUser(chatId, userId);

    const messages = await Message.findAll({
      where: {
        chatId
      },
      include: [{
        model: User,
        as: 'sender',
        attributes: ['id', 'name', 'profileImage']
      }],
      order: [
        ['createdAt', 'ASC']
      ],
    });

    res.json(messages);
  } catch (err) {
    _handleError(res, err);
  }
};

// ─── POST /api/chats/:chatId/messages ────────────────────────────────────────
exports.sendMessage = async (req, res) => {
  try {
    const senderId = req.user.id;
    const {
      chatId
    } = req.params;
    let {
      content
    } = req.body;

    if (!content || typeof content !== 'string') {
      return res.status(400).json({
        error: 'content is required.'
      });
    }
    content = content.trim();
    if (content.length === 0) {
      return res.status(400).json({
        error: 'Message cannot be empty.'
      });
    }
    if (content.length > 2000) {
      return res.status(400).json({
        error: 'Message exceeds 2000 characters.'
      });
    }

    const chat = await _findChatForUser(chatId, senderId);

    const message = await Message.create({
      chatId,
      senderId,
      content
    });
    await chat.update({
      lastMessage: content,
      updatedAt: new Date()
    });

    const full = await Message.findByPk(message.id, {
      include: [{
        model: User,
        as: 'sender',
        attributes: ['id', 'name', 'profileImage']
      }],
    });

    // Determine receiver ID
    const receiverId = chat.participant1Id === senderId ? chat.participant2Id : chat.participant1Id;

    const sender = await User.findByPk(senderId, {
      attributes: ['id', 'name']
    });

    // Create notification for receiver
    const notification = await Notification.create({
      userId: receiverId,
      type: 'message',
      titleAr: 'رسالة جديدة',
      titleEn: 'New Message',
      bodyAr: `${sender?.name ?? 'مستخدم'} أرسل لك رسالة جديدة.`,
      bodyEn: `${sender?.name ?? 'A user'} sent you a new message.`,
      isRead: false,
      metadata: {
        chatId,
        senderId,
        messageId: message.id,
      },
    });

    const io = req.app.get('io');
    if (io) {
      io.to(chatId).emit('newMessage', full);
      io.to(`user-${receiverId}`).emit('notification', notification);
    }

    res.status(201).json(full);
  } catch (err) {
    _handleError(res, err);
  }
};

// ─── PATCH /api/chats/:chatId/read ───────────────────────────────────────────
exports.markAsRead = async (req, res) => {
  try {
    const userId = req.user.id;
    const {
      chatId
    } = req.params;
    await _findChatForUser(chatId, userId);

    const [count] = await Message.update({
      isRead: true
    }, {
      where: {
        chatId,
        senderId: {
          [Op.ne]: userId
        },
        isRead: false,
      },
    });

    const io = req.app.get('io');
    if (io) {
      io.to(chatId).emit('messagesRead', {
        chatId,
        readBy: userId,
        count
      });
    }

    res.json({
      success: true,
      markedAsRead: count
    });
  } catch (err) {
    _handleError(res, err);
  }
};
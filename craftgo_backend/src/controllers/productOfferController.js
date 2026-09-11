const ProductOffer = require('../models/ProductOffer');
const Product = require('../models/Product');
const User = require('../models/User');
const Order = require('../models/Order');
const Notification = require('../models/Notification');

const include = [
  { model: Product, as: 'product' },
  { model: User, as: 'customer', attributes: ['id', 'name'] },
  { model: User, as: 'craftsman', attributes: ['id', 'name'] },
];

async function notify(userId, type, titleEn, bodyEn, metadata) {
  await Notification.create({
    userId, type, titleEn, titleAr: titleEn,
    bodyEn, bodyAr: bodyEn, metadata,
  });
}

exports.create = async (req, res) => {
  try {
    const product = await Product.findByPk(req.body.productId);
    if (!product || !product.isPublic || !product.isAvailable) {
      return res.status(404).json({ error: 'Product is not available' });
    }
    const quantity = Math.max(1, Math.min(99, Number(req.body.quantity) || 1));
    const original = Number(product.price);
    const offered = Number(req.body.offeredPrice);
    if (!Number.isFinite(offered) || offered <= 0 || offered >= original) {
      return res.status(400).json({ error: 'Offer must be greater than zero and lower than the listed price' });
    }
    if (offered < original * 0.8) {
      return res.status(400).json({ error: 'Offer is below CraftGo fair-offer limit (80%)' });
    }
    const offer = await ProductOffer.create({
      productId: product.id, customerId: req.user.id, craftsmanId: product.craftsmanId,
      quantity, originalUnitPrice: original, offeredUnitPrice: offered,
      message: String(req.body.message || '').slice(0, 500),
      expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000),
    });
    await notify(product.craftsmanId, 'product_offer', 'New price offer',
      `A customer offered ${offered.toFixed(2)} JOD for ${product.titleEn}.`, { offerId: offer.id });
    return res.status(201).json({ success: true, offer });
  } catch (error) {
    console.error('[ProductOffer.create]', error);
    return res.status(500).json({ error: 'Failed to create offer' });
  }
};

exports.customerList = async (req, res) => {
  const offers = await ProductOffer.findAll({ where: { customerId: req.user.id }, include, order: [['createdAt', 'DESC']] });
  return res.json({ success: true, offers });
};

exports.artisanList = async (req, res) => {
  const offers = await ProductOffer.findAll({ where: { craftsmanId: req.user.id }, include, order: [['createdAt', 'DESC']] });
  return res.json({ success: true, offers });
};

exports.artisanRespond = async (req, res) => {
  const offer = await ProductOffer.findOne({ where: { id: req.params.id, craftsmanId: req.user.id } });
  if (!offer) return res.status(404).json({ error: 'Offer not found' });
  if (offer.status !== 'pending') return res.status(409).json({ error: 'Offer was already answered' });
  const action = req.body.action;
  if (action === 'accept') {
    offer.status = 'accepted'; offer.acceptedUnitPrice = offer.offeredUnitPrice;
  } else if (action === 'reject') {
    offer.status = 'rejected';
  } else if (action === 'counter') {
    const counter = Number(req.body.counterPrice);
    const original = Number(offer.originalUnitPrice);
    if (!Number.isFinite(counter) || counter <= Number(offer.offeredUnitPrice) || counter > original) {
      return res.status(400).json({ error: 'Counter price must be above the offer and not exceed list price' });
    }
    offer.status = 'countered'; offer.counterUnitPrice = counter;
  } else return res.status(400).json({ error: 'Action must be accept, reject, or counter' });
  await offer.save();
  await notify(offer.customerId, 'offer_response', 'Artisan answered your offer',
    `Your offer status is now ${offer.status}.`, { offerId: offer.id });
  return res.json({ success: true, offer });
};

exports.customerRespond = async (req, res) => {
  const offer = await ProductOffer.findOne({ where: { id: req.params.id, customerId: req.user.id } });
  if (!offer) return res.status(404).json({ error: 'Offer not found' });
  if (offer.status !== 'countered') return res.status(409).json({ error: 'No counter-offer is awaiting your answer' });
  if (req.body.action === 'accept') {
    offer.status = 'accepted'; offer.acceptedUnitPrice = offer.counterUnitPrice;
  } else if (req.body.action === 'reject') offer.status = 'rejected';
  else return res.status(400).json({ error: 'Action must be accept or reject' });
  await offer.save();
  await notify(offer.craftsmanId, 'offer_response', 'Customer answered your counter-offer',
    `The counter-offer is ${offer.status}.`, { offerId: offer.id });
  return res.json({ success: true, offer });
};

exports.createOrder = async (req, res) => {
  const offer = await ProductOffer.findOne({ where: { id: req.params.id, customerId: req.user.id } });
  if (!offer || offer.status !== 'accepted') return res.status(409).json({ error: 'Offer is not accepted' });
  const address = String(req.body.deliveryAddress || '').trim();
  if (!address) return res.status(400).json({ error: 'Delivery address is required' });
  const unit = Number(offer.acceptedUnitPrice);
  const order = await Order.create({
    customerId: offer.customerId, craftsmanId: offer.craftsmanId, productId: offer.productId,
    quantity: offer.quantity, agreedUnitPrice: unit, totalAmount: unit * offer.quantity,
    shippingAddress: address, paymentMethod: 'Stripe Test / Escrow',
    status: 'awaiting_payment', paymentStatus: 'unpaid', escrowStatus: 'none', offerId: offer.id,
  });
  return res.status(201).json({ success: true, order });
};

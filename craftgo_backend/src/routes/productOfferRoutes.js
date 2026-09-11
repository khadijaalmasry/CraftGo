const router = require('express').Router();
const controller = require('../controllers/productOfferController');
const { verifyToken } = require('../middlewares/authMiddleware');

router.post('/', verifyToken, controller.create);
router.get('/customer', verifyToken, controller.customerList);
router.get('/artisan', verifyToken, controller.artisanList);
router.patch('/:id/respond', verifyToken, controller.artisanRespond);
router.patch('/:id/customer-response', verifyToken, controller.customerRespond);
router.post('/:id/order', verifyToken, controller.createOrder);

module.exports = router;

const axios = require('axios');
(async () => {
  try {
    const api = axios.create({ baseURL: 'http://localhost:5000/api' });
    
    // 1. Login Customer
    const loginRes = await api.post('/auth/login', { email: 'admin@craftgo.com', password: '123456' });
    const token = loginRes.data.token;
    const user = loginRes.data.user;
    api.defaults.headers.common['Authorization'] = `Bearer ${token}`;

    console.log('Customer logged in');

    // GET empty orders first to verify empty state doesn't crash
    const emptyOrders = await api.get('/orders/customer');
    console.log('Empty Customer Orders:', JSON.stringify(emptyOrders.data, null, 2));

    // 2. Fetch a real product
    const productsRes = await api.get('/products/public');
    const product = productsRes.data[0];
    console.log('Using Product:', product.titleEn, 'by craftsman:', product.craftsmanId);

    // 3. Add to cart (UserInteraction)
    const addCartRes = await api.post(`/interactions/products/${product.id}`, { interactionType: 'cart' });
    const interactionId = addCartRes.data.interaction.id;
    console.log('Added to cart, Interaction ID:', interactionId);

    // 4. Checkout
    const checkoutBody = {
      items: [{ productId: product.id, quantity: 1, interactionId }],
      deliveryAddress: 'Test Address 123',
      paymentMethod: 'Online Payment (Escrow) ??'
    };
    const checkoutRes = await api.post('/orders', checkoutBody);
    console.log('Checkout Response:', checkoutRes.status, checkoutRes.data.success);

    // 5. Get Customer Orders
    const customerOrdersRes = await api.get('/orders/customer');
    console.log('\n--- CUSTOMER ORDERS RESPONSE ---');
    console.log(JSON.stringify(customerOrdersRes.data, null, 2));

    // 6. Login Artisan to check artisan orders
    const artisanLogin = await api.post('/auth/login', { email: 'maram@craftgo.com', password: '123456' });
    const artisanToken = artisanLogin.data.token;
    
    console.log('\n--- ARTISAN ORDERS RESPONSE ---');
    // Using craftsman ID from the product
    try {
      const artisanOrdersRes = await axios.get(`http://localhost:5000/api/orders/craftsman/${product.craftsmanId}`, {
        headers: { Authorization: `Bearer ${artisanToken}` }
      });
      console.log(JSON.stringify(artisanOrdersRes.data, null, 2));
    } catch(e) {
      console.error('Artisan orders fetch error:', e.response?.data || e.message);
    }
  } catch(e) {
    console.error('Test Failed:', e.response?.data || e.message);
  }
})();

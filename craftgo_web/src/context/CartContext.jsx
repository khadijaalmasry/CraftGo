import React, { createContext, useState, useEffect, useContext } from 'react';
import api from '../services/api';
import { useAuth } from './AuthContext';

const CartContext = createContext();

export const useCart = () => useContext(CartContext);

export const CartProvider = ({ children }) => {
  const { isAuthenticated } = useAuth();
  const [cartItems, setCartItems] = useState([]);
  const [loading, setLoading] = useState(false);

  const fetchCart = async () => {
    if (!isAuthenticated) {
      setCartItems([]);
      return;
    }
    
    setLoading(true);
    try {
      const res = await api.get('/interactions');
      if (res.data) {
        const interactions = Array.isArray(res.data) ? res.data : (res.data.interactions || res.data.data || []);
        const cart = interactions.filter(i => i.type === 'cart' || i.interactionType === 'cart');
        
        const formattedCart = cart.map(item => {
          const p = item.Product || item;
          return {
            id: p.id,
            interactionId: item.id,
            titleAr: p.titleAr || p.nameAr || p.title || '—',
            titleEn: p.titleEn || p.nameEn || p.title || '—',
            price: parseFloat(p.price) || 0,
            imageUrl: p.imageUrl,
            quantity: item.quantity || 1,
            craftsmanName: p.Craftsman?.name || p.artisan || '',
          };
        });
        setCartItems(formattedCart);
      }
    } catch (error) {
      console.error('Error fetching cart:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCart();
  }, [isAuthenticated]);

  const addToCart = async (productId, quantity = 1) => {
    if (!isAuthenticated) return { success: false, message: 'Please login first' };
    
    try {
      const res = await api.post('/interactions/cart', { productId, quantity });
      if (res.status === 200 || res.status === 201) {
        await fetchCart();
        return { success: true };
      }
      return { success: false };
    } catch (error) {
      console.error('Error adding to cart:', error);
      return { success: false, message: 'Failed to add item to cart' };
    }
  };

  const updateQuantity = async (interactionId, newQuantity) => {
    if (newQuantity < 1) return removeFromCart(interactionId);
    
    try {
      await api.patch(`/interactions/${interactionId}`, { quantity: newQuantity });
      setCartItems(prev => prev.map(item => item.interactionId === interactionId ? { ...item, quantity: newQuantity } : item));
      return { success: true };
    } catch (error) {
      console.error('Error updating quantity:', error);
      return { success: false };
    }
  };

  const removeFromCart = async (interactionId) => {
    try {
      await api.delete(`/interactions/${interactionId}`);
      setCartItems(prev => prev.filter(item => item.interactionId !== interactionId));
      return { success: true };
    } catch (error) {
      console.error('Error removing from cart:', error);
      return { success: false };
    }
  };

  const clearCart = () => {
    setCartItems([]);
  };

  const cartTotal = cartItems.reduce((total, item) => total + (item.price * item.quantity), 0);
  const cartCount = cartItems.reduce((count, item) => count + item.quantity, 0);

  const value = {
    cartItems,
    loading,
    cartTotal,
    cartCount,
    fetchCart,
    addToCart,
    updateQuantity,
    removeFromCart,
    clearCart
  };

  return (
    <CartContext.Provider value={value}>
      {children}
    </CartContext.Provider>
  );
};

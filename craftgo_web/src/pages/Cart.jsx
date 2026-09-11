import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useCart } from '../context/CartContext';
import { FaTrash, FaArrowRight } from 'react-icons/fa';

const Cart = () => {
  const { cartItems, loading, cartTotal, updateQuantity, removeFromCart } = useCart();
  const navigate = useNavigate();

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  if (cartItems.length === 0) {
    return (
      <div className="container fade-in" style={{ padding: '4rem 1.5rem', textAlign: 'center', minHeight: '60vh' }}>
        <h2 style={{ color: 'var(--text-primary)', marginBottom: '1rem' }}>سلة المشتريات فارغة</h2>
        <p style={{ color: 'var(--text-dim)', marginBottom: '2rem' }}>اكتشف منتجاتنا المميزة وأضفها إلى سلتك.</p>
        <Link to="/shop" className="btn-primary" style={{ textDecoration: 'none' }}>
          تصفح المتجر
        </Link>
      </div>
    );
  }

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ color: 'var(--text-primary)', marginBottom: '2rem' }}>سلة المشتريات</h1>
      
      <div style={styles.layout}>
        {/* Cart Items List */}
        <div style={styles.itemsList}>
          {cartItems.map(item => (
            <div key={item.interactionId} className="glass-card" style={styles.cartItem}>
              <img 
                src={item.imageUrl || 'https://via.placeholder.com/100?text=CraftGo'} 
                alt={item.titleAr} 
                style={styles.itemImage}
                onError={(e) => e.target.src = 'https://via.placeholder.com/100?text=CraftGo'}
              />
              
              <div style={styles.itemDetails}>
                <h3 style={styles.itemTitle}>{item.titleAr}</h3>
                <p style={styles.itemArtisan}>{item.craftsmanName}</p>
                <p style={styles.itemPrice}>{parseFloat(item.price).toFixed(2)} د.أ</p>
              </div>
              
              <div style={styles.itemActions}>
                <div style={styles.quantityControl}>
                  <button style={styles.qtyBtn} onClick={() => updateQuantity(item.interactionId, item.quantity - 1)}>-</button>
                  <span style={styles.qtyVal}>{item.quantity}</span>
                  <button style={styles.qtyBtn} onClick={() => updateQuantity(item.interactionId, item.quantity + 1)}>+</button>
                </div>
                <button 
                  style={styles.deleteBtn} 
                  onClick={() => removeFromCart(item.interactionId)}
                  title="حذف"
                >
                  <FaTrash />
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Order Summary */}
        <div className="glass-card" style={styles.summaryCard}>
          <h3 style={{ marginBottom: '1.5rem', borderBottom: '1px solid var(--border-color)', paddingBottom: '1rem' }}>ملخص الطلب</h3>
          
          <div style={styles.summaryRow}>
            <span>المجموع الفرعي:</span>
            <span>{cartTotal.toFixed(2)} د.أ</span>
          </div>
          <div style={styles.summaryRow}>
            <span>التوصيل:</span>
            <span>مجاني</span>
          </div>
          
          <div style={{ ...styles.summaryRow, ...styles.summaryTotal }}>
            <span>الإجمالي:</span>
            <span style={{ color: 'var(--accent-color)' }}>{cartTotal.toFixed(2)} د.أ</span>
          </div>
          
          <button 
            className="btn-primary" 
            style={styles.checkoutBtn}
            onClick={() => navigate('/checkout')}
          >
            إتمام الشراء <FaArrowRight />
          </button>
          
          <Link to="/shop" style={styles.continueLink}>
            مواصلة التسوق
          </Link>
        </div>
      </div>
    </div>
  );
};

const styles = {
  layout: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '2rem',
    alignItems: 'flex-start',
  },
  itemsList: {
    flex: '1 1 60%',
    display: 'flex',
    flexDirection: 'column',
    gap: '1rem',
  },
  cartItem: {
    display: 'flex',
    alignItems: 'center',
    gap: '1.5rem',
    padding: '1rem',
  },
  itemImage: {
    width: '100px',
    height: '100px',
    borderRadius: '12px',
    objectFit: 'cover',
  },
  itemDetails: {
    flex: 1,
  },
  itemTitle: {
    fontSize: '1.1rem',
    margin: '0 0 0.5rem 0',
  },
  itemArtisan: {
    color: 'var(--text-secondary)',
    fontSize: '0.9rem',
    margin: '0 0 0.5rem 0',
  },
  itemPrice: {
    color: 'var(--accent-color)',
    fontWeight: 'bold',
    margin: 0,
  },
  itemActions: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'flex-end',
    gap: '1rem',
  },
  quantityControl: {
    display: 'flex',
    alignItems: 'center',
    border: '1px solid var(--border-color)',
    borderRadius: '8px',
    overflow: 'hidden',
    backgroundColor: 'var(--bg-color)',
  },
  qtyBtn: {
    padding: '0.5rem 0.75rem',
    background: 'none',
    color: 'var(--text-primary)',
    fontWeight: 'bold',
  },
  qtyVal: {
    padding: '0 0.5rem',
    fontWeight: 'bold',
  },
  deleteBtn: {
    background: 'rgba(239, 68, 68, 0.1)',
    color: 'var(--danger-color)',
    padding: '0.5rem',
    borderRadius: '8px',
  },
  summaryCard: {
    flex: '1 1 300px',
    position: 'sticky',
    top: '90px',
  },
  summaryRow: {
    display: 'flex',
    justifyContent: 'space-between',
    marginBottom: '1rem',
    color: 'var(--text-secondary)',
  },
  summaryTotal: {
    fontWeight: 'bold',
    fontSize: '1.2rem',
    color: 'var(--text-primary)',
    marginTop: '1rem',
    borderTop: '1px solid var(--border-color)',
    paddingTop: '1rem',
  },
  checkoutBtn: {
    width: '100%',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    gap: '0.5rem',
    marginTop: '1.5rem',
    padding: '1rem',
    fontSize: '1.1rem',
  },
  continueLink: {
    display: 'block',
    textAlign: 'center',
    marginTop: '1rem',
    color: 'var(--text-dim)',
    textDecoration: 'underline',
  }
};

export default Cart;

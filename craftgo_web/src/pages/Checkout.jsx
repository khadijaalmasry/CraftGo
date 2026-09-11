import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import { useCart } from '../context/CartContext';
import { FaCheckCircle, FaMoneyBillWave, FaCreditCard } from 'react-icons/fa';

const Checkout = () => {
  const { cartItems, cartTotal, fetchCart, clearCart } = useCart();
  const navigate = useNavigate();
  
  const [address, setAddress] = useState('نابلس، فلسطين');
  const [paymentMethod, setPaymentMethod] = useState('الدفع عند الاستلام');
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  // If cart is empty and not just checked out, go back
  if (cartItems.length === 0 && !success) {
    navigate('/cart');
    return null;
  }

  const handleCheckout = async (e) => {
    e.preventDefault();
    setLoading(true);

    try {
      const orderItems = cartItems.map(i => ({
        productId: i.id,
        quantity: i.quantity,
        interactionId: i.interactionId
      }));

      const res = await api.post('/orders', {
        items: orderItems,
        deliveryAddress: address,
        paymentMethod: paymentMethod
      });

      if (res.data.success) {
        setSuccess(true);
        clearCart();
        // optionally refresh cart to sync with backend
        fetchCart();
      } else {
        alert('حدث خطأ أثناء الشراء');
      }
    } catch (err) {
      console.error('Checkout error:', err);
      alert('حدث خطأ أثناء إتمام الطلب');
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <div className="container fade-in" style={{ padding: '6rem 1.5rem', textAlign: 'center', minHeight: '80vh' }}>
        <FaCheckCircle color="var(--success-color)" size={80} style={{ marginBottom: '2rem' }} />
        <h1 style={{ color: 'var(--text-primary)', marginBottom: '1rem' }}>تم استلام طلبك بنجاح!</h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: '1.2rem', marginBottom: '3rem' }}>
          شكراً لتسوقك من CraftGo. سنقوم بتجهيز طلبك وتوصيله قريباً.
        </p>
        <button className="btn-primary" onClick={() => navigate('/customer/orders')}>
          متابعة حالة الطلب
        </button>
      </div>
    );
  }

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ color: 'var(--text-primary)', marginBottom: '2rem' }}>إتمام الشراء</h1>
      
      <div style={styles.layout}>
        <div style={styles.formSection}>
          <form onSubmit={handleCheckout} className="glass-card">
            <h3 style={{ marginBottom: '1.5rem' }}>بيانات التوصيل والدفع</h3>
            
            <div style={{ marginBottom: '1.5rem' }}>
              <label style={styles.label}>عنوان التوصيل</label>
              <textarea 
                className="input-field" 
                rows="3" 
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                required
              />
            </div>
            
            <div style={{ marginBottom: '2rem' }}>
              <label style={styles.label}>طريقة الدفع</label>
              <div style={styles.paymentMethods}>
                <label style={paymentMethod === 'الدفع عند الاستلام' ? styles.paymentMethodActive : styles.paymentMethod}>
                  <input 
                    type="radio" 
                    name="payment" 
                    value="الدفع عند الاستلام" 
                    checked={paymentMethod === 'الدفع عند الاستلام'}
                    onChange={(e) => setPaymentMethod(e.target.value)}
                    style={{ display: 'none' }}
                  />
                  <FaMoneyBillWave size={24} color={paymentMethod === 'الدفع عند الاستلام' ? 'var(--accent-color)' : 'var(--text-dim)'} />
                  <span>الدفع عند الاستلام</span>
                </label>
                
                <label style={paymentMethod === 'الدفع الإلكتروني (Escrow)' ? styles.paymentMethodActive : styles.paymentMethod}>
                  <input 
                    type="radio" 
                    name="payment" 
                    value="الدفع الإلكتروني (Escrow)" 
                    checked={paymentMethod === 'الدفع الإلكتروني (Escrow)'}
                    onChange={(e) => setPaymentMethod(e.target.value)}
                    style={{ display: 'none' }}
                  />
                  <FaCreditCard size={24} color={paymentMethod === 'الدفع الإلكتروني (Escrow)' ? 'var(--accent-color)' : 'var(--text-dim)'} />
                  <span>الدفع الإلكتروني (Escrow)</span>
                </label>
              </div>
            </div>
            
            <button type="submit" className="btn-primary" style={{ width: '100%', fontSize: '1.2rem', padding: '1rem' }} disabled={loading}>
              {loading ? 'جاري التأكيد...' : 'تأكيد الطلب'}
            </button>
          </form>
        </div>
        
        <div className="glass-card" style={styles.summarySection}>
          <h3 style={{ marginBottom: '1.5rem' }}>ملخص الطلب</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginBottom: '1.5rem' }}>
            {cartItems.map(item => (
              <div key={item.interactionId} style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: 'var(--text-secondary)' }}>{item.quantity}x {item.titleAr}</span>
                <span style={{ fontWeight: 'bold' }}>{(item.price * item.quantity).toFixed(2)} د.أ</span>
              </div>
            ))}
          </div>
          
          <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '1rem', display: 'flex', justifyContent: 'space-between', fontWeight: 'bold', fontSize: '1.2rem' }}>
            <span>المجموع النهائي:</span>
            <span style={{ color: 'var(--accent-color)' }}>{cartTotal.toFixed(2)} د.أ</span>
          </div>
        </div>
      </div>
    </div>
  );
};

const styles = {
  layout: {
    display: 'flex',
    flexWrap: 'wrap-reverse',
    gap: '2rem',
    alignItems: 'flex-start',
  },
  formSection: {
    flex: '1 1 60%',
  },
  summarySection: {
    flex: '1 1 300px',
    position: 'sticky',
    top: '90px',
  },
  label: {
    display: 'block',
    marginBottom: '0.5rem',
    fontWeight: 'bold',
    color: 'var(--text-primary)',
  },
  paymentMethods: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    gap: '1rem',
  },
  paymentMethod: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '0.75rem',
    padding: '1.5rem',
    border: '2px solid var(--border-color)',
    borderRadius: '12px',
    cursor: 'pointer',
    transition: 'all 0.2s',
  },
  paymentMethodActive: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '0.75rem',
    padding: '1.5rem',
    border: '2px solid var(--accent-color)',
    backgroundColor: 'rgba(212, 160, 23, 0.05)',
    borderRadius: '12px',
    cursor: 'pointer',
    color: 'var(--accent-color)',
    fontWeight: 'bold',
    transition: 'all 0.2s',
  }
};

export default Checkout;

import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';
import { FaBoxOpen, FaClock, FaCheckCircle, FaSpinner } from 'react-icons/fa';

const CustomerOrders = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchOrders = async () => {
      try {
        const res = await api.get('/orders/customer');
        if (res.data.success) {
          setOrders(res.data.orders);
        } else {
          setError('تعذر جلب الطلبات.');
        }
      } catch (err) {
        console.error('Failed to fetch orders:', err);
        setError('حدث خطأ أثناء جلب الطلبات.');
      } finally {
        setLoading(false);
      }
    };
    fetchOrders();
  }, []);

  const getStatusIcon = (status) => {
    switch (status) {
      case 'pending':
        return <FaClock color="var(--accent-color)" size={24} />;
      case 'in_progress':
        return <FaSpinner color="#3B82F6" size={24} className="spin-animation" />;
      case 'completed':
        return <FaCheckCircle color="var(--success-color)" size={24} />;
      default:
        return <FaBoxOpen color="var(--text-dim)" size={24} />;
    }
  };

  const getStatusText = (status) => {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'in_progress': return 'قيد التنفيذ';
      case 'completed': return 'مكتمل';
      case 'cancelled': return 'ملغى';
      default: return status;
    }
  };

  if (loading) return <div className="container" style={{ padding: '4rem', textAlign: 'center' }}>جاري التحميل...</div>;

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh' }}>
      <h1 style={{ color: 'var(--text-primary)', marginBottom: '2rem' }}>طلباتي</h1>

      {error && <div style={{ color: 'var(--danger-color)', marginBottom: '1rem' }}>{error}</div>}

      {orders.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <FaBoxOpen size={48} color="var(--text-dim)" style={{ marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-secondary)' }}>لا يوجد لديك أي طلبات حالياً.</p>
          <Link to="/shop" className="btn-primary" style={{ display: 'inline-block', marginTop: '1rem' }}>
            تصفح المتجر
          </Link>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {orders.map(order => (
            <div key={order.id} className="glass-card" style={styles.orderCard}>
              <div style={styles.orderHeader}>
                <div>
                  <h3 style={{ margin: '0 0 0.5rem 0' }}>طلب رقم #{order.id}</h3>
                  <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                    {new Date(order.createdAt).toLocaleDateString('ar-EG')}
                  </p>
                </div>
                <div style={styles.statusBadge}>
                  {getStatusIcon(order.status)}
                  <span style={{ fontWeight: 'bold' }}>{getStatusText(order.status)}</span>
                </div>
              </div>
              
              <div style={styles.orderDetails}>
                <div>
                  <p style={{ color: 'var(--text-dim)', marginBottom: '0.25rem' }}>طريقة الدفع</p>
                  <p style={{ fontWeight: 'bold' }}>{order.paymentMethod || 'غير محدد'}</p>
                </div>
                <div>
                  <p style={{ color: 'var(--text-dim)', marginBottom: '0.25rem' }}>السعر الإجمالي</p>
                  <p style={{ fontWeight: 'bold', color: 'var(--accent-color)' }}>{parseFloat(order.totalPrice || 0).toFixed(2)} د.أ</p>
                </div>
              </div>

              {/* Display items if populated */}
              {order.OrderItems && order.OrderItems.length > 0 && (
                <div style={styles.itemsList}>
                  <p style={{ fontWeight: 'bold', marginBottom: '0.5rem' }}>المنتجات:</p>
                  {order.OrderItems.map(item => (
                    <div key={item.id} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                      <span>{item.quantity}x {item.Product?.titleAr || 'منتج'}</span>
                      <span>{(item.price * item.quantity).toFixed(2)} د.أ</span>
                    </div>
                  ))}
                </div>
              )}

              {order.status === 'completed' && (
                <div style={{ marginTop: '1.5rem', display: 'flex', justifyContent: 'flex-end' }}>
                  <Link to={`/customer/review/${order.id}`} className="btn-primary" style={{ textDecoration: 'none', fontSize: '0.9rem', padding: '0.6rem 1.25rem' }}>
                    تقييم الطلب
                  </Link>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

const styles = {
  orderCard: {
    padding: '1.5rem',
  },
  orderHeader: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    borderBottom: '1px solid var(--border-color)',
    paddingBottom: '1rem',
    marginBottom: '1rem',
  },
  statusBadge: {
    display: 'flex',
    alignItems: 'center',
    gap: '0.5rem',
    backgroundColor: 'var(--bg-color)',
    padding: '0.5rem 1rem',
    borderRadius: '20px',
  },
  orderDetails: {
    display: 'flex',
    gap: '3rem',
    marginBottom: '1rem',
  },
  itemsList: {
    backgroundColor: 'var(--bg-color)',
    padding: '1rem',
    borderRadius: '8px',
  }
};

export default CustomerOrders;

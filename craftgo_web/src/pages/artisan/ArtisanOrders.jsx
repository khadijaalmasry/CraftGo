import React, { useState, useEffect } from 'react';
import api from '../../services/api';
import { FaClock, FaSpinner, FaCheckCircle, FaBoxOpen } from 'react-icons/fa';

const ArtisanOrders = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    try {
      const res = await api.get('/orders/artisan');
      if (res.data.success) {
        setOrders(res.data.orders);
      } else {
        setError('تعذر جلب الطلبات.');
      }
    } catch (err) {
      console.error('Failed to fetch artisan orders:', err);
      setError('حدث خطأ أثناء جلب الطلبات.');
    } finally {
      setLoading(false);
    }
  };

  const handleUpdateStatus = async (orderId, newStatus) => {
    try {
      const res = await api.patch(`/orders/artisan/${orderId}/status`, { status: newStatus });
      if (res.data.success) {
        // Update local state
        setOrders(prev => prev.map(o => o.id === orderId ? { ...o, status: newStatus } : o));
      } else {
        alert('فشل في تحديث حالة الطلب');
      }
    } catch (err) {
      console.error('Update status error:', err);
      alert('حدث خطأ أثناء تحديث حالة الطلب');
    }
  };

  const getStatusIcon = (status) => {
    switch (status) {
      case 'pending': return <FaClock color="var(--accent-color)" />;
      case 'in_progress': return <FaSpinner color="#3B82F6" className="spin-animation" />;
      case 'completed': return <FaCheckCircle color="var(--success-color)" />;
      default: return <FaBoxOpen color="var(--text-dim)" />;
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
      <h1 style={{ color: 'var(--text-primary)', marginBottom: '2rem' }}>الطلبات الواردة</h1>

      {error && <div style={{ color: 'var(--danger-color)', marginBottom: '1rem' }}>{error}</div>}

      {orders.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '4rem', backgroundColor: 'var(--surface-color)', borderRadius: '12px' }}>
          <FaClipboardList size={48} color="var(--text-dim)" style={{ marginBottom: '1rem' }} />
          <p style={{ color: 'var(--text-secondary)' }}>لا يوجد طلبات واردة حالياً.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {orders.map(order => (
            <div key={order.id} className="glass-card" style={styles.orderCard}>
              <div style={styles.orderHeader}>
                <div>
                  <h3 style={{ margin: '0 0 0.5rem 0' }}>طلب رقم #{order.id}</h3>
                  <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                    بواسطة: {order.customer?.name || 'زبون'} | {new Date(order.createdAt).toLocaleDateString('ar-EG')}
                  </p>
                </div>
                <div style={styles.statusBadge}>
                  {getStatusIcon(order.status)}
                  <span style={{ fontWeight: 'bold' }}>{getStatusText(order.status)}</span>
                </div>
              </div>
              
              <div style={styles.orderDetails}>
                <div style={{ flex: 1 }}>
                  <p style={{ color: 'var(--text-dim)', marginBottom: '0.25rem' }}>عنوان التوصيل</p>
                  <p style={{ fontWeight: 'bold' }}>{order.deliveryAddress || 'غير محدد'}</p>
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ color: 'var(--text-dim)', marginBottom: '0.25rem' }}>طريقة الدفع</p>
                  <p style={{ fontWeight: 'bold' }}>{order.paymentMethod || 'غير محدد'}</p>
                </div>
                <div style={{ flex: 1 }}>
                  <p style={{ color: 'var(--text-dim)', marginBottom: '0.25rem' }}>إجمالي الدخل</p>
                  <p style={{ fontWeight: 'bold', color: 'var(--success-color)' }}>{parseFloat(order.totalPrice || 0).toFixed(2)} د.أ</p>
                </div>
              </div>

              {/* Items List */}
              {order.OrderItems && order.OrderItems.length > 0 && (
                <div style={styles.itemsList}>
                  <p style={{ fontWeight: 'bold', marginBottom: '0.5rem' }}>المنتجات المطلوبة:</p>
                  {order.OrderItems.map(item => (
                    <div key={item.id} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                      <span>{item.quantity}x {item.Product?.titleAr || 'منتج'}</span>
                      <span>{(item.price * item.quantity).toFixed(2)} د.أ</span>
                    </div>
                  ))}
                </div>
              )}
              
              {/* Action Buttons */}
              <div style={styles.actions}>
                {order.status === 'pending' && (
                  <button onClick={() => handleUpdateStatus(order.id, 'in_progress')} className="btn-primary" style={{ backgroundColor: '#3B82F6' }}>
                    بدء التنفيذ
                  </button>
                )}
                {order.status === 'in_progress' && (
                  <button onClick={() => handleUpdateStatus(order.id, 'completed')} className="btn-primary" style={{ backgroundColor: 'var(--success-color)' }}>
                    اكتمل
                  </button>
                )}
              </div>
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
    flexWrap: 'wrap',
    gap: '1.5rem',
    marginBottom: '1rem',
  },
  itemsList: {
    backgroundColor: 'var(--bg-color)',
    padding: '1rem',
    borderRadius: '8px',
    marginBottom: '1rem',
  },
  actions: {
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '1rem',
    borderTop: '1px solid var(--border-color)',
    paddingTop: '1rem',
  }
};

export default ArtisanOrders;

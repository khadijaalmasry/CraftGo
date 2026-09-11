import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';

const CustomOrderForm = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [craftsmen, setCraftsmen] = useState([]);
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);
  const [formData, setFormData] = useState({
    artisanId: '',
    description: '',
    preferredDeadline: '',
    budget: '',
  });

  useEffect(() => {
    api.get('/craftsmen').then(res => {
      const data = res.data;
      setCraftsmen(Array.isArray(data) ? data : (data.craftsmen || data.data || []));
    }).catch(() => {});
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.post('/custom-orders/requests', {
        ...formData,
        budget: parseFloat(formData.budget),
      });
      setSuccess(true);
    } catch (err) {
      alert('حدث خطأ أثناء إرسال الطلب.');
    } finally {
      setLoading(false);
    }
  };

  if (success) return (
    <div className="container fade-in" style={{ padding: '4rem 1.5rem', textAlign: 'center', minHeight: '70vh' }}>
      <div style={{ fontSize: '4rem', marginBottom: '1rem' }}>✅</div>
      <h2>تم إرسال طلبك بنجاح!</h2>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
        سيتواصل معك الحرفي قريباً بعد مراجعة طلبك وتحديد السعر.
      </p>
      <button className="btn-primary" onClick={() => navigate('/customer/custom-orders')}>
        عرض طلباتي
      </button>
    </div>
  );

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '80vh', display: 'flex', justifyContent: 'center' }}>
      <div className="glass-card" style={{ width: '100%', maxWidth: '600px', padding: '2.5rem' }}>
        <h1 style={{ marginBottom: '0.5rem' }}>طلب منتج مخصص</h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
          أخبر الحرفي بما تريده بالضبط وسيقوم بتصميمه خصيصاً لك.
        </p>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
          <div>
            <label style={styles.label}>اختر الحرفي</label>
            <select
              className="input-field"
              value={formData.artisanId}
              onChange={e => setFormData({ ...formData, artisanId: e.target.value })}
              required
            >
              <option value="">-- اختر حرفياً --</option>
              {craftsmen.map(c => (
                <option key={c.id} value={c.id}>
                  {c.name || c.User?.name || c.username}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label style={styles.label}>وصف المنتج المطلوب</label>
            <textarea
              className="input-field"
              rows="5"
              placeholder="صف المنتج الذي تريده بالتفصيل: الحجم، اللون، المادة، الاستخدام..."
              value={formData.description}
              onChange={e => setFormData({ ...formData, description: e.target.value })}
              required
            />
          </div>

          <div>
            <label style={styles.label}>الميزانية المقترحة (د.أ)</label>
            <input
              type="number"
              className="input-field"
              placeholder="مثال: 150"
              min="1"
              value={formData.budget}
              onChange={e => setFormData({ ...formData, budget: e.target.value })}
              required
            />
          </div>

          <div>
            <label style={styles.label}>الموعد المفضل للتسليم</label>
            <input
              type="date"
              className="input-field"
              value={formData.preferredDeadline}
              min={new Date().toISOString().split('T')[0]}
              onChange={e => setFormData({ ...formData, preferredDeadline: e.target.value })}
            />
          </div>

          <button type="submit" className="btn-primary" style={{ marginTop: '0.5rem', padding: '1rem', fontSize: '1.05rem' }} disabled={loading}>
            {loading ? 'جاري الإرسال...' : 'إرسال الطلب للحرفي'}
          </button>
        </form>
      </div>
    </div>
  );
};

const styles = {
  label: { display: 'block', marginBottom: '0.5rem', fontWeight: '600', color: 'var(--text-primary)' }
};

export default CustomOrderForm;

import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { FaStar } from 'react-icons/fa';

const ReviewSubmission = () => {
  const { id } = useParams(); // orderId
  const navigate = useNavigate();
  const [rating, setRating] = useState(5);
  const [hover, setHover] = useState(5);
  const [comment, setComment] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      await api.post('/reviews', { orderId: id, rating, comment });
      alert('تم إرسال التقييم بنجاح!');
      navigate('/customer/orders');
    } catch {
      alert('حدث خطأ أثناء إرسال التقييم. قد تكون قيمت هذا الطلب مسبقاً.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container fade-in" style={{ padding: '2rem 1.5rem', minHeight: '70vh', display: 'flex', justifyContent: 'center' }}>
      <div className="glass-card" style={{ width: '100%', maxWidth: '500px', padding: '2.5rem', textAlign: 'center' }}>
        <h1 style={{ marginBottom: '1rem' }}>تقييم الحرفي</h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>
          رأيك يهمنا! كيف كانت تجربتك مع هذا الطلب؟
        </p>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '0.5rem' }}>
            {[1, 2, 3, 4, 5].map((star) => (
              <button
                key={star}
                type="button"
                style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: '2rem', color: star <= (hover || rating) ? '#FFD700' : 'var(--border-color)', transition: 'color 0.2s' }}
                onClick={() => setRating(star)}
                onMouseEnter={() => setHover(star)}
                onMouseLeave={() => setHover(rating)}
              >
                <FaStar />
              </button>
            ))}
          </div>

          <textarea
            className="input-field"
            rows="4"
            placeholder="شاركنا تفاصيل تجربتك (اختياري)..."
            value={comment}
            onChange={e => setComment(e.target.value)}
          />

          <button type="submit" className="btn-primary" disabled={loading} style={{ padding: '1rem', fontSize: '1.1rem' }}>
            {loading ? 'جاري الإرسال...' : 'إرسال التقييم'}
          </button>
        </form>
      </div>
    </div>
  );
};

export default ReviewSubmission;

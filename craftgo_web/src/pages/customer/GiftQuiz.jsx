import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { FaGift, FaMagic, FaSpinner } from 'react-icons/fa';

const GiftQuiz = () => {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [answers, setAnswers] = useState({
    recipient: '',
    occasion: '',
    budget: '',
    style: ''
  });

  const handleNext = () => setStep(step + 1);

  const handleSubmit = async () => {
    setLoading(true);
    try {
      const query = `هدية لـ ${answers.recipient} بمناسبة ${answers.occasion} بميزانية ${answers.budget} بأسلوب ${answers.style}`;
      navigate(`/search?search=${encodeURIComponent(query)}`);
    } catch {
      alert('حدث خطأ.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container fade-in" style={{ padding: '4rem 1.5rem', minHeight: '80vh', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
      <div className="glass-card" style={{ width: '100%', maxWidth: '600px', padding: '3rem', textAlign: 'center' }}>
        <FaGift size={50} color="var(--accent-color)" style={{ marginBottom: '1.5rem' }} />
        <h1 style={{ marginBottom: '1rem' }}>مساعد الهدايا الذكي</h1>
        <p style={{ color: 'var(--text-secondary)', marginBottom: '2rem' }}>نجد لك الهدية المثالية بناءً على إجاباتك.</p>

        {step === 1 && (
          <div className="fade-in">
            <h3 style={{ marginBottom: '1.5rem' }}>لمن هذه الهدية؟</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              {['رجل', 'امرأة', 'طفل', 'صديق', 'عائلة'].map(opt => (
                <button
                  key={opt}
                  className={answers.recipient === opt ? 'btn-primary' : ''}
                  style={answers.recipient === opt ? {} : styles.optionBtn}
                  onClick={() => setAnswers({ ...answers, recipient: opt })}
                >
                  {opt}
                </button>
              ))}
            </div>
            <button className="btn-primary" style={{ marginTop: '2rem', width: '100%' }} disabled={!answers.recipient} onClick={handleNext}>التالي</button>
          </div>
        )}

        {step === 2 && (
          <div className="fade-in">
            <h3 style={{ marginBottom: '1.5rem' }}>ما هي المناسبة؟</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              {['عيد ميلاد', 'زواج', 'تخرج', 'ذكرى سنوية', 'بدون مناسبة'].map(opt => (
                <button
                  key={opt}
                  className={answers.occasion === opt ? 'btn-primary' : ''}
                  style={answers.occasion === opt ? {} : styles.optionBtn}
                  onClick={() => setAnswers({ ...answers, occasion: opt })}
                >
                  {opt}
                </button>
              ))}
            </div>
            <button className="btn-primary" style={{ marginTop: '2rem', width: '100%' }} disabled={!answers.occasion} onClick={handleNext}>التالي</button>
          </div>
        )}

        {step === 3 && (
          <div className="fade-in">
            <h3 style={{ marginBottom: '1.5rem' }}>ما هي ميزانيتك التقريبية (د.أ)؟</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              {['أقل من 20', '20 - 50', '50 - 100', 'أكثر من 100'].map(opt => (
                <button
                  key={opt}
                  className={answers.budget === opt ? 'btn-primary' : ''}
                  style={answers.budget === opt ? {} : styles.optionBtn}
                  onClick={() => setAnswers({ ...answers, budget: opt })}
                >
                  {opt}
                </button>
              ))}
            </div>
            <button className="btn-primary" style={{ marginTop: '2rem', width: '100%' }} disabled={!answers.budget} onClick={handleNext}>التالي</button>
          </div>
        )}

        {step === 4 && (
          <div className="fade-in">
            <h3 style={{ marginBottom: '1.5rem' }}>ما هو الأسلوب المفضل؟</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              {['تقليدي', 'حديث', 'فني', 'بسيط', 'فخم'].map(opt => (
                <button
                  key={opt}
                  className={answers.style === opt ? 'btn-primary' : ''}
                  style={answers.style === opt ? {} : styles.optionBtn}
                  onClick={() => setAnswers({ ...answers, style: opt })}
                >
                  {opt}
                </button>
              ))}
            </div>
            <button className="btn-primary" style={{ marginTop: '2rem', width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem' }} disabled={!answers.style || loading} onClick={handleSubmit}>
              {loading ? <FaSpinner className="spin-animation" /> : <FaMagic />} {loading ? 'جاري البحث...' : 'اكتشف الهدايا'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

const styles = {
  optionBtn: {
    padding: '1rem',
    backgroundColor: 'var(--bg-color)',
    border: '1px solid var(--border-color)',
    borderRadius: '8px',
    color: 'var(--text-primary)',
    fontWeight: '600',
    cursor: 'pointer',
    transition: 'all 0.2s',
  }
};

export default GiftQuiz;

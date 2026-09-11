import React, { useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
  FaTshirt, FaGem, FaTree, FaPaintBrush, FaShoppingBasket,
  FaMugHot, FaLock, FaEnvelope, FaUser, FaPhone, FaArrowRight, FaArrowLeft, FaCheck
} from 'react-icons/fa';
import { useTheme } from '../../context/ThemeContext';
import api from '../../services/api';
import { useAuth } from '../../context/AuthContext';

/* ── Craft Categories ──────────────────────────────── */
const crafts = {
  ar: [
    { id: 'crochet', icon: FaTshirt, label: 'كروشيه وحياكة', desc: 'ملابس، ألعاب، وأقمشة مطرزة يدوية.' },
    { id: 'pottery', icon: FaMugHot, label: 'فخار وسيراميك', desc: 'أواني طينية، أطباق خزفية، وتحف أرضية.' },
    { id: 'jewelry', icon: FaGem, label: 'مجوهرات وإكسسوار', desc: 'خواتم، أساور، وقلائد يدوية فاخرة.' },
    { id: 'woodwork', icon: FaTree, label: 'نجارة وأعمال خشبية', desc: 'نحت خشبي، إطارات مخصصة، وهدايا خشبية.' },
    { id: 'weaving', icon: FaShoppingBasket, label: 'نسيج وسلال', desc: 'سلال تراثية، كراسي تقليدية، وأعمال مجدولة.' },
    { id: 'painting', icon: FaPaintBrush, label: 'رسم وتزيين', desc: 'لوحات فنية، خط عربي، وديكورات زجاجية.' },
  ],
  en: [
    { id: 'crochet', icon: FaTshirt, label: 'Crochet & Knitting', desc: 'Handmade clothes, toys, and embroidered fabrics.' },
    { id: 'pottery', icon: FaMugHot, label: 'Pottery & Ceramics', desc: 'Clay pots, ceramic plates, and earthen masterpieces.' },
    { id: 'jewelry', icon: FaGem, label: 'Jewelry & Accessories', desc: 'Premium handmade rings, bracelets, and necklaces.' },
    { id: 'woodwork', icon: FaTree, label: 'Woodworking', desc: 'Wood carving, custom frames, and wooden gifts.' },
    { id: 'weaving', icon: FaShoppingBasket, label: 'Weaving & Baskets', desc: 'Straw baskets, traditional stools, and handmade mats.' },
    { id: 'painting', icon: FaPaintBrush, label: 'Painting & Decoration', desc: 'Artistic paintings, Arabic calligraphy, and glass decor.' },
  ],
};

const text = {
  ar: {
    stepInfo: 'معلوماتك الأساسية',
    stepCraft: 'ما هي حرفتك الإبداعية؟',
    subCraft: 'اختر تخصصك الرئيسي ليوجهنا نحو الطلبات المناسبة لك.',
    name: 'الاسم الكامل', email: 'البريد الإلكتروني', phone: 'رقم الهاتف',
    pass: 'كلمة المرور', confirm: 'تأكيد كلمة المرور',
    next: 'التالي', register: 'إنشاء الحساب', back: 'رجوع',
    haveAccount: 'لديك حساب؟ تسجيل الدخول',
    success: '🎉 تم إنشاء حسابك بنجاح! يمكنك الآن تسجيل الدخول.',
  },
  en: {
    stepInfo: 'Your Basic Info',
    stepCraft: 'What is your creative craft?',
    subCraft: 'Select your main craft to guide you to the right orders.',
    name: 'Full Name', email: 'Email Address', phone: 'Phone Number',
    pass: 'Password', confirm: 'Confirm Password',
    next: 'Next', register: 'Create Account', back: 'Back',
    haveAccount: 'Have an account? Sign in',
    success: '🎉 Account created successfully! You can now sign in.',
  },
};

/* ── Component ─────────────────────────────────────── */
const ArtisanRegister = () => {
  const navigate = useNavigate();
  const { isArabic } = useTheme();
  const { login } = useAuth();
  const lang = isArabic ? 'ar' : 'en';
  const t = text[lang];
  const craftList = crafts[lang];

  const [step, setStep] = useState(1); // 1 = info, 2 = craft
  const [selectedCraft, setSelectedCraft] = useState(null);
  const [form, setForm] = useState({ name: '', email: '', phone: '', password: '', confirm: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleNext = () => {
    if (!form.name || !form.email || !form.password) return setError(isArabic ? 'يرجى ملء جميع الحقول المطلوبة' : 'Please fill all required fields');
    if (form.password !== form.confirm) return setError(isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match');
    setError('');
    setStep(2);
  };

  const handleSubmit = async () => {
    if (!selectedCraft) return setError(isArabic ? 'الرجاء اختيار تخصصك' : 'Please select your craft');
    setLoading(true);
    setError('');
    try {
      await api.post('/auth/register', {
        name: form.name,
        email: form.email,
        phone: form.phone,
        password: form.password,
        role: 'craftsman',
        specialty: selectedCraft,
      });
      alert(t.success);
      await login(form.email, form.password);
      navigate('/artisan/dashboard');
    } catch (err) {
      setError(err.response?.data?.message || (isArabic ? 'حدث خطأ، حاول مجدداً' : 'An error occurred, try again'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ ...styles.wrapper, direction: isArabic ? 'rtl' : 'ltr' }} className="fade-in">

      {/* Step 1: Basic Info */}
      {step === 1 && (
        <div style={styles.card} className="glass-card">
          <button onClick={() => navigate('/role-selection')} style={styles.backBtn}>
            {isArabic ? <FaArrowLeft /> : <FaArrowRight />} {t.back}
          </button>
          <h2 style={styles.cardTitle}>{t.stepInfo}</h2>

          <div style={styles.form}>
            <div style={styles.inputWrap}>
              <FaUser color="var(--text-dim)" style={styles.inputIcon} />
              <input className="input-field" placeholder={t.name} style={styles.input}
                value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} />
            </div>
            <div style={styles.inputWrap}>
              <FaEnvelope color="var(--text-dim)" style={styles.inputIcon} />
              <input className="input-field" type="email" placeholder={t.email} style={styles.input}
                value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} />
            </div>
            <div style={styles.inputWrap}>
              <FaPhone color="var(--text-dim)" style={styles.inputIcon} />
              <input className="input-field" placeholder={t.phone} style={styles.input}
                value={form.phone} onChange={e => setForm({ ...form, phone: e.target.value })} />
            </div>
            <div style={styles.inputWrap}>
              <FaLock color="var(--text-dim)" style={styles.inputIcon} />
              <input className="input-field" type="password" placeholder={t.pass} style={styles.input}
                value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} />
            </div>
            <div style={styles.inputWrap}>
              <FaLock color="var(--text-dim)" style={styles.inputIcon} />
              <input className="input-field" type="password" placeholder={t.confirm} style={styles.input}
                value={form.confirm} onChange={e => setForm({ ...form, confirm: e.target.value })} />
            </div>
          </div>

          {error && <p style={styles.error}>{error}</p>}

          <button className="btn-primary" style={styles.mainBtn} onClick={handleNext}>{t.next}</button>
          <p style={{ textAlign: 'center', marginTop: '1rem', color: 'var(--text-dim)', fontSize: '0.9rem' }}>
            <span style={{ color: 'var(--accent-color)', cursor: 'pointer' }} onClick={() => navigate('/login?role=artisan')}>
              {t.haveAccount}
            </span>
          </p>
        </div>
      )}

      {/* Step 2: Craft Selection */}
      {step === 2 && (
        <div style={styles.craftWrapper}>
          <button onClick={() => setStep(1)} style={{ ...styles.backBtn, marginBottom: '1.5rem' }}>
            {isArabic ? <FaArrowLeft /> : <FaArrowRight />} {t.back}
          </button>

          <h2 style={styles.craftTitle}>{t.stepCraft}</h2>
          <p style={styles.craftSub}>{t.subCraft}</p>

          {error && <p style={{ ...styles.error, textAlign: 'center', marginBottom: '1rem' }}>{error}</p>}

          <div style={styles.craftGrid}>
            {craftList.map(craft => {
              const Icon = craft.icon;
              const selected = selectedCraft === craft.id;
              return (
                <div
                  key={craft.id}
                  style={{
                    ...styles.craftCard,
                    border: selected ? '2px solid var(--accent-color)' : '1.5px solid rgba(255,215,0,0.08)',
                    background: selected ? 'rgba(184,134,11,0.12)' : 'var(--surface-color)',
                  }}
                  onClick={() => setSelectedCraft(craft.id)}
                >
                  <div style={{ ...styles.craftIcon, background: selected ? 'linear-gradient(135deg,#B8860B,#FFD700)' : 'rgba(255,215,0,0.08)' }}>
                    <Icon size={28} color={selected ? '#0D1420' : 'var(--accent-color)'} />
                  </div>
                  <h4 style={{ ...styles.craftLabel, color: selected ? 'var(--accent-color)' : 'var(--text-primary)' }}>{craft.label}</h4>
                  <p style={styles.craftDesc}>{craft.desc}</p>
                  {selected && (
                    <div style={styles.checkBadge}><FaCheck size={10} color="#0D1420" /></div>
                  )}
                </div>
              );
            })}
          </div>

          <button
            className="btn-primary"
            style={{ ...styles.mainBtn, maxWidth: '500px', marginTop: '2rem' }}
            onClick={handleSubmit}
            disabled={loading}
          >
            {loading ? (isArabic ? 'جارٍ التسجيل...' : 'Creating account...') : t.register}
          </button>
        </div>
      )}
    </div>
  );
};

const styles = {
  wrapper: {
    minHeight: '100vh',
    backgroundColor: 'var(--bg-color)',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '3rem 1.5rem',
  },
  card: {
    width: '100%',
    maxWidth: '480px',
    padding: '2.5rem 2rem',
  },
  backBtn: {
    background: 'none',
    color: 'var(--text-dim)',
    fontWeight: '600',
    fontSize: '0.9rem',
    display: 'flex',
    alignItems: 'center',
    gap: '0.5rem',
    marginBottom: '1.5rem',
    fontFamily: 'var(--font-primary)',
  },
  cardTitle: {
    textAlign: 'center',
    fontSize: '1.8rem',
    color: 'var(--text-primary)',
    marginBottom: '2rem',
  },
  form: { display: 'flex', flexDirection: 'column', gap: '1rem', marginBottom: '1.25rem' },
  inputWrap: { position: 'relative' },
  inputIcon: { position: 'absolute', top: '50%', transform: 'translateY(-50%)', right: '1rem', pointerEvents: 'none' },
  input: { paddingRight: '2.5rem' },
  error: { color: 'var(--danger-color)', fontSize: '0.88rem', marginBottom: '0.75rem' },
  mainBtn: { width: '100%', padding: '0.9rem', fontSize: '1.05rem' },
  craftWrapper: {
    width: '100%',
    maxWidth: '900px',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
  },
  craftTitle: {
    fontSize: '2.2rem',
    color: 'var(--accent-color)',
    textAlign: 'center',
    marginBottom: '0.5rem',
  },
  craftSub: {
    color: 'var(--text-secondary)',
    textAlign: 'center',
    marginBottom: '2rem',
    fontSize: '1rem',
  },
  craftGrid: {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
    gap: '1.25rem',
    width: '100%',
  },
  craftCard: {
    position: 'relative',
    padding: '1.75rem 1.5rem',
    borderRadius: '16px',
    cursor: 'pointer',
    transition: 'all 0.2s ease',
    textAlign: 'center',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '0.75rem',
  },
  craftIcon: {
    width: '64px',
    height: '64px',
    borderRadius: '50%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    transition: 'background 0.2s ease',
    marginBottom: '0.25rem',
  },
  craftLabel: {
    fontSize: '1rem',
    fontWeight: '700',
    fontFamily: 'var(--font-primary)',
    margin: 0,
  },
  craftDesc: {
    fontSize: '0.82rem',
    color: 'var(--text-dim)',
    margin: 0,
    lineHeight: 1.5,
  },
  checkBadge: {
    position: 'absolute',
    top: '12px',
    left: '12px',
    width: '22px',
    height: '22px',
    borderRadius: '50%',
    background: 'var(--accent-color)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  },
};

export default ArtisanRegister;

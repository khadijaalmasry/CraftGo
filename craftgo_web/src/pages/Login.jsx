import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { FaEnvelope, FaLock, FaArrowRight, FaArrowLeft, FaGlobe, FaSun, FaMoon } from 'react-icons/fa';

const text = {
  ar: {
    back: 'رجوع',
    title: {
      admin: 'دخول الإدارة',
      customer: 'دخول المستخدم',
      artisan: 'دخول الحرفي',
      delivery: 'دخول المندوب',
      exhibition: 'دخول صاحب المعرض'
    },
    email: 'البريد الإلكتروني',
    pass: 'كلمة المرور',
    login: 'دخول',
    noAccount: 'ليس لديك حساب؟ إنشاء حساب',
    error: 'خطأ في البريد الإلكتروني أو كلمة المرور',
  },
  en: {
    back: 'Back',
    title: {
      admin: 'Admin Login',
      customer: 'Customer Login',
      artisan: 'Artisan Login',
      delivery: 'Delivery Login',
      exhibition: 'Exhibition Owner Login'
    },
    email: 'Email Address',
    pass: 'Password',
    login: 'Login',
    noAccount: 'Don\'t have an account? Sign up',
    error: 'Invalid email or password',
  }
};

const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const { login } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { isDark, isArabic, toggleTheme, toggleLanguage } = useTheme();

  const lang = isArabic ? 'ar' : 'en';
  const t = text[lang];

  const queryParams = new URLSearchParams(location.search);
  const role = queryParams.get('role') || 'customer';

  const handleLogin = async (e) => {
    e.preventDefault();
    const success = await login(email, password);
    if (success) {
      if (role === 'admin') navigate('/admin/dashboard');
      else if (role === 'artisan') navigate('/artisan/dashboard');
      else navigate('/');
    } else {
      alert(t.error);
    }
  };

  return (
    <div style={{ ...styles.wrapper, direction: isArabic ? 'rtl' : 'ltr' }} className="fade-in">
      {/* ── Top Bar ─────────────────────────────────── */}
      <div style={styles.topBar}>
        <button style={styles.topBtn} onClick={toggleLanguage}>
          <FaGlobe size={14} /> {isArabic ? 'EN' : 'عربي'}
        </button>
        <button style={styles.topBtnIcon} onClick={toggleTheme} title="Toggle Theme">
          {isDark ? <FaSun size={16} color="#FFD700" /> : <FaMoon size={16} color="#1A1A2E" />}
        </button>
      </div>

      <div style={styles.card} className="glass-card">
        <button onClick={() => navigate('/role-selection')} style={styles.backBtn}>
          {isArabic ? <FaArrowRight /> : <FaArrowLeft />} {t.back}
        </button>

        <h2 style={styles.title}>{t.title[role]}</h2>

        <form onSubmit={handleLogin} style={styles.form}>
          <div style={styles.inputWrap}>
            <FaEnvelope color="var(--text-dim)" style={styles.inputIcon} />
            <input
              type="email"
              className="input-field"
              placeholder={t.email}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              style={styles.input}
            />
          </div>
          
          <div style={styles.inputWrap}>
            <FaLock color="var(--text-dim)" style={styles.inputIcon} />
            <input
              type="password"
              className="input-field"
              placeholder={t.pass}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              style={styles.input}
            />
          </div>

          <button type="submit" className="btn-primary" style={styles.mainBtn}>
            {t.login}
          </button>
        </form>

        <p style={{ textAlign: 'center', marginTop: '1.5rem', color: 'var(--accent-color)', fontWeight: 'bold', cursor: 'pointer', fontSize: '0.9rem' }}>
          {t.noAccount}
        </p>
      </div>
    </div>
  );
};

const styles = {
  wrapper: {
    minHeight: '100vh',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    backgroundColor: 'var(--bg-color)',
    padding: '1rem 1.5rem 4rem 1.5rem',
  },
  topBar: {
    width: '100%',
    display: 'flex',
    justifyContent: 'flex-end',
    gap: '0.75rem',
    marginBottom: '2rem',
  },
  topBtn: {
    background: 'rgba(128,128,128,0.12)',
    border: '1px solid rgba(128,128,128,0.2)',
    color: 'var(--text-secondary)',
    borderRadius: '20px',
    padding: '0.45rem 1rem',
    display: 'flex',
    alignItems: 'center',
    gap: '0.45rem',
    fontSize: '0.85rem',
    fontFamily: 'var(--font-primary)',
    cursor: 'pointer',
  },
  topBtnIcon: {
    background: 'rgba(128,128,128,0.12)',
    border: '1px solid rgba(128,128,128,0.2)',
    borderRadius: '50%',
    width: '38px',
    height: '38px',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  },
  card: {
    width: '100%',
    maxWidth: '420px',
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
    cursor: 'pointer',
  },
  title: {
    textAlign: 'center',
    fontSize: '1.8rem',
    color: 'var(--text-primary)',
    marginBottom: '2rem',
  },
  form: {
    display: 'flex',
    flexDirection: 'column',
    gap: '1rem',
  },
  inputWrap: {
    position: 'relative',
  },
  inputIcon: {
    position: 'absolute',
    top: '50%',
    transform: 'translateY(-50%)',
    right: '1rem',
    pointerEvents: 'none',
  },
  input: {
    paddingRight: '2.5rem',
  },
  mainBtn: {
    width: '100%',
    padding: '0.85rem',
    fontSize: '1.1rem',
    marginTop: '0.5rem',
  },
};

export default Login;

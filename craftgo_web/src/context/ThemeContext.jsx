import React, { createContext, useContext, useState, useEffect } from 'react';

const ThemeContext = createContext();

export const ThemeProvider = ({ children }) => {
  const [isDark, setIsDark] = useState(true); // default dark
  const [isArabic, setIsArabic] = useState(true); // default Arabic

  useEffect(() => {
    const html = document.documentElement;
    html.setAttribute('data-theme', isDark ? 'dark' : 'light');
    document.body.style.direction = isArabic ? 'rtl' : 'ltr';
    html.lang = isArabic ? 'ar' : 'en';
  }, [isDark, isArabic]);

  const toggleTheme = () => setIsDark(prev => !prev);
  const toggleLanguage = () => setIsArabic(prev => !prev);

  return (
    <ThemeContext.Provider value={{ isDark, isArabic, toggleTheme, toggleLanguage }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => useContext(ThemeContext);

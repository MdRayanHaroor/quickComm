import React from 'react';
import { useTheme } from './ThemeContext';
import { motion } from 'framer-motion';

const ThemeToggle: React.FC = () => {
  const { theme, toggleTheme } = useTheme();
  const isDark = theme === 'dark';

  return (
    <div 
      onClick={toggleTheme}
      style={{
        display: 'flex',
        alignItems: 'center',
        cursor: 'pointer',
        padding: '10px 18px',
        borderRadius: '10px',
        backgroundColor: 'var(--bg-surface-elevated)',
        border: '1px solid var(--border-color)',
        transition: 'all 0.3s ease',
        marginTop: 'auto'
      }}
    >
      <span style={{ flex: 1, color: 'var(--text-muted)', fontWeight: 500, fontSize: '0.9rem' }}>
        {isDark ? 'Dark Mode' : 'Light Mode'}
      </span>
      
      <div 
        style={{
          width: '40px',
          height: '24px',
          backgroundColor: isDark ? 'var(--accent-primary)' : '#D1D5DB',
          borderRadius: '12px',
          position: 'relative',
          transition: 'background-color 0.3s ease'
        }}
      >
        <motion.div 
          initial={false}
          animate={{ x: isDark ? 18 : 2 }}
          transition={{ type: "spring", stiffness: 500, damping: 30 }}
          style={{
            width: '20px',
            height: '20px',
            backgroundColor: isDark ? '#141414' : '#FFFFFF',
            borderRadius: '50%',
            position: 'absolute',
            top: '2px',
            boxShadow: '0 1px 3px rgba(0,0,0,0.3)'
          }}
        />
      </div>
    </div>
  );
};

export default ThemeToggle;

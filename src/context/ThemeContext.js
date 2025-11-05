import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext();

export const themes = {
  light: {
    primary: '#5166C6',
    background: '#FFFFFF',
    surface: '#F8F9FA',
    card: '#FFFFFF',
    text: '#2D4150',
    textSecondary: '#666666',
    border: '#E0E0E0',
    success: '#10B981',
    warning: '#F59E0B',
    error: '#EF4444',
    shadow: 'rgba(0, 0, 0, 0.1)',
    statusBar: '#5166C6',
    tabBackground: '#FFFFFF',
  },
  dark: {
    primary: '#5166C6',
    background: '#000000',
    surface: '#000000',
    card: '#1E1E1E',
    text: '#FFFFFF',
    textSecondary: '#A0A0A0',
    border: '#333333',
    success: '#10B981',
    warning: '#F59E0B',
    error: '#EF4444',
    shadow: 'rgba(255, 255, 255, 0.1)',
    statusBar: '#000000',
    tabBackground: '#1E1E1E',
  }
};

export const ThemeProvider = ({ children }) => {
  const [isDark, setIsDark] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  // Carregar tema salvo
  useEffect(() => {
    loadTheme();
  }, []);

  const loadTheme = async () => {
    try {
      const savedTheme = await AsyncStorage.getItem('app_theme');
      if (savedTheme !== null) {
        setIsDark(savedTheme === 'dark');
      }
    } catch (error) {
      console.log('Erro ao carregar tema:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const toggleTheme = async () => {
    try {
      const newTheme = !isDark;
      setIsDark(newTheme);
      await AsyncStorage.setItem('app_theme', newTheme ? 'dark' : 'light');
    } catch (error) {
      console.log('Erro ao salvar tema:', error);
    }
  };

  const currentTheme = isDark ? themes.dark : themes.light;

  return (
    <ThemeContext.Provider 
      value={{ 
        theme: currentTheme, 
        isDark, 
        toggleTheme, 
        isLoading 
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme deve ser usado dentro de ThemeProvider');
  }
  return context;
};

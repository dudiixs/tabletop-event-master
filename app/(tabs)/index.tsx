import CalendarScreen from '@src/components/CalendarScreen';
import Header from '@src/components/Header';
import HomeScreen from '@src/components/HomeScreen';
import WeeklyEventsScreen from '@src/components/WeeklyEventsScreen';
import WhatsAppButton from '@src/components/WhatsAppButton';
import { ThemeProvider, useTheme } from '@src/context/ThemeContext';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect, useState } from 'react';
import { Alert, BackHandler, StyleSheet, View } from 'react-native';

// Componente principal com tema
function AppContent() {
  const { theme, isDark } = useTheme();
  const [currentScreen, setCurrentScreen] = useState('home');
  const [eventsCache, setEventsCache] = useState<any>(null);
  const [cacheTimestamp, setCacheTimestamp] = useState<number | null>(null);
  
  const config = {
    whatsappNumber: '5515998135916',
    companyName: 'TableTop - Board & Card Games'
  };

  const CACHE_DURATION = 5 * 60 * 1000;

  const cacheConfig = {
    eventsCache,
    cacheTimestamp,
    CACHE_DURATION,
    setCache: (events: any) => {
      setEventsCache(events);
      setCacheTimestamp(Date.now());
      console.log(`💾 Cache atualizado com ${events.length} eventos`);
    },
    isValidCache: () => {
      if (!eventsCache || !cacheTimestamp) return false;
      const isExpired = (Date.now() - cacheTimestamp) > CACHE_DURATION;
      return !isExpired;
    }
  };

  // Back handler
  useEffect(() => {
    const backAction = () => {
      if (currentScreen === 'home') {
        Alert.alert(
          'Sair do App', 
          'Tem certeza que deseja sair?',
          [
            { text: 'Cancelar', onPress: () => null, style: 'cancel' },
            { text: 'Sair', onPress: () => BackHandler.exitApp() },
          ]
        );
        return true;
      } else {
        setCurrentScreen('home');
        return true;
      }
    };

    const backHandler = BackHandler.addEventListener('hardwareBackPress', backAction);
    return () => backHandler.remove();
  }, [currentScreen]);

  const renderScreen = () => {
    switch (currentScreen) {
      case 'home':
        return <HomeScreen onNavigate={setCurrentScreen} />;
      case 'monthly':
        return <CalendarScreen onBack={() => setCurrentScreen('home')} cacheConfig={cacheConfig} />;
      case 'weekly':
        return <WeeklyEventsScreen onBack={() => setCurrentScreen('home')} cacheConfig={cacheConfig} />;
      default:
        return <HomeScreen onNavigate={setCurrentScreen} />;
    }
  };

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      <StatusBar 
        style={isDark ? "light" : "light"} 
        backgroundColor={theme.statusBar} 
        translucent={false} 
      />
      <Header 
        companyName={config.companyName} 
        showBackButton={currentScreen !== 'home'}
        onBack={() => setCurrentScreen('home')}
      />
      {renderScreen()}
      <WhatsAppButton phoneNumber={config.whatsappNumber} />
    </View>
  );
}

// App principal com Provider
export default function App() {
  return (
    <ThemeProvider>
      <AppContent />
    </ThemeProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});

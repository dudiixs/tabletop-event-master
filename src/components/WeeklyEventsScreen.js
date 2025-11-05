import { useTheme } from '@src/context/ThemeContext';
import { fetchNotionEvents } from '@src/data/notionAPI';
import React, { useEffect, useState } from 'react';
import { ScrollView, StyleSheet } from 'react-native';
import EventsList from './EventsList';
import LoadingScreen from './LoadingScreen';

export default function WeeklyEventsScreen({ onBack, cacheConfig }) {
  const { theme, isDark } = useTheme();
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadWeeklyEvents();
  }, []);

  // 📅 FUNÇÃO PARA FILTRAR EVENTOS DA SEMANA (INLINE)
  const getWeeklyEvents = (notionEvents) => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const nextWeek = new Date(today);
    nextWeek.setDate(today.getDate() + 7);
    nextWeek.setHours(23, 59, 59, 999);

    const weeklyEvents = notionEvents.filter(event => {
      const eventDate = new Date(event.date);
      return eventDate >= today && eventDate <= nextWeek;
    });

    // Ordenar por data
    return weeklyEvents.sort((a, b) => {
      return new Date(a.date) - new Date(b.date);
    });
  };

  const loadWeeklyEvents = async () => {
    try {
      setLoading(true);
      
      // Verificar se tem cache válido
      if (cacheConfig && cacheConfig.isValidCache()) {
        console.log('📦 Usando dados do cache para eventos semanais!');
        const cachedEvents = cacheConfig.eventsCache;
        const weeklyEvents = getWeeklyEvents(cachedEvents);
        setEvents(weeklyEvents);
        
        setTimeout(() => {
          setLoading(false);
        }, 500);
        return;
      }
      
      // Buscar da API
      console.log('🌐 Buscando eventos semanais da API...');
      const notionEvents = await fetchNotionEvents();
      
      // Salvar no cache
      if (cacheConfig) {
        cacheConfig.setCache(notionEvents);
      }
      
      // Filtrar eventos da semana
      const weeklyEvents = getWeeklyEvents(notionEvents);
      setEvents(weeklyEvents);
      
    } catch (err) {
      console.error('💥 Erro ao carregar eventos semanais:', err);
    } finally {
      setTimeout(() => {
        setLoading(false);
      }, 1000);
    }
  };

  if (loading) {
    const isFromCache = cacheConfig && cacheConfig.isValidCache();
    
    return (
      <LoadingScreen 
        message="Carregando eventos da semana..."
        subtitle={isFromCache ? "Quase pronto!" : "Aguarde um momento"}
      />
    );
  }

  return (
    <ScrollView 
      style={[styles.container, { backgroundColor: theme.surface }]}
      showsVerticalScrollIndicator={false}
    >
      <EventsList events={events} selectedDate={null} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});

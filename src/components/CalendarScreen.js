import { useTheme } from '@src/context/ThemeContext';
import {
  fetchNotionEvents,
  getAllEventsFromNotion,
  getEventsForDateFromNotion,
  getMarkedDatesFromNotion
} from '@src/data/notionAPI';
import '@src/utils/localeConfig';
import React, { useEffect, useState } from 'react';
import { ScrollView, StyleSheet } from 'react-native';
import { Calendar } from 'react-native-calendars';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import EventsList from './EventsList';
import LoadingScreen from './LoadingScreen';

export default function CalendarScreen({ onBack, cacheConfig }) {
  const { theme, isDark } = useTheme();
  const insets = useSafeAreaInsets();
  const [selectedDate, setSelectedDate] = useState('');
  const [events, setEvents] = useState([]);
  const [allNotionEvents, setAllNotionEvents] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadNotionEvents();
  }, []);

  const loadNotionEvents = async () => {
    try {
      setLoading(true);
      
      if (cacheConfig && cacheConfig.isValidCache()) {
        console.log('📦 Usando dados do cache!');
        const cachedEvents = cacheConfig.eventsCache;
        setAllNotionEvents(cachedEvents);
        setEvents(getAllEventsFromNotion(cachedEvents));
        
        setTimeout(() => {
          setLoading(false);
        }, 500);
        return;
      }
      
      console.log('🌐 Buscando dados da API...');
      const notionEvents = await fetchNotionEvents();
      
      if (cacheConfig) {
        cacheConfig.setCache(notionEvents);
      }
      
      setAllNotionEvents(notionEvents);
      setEvents(getAllEventsFromNotion(notionEvents));
      
    } catch (err) {
      console.error('💥 Erro ao carregar eventos:', err);
    } finally {
      setTimeout(() => {
        setLoading(false);
      }, 1000);
    }
  };

  const handleDayPress = (day) => {
    const dateString = day.dateString;
    setSelectedDate(dateString);
    
    if (dateString && allNotionEvents.length > 0) {
      const dayEvents = getEventsForDateFromNotion(allNotionEvents, dateString);
      setEvents(dayEvents);
    } else {
      setEvents(getAllEventsFromNotion(allNotionEvents));
    }
  };

  const getMarkedDates = () => {
    return {
      ...getMarkedDatesFromNotion(allNotionEvents),
      [selectedDate]: {
        selected: true,
        selectedColor: theme.primary,
        marked: true,
        dotColor: '#fff'
      }
    };
  };

  if (loading) {
    const isFromCache = cacheConfig && cacheConfig.isValidCache();
    
    return (
      <LoadingScreen 
        message="Carregando eventos..."
        subtitle={isFromCache ? "Quase pronto!" : "Aguarde um momento"}
      />
    );
  }

  return (
    <ScrollView 
      style={[styles.container, { backgroundColor: theme.surface }]} 
      contentContainerStyle={{ paddingBottom: insets.bottom + 20 }}
      showsVerticalScrollIndicator={false}
    >
      <Calendar
        key={isDark ? 'dark' : 'light'}  // ✨ FORÇA RE-RENDER quando muda o tema
        style={styles.calendar}
        theme={{
          backgroundColor: theme.card,
          calendarBackground: theme.card,
          textSectionTitleColor: theme.textSecondary,
          selectedDayBackgroundColor: theme.primary,
          selectedDayTextColor: '#ffffff',
          todayTextColor: theme.primary,
          dayTextColor: theme.text,
          textDisabledColor: theme.textSecondary + '60',
          dotColor: theme.primary,
          selectedDotColor: '#ffffff',
          arrowColor: theme.primary,
          monthTextColor: theme.text,
          indicatorColor: theme.primary,
          textDayFontFamily: 'System',
          textMonthFontFamily: 'System',
          textDayHeaderFontFamily: 'System',
          textDayFontWeight: '300',
          textMonthFontWeight: 'bold',
          textDayHeaderFontWeight: '300',
          textDayFontSize: 16,
          textMonthFontSize: 16,
          textDayHeaderFontSize: 13
        }}
        onDayPress={handleDayPress}
        markedDates={getMarkedDates()}
        markingType="dot"
        hideExtraDays={true}
        firstDay={1}
      />
      
      <EventsList events={events} selectedDate={selectedDate} />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  calendar: {
    marginBottom: 10,
    paddingBottom: 10,
  },
});

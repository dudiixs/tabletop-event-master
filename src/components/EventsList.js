import React, { useState } from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity, Dimensions } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@src/context/ThemeContext';
import EventDetailsModal from './EventDetailsModal';

const { width } = Dimensions.get('window');

export default function EventsList({ events, selectedDate }) {
  const { theme, isDark } = useTheme();
  const [selectedEvent, setSelectedEvent] = useState(null);
  const [modalVisible, setModalVisible] = useState(false);

  const getCategoryInfo = (eventName, tags) => {
    const name = eventName.toLowerCase();
    const tagsList = tags ? tags.toLowerCase() : '';
    
    if (name.includes('pokémon') || name.includes('pokemon') || tagsList.includes('pokémon')) {
      return { emoji: "⚡", category: "Pokémon TCG" };
    }
    if (name.includes('digimon') || tagsList.includes('digimon')) {
      return { emoji: "🔥", category: "Digimon" };
    }
    if (name.includes('magic') || tagsList.includes('magic') || name.includes('mtg')) {
      return { emoji: "✨", category: "Magic The Gathering" };
    }
    if (name.includes('yu-gi-oh') || name.includes('yugioh') || tagsList.includes('yu-gi-oh')) {
      return { emoji: "🌟", category: "Yu-Gi-Oh!" };
    }
    if (name.includes('gundam') || tagsList.includes('gundam')) {
      return { emoji: "🤖", category: "Gundam" };
    }
    if (name.includes('board') || name.includes('tabuleiro') || tagsList.includes('board')) {
      return { emoji: "🎲", category: "Board Games" };
    }
    if (name.includes('rpg') || name.includes('d&d') || tagsList.includes('rpg')) {
      return { emoji: "🐉", category: "RPG" };
    }
    if (name.includes('torneio') || name.includes('campeonato') || name.includes('tournament')) {
      return { emoji: "🏆", category: "Torneio" };
    }
    
    return { emoji: "🎮", category: "Evento Especial" };
  };

  const formatPrice = (price) => {
    if (price === 0) return 'Gratuito';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(price);
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('pt-BR', {
      weekday: 'short',
      day: '2-digit',
      month: 'short'
    });
  };

  const getDateDisplay = (dateString) => {
    const date = new Date(dateString);
    const day = date.getDate();
    const month = date.toLocaleDateString('pt-BR', { month: 'short' }).toUpperCase();
    
    return { day, month };
  };

  const getStatusColor = (status) => {
    return status === 'available' ? theme.success : theme.error;
  };

  const getStatusText = (status) => {
    return status === 'available' ? 'Disponível' : 'Esgotado';
  };

  const handleEventPress = (event) => {
    setSelectedEvent(event);
    setModalVisible(true);
  };

  const renderEvent = ({ item, index }) => {
    const { day, month } = getDateDisplay(item.date);
    const categoryInfo = getCategoryInfo(item.name, item.tags);
    
    return (
      <TouchableOpacity 
        style={[
          styles.eventCard, 
          { 
            marginTop: index === 0 ? 0 : 12,
            backgroundColor: theme.card
          }
        ]}
        onPress={() => handleEventPress(item)}
        activeOpacity={0.7}
      >
        {/* Header do Card */}
        <View style={styles.cardHeader}>
          <View style={[
            styles.dateCircle,
            { 
              backgroundColor: theme.primary,
              shadowColor: theme.primary 
            }
          ]}>
            <Text style={styles.dateDay}>{day}</Text>
            <Text style={styles.dateMonth}>{month}</Text>
          </View>
          
          <View style={styles.headerInfo}>
            <Text style={[styles.eventName, { color: theme.text }]} numberOfLines={2}>
              {item.name}
            </Text>
            <View style={styles.timeContainer}>
              <Ionicons name="time" size={14} color={theme.primary} />
              <Text style={[styles.timeText, { color: theme.primary }]}>{item.time}</Text>
            </View>
          </View>

          <View 
            style={[
              styles.statusBadge, 
              { backgroundColor: getStatusColor(item.status) }
            ]}
          >
            <Text style={styles.statusText}>
              {getStatusText(item.status)}
            </Text>
          </View>
        </View>

        {/* Corpo do Card */}
        <View style={styles.cardBody}>
          {/* Categoria Badge */}
          <View style={[
            styles.categoryContainer,
            { backgroundColor: theme.primary + '20' }
          ]}>
            <Text style={styles.categoryEmoji}>{categoryInfo.emoji}</Text>
            <Text style={[styles.categoryText, { color: theme.primary }]}>
              {categoryInfo.category}
            </Text>
          </View>

          {/* Descrição curta */}
          <Text style={[styles.eventDescription, { color: theme.textSecondary }]} numberOfLines={2}>
            {item.description}
          </Text>
          
          {/* Footer */}
          <View style={styles.cardFooter}>
            <View style={styles.locationContainer}>
              <Ionicons name="location" size={16} color={theme.textSecondary} />
              <Text style={[styles.locationText, { color: theme.textSecondary }]} numberOfLines={1}>
                {item.location}
              </Text>
            </View>
            
            <View style={[
              styles.priceContainer,
              { 
                backgroundColor: theme.success + '20',
                borderColor: theme.success 
              }
            ]}>
              <Text style={[styles.priceText, { color: theme.success }]}>
                {formatPrice(item.price)}
              </Text>
            </View>
          </View>

          {/* Indicador de clique */}
          <View style={styles.clickIndicator}>
            <Text style={[styles.clickText, { color: theme.primary }]}>
              Toque para ver detalhes
            </Text>
            <Ionicons name="chevron-forward" size={16} color={theme.primary} />
          </View>
        </View>

        {/* Gradiente decorativo */}
        <View style={[styles.cardAccent, { backgroundColor: theme.primary }]} />
      </TouchableOpacity>
    );
  };

  const title = selectedDate 
    ? `Eventos de ${formatDate(selectedDate)}` 
    : 'Todos os Eventos';

  return (
    <View style={styles.container}>
      <View style={styles.titleContainer}>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>{title}</Text>
        {events.length > 0 && (
          <View style={[styles.countBadge, { backgroundColor: theme.primary }]}>
            <Text style={styles.countText}>{events.length}</Text>
          </View>
        )}
      </View>
      
      {events.length === 0 ? (
        <View style={styles.emptyContainer}>
          <View style={styles.emptyIcon}>
            <Ionicons name="calendar-outline" size={60} color={theme.textSecondary} />
          </View>
          <Text style={[styles.emptyTitle, { color: theme.text }]}>
            {selectedDate ? 'Nenhum evento nesta data' : 'Nenhum evento encontrado'}
          </Text>
          <Text style={[styles.emptySubtitle, { color: theme.textSecondary }]}>
            Explore outras datas no calendário para encontrar eventos incríveis!
          </Text>
        </View>
      ) : (
        <FlatList
          data={events}
          keyExtractor={(item) => item.id}
          renderItem={renderEvent}
          scrollEnabled={false}
          showsVerticalScrollIndicator={false}
        />
      )}

      {/* Modal de detalhes */}
      <EventDetailsModal
        visible={modalVisible}
        event={selectedEvent}
        onClose={() => setModalVisible(false)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingHorizontal: 16,
    paddingBottom: 100,
  },
  titleContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
    marginTop: 8,
  },
  sectionTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    flex: 1,
  },
  countBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 15,
  },
  countText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  eventCard: {
    borderRadius: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 6,
    overflow: 'hidden',
  },
  cardAccent: {
    position: 'absolute',
    top: 0,
    left: 0,
    width: 4,
    height: '100%',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    paddingBottom: 12,
  },
  dateCircle: {
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 5,
  },
  dateDay: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#fff',
    lineHeight: 20,
  },
  dateMonth: {
    fontSize: 10,
    color: '#fff',
    fontWeight: '600',
    lineHeight: 12,
    letterSpacing: 0.5,
  },
  headerInfo: {
    flex: 1,
  },
  eventName: {
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 6,
    lineHeight: 20,
  },
  timeContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  timeText: {
    fontSize: 13,
    fontWeight: '600',
    marginLeft: 4,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 20,
  },
  statusText: {
    fontSize: 10,
    color: '#fff',
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  cardBody: {
    paddingHorizontal: 16,
    paddingBottom: 16,
  },
  categoryContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    alignSelf: 'flex-start',
    marginBottom: 12,
  },
  categoryEmoji: {
    fontSize: 14,
    marginRight: 6,
  },
  categoryText: {
    fontSize: 12,
    fontWeight: '600',
  },
  eventDescription: {
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 12,
  },
  cardFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  locationContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
    marginRight: 12,
  },
  locationText: {
    fontSize: 13,
    marginLeft: 6,
    flex: 1,
  },
  priceContainer: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    borderWidth: 1,
  },
  priceText: {
    fontSize: 13,
    fontWeight: '700',
  },
  clickIndicator: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
  },
  clickText: {
    fontSize: 12,
    fontWeight: '600',
    marginRight: 4,
  },
  emptyContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 60,
    paddingHorizontal: 40,
  },
  emptyIcon: {
    marginBottom: 20,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginBottom: 8,
    textAlign: 'center',
  },
  emptySubtitle: {
    fontSize: 14,
    textAlign: 'center',
    lineHeight: 20,
  },
});

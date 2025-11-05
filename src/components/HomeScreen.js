import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@src/context/ThemeContext';
import { fetchNotionEvents } from '@src/data/notionAPI';
import React, { useEffect, useState } from 'react';
import { Dimensions, ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const { width } = Dimensions.get('window');

export default function HomeScreen({ onNavigate }) {
  const { theme, isDark } = useTheme();
  const [featuredEvent, setFeaturedEvent] = useState(null);
  const [loading, setLoading] = useState(true);
  const insets = useSafeAreaInsets();

  // 🎨 COR DO HERO MUDA CONFORME O TEMA
  const heroBgColor = isDark ? '#1E1E1E' : '#5166C6';

  useEffect(() => {
    loadRandomEvent();
  }, []);

  const loadRandomEvent = async () => {
    try {
      setLoading(true);
      const events = await fetchNotionEvents();

      if (events.length > 0) {
        // Filtrar eventos futuros
        const futureEvents = events.filter(event => {
          const eventDate = new Date(event.date);
          const today = new Date();
          today.setHours(0, 0, 0, 0);
          return eventDate >= today;
        });

        if (futureEvents.length > 0) {
          // Selecionar evento aleatório
          const randomIndex = Math.floor(Math.random() * futureEvents.length);
          setFeaturedEvent(futureEvents[randomIndex]);
        }
      }
    } catch (error) {
      console.error('Erro ao carregar evento em destaque:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatEventDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('pt-BR', {
      day: '2-digit',
      month: 'long',
      year: 'numeric'
    });
  };

  const formatPrice = (price) => {
    if (price === 0) return 'Gratuito';
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(price);
  };

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: theme.surface }]}
      contentContainerStyle={{ paddingBottom: insets.bottom + 24 }}
      showsVerticalScrollIndicator={false}
    >
      {/* Hero Section - MUDA DE COR ✨ */}
      <View style={[styles.heroSection, { backgroundColor: heroBgColor }]}>
        <View style={styles.heroContent}>
          <View style={[
            styles.heroIcon, 
            { 
              backgroundColor: isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(255, 255, 255, 0.2)',
              borderColor: isDark ? 'rgba(255, 255, 255, 0.2)' : 'rgba(255, 255, 255, 0.3)'
            }
          ]}>
            <Ionicons name="calendar" size={32} color={isDark ? '#FFFFFF' : heroBgColor} />
          </View>
          <Text style={[styles.heroTitle, { color: '#fff' }]}>Bem-vindo! 👋</Text>
          <Text style={[styles.heroSubtitle, { color: 'rgba(255, 255, 255, 0.9)' }]}>
            Descubra os melhores eventos de board games e diversão
          </Text>
        </View>
      </View>

      {/* Navegação Principal */}
      <View style={styles.navigationSection}>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>🚀 Explorar Eventos</Text>

        {/* Card Eventos da Semana */}
        <TouchableOpacity
          style={[
            styles.navCard,
            styles.weeklyCard,
            {
              backgroundColor: theme.card,
              borderLeftColor: theme.primary
            }
          ]}
          onPress={() => onNavigate('weekly')}
          activeOpacity={0.8}
        >
          <View style={styles.cardIconContainer}>
            <View style={[
              styles.cardIconBackground,
              {
                backgroundColor: theme.primary + '20',
                shadowColor: theme.primary
              }
            ]}>
              <Ionicons name="today" size={28} color={theme.primary} />
            </View>
          </View>

          <View style={styles.cardContent}>
            <Text style={[styles.cardTitle, { color: theme.text }]}>Eventos da Semana</Text>
            <Text style={[styles.cardSubtitle, { color: theme.textSecondary }]}>
              Veja o que está rolando nos próximos 7 dias
            </Text>
            <View style={[
              styles.cardBadge,
              { backgroundColor: theme.primary + '20' }
            ]}>
              <Text style={[styles.cardBadgeText, { color: theme.primary }]}>Esta Semana</Text>
            </View>
          </View>

          <Ionicons name="chevron-forward" size={24} color={theme.primary} style={styles.cardArrow} />
        </TouchableOpacity>

        {/* Card Calendário Completo */}
        <TouchableOpacity
          style={[
            styles.navCard,
            styles.monthlyCard,
            {
              backgroundColor: theme.card,
              borderLeftColor: theme.success
            }
          ]}
          onPress={() => onNavigate('monthly')}
          activeOpacity={0.8}
        >
          <View style={styles.cardIconContainer}>
            <View style={[
              styles.cardIconBackground,
              styles.monthlyIconBg,
              {
                backgroundColor: theme.success + '20',
                shadowColor: theme.success
              }
            ]}>
              <Ionicons name="calendar" size={28} color={theme.success} />
            </View>
          </View>

          <View style={styles.cardContent}>
            <Text style={[styles.cardTitle, { color: theme.text }]}>Calendário Completo</Text>
            <Text style={[styles.cardSubtitle, { color: theme.textSecondary }]}>
              Visualize todos os eventos do mês
            </Text>
            <View style={[
              styles.cardBadge,
              styles.monthlyBadge,
              { backgroundColor: theme.success + '20' }
            ]}>
              <Text style={[styles.cardBadgeText, styles.monthlyBadgeText, { color: theme.success }]}>Ver Tudo</Text>
            </View>
          </View>

          <Ionicons name="chevron-forward" size={24} color={theme.success} style={styles.cardArrow} />
        </TouchableOpacity>
      </View>

      {/* Seção de Destaque COM EVENTO REAL */}
      <View style={styles.highlightSection}>
        <View style={styles.highlightHeader}>
          <Text style={[styles.highlightTitle, { color: theme.text }]}>⭐ Em Destaque</Text>
          <TouchableOpacity onPress={loadRandomEvent} style={[
            styles.refreshButton,
            { backgroundColor: theme.primary + '20' }
          ]}>
            <Ionicons name="refresh" size={16} color={theme.primary} />
          </TouchableOpacity>
        </View>

        <View style={[
          styles.highlightCard,
          {
            backgroundColor: theme.card,
            borderTopColor: theme.warning
          }
        ]}>
          {loading ? (
            <View style={styles.loadingContainer}>
              <Text style={[styles.loadingText, { color: theme.textSecondary }]}>Carregando evento...</Text>
            </View>
          ) : featuredEvent ? (
            <View style={styles.highlightContent}>
              <Text style={[styles.highlightCardTitle, { color: theme.text }]}>
                🎲 {featuredEvent.name}
              </Text>

              <View style={styles.eventDetails}>
                <View style={styles.eventDetailItem}>
                  <Ionicons name="calendar" size={16} color={theme.primary} />
                  <Text style={[styles.eventDetailText, { color: theme.textSecondary }]}>
                    {formatEventDate(featuredEvent.date)}
                  </Text>
                </View>

                <View style={styles.eventDetailItem}>
                  <Ionicons name="time" size={16} color={theme.primary} />
                  <Text style={[styles.eventDetailText, { color: theme.textSecondary }]}>
                    {featuredEvent.time}
                  </Text>
                </View>

                <View style={styles.eventDetailItem}>
                  <Ionicons name="location" size={16} color={theme.primary} />
                  <Text style={[styles.eventDetailText, { color: theme.textSecondary }]}>
                    {featuredEvent.location}
                  </Text>
                </View>
              </View>

              <Text style={[styles.highlightText, { color: theme.textSecondary }]}>
                {featuredEvent.description}
              </Text>

              <View style={styles.eventFooter}>
                <View style={[
                  styles.priceTag,
                  {
                    backgroundColor: theme.success + '20',
                    borderColor: theme.success
                  }
                ]}>
                  <Text style={[styles.priceText, { color: theme.success }]}>
                    {formatPrice(featuredEvent.price)}
                  </Text>
                </View>

                <TouchableOpacity
                  style={[styles.highlightButton, { backgroundColor: theme.primary }]}
                  onPress={() => onNavigate('weekly')}
                >
                  <Text style={styles.highlightButtonText}>Ver Mais</Text>
                  <Ionicons name="arrow-forward" size={16} color="#fff" />
                </TouchableOpacity>
              </View>
            </View>
          ) : (
            <View style={styles.noEventContainer}>
              <Text style={[styles.noEventTitle, { color: theme.text }]}>🎲 Próximos Eventos</Text>
              <Text style={[styles.noEventText, { color: theme.textSecondary }]}>
                Não perca os eventos mais esperados! Confira nossa agenda
                completa e garanta já o seu lugar nos melhores jogos.
              </Text>
              <TouchableOpacity
                style={[styles.highlightButton, { backgroundColor: theme.primary }]}
                onPress={() => onNavigate('weekly')}
              >
                <Text style={styles.highlightButtonText}>Ver Eventos</Text>
                <Ionicons name="arrow-forward" size={16} color="#fff" />
              </TouchableOpacity>
            </View>
          )}
          <View style={[
            styles.highlightDecoration,
            { backgroundColor: theme.warning + '30' }
          ]} />
        </View>
      </View>

      {/* Features Section */}
      <View style={styles.featuresSection}>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>💎 Por que escolher nossos eventos?</Text>
        <View style={styles.featuresGrid}>
          <View style={[styles.featureItem, { backgroundColor: theme.card }]}>
            <View style={[styles.featureIcon, styles.featureIcon1, { backgroundColor: theme.primary + '20' }]}>
              <Ionicons name="people" size={24} color={theme.primary} />
            </View>
            <Text style={[styles.featureTitle, { color: theme.text }]}>Comunidade</Text>
            <Text style={[styles.featureDescription, { color: theme.textSecondary }]}>
              Encontre outros jogadores apaixonados
            </Text>
          </View>
          <View style={[styles.featureItem, { backgroundColor: theme.card }]}>
            <View style={[styles.featureIcon, styles.featureIcon2, { backgroundColor: theme.warning + '20' }]}>
              <Ionicons name="trophy" size={24} color={theme.warning} />
            </View>
            <Text style={[styles.featureTitle, { color: theme.text }]}>Qualidade</Text>
            <Text style={[styles.featureDescription, { color: theme.textSecondary }]}>
              Eventos organizados com excelência
            </Text>
          </View>
          <View style={[styles.featureItem, { backgroundColor: theme.card }]}>
            <View style={[styles.featureIcon, styles.featureIcon3, { backgroundColor: theme.success + '20' }]}>
              <Ionicons name="time" size={24} color={theme.success} />
            </View>
            <Text style={[styles.featureTitle, { color: theme.text }]}>Sempre Atual</Text>
            <Text style={[styles.featureDescription, { color: theme.textSecondary }]}>
              Agenda atualizada em tempo real
            </Text>
          </View>
          <View style={[styles.featureItem, { backgroundColor: theme.card }]}>
            <View style={[styles.featureIcon, styles.featureIcon4, { backgroundColor: theme.error + '20' }]}>
              <Ionicons name="heart" size={24} color={theme.error} />
            </View>
            <Text style={[styles.featureTitle, { color: theme.text }]}>Diversão</Text>
            <Text style={[styles.featureDescription, { color: theme.textSecondary }]}>
              Experiências inesquecíveis garantidas
            </Text>
          </View>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },

  // Hero Section
  heroSection: {
    paddingVertical: 50,
    paddingHorizontal: 20,
    marginBottom: 20,
    position: 'relative',
    overflow: 'hidden',
  },
  heroContent: {
    alignItems: 'center',
    zIndex: 1,
  },
  heroIcon: {
    width: 70,
    height: 70,
    borderRadius: 35,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
    borderWidth: 2,
  },
  heroTitle: {
    fontSize: 32,
    fontWeight: 'bold',
    marginBottom: 12,
    textAlign: 'center',
  },
  heroSubtitle: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 24,
    maxWidth: width * 0.85,
  },

  // Navigation Section
  navigationSection: {
    paddingHorizontal: 20,
    marginBottom: 30,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 24,
  },
  navCard: {
    borderRadius: 20,
    padding: 24,
    marginBottom: 20,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.1,
    shadowRadius: 15,
    elevation: 8,
    borderLeftWidth: 4,
  },
  weeklyCard: {},
  monthlyCard: {},
  cardIconContainer: {
    marginRight: 20,
  },
  cardIconBackground: {
    width: 64,
    height: 64,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 3,
  },
  monthlyIconBg: {},
  cardContent: {
    flex: 1,
  },
  cardTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  cardSubtitle: {
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 12,
  },
  cardBadge: {
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 25,
    alignSelf: 'flex-start',
  },
  cardBadgeText: {
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  monthlyBadge: {},
  monthlyBadgeText: {},
  cardArrow: {
    marginLeft: 16,
  },

  // Highlight Section
  highlightSection: {
    paddingHorizontal: 20,
    marginBottom: 30,
  },
  highlightHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  highlightTitle: {
    fontSize: 24,
    fontWeight: 'bold',
  },
  refreshButton: {
    padding: 8,
    borderRadius: 20,
  },
  highlightCard: {
    borderRadius: 20,
    padding: 28,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.1,
    shadowRadius: 15,
    elevation: 8,
    position: 'relative',
    overflow: 'hidden',
    borderTopWidth: 4,
  },
  loadingContainer: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  loadingText: {
    fontSize: 14,
  },
  highlightContent: {
    zIndex: 1,
  },
  highlightCardTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 16,
    lineHeight: 28,
  },
  eventDetails: {
    marginBottom: 16,
  },
  eventDetailItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  eventDetailText: {
    fontSize: 14,
    marginLeft: 8,
    fontWeight: '500',
  },
  highlightText: {
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 20,
  },
  eventFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  priceTag: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: 1,
  },
  priceText: {
    fontWeight: 'bold',
    fontSize: 14,
  },
  highlightButton: {
    paddingVertical: 12,
    paddingHorizontal: 20,
    borderRadius: 16,
    flexDirection: 'row',
    alignItems: 'center',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 5,
  },
  highlightButtonText: {
    color: '#fff',
    fontWeight: '700',
    fontSize: 14,
    marginRight: 8,
  },
  noEventContainer: {
    zIndex: 1,
  },
  noEventTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    marginBottom: 16,
  },
  noEventText: {
    fontSize: 15,
    lineHeight: 24,
    marginBottom: 24,
  },
  highlightDecoration: {
    position: 'absolute',
    top: -30,
    right: -30,
    width: 100,
    height: 100,
    borderRadius: 50,
    zIndex: 0,
  },

  // Features Section
  featuresSection: {
    paddingHorizontal: 20,
    paddingBottom: 120,
  },
  featuresGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  featureItem: {
    width: '48%',
    borderRadius: 16,
    padding: 24,
    marginBottom: 20,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.08,
    shadowRadius: 12,
    elevation: 5,
  },
  featureIcon: {
    width: 56,
    height: 56,
    borderRadius: 28,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  featureIcon1: {},
  featureIcon2: {},
  featureIcon3: {},
  featureIcon4: {},
  featureTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 8,
    textAlign: 'center',
  },
  featureDescription: {
    fontSize: 13,
    textAlign: 'center',
    lineHeight: 18,
  },
});

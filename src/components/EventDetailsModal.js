import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  Modal,
  ScrollView,
  TouchableOpacity,
  Linking,
  Dimensions,
  Image
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@src/context/ThemeContext';

const { width, height } = Dimensions.get('window');

export default function EventDetailsModal({ visible, event, onClose }) {
  const { theme, isDark } = useTheme();

  if (!event) return null;

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
      weekday: 'long',
      day: '2-digit',
      month: 'long',
      year: 'numeric'
    });
  };

  const openWhatsApp = () => {
    const phoneNumber = '5515998135916';
    const message = `Olá! 👋 Gostaria de mais informações sobre o evento:\n\n🎯 *${event.name}*\n📅 ${formatDate(event.date)} às ${event.time}\n📍 ${event.location}\n💰 ${formatPrice(event.price)}\n\nPoderia me dar mais detalhes?`;
    const encodedMessage = encodeURIComponent(message);
    const whatsappURL = `https://wa.me/${phoneNumber}?text=${encodedMessage}`;
    Linking.openURL(whatsappURL);
  };

  const getStatusColor = (status) => {
    return status === 'available' ? theme.success : theme.error;
  };

  const getStatusText = (status) => {
    return status === 'available' ? 'Vagas Disponíveis' : 'Esgotado';
  };

  // Verificar se tem imagem
  const hasImage = event.image && event.image.trim() !== '';

  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="slide"
      onRequestClose={onClose}
    >
      <View style={styles.modalOverlay}>
        <View style={[styles.modalContainer, { backgroundColor: theme.surface }]}>
          {/* Header do Modal */}
          <View style={[styles.modalHeader, { backgroundColor: theme.primary }]}>
            <View style={styles.headerContent}>
              <Text style={styles.modalTitle} numberOfLines={2}>
                {event.name}
              </Text>
              <TouchableOpacity
                style={styles.closeButton}
                onPress={onClose}
              >
                <Ionicons name="close" size={24} color="#fff" />
              </TouchableOpacity>
            </View>
            
            <View style={[
              styles.statusBadgeModal,
              { backgroundColor: getStatusColor(event.status) }
            ]}>
              <Text style={styles.statusTextModal}>
                {getStatusText(event.status)}
              </Text>
            </View>
          </View>

          {/* Conteúdo do Modal */}
          <ScrollView
            style={styles.modalContent}
            showsVerticalScrollIndicator={false}
          >
            {/* 📸 IMAGEM DO EVENTO (se existir) */}
            {hasImage && (
              <View style={styles.imageContainer}>
                <Image
                  source={{ uri: event.image }}
                  style={styles.eventImage}
                  resizeMode="cover"
                />
                <View style={styles.imageOverlay}>
                  <Ionicons name="image" size={20} color="#fff" />
                  <Text style={styles.imageLabel}>Imagem do Evento</Text>
                </View>
              </View>
            )}

            {/* Data e Hora */}
            <View style={[styles.infoCard, { backgroundColor: theme.card }]}>
              <View style={styles.infoRow}>
                <View style={[styles.iconCircle, { backgroundColor: theme.primary + '20' }]}>
                  <Ionicons name="calendar" size={20} color={theme.primary} />
                </View>
                <View style={styles.infoText}>
                  <Text style={[styles.infoLabel, { color: theme.textSecondary }]}>
                    Data
                  </Text>
                  <Text style={[styles.infoValue, { color: theme.text }]}>
                    {formatDate(event.date)}
                  </Text>
                </View>
              </View>

              <View style={[styles.divider, { backgroundColor: theme.border }]} />

              <View style={styles.infoRow}>
                <View style={[styles.iconCircle, { backgroundColor: theme.primary + '20' }]}>
                  <Ionicons name="time" size={20} color={theme.primary} />
                </View>
                <View style={styles.infoText}>
                  <Text style={[styles.infoLabel, { color: theme.textSecondary }]}>
                    Horário
                  </Text>
                  <Text style={[styles.infoValue, { color: theme.text }]}>
                    {event.time}
                  </Text>
                </View>
              </View>
            </View>

            {/* Local */}
            <View style={[styles.infoCard, { backgroundColor: theme.card }]}>
              <View style={styles.infoRow}>
                <View style={[styles.iconCircle, { backgroundColor: theme.primary + '20' }]}>
                  <Ionicons name="location" size={20} color={theme.primary} />
                </View>
                <View style={styles.infoText}>
                  <Text style={[styles.infoLabel, { color: theme.textSecondary }]}>
                    Local
                  </Text>
                  <Text style={[styles.infoValue, { color: theme.text }]}>
                    {event.location}
                  </Text>
                </View>
              </View>
            </View>

            {/* Preço */}
            <View style={[styles.infoCard, { backgroundColor: theme.card }]}>
              <View style={styles.infoRow}>
                <View style={[styles.iconCircle, { backgroundColor: theme.success + '20' }]}>
                  <Ionicons name="cash" size={20} color={theme.success} />
                </View>
                <View style={styles.infoText}>
                  <Text style={[styles.infoLabel, { color: theme.textSecondary }]}>
                    Valor
                  </Text>
                  <Text style={[styles.priceValueLarge, { color: theme.success }]}>
                    {formatPrice(event.price)}
                  </Text>
                </View>
              </View>
            </View>

            {/* Descrição */}
            {event.description && (
              <View style={[styles.infoCard, { backgroundColor: theme.card }]}>
                <Text style={[styles.sectionTitle, { color: theme.text }]}>
                  📝 Sobre o Evento
                </Text>
                <Text style={[styles.descriptionText, { color: theme.textSecondary }]}>
                  {event.description}
                </Text>
              </View>
            )}

            {/* Tags */}
            {event.tags && (
              <View style={[styles.infoCard, { backgroundColor: theme.card }]}>
                <Text style={[styles.sectionTitle, { color: theme.text }]}>
                  🏷️ Tags
                </Text>
                <View style={styles.tagsContainer}>
                  {event.tags.split(',').map((tag, index) => (
                    <View
                      key={index}
                      style={[styles.tag, { backgroundColor: theme.primary + '20' }]}
                    >
                      <Text style={[styles.tagText, { color: theme.primary }]}>
                        {tag.trim()}
                      </Text>
                    </View>
                  ))}
                </View>
              </View>
            )}

            {/* Espaço extra no final */}
            <View style={{ height: 20 }} />
          </ScrollView>

          {/* Footer com botão WhatsApp */}
          <View style={[styles.modalFooter, { backgroundColor: theme.surface, borderTopColor: theme.border }]}>
            <TouchableOpacity
              style={styles.whatsappButton}
              onPress={openWhatsApp}
            >
              <Ionicons name="logo-whatsapp" size={22} color="#fff" />
              <Text style={styles.whatsappButtonText}>
                Entrar em Contato
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContainer: {
    height: height * 0.85,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    overflow: 'hidden',
  },
  modalHeader: {
    paddingTop: 20,
    paddingHorizontal: 20,
    paddingBottom: 20,
  },
  headerContent: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  modalTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    flex: 1,
    marginRight: 12,
  },
  closeButton: {
    padding: 4,
  },
  statusBadgeModal: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    alignSelf: 'flex-start',
  },
  statusTextModal: {
    fontSize: 12,
    color: '#fff',
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  modalContent: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 20,
  },
  
  // 📸 ESTILOS DA IMAGEM
  imageContainer: {
    width: '100%',
    height: 220,
    borderRadius: 16,
    overflow: 'hidden',
    marginBottom: 16,
    position: 'relative',
  },
  eventImage: {
    width: '100%',
    height: '100%',
  },
  imageOverlay: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    paddingVertical: 8,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
  },
  imageLabel: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
    marginLeft: 6,
  },
  
  infoCard: {
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 3,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  infoText: {
    flex: 1,
  },
  infoLabel: {
    fontSize: 12,
    fontWeight: '600',
    marginBottom: 4,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  infoValue: {
    fontSize: 16,
    fontWeight: '600',
  },
  priceValueLarge: {
    fontSize: 22,
    fontWeight: 'bold',
  },
  divider: {
    height: 1,
    marginVertical: 16,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  descriptionText: {
    fontSize: 15,
    lineHeight: 22,
  },
  tagsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  tag: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  tagText: {
    fontSize: 12,
    fontWeight: '600',
  },
  modalFooter: {
    paddingHorizontal: 20,
    paddingVertical: 16,
    borderTopWidth: 1,
  },
  whatsappButton: {
    backgroundColor: '#25D366',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 16,
    borderRadius: 16,
    shadowColor: '#25D366',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 6,
  },
  whatsappButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '700',
    marginLeft: 8,
  },
});

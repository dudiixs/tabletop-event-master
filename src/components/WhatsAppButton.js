import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@src/context/ThemeContext';
import React from 'react';
import { Linking, StyleSheet, TouchableOpacity } from 'react-native';

export default function WhatsAppButton({ phoneNumber }) {
  const { theme, isDark } = useTheme(); // USAR TEMA

  const openWhatsApp = () => {
    const message = 'Olá! Vim através do app de eventos!';
    const url = `https://wa.me/${phoneNumber}?text=${encodeURIComponent(message)}`;
    Linking.openURL(url);
  };

  return (
    <TouchableOpacity 
      style={[
        styles.button,
        { 
          backgroundColor: '#25D366',
          shadowColor: isDark ? '#25D366' : '#000'
        }
      ]} 
      onPress={openWhatsApp}
    >
      <Ionicons name="logo-whatsapp" size={28} color="#fff" />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    width: 60,
    height: 60,
    borderRadius: 30,
    justifyContent: 'center',
    alignItems: 'center',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
});

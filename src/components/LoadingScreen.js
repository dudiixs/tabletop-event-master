import { useTheme } from '@src/context/ThemeContext';
import React, { useEffect, useRef } from 'react';
import { ActivityIndicator, Animated, Image, StyleSheet, Text, View } from 'react-native';

export default function LoadingScreen({ message = 'Carregando...', subtitle = '' }) {
  const { theme, isDark } = useTheme();
  
  // Animação de pulsação da logo
  const pulseAnim = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    // Animação de pulsação contínua
    Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.1,
          duration: 800,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 800,
          useNativeDriver: true,
        }),
      ])
    ).start();
  }, []);

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      {/* LOGO COM ANIMAÇÃO - CAMINHO CORRIGIDO */}
      <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
        <Image 
          source={require('../../assets/images/logo-azul.png')}
          style={styles.logo}
          resizeMode="contain"
        />
      </Animated.View>

      {/* LOADING INDICATOR */}
      <ActivityIndicator 
        size="large" 
        color={theme.primary} 
        style={styles.spinner}
      />
      
      {/* TEXTOS */}
      <Text style={[styles.message, { color: theme.text }]}>{message}</Text>
      {subtitle && (
        <Text style={[styles.subtitle, { color: theme.textSecondary }]}>{subtitle}</Text>
      )}

      {/* INDICADOR VISUAL */}
      <View style={styles.dotsContainer}>
        <View style={[styles.dot, { backgroundColor: theme.primary }]} />
        <View style={[styles.dot, { backgroundColor: theme.primary, opacity: 0.6 }]} />
        <View style={[styles.dot, { backgroundColor: theme.primary, opacity: 0.3 }]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  logo: {
    width: 120,
    height: 120,
    marginBottom: 20,
  },
  spinner: {
    marginVertical: 20,
  },
  message: {
    fontSize: 18,
    fontWeight: '600',
    marginTop: 20,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    marginTop: 8,
    textAlign: 'center',
  },
  dotsContainer: {
    flexDirection: 'row',
    marginTop: 30,
    gap: 8,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
});

import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Animated } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@src/context/ThemeContext';

export default function ThemeSwitch({ style }) {
  const { theme, isDark, toggleTheme } = useTheme();

  return (
    <TouchableOpacity 
      style={[styles.container, { backgroundColor: theme.surface }, style]}
      onPress={toggleTheme}
      activeOpacity={0.8}
    >
      <View style={styles.content}>
        <View style={styles.iconContainer}>
          <Ionicons 
            name={isDark ? "moon" : "sunny"} 
            size={20} 
            color={theme.primary} 
          />
        </View>
        
        <View style={styles.textContainer}>
          <Text style={[styles.title, { color: theme.text }]}>
            {isDark ? 'Modo Escuro' : 'Modo Claro'}
          </Text>
          <Text style={[styles.subtitle, { color: theme.textSecondary }]}>
            {isDark ? 'Interface escura ativa' : 'Interface clara ativa'}
          </Text>
        </View>

        <View style={[
          styles.switch, 
          { 
            backgroundColor: isDark ? theme.primary : theme.border,
            justifyContent: isDark ? 'flex-end' : 'flex-start'
          }
        ]}>
          <View style={[
            styles.switchThumb,
            { backgroundColor: theme.card }
          ]} />
        </View>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  iconContainer: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: '#F0F7FF',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  textContainer: {
    flex: 1,
  },
  title: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 2,
  },
  subtitle: {
    fontSize: 12,
    opacity: 0.7,
  },
  switch: {
    width: 50,
    height: 28,
    borderRadius: 14,
    padding: 2,
    flexDirection: 'row',
    alignItems: 'center',
  },
  switchThumb: {
    width: 24,
    height: 24,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
    elevation: 2,
  },
});

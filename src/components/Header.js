import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@src/context/ThemeContext';
import React from 'react';
import { Image, StyleSheet, TouchableOpacity, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export default function Header({
  companyName = 'TableTop',
  showBackButton = false,
  onBack
}) {
  const { theme, isDark, toggleTheme } = useTheme();
  const insets = useSafeAreaInsets();

  // 🎨 COR DO HEADER MUDA CONFORME O TEMA
  const headerBgColor = isDark ? '#1E1E1E' : '#5166C6';

  return (
    <View style={[
      styles.container,
      {
        backgroundColor: headerBgColor,
        paddingTop: insets.top + 10
      }
    ]}>
      <View style={styles.content}>
        {/* BOTÃO VOLTAR */}
        <TouchableOpacity
          style={styles.backButton}
          onPress={showBackButton ? onBack : undefined}
        >
          {showBackButton ? (
            <Ionicons name="arrow-back" size={24} color="#fff" />
          ) : (
            <View style={styles.placeholder} />
          )}
        </TouchableOpacity>

        {/* LOGO CENTRALIZADA - SEMPRE BRANCA - GRANDE ✨ */}
        <View style={styles.centerContent}>
          <Image
            source={require('../../assets/images/logo.png')}
            style={[
              styles.logoFull,
              { tintColor: '#FFFFFF' }
            ]}
            resizeMode="contain"
          />
        </View>

        {/* BOTÃO TEMA */}
        <TouchableOpacity
          style={styles.themeButton}
          onPress={toggleTheme}
        >
          <Ionicons
            name={isDark ? "sunny" : "moon"}
            size={22}
            color="#fff"
          />
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingBottom: 15,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 5,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  backButton: {
    padding: 8,
    minWidth: 40,
  },
  placeholder: {
    width: 24,
    height: 24,
  },
  centerContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginHorizontal: 8,
  },
  logoFull: {
    width: 260,    // ✨ EXTRA GRANDE!
    height: 75,    // ✨ BEM ALTO!
  },
  themeButton: {
    padding: 8,
    borderRadius: 20,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
  },
});

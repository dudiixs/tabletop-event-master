import * as Device from 'expo-device';
import * as NavigationBar from 'expo-navigation-bar';
import * as Notifications from 'expo-notifications';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect } from 'react';
import { Platform, View, useColorScheme } from 'react-native';

Notifications.setNotificationHandler({
  handleNotification: async (notification: Notifications.Notification) => {
    return {
      shouldShowAlert: true,
      shouldPlaySound: true,
      shouldSetBadge: false,
    } as Notifications.NotificationBehavior;
  },
});

export default function RootLayout() {
  const colorScheme = useColorScheme();

  useEffect(() => {
    setupNotifications();
    setupNavigationBar();
  }, [colorScheme]);

  async function setupNotifications() {
    if (!Device.isDevice) return;

    const { status } = await Notifications.requestPermissionsAsync();
    if (status !== 'granted') return;

    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('default', {
        name: 'Eventos',
        importance: Notifications.AndroidImportance.MAX,
      });
    }

    console.log('✅ Notificações ativadas!');
  }

  async function setupNavigationBar() {
    if (Platform.OS === 'android') {
      const bgColor = colorScheme === 'dark' ? '#000000' : '#FFFFFF';
      const buttonStyle = colorScheme === 'dark' ? 'light' : 'dark';
      
      await NavigationBar.setBackgroundColorAsync(bgColor);
      await NavigationBar.setButtonStyleAsync(buttonStyle);
    }
  }

  return (
    <View style={{ 
      flex: 1, 
      backgroundColor: colorScheme === 'dark' ? '#000' : '#fff' 
    }}>
      <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
      <Stack screenOptions={{ 
        headerShown: false,
        contentStyle: {
          backgroundColor: colorScheme === 'dark' ? '#000' : '#fff'
        }
      }}>
        <Stack.Screen name="index" />
      </Stack>
    </View>
  );
}

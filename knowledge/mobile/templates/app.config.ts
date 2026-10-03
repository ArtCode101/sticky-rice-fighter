// Expo app config.
//
// Configuration is EMBEDDED AT BUILD TIME, per environment, from the workspace's
// config repository. A built app cannot fetch config at runtime the way a server can.
//
// NO SECRET GOES IN HERE. A user can unpack the installed file and read every value.
// Public values only: the gateway URL and the like. Anything secret stays on the
// backend.
//
// One build per environment. A single build does not switch environments.

import type { ExpoConfig } from 'expo/config';

// Which environment this build is for. EAS sets it per build profile; locally it
// comes from the shell.
const ENV = process.env.APP_ENV ?? 'local';

// Pulled from the config repository at build time and injected as plain environment
// variables. Public values only.
const publicConfig = {
  // Always the Nginx gateway. Never a backend port.
  gatewayUrl: process.env.EXPO_PUBLIC_GATEWAY_URL,
  environment: ENV,
};

const config: ExpoConfig = {
  name: ENV === 'production' ? 'App' : `App (${ENV})`,
  slug: 'app',
  version: '0.1.0', // the store version. Increases on every submission; never reused.
  orientation: 'portrait',
  scheme: 'app',

  ios: {
    bundleIdentifier: 'com.example.app',
    // Raised on every store submission. iOS rejects a repeated build number.
    buildNumber: '1',
  },

  android: {
    package: 'com.example.app',
    // Raised on every store submission. Android rejects a repeated versionCode.
    versionCode: 1,
  },

  // Only the modules this project actually needs. expo-notifications appears here
  // only when the project asked for push.
  plugins: ['expo-camera', 'expo-image-picker'],

  extra: publicConfig,
};

export default config;

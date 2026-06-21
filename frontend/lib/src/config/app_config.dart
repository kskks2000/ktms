class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment('KTMS_API_BASE_URL');
  static const naverMapClientId = String.fromEnvironment(
    'KTMS_NAVER_MAP_CLIENT_ID',
  );

  static const firebaseProjectId = String.fromEnvironment(
    'KTMS_FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'KTMS_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseStorageBucket = String.fromEnvironment(
    'KTMS_FIREBASE_STORAGE_BUCKET',
  );

  static const firebaseWebApiKey = String.fromEnvironment(
    'KTMS_FIREBASE_WEB_API_KEY',
  );
  static const firebaseWebAppId = String.fromEnvironment(
    'KTMS_FIREBASE_WEB_APP_ID',
  );
  static const firebaseWebAuthDomain = String.fromEnvironment(
    'KTMS_FIREBASE_AUTH_DOMAIN',
  );

  static const firebaseAndroidApiKey = String.fromEnvironment(
    'KTMS_FIREBASE_ANDROID_API_KEY',
  );
  static const firebaseAndroidAppId = String.fromEnvironment(
    'KTMS_FIREBASE_ANDROID_APP_ID',
  );

  static const firebaseIosApiKey = String.fromEnvironment(
    'KTMS_FIREBASE_IOS_API_KEY',
  );
  static const firebaseIosAppId = String.fromEnvironment(
    'KTMS_FIREBASE_IOS_APP_ID',
  );
  static const firebaseIosClientId = String.fromEnvironment(
    'KTMS_FIREBASE_IOS_CLIENT_ID',
  );
  static const firebaseIosBundleId = String.fromEnvironment(
    'KTMS_FIREBASE_IOS_BUNDLE_ID',
  );
}

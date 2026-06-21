#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const toolDir = dirname(fileURLToPath(import.meta.url));
const frontendRoot = resolve(toolDir, '..');
const repoRoot = resolve(frontendRoot, '..');
const envFile = process.env.KTMS_ENV_FILE
  ? resolve(repoRoot, process.env.KTMS_ENV_FILE)
  : resolve(repoRoot, '.env');

const dartDefineCommands = new Set(['run', 'build', 'test', 'drive']);
const dartDefineKeys = [
  'KTMS_API_BASE_URL',
  'KTMS_NAVER_MAP_CLIENT_ID',
  'KTMS_FIREBASE_PROJECT_ID',
  'KTMS_FIREBASE_MESSAGING_SENDER_ID',
  'KTMS_FIREBASE_STORAGE_BUCKET',
  'KTMS_FIREBASE_AUTH_DOMAIN',
  'KTMS_FIREBASE_WEB_API_KEY',
  'KTMS_FIREBASE_WEB_APP_ID',
  'KTMS_FIREBASE_ANDROID_API_KEY',
  'KTMS_FIREBASE_ANDROID_APP_ID',
  'KTMS_FIREBASE_IOS_API_KEY',
  'KTMS_FIREBASE_IOS_APP_ID',
  'KTMS_FIREBASE_IOS_CLIENT_ID',
  'KTMS_FIREBASE_IOS_BUNDLE_ID',
];
const firebaseKeys = [
  'KTMS_FIREBASE_PROJECT_ID',
  'KTMS_FIREBASE_PROJECT_NUMBER',
  'KTMS_FIREBASE_MESSAGING_SENDER_ID',
  'KTMS_FIREBASE_STORAGE_BUCKET',
  'KTMS_FIREBASE_WEB_API_KEY',
  'KTMS_FIREBASE_WEB_APP_ID',
  'KTMS_FIREBASE_ANDROID_API_KEY',
  'KTMS_FIREBASE_ANDROID_APP_ID',
  'KTMS_FIREBASE_ANDROID_PACKAGE_NAME',
  'KTMS_FIREBASE_IOS_API_KEY',
  'KTMS_FIREBASE_IOS_APP_ID',
  'KTMS_FIREBASE_IOS_CLIENT_ID',
  'KTMS_FIREBASE_IOS_REVERSED_CLIENT_ID',
  'KTMS_FIREBASE_IOS_BUNDLE_ID',
];

const fileEnv = existsSync(envFile) ? parseDotenv(readFileSync(envFile, 'utf8')) : {};
const config = { ...fileEnv, ...process.env };
const args = process.argv.slice(2);

if (args[0] === 'prepare-firebase') {
  prepareFirebaseFiles();
  console.log('Generated Firebase platform config files from .env.');
  process.exit(0);
}

if (args.length === 0 || args.includes('--help')) {
  printUsage();
  process.exit(0);
}

const flutterArgs = [...args];
if (dartDefineCommands.has(args[0])) {
  for (const key of dartDefineKeysForCommand(args[0])) {
    const value = getConfig(key);
    if (value) {
      flutterArgs.push('--dart-define', `${key}=${value}`);
    }
  }
}

const result = spawnSync(process.env.FLUTTER_BIN || 'flutter', flutterArgs, {
  cwd: frontendRoot,
  stdio: 'inherit',
  env: process.env,
});

process.exit(result.status ?? 1);

function parseDotenv(source) {
  const values = {};
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }

    const equalsIndex = line.indexOf('=');
    if (equalsIndex <= 0) {
      continue;
    }

    const key = line.slice(0, equalsIndex).trim();
    let value = line.slice(equalsIndex + 1).trim();
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(key)) {
      continue;
    }

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    values[key] = value;
  }
  return values;
}

function getConfig(key, fallback = '') {
  return config[key] ?? fallback;
}

function dartDefineKeysForCommand(command) {
  if (command !== 'test' || getConfig('KTMS_ENABLE_API_IN_TESTS') === 'true') {
    return dartDefineKeys;
  }

  return dartDefineKeys.filter((key) => key !== 'KTMS_API_BASE_URL');
}

function prepareFirebaseFiles() {
  if (!firebaseKeys.some((key) => getConfig(key))) {
    throw new Error(`No Firebase settings found in ${envFile}.`);
  }

  const missing = [
    'KTMS_FIREBASE_PROJECT_ID',
    'KTMS_FIREBASE_MESSAGING_SENDER_ID',
    'KTMS_FIREBASE_STORAGE_BUCKET',
    'KTMS_FIREBASE_ANDROID_API_KEY',
    'KTMS_FIREBASE_ANDROID_APP_ID',
    'KTMS_FIREBASE_ANDROID_PACKAGE_NAME',
    'KTMS_FIREBASE_IOS_API_KEY',
    'KTMS_FIREBASE_IOS_APP_ID',
    'KTMS_FIREBASE_IOS_CLIENT_ID',
    'KTMS_FIREBASE_IOS_BUNDLE_ID',
  ].filter((key) => !getConfig(key));

  if (missing.length) {
    throw new Error(`Missing Firebase .env keys: ${missing.join(', ')}`);
  }

  writeIfChanged(
    resolve(frontendRoot, 'android/app/google-services.json'),
    `${JSON.stringify(androidGoogleServices(), null, 2)}\n`,
  );
  writeIfChanged(
    resolve(frontendRoot, 'ios/Runner/GoogleService-Info.plist'),
    iosGoogleServiceInfo(),
  );
  writeIfChanged(
    resolve(frontendRoot, 'ios/Flutter/KtmsEnv.xcconfig'),
    iosEnvXcconfig(),
  );
}

function androidGoogleServices() {
  const projectNumber =
    getConfig('KTMS_FIREBASE_PROJECT_NUMBER') ||
    getConfig('KTMS_FIREBASE_MESSAGING_SENDER_ID');
  const packageName = getConfig('KTMS_FIREBASE_ANDROID_PACKAGE_NAME');
  const androidClientId = getConfig('KTMS_FIREBASE_ANDROID_CLIENT_ID');
  const androidCertificateHash = getConfig(
    'KTMS_FIREBASE_ANDROID_CERTIFICATE_HASH',
  );
  const iosClientId = getConfig('KTMS_FIREBASE_IOS_CLIENT_ID');
  const iosBundleId = getConfig('KTMS_FIREBASE_IOS_BUNDLE_ID');
  const oauthClient = [];
  const otherPlatformOauthClient = [];

  if (androidClientId) {
    oauthClient.push({
      client_id: androidClientId,
      client_type: 1,
      android_info: {
        package_name: packageName,
        ...(androidCertificateHash
          ? { certificate_hash: androidCertificateHash }
          : {}),
      },
    });
  }

  if (iosClientId) {
    const iosOauth = {
      client_id: iosClientId,
      client_type: 3,
      ios_info: {
        bundle_id: iosBundleId,
      },
    };
    oauthClient.push(iosOauth);
    otherPlatformOauthClient.push(iosOauth);
  }

  return {
    project_info: {
      project_number: projectNumber,
      project_id: getConfig('KTMS_FIREBASE_PROJECT_ID'),
      storage_bucket: getConfig('KTMS_FIREBASE_STORAGE_BUCKET'),
    },
    client: [
      {
        client_info: {
          mobilesdk_app_id: getConfig('KTMS_FIREBASE_ANDROID_APP_ID'),
          android_client_info: {
            package_name: packageName,
          },
        },
        oauth_client: oauthClient,
        api_key: [
          {
            current_key: getConfig('KTMS_FIREBASE_ANDROID_API_KEY'),
          },
        ],
        services: {
          appinvite_service: {
            other_platform_oauth_client: otherPlatformOauthClient,
          },
        },
      },
    ],
    configuration_version: '1',
  };
}

function iosGoogleServiceInfo() {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CLIENT_ID</key>
\t<string>${xml(getConfig('KTMS_FIREBASE_IOS_CLIENT_ID'))}</string>
\t<key>REVERSED_CLIENT_ID</key>
\t<string>${xml(iosReversedClientId())}</string>
\t<key>API_KEY</key>
\t<string>${xml(getConfig('KTMS_FIREBASE_IOS_API_KEY'))}</string>
\t<key>GCM_SENDER_ID</key>
\t<string>${xml(getConfig('KTMS_FIREBASE_MESSAGING_SENDER_ID'))}</string>
\t<key>PLIST_VERSION</key>
\t<string>1</string>
\t<key>BUNDLE_ID</key>
\t<string>${xml(getConfig('KTMS_FIREBASE_IOS_BUNDLE_ID'))}</string>
\t<key>PROJECT_ID</key>
\t<string>${xml(getConfig('KTMS_FIREBASE_PROJECT_ID'))}</string>
\t<key>STORAGE_BUCKET</key>
\t<string>${xml(getConfig('KTMS_FIREBASE_STORAGE_BUCKET'))}</string>
\t<key>IS_ADS_ENABLED</key>
\t<false/>
\t<key>IS_ANALYTICS_ENABLED</key>
\t<false/>
\t<key>IS_APPINVITE_ENABLED</key>
\t<true/>
\t<key>IS_GCM_ENABLED</key>
\t<true/>
\t<key>IS_SIGNIN_ENABLED</key>
\t<true/>
\t<key>GOOGLE_APP_ID</key>
\t<string>${xml(getConfig('KTMS_FIREBASE_IOS_APP_ID'))}</string>
</dict>
</plist>
`;
}

function iosEnvXcconfig() {
  return `KTMS_FIREBASE_IOS_REVERSED_CLIENT_ID=${xcconfig(iosReversedClientId())}\n`;
}

function iosReversedClientId() {
  const configured = getConfig('KTMS_FIREBASE_IOS_REVERSED_CLIENT_ID');
  if (configured) {
    return configured;
  }

  const iosClientId = getConfig('KTMS_FIREBASE_IOS_CLIENT_ID');
  const suffix = '.apps.googleusercontent.com';
  if (iosClientId.endsWith(suffix)) {
    return `com.googleusercontent.apps.${iosClientId.slice(0, -suffix.length)}`;
  }
  return iosClientId;
}

function writeIfChanged(filePath, content) {
  mkdirSync(dirname(filePath), { recursive: true });
  if (existsSync(filePath) && readFileSync(filePath, 'utf8') === content) {
    return;
  }
  writeFileSync(filePath, content);
}

function xml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function xcconfig(value) {
  return String(value).replaceAll('\\n', '').replaceAll('\\r', '');
}

function printUsage() {
  console.log(`Usage:
  node tool/flutter_env.mjs run -d chrome
  node tool/flutter_env.mjs test
  node tool/flutter_env.mjs build web --release
  node tool/flutter_env.mjs prepare-firebase

Reads ${envFile} and passes only client-safe KTMS_* keys to Flutter.`);
}

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const sourceIcon = join(root, 'assets/branding/ktms-app-icon-source.png');

const webIcons = [
  ['web/favicon.png', 32],
  ['web/icons/Icon-192.png', 192],
  ['web/icons/Icon-512.png', 512],
  ['web/icons/Icon-maskable-192.png', 192],
  ['web/icons/Icon-maskable-512.png', 512],
];

const androidIcons = [
  ['android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48],
  ['android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72],
  ['android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96],
  ['android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144],
  ['android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192],
];

const iosIcons = [
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png', 20],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png', 40],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png', 60],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png', 29],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png', 58],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png', 87],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png', 40],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png', 80],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png', 120],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png', 120],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png', 180],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png', 76],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png', 152],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png', 167],
  ['ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png', 1024],
];

const allTargets = [
  ['assets/branding/ktms-app-icon-1024.png', 1024],
  ['assets/branding/ktms-app-icon-final-route-20260614.png', 1024],
  ['assets/branding/ktms-app-icon-final-route-smooth-20260614.png', 1024],
  ['assets/branding/ktms-app-icon-selected-20260614.png', 1024],
  ['assets/branding/ktms-app-icon-truck-20260614.png', 1024],
  ...webIcons,
  ...androidIcons,
  ...iosIcons,
];

if (!existsSync(sourceIcon)) {
  throw new Error(`Missing source icon: ${sourceIcon}`);
}

for (const [relativePath, size] of allTargets) {
  const outputPath = join(root, relativePath);
  mkdirSync(dirname(outputPath), { recursive: true });
  execFileSync(
    'sips',
    [
      '-s',
      'format',
      'png',
      '-z',
      String(size),
      String(size),
      sourceIcon,
      '--out',
      outputPath,
    ],
    { stdio: 'ignore' },
  );
}

console.log(`Generated ${allTargets.length} KTMS icon files.`);

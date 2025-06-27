# Icon Replacement Guide for AL-Tijwal Agent

## Android Icons
You need to replace the following Android icon files with your logo2.png, resized appropriately:

### Required Icon Sizes:
1. **android/app/src/main/res/mipmap-hdpi/ic_launcher.png** (72x72 px)
2. **android/app/src/main/res/mipmap-mdpi/ic_launcher.png** (48x48 px)  
3. **android/app/src/main/res/mipmap-xhdpi/ic_launcher.png** (96x96 px)
4. **android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png** (144x144 px)
5. **android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png** (192x192 px)

### Steps:
1. Use an image editor or online tool to resize your `icons/logo2.png` to each required size
2. Replace each `ic_launcher.png` file with the resized version
3. Keep the same filename: `ic_launcher.png`

## Web Icons
Replace these web icon files with your logo2.png:

### Required Web Icon Sizes:
1. **web/icons/Icon-192.png** (192x192 px)
2. **web/icons/Icon-512.png** (512x512 px)
3. **web/icons/Icon-maskable-192.png** (192x192 px)
4. **web/icons/Icon-maskable-512.png** (512x512 px)
5. **web/favicon.png** (32x32 px)

### Steps:
1. Resize your `icons/logo2.png` to each required size
2. Replace each file with the resized version
3. Keep the same filenames

## Automated Tools (Recommended)
You can use online tools like:
- **App Icon Generator**: https://www.appicon.co/
- **Flutter Icon**: Use the `flutter_launcher_icons` package

### Using flutter_launcher_icons package:
1. Add to pubspec.yaml:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: false  # Set to true if you have iOS
  web:
    generate: true
    image_path: "icons/logo2.png"
    background_color: "#2563EB"
    theme_color: "#2563EB"
  image_path: "icons/logo2.png"
  adaptive_icon_background: "#2563EB"
  adaptive_icon_foreground: "icons/logo2.png"
```

2. Run:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will automatically generate all the required icon sizes for you!
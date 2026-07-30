# Puesta en marcha local

## Requisitos

| Requisito | Versión | Para qué |
|---|---|---|
| Flutter SDK | 3.x | Compilar y ejecutar la aplicación |
| Dart | 3.x | Incluido con Flutter |
| Xcode | 15+ | Compilar y ejecutar en macOS |
| Visual Studio 2022 (con "Desktop development with C++") | — | Compilar y ejecutar en Windows |

## Instalación

```bash
brew install --cask flutter
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter doctor -v
```

`flutter doctor -v` debe confirmar que el SDK, y el toolchain de la plataforma en la que se
vaya a compilar (Xcode en macOS, Visual Studio en Windows), están correctamente instalados.

## Ejecutar la aplicación

```bash
flutter pub get
flutter run -d macos
# o, en Windows:
flutter run -d windows
```

## Ejecutar las pruebas

```bash
flutter test
dart analyze --fatal-infos
```

El núcleo de la aplicación (`domain/`, `core/journal/`, `core/fs/`, `core/scanner/`,
`core/preview/`) es Dart puro y no depende de Flutter, así que sus pruebas corren sin
necesidad de tener instalado Xcode ni Visual Studio — solo el SDK de Dart. Las pruebas de
widgets e integración que sí tocan `ui/` o `state/` necesitan el toolchain completo de
Flutter para la plataforma correspondiente.

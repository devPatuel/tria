# Tría

> Clasifica miles de archivos en carpetas, una pulsación de tecla cada vez — y deshaz cualquier
> decisión.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows-lightgrey)
![License](https://img.shields.io/badge/License-MIT-green)

🇬🇧 [Read in English](README.md)

## Qué es

Tría recorre una carpeta archivo por archivo y permite enviar cada uno a su destino con una
sola pulsación de tecla. Está diseñada para sostener miles de decisiones seguidas sin fatigar
ni al usuario ni a la máquina.

**No** es un organizador por IA ni un culler profesional de fotografía. Cada decisión es tuya;
Tría solo se aparta del camino.

## Por qué puedes confiarle 30.000 fotos irremplazables

- Toda operación se escribe en un diario *append-only* **antes** de ejecutarse.
- El deshacer es ilimitado dentro de una sesión, y una sesión entera se puede revertir días
  después.
- Borrar significa mover a una papelera blanda. La única acción irreversible de toda la
  aplicación es vaciar esa papelera, y antes pregunta.
- Sin red. Sin telemetría. Nada sale de tu máquina.

## Teclado

| Tecla | Acción |
|---|---|
| `1`–`9` | Mover al destino configurado |
| `↑` | Papelera blanda |
| `↓` | Posponer — se vuelve a preguntar al final de la sesión |
| `←` | Deshacer la decisión anterior |
| `→` | Dejar donde está y seguir |
| `Intro` | Abrir en el visor del sistema |
| `Espacio` | Zoom 1:1 |

## Instalación

Descarga la última versión para macOS o Windows desde [Releases](../../releases).

## Compilar desde el código fuente

Consulta [docs/SETUP.md](docs/SETUP.md).

## Documentación

| Documento | Contenido |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Capas, flujo de datos, el diario |
| [DECISIONS.md](docs/DECISIONS.md) | Registro de decisiones de arquitectura (ADR) |
| [SECURITY.md](docs/SECURITY.md) | Qué toca Tría en tu disco, y qué nunca hace |
| [TESTING.md](docs/TESTING.md) | Estrategia de pruebas |
| [RELEASE.md](docs/RELEASE.md) | Runbook de compilación y publicación |

## Licencia

MIT © Jordi Patuel Pons

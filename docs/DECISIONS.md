# Architecture Decision Records — Tría

**Proyecto**: Tría — organizador de archivos por teclado
**Autor**: Jordi Patuel Pons

---

## Índice

| # | Decisión | Estado |
|---|----------|--------|
| [ADR-001](#adr-001-flutter-desktop-como-stack) | Flutter desktop como stack | Aceptado |
| [ADR-002](#adr-002-diario-append-only-como-fuente-de-verdad) | Diario append-only como fuente de verdad | Aceptado |

---

## ADR-001: Flutter desktop como stack

**Fecha**: 2026-07-30

### Contexto

Tría necesita una interfaz fluida, control fino del teclado y un binario para macOS y
Windows. El desarrollador domina Flutter y Java.

### Decisión

**Flutter desktop (Dart)** para toda la aplicación, con el núcleo escrito en Dart puro
sin dependencias de Flutter.

### Alternativas descartadas

**Tauri (Rust + web)**
Es lo que usa el competidor con más estrellas y su tratamiento de imagen sería más
rápido, pero exige aprender Rust: la curva se come el tiempo de producto y el riesgo de
abandono del proyecto sube.

**Java + JavaFX**
El lenguaje profesional del autor, pero el empaquetado de escritorio y el ecosistema de
UI están muy por detrás en 2026.

**Swift / SwiftUI**
Máximo rendimiento e integración en macOS, pero renuncia a Windows.

---

## ADR-002: Diario append-only como fuente de verdad

**Fecha**: 2026-07-30

### Contexto

La aplicación mueve archivos irremplazables a gran velocidad. Necesita deshacer, reanudar
tras un cierre inesperado y revertir una sesión completa.

### Decisión

Un **diario append-only en JSONL** registra cada operación como intención (`pending`) y
después como resultado (`done` / `failed`). Es la única fuente de verdad sobre lo que ha
pasado; el estado en memoria se deriva de él.

### Alternativas descartadas

**Estado solo en memoria**
Simple, pero pierde todo ante un cierre inesperado y hace imposible revertir una sesión
pasada.

**SQLite**
Robusto y consultable, pero añade una dependencia nativa y complica el empaquetado para
un caso de uso que es puramente secuencial: escribir al final y leer entero.

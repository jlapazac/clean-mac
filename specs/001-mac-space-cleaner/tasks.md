---

description: "Task list for CleanMac implementation"
---

# Tasks: CleanMac — Analizador de espacio y desinstalador para macOS

**Input**: Design documents from `/specs/001-mac-space-cleaner/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/core-api.md

**Tests**: Requeridos por la constitución (principio IV) para las reglas de seguridad y la lógica de
`CleanMacCore`. Los tests usan directorios temporales y se escriben antes de la implementación.

**Organization**: Tareas agrupadas por historia de usuario.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencias)
- **[Story]**: Historia de usuario (US1, US2, US3)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Inicialización del paquete SwiftPM y scripts

- [X] T001 Crear `Package.swift` con targets `CleanMacCore` (library), `CleanMac` (executable, depende de CleanMacCore) y `CleanMacCoreTests`, plataforma macOS 14, Swift 6
- [X] T002 [P] Crear `scripts/test.sh` que ejecuta `swift test` con las rutas `-F`/`-rpath` de Testing.framework de Command Line Tools (research.md §R1)
- [X] T003 [P] Crear `Resources/Info.plist` (bundle ID `dev.cleanmac.CleanMac`, `LSMinimumSystemVersion` 14.0) y `scripts/build-app.sh` que genera y firma ad hoc `dist/CleanMac.app` (research.md §R9)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Modelos, formato de bytes, cálculo de tamaños y la capa de seguridad que usan todas las historias

**⚠️ CRITICAL**: Ninguna historia empieza hasta completar esta fase

- [X] T004 [P] Crear modelos en `Sources/CleanMacCore/Models/` (`DiskItem.swift`, `VolumeInfo.swift`, `InstalledApp.swift`, `Leftover.swift`, `CleanupCategory.swift`, `DeletionResult.swift`) según data-model.md
- [X] T005 [P] Implementar `ByteFormatting` en `Sources/CleanMacCore/Support/ByteFormatting.swift`
- [X] T006 [P] Crear helpers de fixtures (directorio temporal, crear archivos de N bytes) en `Tests/CleanMacCoreTests/TestFixtures.swift`
- [X] T007 [P] Escribir tests de `ProtectionPolicy` (rutas de sistema, home y Library en sí, subcarpetas estándar de Library, fuera de home, apps com.apple, bundle propio, rutas válidas permitidas) en `Tests/CleanMacCoreTests/ProtectionPolicyTests.swift`
- [X] T008 [P] Escribir tests de `DeletionService` con un `Trasher` falso (nunca llama al trasher con rutas protegidas, reporta fallos, suma bytes liberados, continúa tras un error) en `Tests/CleanMacCoreTests/DeletionServiceTests.swift`
- [X] T009 [P] Escribir tests de `SizeCalculator` (suma recursiva, no sigue symlinks, cuenta ilegibles) en `Tests/CleanMacCoreTests/SizeCalculatorTests.swift`
- [X] T010 Implementar `ProtectionPolicy` en `Sources/CleanMacCore/Safety/ProtectionPolicy.swift` hasta que pase T007
- [X] T011 Implementar `SizeCalculator` en `Sources/CleanMacCore/Scanning/SizeCalculator.swift` hasta que pase T009
- [X] T012 Implementar `Trasher`, `FileManagerTrasher` y `DeletionService` en `Sources/CleanMacCore/Safety/DeletionService.swift` hasta que pase T008 (depende de T010, T011)
- [X] T013 [P] Crear `ConfirmationSheet` (lista de rutas, total, botón "Mover a la Papelera") en `Sources/CleanMac/Shared/ConfirmationSheet.swift` y `SizeLabel` en `Sources/CleanMac/Shared/SizeLabel.swift`
- [X] T014 [P] Crear `SystemServices` (revelar en Finder, icono de app, apps en ejecución vía NSWorkspace) en `Sources/CleanMac/Shared/SystemServices.swift`
- [X] T015 Crear `CleanMacApp.swift` y `ContentView.swift` (NavigationSplitView con secciones Espacio, Aplicaciones, Limpieza) en `Sources/CleanMac/`

**Checkpoint**: `swift build` y `scripts/test.sh` en verde; la app abre con tres secciones vacías

---

## Phase 3: User Story 1 - Ver qué está ocupando el espacio (Priority: P1) 🎯 MVP

**Goal**: Resumen del volumen y árbol navegable de tamaños con borrado a Papelera

**Independent Test**: Analizar, navegar, comparar con `du`, mover un archivo de prueba a la Papelera

### Tests for User Story 1

- [X] T016 [P] [US1] Escribir tests de `DiskScanner` (umbral 1 MB y agregado "Otros", suma de tamaños, orden descendente, exclusiones, cancelación, `scanItem`, archivos que desaparecen durante el escaneo) en `Tests/CleanMacCoreTests/DiskScannerTests.swift`

### Implementation for User Story 1

- [X] T017 [P] [US1] Implementar `VolumeInfoProvider` en `Sources/CleanMacCore/Scanning/VolumeInfoProvider.swift`
- [X] T018 [US1] Implementar `DiskScanner` (TaskGroup en primer nivel, progreso muestreado, cancelación cooperativa, exclusión de CloudStorage/Mobile Documents, ignorar archivos que desaparecen) en `Sources/CleanMacCore/Scanning/DiskScanner.swift` hasta que pase T016
- [X] T019 [US1] Implementar `SpaceViewModel` (@MainActor @Observable: estado idle/scanning/done/cancelled, ruta de navegación, selección, borrado vía DeletionService y re-escaneo del padre) en `Sources/CleanMac/Space/SpaceViewModel.swift`
- [X] T020 [US1] Implementar `SpaceView` (barra de uso del volumen, botón Analizar/Cancelar con progreso, lista con barras de tamaño, navegación drill-down con breadcrumb, fila "Otros elementos pequeños", menú contextual "Mostrar en Finder", casillas y botón "Mover a la Papelera", aviso de ilegibles con enlace a Acceso Total al Disco) en `Sources/CleanMac/Space/SpaceView.swift`

**Checkpoint**: US1 completamente funcional (MVP)

---

## Phase 4: User Story 2 - Desinstalar una app junto con sus restos (Priority: P2)

**Goal**: Inventario de apps con tamaño total y desinstalación a la Papelera

**Independent Test**: Desinstalar una app de prueba con restos falsos en Library

### Tests for User Story 2

- [X] T021 [P] [US2] Escribir tests de `LeftoverFinder` (coincidencia exacta, sufijos `.plist`/`.savedState`, Group Containers con prefijo de equipo, coincidencias ambiguas por nombre y prefijo de organización, exclusión de bundle IDs de otras apps, nada fuera de Library) en `Tests/CleanMacCoreTests/LeftoverFinderTests.swift`
- [X] T022 [P] [US2] Escribir tests de `AppInventory` (lee bundles falsos con Info.plist, detecta com.apple, un nivel de subcarpetas) en `Tests/CleanMacCoreTests/AppInventoryTests.swift`

### Implementation for User Story 2

- [X] T023 [P] [US2] Implementar `AppInventory` en `Sources/CleanMacCore/Apps/AppInventory.swift` hasta que pase T022
- [X] T024 [P] [US2] Implementar `LeftoverFinder` en `Sources/CleanMacCore/Apps/LeftoverFinder.swift` hasta que pase T021
- [X] T025 [US2] Implementar `AppsViewModel` (carga de apps y restos en segundo plano, búsqueda, orden por nombre/tamaño, selección de restos, refresco de "en ejecución", desinstalación vía DeletionService) en `Sources/CleanMac/Apps/AppsViewModel.swift`
- [X] T026 [US2] Implementar `AppsView` (lista con icono, versión, tamaño paquete/restos/total, búsqueda, orden; apps de Apple deshabilitadas) en `Sources/CleanMac/Apps/AppsView.swift`
- [X] T027 [US2] Implementar `AppDetailView` (restos con tipo, ruta, tamaño, motivo, confianza, casillas; bloqueo si está en ejecución; confirmación y resultado) en `Sources/CleanMac/Apps/AppDetailView.swift`

**Checkpoint**: US1 y US2 funcionan de forma independiente

---

## Phase 5: User Story 3 - Limpiar cachés y datos de desarrollo regenerables (Priority: P3)

**Goal**: Categorías de limpieza con tamaño, riesgo y borrado del contenido a la Papelera

**Independent Test**: Limpiar una caché de prueba; la carpeta raíz sigue existiendo

### Tests for User Story 3

- [X] T028 [P] [US3] Escribir tests de `CleanupCatalog` (categorías de research §R7 relativas a un home falso, `measure`, `exists=false` si falta, `itemsToClean` devuelve hijos y nunca la raíz, Docker devuelve `[]`) en `Tests/CleanMacCoreTests/CleanupCatalogTests.swift`

### Implementation for User Story 3

- [X] T029 [US3] Implementar `CleanupCatalog` en `Sources/CleanMacCore/Cleanup/CleanupCatalog.swift` hasta que pase T028
- [X] T030 [US3] Implementar `CleanupViewModel` (medición en paralelo, selección, limpieza vía DeletionService, re-medición) en `Sources/CleanMac/Cleanup/CleanupViewModel.swift`
- [X] T031 [US3] Implementar `CleanupView` (tarjetas con tamaño, descripción y riesgo; Docker con instrucciones y sin casilla; categorías inexistentes como "No encontrada"; total seleccionado; confirmación y resultado) en `Sources/CleanMac/Cleanup/CleanupView.swift`

**Checkpoint**: Las tres historias funcionan

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T032 [P] Escribir `README.md` (qué hace, build, tests, empaquetado, Acceso Total al Disco, garantías de seguridad)
- [X] T033 Auditar que la única llamada de borrado del código es `FileManager.trashItem` dentro de `DeletionService` (`grep` de `removeItem`, `unlink`, `rm `), que no hay red ni procesos externos (`URLSession`, `Process`) (FR-019) y que toda acción de borrado de la UI pasa por `ConfirmationSheet`
- [X] T034 Ejecutar puertas de calidad: `swift build` sin warnings, `scripts/test.sh` verde, `scripts/build-app.sh` genera la app
- [X] T035 Validar escenarios de quickstart.md (comparación ±5 % con `du` en una carpeta real, solo lectura)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sin dependencias
- **Foundational (Phase 2)**: depende de Setup; bloquea todas las historias
- **US1 / US2 / US3 (Phases 3–5)**: dependen solo de Foundational; independientes entre sí
- **Polish (Phase 6)**: depende de las historias completadas

### Within Each User Story

- Tests antes que la implementación (deben fallar primero)
- Core (`CleanMacCore`) antes que ViewModel; ViewModel antes que View

### Parallel Opportunities

- T002, T003 en paralelo tras T001
- T004–T009 en paralelo; T013, T014 en paralelo
- Tras Foundational: US1, US2 y US3 pueden avanzar en paralelo
- Dentro de US2: T021/T022 y luego T023/T024 en paralelo

## Parallel Example: User Story 2

```bash
Task: "Tests de LeftoverFinder en Tests/CleanMacCoreTests/LeftoverFinderTests.swift"
Task: "Tests de AppInventory en Tests/CleanMacCoreTests/AppInventoryTests.swift"
# luego
Task: "AppInventory en Sources/CleanMacCore/Apps/AppInventory.swift"
Task: "LeftoverFinder en Sources/CleanMacCore/Apps/LeftoverFinder.swift"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2 (incluye toda la capa de seguridad)
2. Phase 3 (US1) → validar → ya permite saber qué borrar

### Incremental Delivery

1. US1 → análisis de espacio
2. US2 → desinstalador
3. US3 → limpieza de cachés
4. Polish → README, auditoría de borrado, empaquetado

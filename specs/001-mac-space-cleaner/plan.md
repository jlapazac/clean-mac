# Implementation Plan: CleanMac — Analizador de espacio y desinstalador para macOS

**Branch**: `001-mac-space-cleaner` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-mac-space-cleaner/spec.md`

## Summary

App nativa de macOS (SwiftUI) con tres secciones: **Espacio** (resumen del volumen + árbol de
tamaños navegable con borrado a Papelera), **Aplicaciones** (inventario de apps con restos en
`~/Library` y desinstalación) y **Limpieza** (categorías de cachés regenerables + Docker
informativo). Toda la lógica vive en la biblioteca `CleanMacCore` (sin SwiftUI), con una política de
rutas protegidas y un único punto de borrado (`DeletionService`) que solo usa
`FileManager.trashItem`. La UI es un ejecutable SwiftPM que se empaqueta como `.app` con un script.

## Technical Context

**Language/Version**: Swift 6.3 (modo de lenguaje Swift 6, concurrencia estricta)

**Primary Dependencies**: Solo frameworks de Apple: Foundation, SwiftUI, AppKit (NSWorkspace para
apps en ejecución, iconos y "Mostrar en Finder"). Sin paquetes de terceros.

**Storage**: N/A — resultados solo en memoria (FR-006c).

**Testing**: Swift Testing (`import Testing`) desde las Command Line Tools; se ejecuta con
`scripts/test.sh`, que añade las rutas del framework (ver research.md §R1).

**Target Platform**: macOS 14+ (desarrollo en macOS 26.6, arm64).

**Project Type**: desktop-app (paquete SwiftPM: biblioteca + ejecutable + tests).

**Performance Goals**: Escanear ~200 GB / ~1–2 M archivos de la carpeta personal en < 2 min en
Apple Silicon (SC-001); respuesta de la UI < 0,5 s durante el escaneo (SC-003).

**Constraints**: Sin red, sin sudo, sin borrado permanente; árbol en memoria acotado (solo nodos
≥ 1 MB + agregado "Otros" por carpeta); tamaños = espacio asignado en disco (±5 % vs `du`, SC-002).

**Scale/Scope**: Un usuario, ~3 pantallas principales + diálogos de confirmación; ~100 apps
instaladas; 6 categorías de limpieza.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principio | Cómo lo cumple el diseño | Estado |
|---|---|---|
| I. Seguridad primero | `DeletionService` es el único que borra; usa solo `trashItem`; consulta `ProtectionPolicy` antes de cada elemento; la UI exige `ConfirmationSheet`; sin sudo | ✅ |
| II. Transparencia | Cada `DiskItem`/`Leftover` lleva ruta, tamaño asignado y `reason`; "Mostrar en Finder"; `DeletionResult` con fallidos | ✅ |
| III. Nativo, local, privado | Solo frameworks de Apple; sin red; Docker informativo sin ejecutar comandos | ✅ |
| IV. Núcleo testeable | `CleanMacCore` sin SwiftUI; dependencias del sistema inyectadas (`Trasher`, `RunningAppsProvider`, rutas raíz); tests con directorios temporales | ✅ |
| V. Respuesta y rendimiento | `DiskScanner` asíncrono con `Task` cancelable y progreso por `AsyncStream`; errores de permisos agregados | ✅ |
| VI. Simplicidad | Un solo paquete SwiftPM, sin proyecto Xcode; sin persistencia | ✅ |

**Post-design re-check (tras Phase 1)**: ✅ sin violaciones. El script de tests con flags extra
no viola ningún principio (es una adaptación a la toolchain sin Xcode completo).

## Project Structure

### Documentation (this feature)

```text
specs/001-mac-space-cleaner/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── core-api.md
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
Package.swift
Sources/
├── CleanMacCore/                 # Biblioteca: lógica sin UI
│   ├── Models/
│   │   ├── DiskItem.swift
│   │   ├── VolumeInfo.swift
│   │   ├── InstalledApp.swift
│   │   ├── Leftover.swift
│   │   ├── CleanupCategory.swift
│   │   └── DeletionResult.swift
│   ├── Safety/
│   │   ├── ProtectionPolicy.swift
│   │   └── DeletionService.swift
│   ├── Scanning/
│   │   ├── SizeCalculator.swift
│   │   ├── DiskScanner.swift
│   │   └── VolumeInfoProvider.swift
│   ├── Apps/
│   │   ├── AppInventory.swift
│   │   └── LeftoverFinder.swift
│   ├── Cleanup/
│   │   └── CleanupCatalog.swift
│   └── Support/
│       └── ByteFormatting.swift
└── CleanMac/                     # Ejecutable SwiftUI
    ├── CleanMacApp.swift
    ├── ContentView.swift
    ├── Shared/
    │   ├── ConfirmationSheet.swift
    │   ├── SystemServices.swift  # NSWorkspace: running apps, iconos, Finder
    │   └── SizeLabel.swift
    ├── Space/
    │   ├── SpaceViewModel.swift
    │   └── SpaceView.swift
    ├── Apps/
    │   ├── AppsViewModel.swift
    │   ├── AppsView.swift
    │   └── AppDetailView.swift
    └── Cleanup/
        ├── CleanupViewModel.swift
        └── CleanupView.swift
Tests/
└── CleanMacCoreTests/
    ├── TestFixtures.swift
    ├── ProtectionPolicyTests.swift
    ├── DeletionServiceTests.swift
    ├── SizeCalculatorTests.swift
    ├── DiskScannerTests.swift
    ├── LeftoverFinderTests.swift
    ├── AppInventoryTests.swift
    └── CleanupCatalogTests.swift
scripts/
├── test.sh                       # swift test con rutas de Testing.framework
└── build-app.sh                  # empaqueta dist/CleanMac.app (firma ad hoc)
Resources/
└── Info.plist                    # plantilla del bundle
```

**Structure Decision**: Paquete SwiftPM único con un target biblioteca (`CleanMacCore`), un target
ejecutable (`CleanMac`) y un target de tests. Cumple el principio IV (núcleo aislado) y el VI (sin
proyecto Xcode).

## Complexity Tracking

Sin violaciones de la constitución; no aplica.

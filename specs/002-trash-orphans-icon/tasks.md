# Tasks: Vaciar Papelera, apps huérfanas e icono

## Phase 1: Setup

- [ ] T001 Enmendar constitución a v1.3.0 (vaciar Papelera) en `.specify/memory/constitution.md`

## Phase 2: User Story 1 - Vaciar la Papelera (P1)

- [ ] T002 [US1] `TrashLocation` (ruta y tamaño de ~/.Trash) en `Sources/CleanMacCore/Cleanup/TrashLocation.swift`
- [ ] T003 [US1] `TrashViewModel` + `TrashFooter` (tamaño, botón, confirmación permanente, vaciado vía Finder, refresco al activarse la app y tras cada borrado) en `Sources/CleanMac/Shared/TrashFooter.swift`
- [ ] T004 [US1] Notificar borrados (`.cleanMacDidTrash`) desde los view models y montar el pie en `ContentView`

## Phase 3: User Story 2 - Huérfanos (P2)

- [ ] T005 [P] [US2] Tests de `OrphanFinder` (extracción de identificador, ByHost, Group Containers, helpers de apps instaladas, Apple excluido, app conocida por macOS, confianza por empresa, agrupación y orden) en `Tests/CleanMacCoreTests/OrphanFinderTests.swift`
- [ ] T006 [US2] Implementar `OrphanFinder` en `Sources/CleanMacCore/Apps/OrphanFinder.swift`
- [ ] T007 [US2] `OrphansViewModel` en `Sources/CleanMac/Orphans/OrphansViewModel.swift`
- [ ] T008 [US2] `OrphansView` y entrada "Huérfanos" en el menú lateral

## Phase 4: User Story 3 - Icono (P3)

- [ ] T009 [US3] `scripts/make-icon.swift` → `Resources/AppIcon.icns` y `docs/icon.png`
- [ ] T010 [US3] `CFBundleIconFile` en `Info.plist` y copia del icono en `scripts/build-app.sh`

## Phase 5: Polish

- [ ] T011 README (nuevas funciones, icono, constitución) y verificación: build sin warnings, tests, `.app`, capturas de las secciones nuevas
- [ ] T012 Publicar en `git@github.com:jlapazac/clean-mac.git`

# Implementation Plan: Vaciar Papelera, apps huérfanas e icono

**Branch**: `002-trash-orphans-icon` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

## Summary

Se reutiliza la arquitectura de 001 (`CleanMacCore` + SwiftUI). Nuevo `OrphanFinder` en el núcleo
(con tests) que detecta identificadores de apps sin app instalada; la UI añade la sección
"Huérfanos" y un pie en la barra lateral con el tamaño de la Papelera y "Vaciar Papelera…" (vía
Finder). El icono se genera con un script Swift (CoreGraphics) y `iconutil`.

## Technical Context

**Language/Version**: Swift 6.3 · **Dependencies**: Foundation, SwiftUI, AppKit ·
**Testing**: Swift Testing (`scripts/test.sh`) · **Platform**: macOS 14+ ·
**Performance**: búsqueda de huérfanos < 30 s (SC-003): solo hijos directos de 11 carpetas +
tamaño de los candidatos.

## Constitution Check

| Principio | Cumplimiento | Estado |
|---|---|---|
| I. Seguridad | Huérfanos: misma ruta segura (confirmación + Papelera + política), nada premarcado. Vaciar Papelera: enmienda v1.3.0, botón explícito + confirmación con tamaño, lo ejecuta Finder | ✅ (con enmienda) |
| II. Transparencia | Grupo con identificador, motivo, rutas, tamaños y fecha | ✅ |
| III. Local | Sin red; Apple Events solo a Finder | ✅ |
| IV. Núcleo testeable | `OrphanFinder` en `CleanMacCore` con `isKnownApp` inyectado; tests en sandbox | ✅ |
| V. Respuesta | Búsqueda async fuera del hilo principal | ✅ |
| VI. Simplicidad | Sin dependencias; icono generado por script versionado | ✅ |

## Project Structure

```text
Sources/CleanMacCore/Apps/OrphanFinder.swift       # detección + agrupación
Sources/CleanMacCore/Cleanup/TrashLocation.swift   # ruta y tamaño de ~/.Trash
Sources/CleanMac/Shared/TrashFooter.swift          # pie de la barra lateral + TrashViewModel
Sources/CleanMac/Orphans/OrphansViewModel.swift
Sources/CleanMac/Orphans/OrphansView.swift
Tests/CleanMacCoreTests/OrphanFinderTests.swift
scripts/make-icon.swift                            # genera Resources/AppIcon.icns y docs/icon.png
```

## Research (decisiones)

- **Detección de identificador**: quitar sufijos `.plist`, `.savedState`, `.binarycookies`, sufijo
  de host en ByHost, prefijo `group.` y prefijo de equipo (10 caracteres A-Z0-9) en Group
  Containers; exigir ≥ 3 componentes con TLD en minúsculas (2–6 letras). Agrupar por los 3 primeros
  componentes.
- **App conocida**: `NSWorkspace.urlForApplication(withBundleIdentifier:)` (inyectado como closure);
  si la URL está en una Papelera, se considera no instalada.
- **Vaciar Papelera**: `tell application "Finder" to empty trash` (gestiona elementos bloqueados y
  todas las Papeleras de volúmenes); CleanMac nunca borra permanentemente por sí misma.
- **Icono**: CoreGraphics → PNGs 16–1024 → `iconutil -c icns`; sin SF Symbols (licencia).

## Complexity Tracking

| Violación | Por qué | Alternativa rechazada |
|---|---|---|
| Borrado permanente (vaciar Papelera) | Pedido explícito; sin vaciar no se libera espacio | Pedir al usuario vaciarla desde el Dock (peor UX) |

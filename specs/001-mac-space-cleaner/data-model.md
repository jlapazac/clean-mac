# Data Model: CleanMac

Todos los tipos viven en `CleanMacCore`, son `Sendable` y se mantienen solo en memoria.

## VolumeInfo

| Campo | Tipo | Notas |
|---|---|---|
| totalCapacity | Int64 | bytes |
| availableCapacity | Int64 | `volumeAvailableCapacityForImportantUsage` |
| usedCapacity | Int64 | calculado: total − disponible |

## DiskItem (nodo del árbol de análisis)

| Campo | Tipo | Notas |
|---|---|---|
| id | URL | ruta estandarizada, única en el árbol |
| name | String | nombre visible |
| size | Int64 | bytes asignados (incluye `smallItemsSize`) |
| isDirectory | Bool | |
| children | [DiskItem] | solo hijos ≥ 1 MB, ordenados por `size` desc |
| smallItemsSize | Int64 | suma de hijos < 1 MB (fila "Otros elementos pequeños") |
| smallItemsCount | Int | |
| isSkipped | Bool | carpeta excluida (nube) o ilegible |

Regla: `size == sum(children.size) + smallItemsSize` (+ tamaño propio de la carpeta).

## ScanSummary

| Campo | Tipo | Notas |
|---|---|---|
| roots | [DiskItem] | `~` y `/Applications` |
| unreadableCount | Int | errores de permiso agregados |
| fileCount | Int | |
| duration | Duration | |

## ScanProgress

`filesScanned: Int`, `bytesScanned: Int64`, `currentPath: String`.

## InstalledApp

| Campo | Tipo | Notas |
|---|---|---|
| id | URL | ruta del `.app` |
| name | String | |
| bundleIdentifier | String? | nil → sin búsqueda de restos |
| version | String? | |
| bundleSize | Int64 | |
| isAppleApp | Bool | `com.apple.*` |
| isRunning | Bool | se refresca antes de desinstalar |
| leftovers | [Leftover] | se calculan bajo demanda |
| totalSize | Int64 | bundleSize + Σ leftovers.size |
| canUninstall | Bool | !isAppleApp && !isRunning && !esCleanMac |

## Leftover

| Campo | Tipo | Notas |
|---|---|---|
| id | URL | |
| kind | LeftoverKind | applicationSupport, containers, groupContainers, caches, preferences, logs, savedState, httpStorages, webKit, cookies, launchAgents |
| size | Int64 | |
| confidence | MatchConfidence | `.high` / `.ambiguous` |
| reason | String | p. ej. "Nombre igual al identificador com.docker.docker" |

Estado de selección (UI): `high` → marcado por defecto; `ambiguous` → desmarcado.

## CleanupCategory

| Campo | Tipo | Notas |
|---|---|---|
| id | String | `npm`, `userCache`, `libraryCaches`, `xcodeDerived`, `logs`, `docker` |
| title / detail | String | descripción de qué es y qué pasa al borrar |
| paths | [URL] | raíces de la categoría |
| risk | CleanupRisk | `.low`, `.informational` |
| size | Int64 | 0 si no existe |
| exists | Bool | |
| instructions | String? | solo Docker |

## DeletionResult

| Campo | Tipo | Notas |
|---|---|---|
| trashed | [URL] | |
| failures | [DeletionFailure] | `url`, `reason` (protegida, no existe, error del sistema) |
| bytesFreed | Int64 | suma del tamaño medido de lo movido |

## Transiciones

- Análisis: `idle → scanning(progress) → done(summary) | cancelled | failed`.
- Desinstalación: `selected → leftoversLoaded → confirming → deleting → finished(result)`.
- Limpieza: `measuring → ready → confirming → deleting → finished(result) → measuring`.

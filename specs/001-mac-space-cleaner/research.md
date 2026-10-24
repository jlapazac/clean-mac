# Research: CleanMac

## R1. Framework de tests sin Xcode completo

- **Decision**: Swift Testing (`import Testing`), ejecutado vía `scripts/test.sh`, que llama a
  `swift test` con `-F`/`-rpath` hacia
  `/Library/Developer/CommandLineTools/Library/Developer/Frameworks` y `.../usr/lib`.
- **Rationale**: El equipo solo tiene Command Line Tools (`xcode-select -p` →
  `/Library/Developer/CommandLineTools`). XCTest no está disponible; `Testing.framework` sí, pero
  SwiftPM no lo encuentra sin las rutas. Verificado con un paquete de prueba (1 test en verde).
- **Alternatives**: XCTest (no disponible); instalar Xcode completo (pesa > 10 GB con el disco
  casi lleno); tests ejecutables propios (reinventar la rueda).

## R2. Cálculo de tamaño en disco

- **Decision**: `FileManager.enumerator(at:includingPropertiesForKeys:options:errorHandler:)` con
  claves `.totalFileAllocatedSizeKey` (fallback `.fileAllocatedSizeKey`), `.isDirectoryKey`,
  `.isSymbolicLinkKey`; sin seguir enlaces simbólicos; el `errorHandler` cuenta errores y devuelve
  `true` para continuar.
- **Rationale**: El tamaño asignado coincide con `du` (SC-002) y refleja correctamente archivos
  dispersos como `Docker.raw`. El handler permite omitir errores de permisos (principio V).
- **Alternatives**: `fts`/`getattrlist` en C (más rápido pero más complejo, innecesario de inicio);
  `fileSizeKey` (tamaño lógico; sobreestima archivos dispersos).
- **Nota**: Los hard links pueden contarse dos veces; es raro en la carpeta personal y se acepta.

## R3. Árbol de análisis acotado en memoria

- **Decision**: `DiskScanner` recorre recursivamente con una función que, para cada carpeta,
  calcula el tamaño de los hijos; conserva como nodos los hijos ≥ 1 MB y suma el resto en
  `smallItemsSize`. Los hijos de primer nivel de cada raíz se procesan en paralelo con
  `TaskGroup` (limitado al número de núcleos). Progreso: contador de archivos y ruta actual vía
  `AsyncStream`, muestreado como máximo cada 100 ms.
- **Rationale**: Mantiene el árbol en decenas de miles de nodos en vez de millones; cumple
  FR-006b; el paralelismo de primer nivel acelera `~/Library` y la cancelación cooperativa
  (`Task.checkCancellation`) cumple FR-004.
- **Alternatives**: Guardar todos los archivos (memoria excesiva); escaneo perezoso por nivel
  (re-escanea al navegar, peor UX).

## R4. Raíces del análisis

- **Decision**: Raíces = carpeta personal (`~`) y `/Applications`. Se excluye `~/Library/CloudStorage`
  y `~/Library/Mobile Documents` del recorrido profundo para no forzar descargas de iCloud/OneDrive
  (se muestran como no analizados).
- **Rationale**: FR-002 y supuestos de la spec; enumerar archivos de proveedores en la nube puede
  desencadenar descargas o ser lento.
- **Alternatives**: Escanear todo `/` (requiere permisos de sistema; fuera de alcance).

## R5. Inventario de apps

- **Decision**: Enumerar `*.app` en `/Applications`, `/Applications/Utilities` y `~/Applications`
  (un nivel de subcarpetas). Leer `Bundle(url:)` → `bundleIdentifier`,
  `CFBundleShortVersionString`, `CFBundleDisplayName`/`CFBundleName`. Es de Apple si el bundle ID
  empieza por `com.apple.`. Apps en ejecución vía `NSWorkspace.shared.runningApplications`
  inyectado como protocolo `RunningAppsProvider` (en el target UI).
- **Rationale**: Cubre las apps del usuario; `/System/Applications` nunca se lista (protegido).

## R6. Restos de apps

- **Decision**: Para cada carpeta de FR-008 bajo `~/Library`, listar sus hijos directos (en
  Preferences también `ByHost/`) y clasificar según FR-009:
  - Alta: `name == bundleID` o `name.hasPrefix(bundleID + ".")` (cubre `.plist`, `.savedState`,
    `.binarycookies`) o, en Group Containers, `name.hasSuffix("." + bundleID)`.
  - Ambigua: `name` igual (sin distinguir mayúsculas) al nombre de la app o al nombre del ejecutable,
    o `name` empieza por el prefijo de organización del bundle ID (dos primeros componentes, p. ej.
    `com.docker`) — solo si el prefijo tiene ≥ 2 componentes y no es un prefijo genérico como
    `com.apple`.
  - Se excluyen elementos protegidos y los que pertenecen a otra app instalada por coincidencia
    exacta de bundle ID.
- **Rationale**: Las coincidencias exactas son seguras; las difusas requieren decisión del usuario
  (principio I).

## R7. Categorías de limpieza

| ID | Nombre | Ruta(s) | Riesgo |
|---|---|---|---|
| npm | Caché de npm | `~/.npm/_cacache`, `~/.npm/_npx` | Bajo |
| userCache | Caché general (~/.cache) | `~/.cache` | Bajo |
| libraryCaches | Cachés de apps | `~/Library/Caches` | Bajo |
| xcodeDerived | Datos derivados de Xcode | `~/Library/Developer/Xcode/DerivedData` | Bajo |
| logs | Registros de usuario | `~/Library/Logs` | Bajo |
| docker | Docker (informativo) | `~/Library/Containers/com.docker.docker` | Solo informativo |

- Limpiar = mover a la Papelera cada hijo directo de la ruta (FR-013).
- Docker: muestra tamaño e instrucciones (`docker system prune -a --volumes`, o Docker Desktop →
  Settings → Resources → reducir "Virtual disk limit" / "Troubleshoot → Clean / Purge data"); no se
  ejecuta nada (FR-014, principio III).

## R8. Borrado y protecciones

- **Decision**: `DeletionService.trash(_ urls:)` resuelve rutas (`standardizedFileURL`,
  `resolvingSymlinksInPath` del padre), consulta `ProtectionPolicy`, y llama a
  `Trasher.trashItem(at:)` (por defecto `FileManager.default.trashItem`). Devuelve
  `DeletionResult` con éxitos, fallidos (motivo) y bytes liberados (tamaño medido antes).
- **ProtectionPolicy** rechaza: `/`, `/System`, `/usr`, `/bin`, `/sbin`, `/private`, `/etc`,
  `/var`, `/Library`, `/Applications` (la carpeta en sí), `/System/Applications`, la carpeta
  personal en sí, `~/Library` en sí y sus subcarpetas estándar de primer nivel (Application
  Support, Containers, Caches, Preferences, …), `~/Documents`, `~/Desktop`, `~/Downloads` en sí,
  cualquier ruta fuera de la carpeta personal salvo `.app` dentro de `/Applications` o sus subcarpetas, y `~/Applications`, apps
  `com.apple.*`, y el bundle de la propia CleanMac.
- **Rationale**: Doble barrera (UI + servicio) exigida por FR-017.

## R9. Empaquetado `.app`

- **Decision**: `scripts/build-app.sh`: `swift build -c release`, crea
  `dist/CleanMac.app/Contents/{MacOS,Resources}`, copia el binario y `Resources/Info.plist`
  (bundle ID `dev.cleanmac.CleanMac`, `LSMinimumSystemVersion` 14.0), firma ad hoc
  `codesign --force --sign - dist/CleanMac.app`.
- **Rationale**: Un bundle con identidad estable permite concederle Acceso Total al Disco.

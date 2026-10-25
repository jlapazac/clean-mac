# CleanMac

App nativa de macOS para saber **qué ocupa tu disco** y liberar espacio de forma segura.

- **Espacio**: estado del disco y ranking navegable de lo que más ocupa en tu carpeta personal y en
  Aplicaciones. Puedes marcar elementos y moverlos a la Papelera.
- **Aplicaciones**: cada app con su tamaño real (paquete + restos en `~/Library`). Al desinstalar se
  eliminan también sus restos; los ambiguos («Posible resto») quedan desmarcados para que los revises.
- **Limpieza**: cachés regenerables (npm, `~/.cache`, cachés de apps, DerivedData de Xcode,
  registros) y Docker en modo informativo, con instrucciones para recuperar su espacio.

## Garantías de seguridad

- Nada se borra de forma permanente: todo va a la **Papelera** (`FileManager.trashItem`).
- Toda eliminación pasa por una **confirmación** con la lista de rutas y el total.
- Rutas protegidas que nunca se pueden borrar: sistema (`/System`, `/usr`, `/Library`, …), tu
  carpeta personal y sus carpetas estándar en sí (Library, Documents, Descargas…), apps de Apple, la
  propia CleanMac y cualquier cosa fuera de tu carpeta personal salvo apps de terceros en
  Aplicaciones.
- Sin red, sin telemetría, sin `sudo`.

## Requisitos

macOS 14+ y Command Line Tools (`xcode-select --install`). No hace falta Xcode completo.

## Uso

```bash
scripts/build-app.sh      # genera dist/CleanMac.app (firma ad hoc)
open dist/CleanMac.app
```

Para analizar todo `~/Library`, concede **Acceso total al disco**: Ajustes del Sistema →
Privacidad y seguridad → Acceso total al disco → `+` → `CleanMac.app`. Recuerda vaciar la Papelera
para liberar realmente el espacio.

## Desarrollo

```bash
swift build
scripts/test.sh           # Swift Testing (añade las rutas del framework de Command Line Tools)
swift run CleanMac
```

Estructura: `Sources/CleanMacCore` (lógica sin UI, con tests), `Sources/CleanMac` (SwiftUI),
`Tests/CleanMacCoreTests`. Especificación y plan en `specs/001-mac-space-cleaner/`.

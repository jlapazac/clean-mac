# Quickstart: CleanMac

## Requisitos

- macOS 14+ y Command Line Tools de Xcode (`xcode-select --install`). No hace falta Xcode completo.

## Desarrollo

```bash
swift build              # compila biblioteca + app
scripts/test.sh          # ejecuta los tests (Swift Testing)
swift run CleanMac       # abre la app en modo desarrollo
```

## Generar la app

```bash
scripts/build-app.sh     # crea dist/CleanMac.app
open dist/CleanMac.app
```

Para que el análisis vea todo `~/Library`: Ajustes del Sistema → Privacidad y seguridad → Acceso
total al disco → `+` → `dist/CleanMac.app` (o moverla antes a `/Applications`).

## Validación manual (escenarios de la spec)

1. **Espacio (US1)**: Pulsar "Analizar". Ver progreso, cancelar y reanudar. Comprobar que el tamaño
   de `~/Library/Containers` coincide (±5 %) con `du -sh ~/Library/Containers`. Entrar en
   carpetas, volver, "Mostrar en Finder". Marcar un archivo de prueba y moverlo a la Papelera.
2. **Aplicaciones (US2)**: Ordenar por tamaño total. Abrir una app: ver restos con motivo; los
   ambiguos desmarcados. Intentar desinstalar una app abierta → se bloquea. Las apps de Apple no
   se pueden seleccionar.
3. **Limpieza (US3)**: Ver categorías con tamaño y riesgo. Limpiar "Caché de npm" → el contenido
   aparece en la Papelera y `~/.npm/_cacache` sigue existiendo. Docker muestra instrucciones y no
   tiene botón de borrar.
4. **Seguridad**: Ninguna acción borra sin la hoja de confirmación; todo lo borrado se puede
   "Devolver" desde la Papelera.

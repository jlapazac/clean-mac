<p align="center">
  <img src="docs/icon.png" width="128" alt="Icono de CleanMac">
</p>

# CleanMac

App nativa de macOS para saber **qué ocupa tu disco** y liberar espacio de forma segura.

- **Espacio**: estado del disco y ranking navegable de lo que más ocupa en tu carpeta personal,
  Aplicaciones y (solo consulta) las carpetas del sistema. Muestra cuánto ocupa lo que macOS no deja
  leer y permite medir carpetas de administrador con contraseña o Touch ID.
- **Aplicaciones**: cada app con su tamaño real (paquete + restos en `~/Library`). Al desinstalar se
  eliminan también sus restos; los dudosos («Posibles») quedan desmarcados.
- **Huérfanos**: restos de apps que ya desinstalaste (identificadores sin app instalada ni conocida
  por macOS), agrupados por app con tamaño y fecha. Nada viene marcado.
- **Limpieza**: cachés regenerables (npm, `~/.cache`, cachés de apps, DerivedData de Xcode,
  registros) y Docker en modo informativo.
- **Papelera**: tamaño siempre visible en la barra lateral y botón **Vaciar Papelera…**.

## Garantías de seguridad

- Todo lo que borra CleanMac va a la **Papelera**. La única acción permanente es **Vaciar
  Papelera**, con confirmación que muestra el tamaño, y la ejecuta Finder.
- Toda eliminación pasa por una **confirmación** con la lista de rutas y el total.
- Rutas protegidas que nunca se pueden borrar: sistema (`/System`, `/usr`, `/Library`, …), tu
  carpeta personal y sus carpetas estándar en sí, apps de Apple, la propia CleanMac y cualquier cosa
  fuera de tu carpeta personal salvo apps de terceros en Aplicaciones.
- Cuando macOS exige autorización (apps instaladas por `root`, carpetas de administrador), la pide
  **el sistema** (contraseña o Touch ID); CleanMac nunca ve ni guarda credenciales.
- Sin red, sin telemetría.

## Requisitos

macOS 14+ y Command Line Tools (`xcode-select --install`). No hace falta Xcode completo.

## Instalación

```bash
git clone git@github.com:jlapazac/clean-mac.git && cd clean-mac
scripts/build-app.sh                  # genera dist/CleanMac.app (firma ad hoc)
cp -R dist/CleanMac.app /Applications/
open /Applications/CleanMac.app
```

### Permisos (Ajustes del Sistema → Privacidad y seguridad)

| Permiso | Para qué |
|---|---|
| Acceso total al disco | Ver los datos de otras apps en `~/Library` y la Papelera |
| Gestión de apps | Desinstalar apps |
| Automatización → Finder | Mover a la Papelera lo protegido y vaciar la Papelera (macOS lo pregunta la primera vez) |

La firma es ad hoc: tras recompilar, quita y vuelve a agregar CleanMac en esos permisos.

## Desarrollo

```bash
swift build
scripts/test.sh                       # Swift Testing (añade las rutas del framework de Command Line Tools)
swift run CleanMac
swift scripts/make-icon.swift         # regenera Resources/AppIcon.icns y docs/icon.png
```

Estructura: `Sources/CleanMacCore` (lógica sin UI, con tests), `Sources/CleanMac` (SwiftUI),
`Tests/CleanMacCoreTests`. El proyecto sigue [Spec Kit](https://github.com/github/spec-kit):
constitución en `.specify/memory/constitution.md` y especificaciones en `specs/`.

<!--
Sync Impact Report
- Version change: (template, unversioned) → 1.0.0
- Modified principles: N/A (initial ratification)
- Added principles:
  I. Seguridad del Usuario Primero (NO NEGOCIABLE)
  II. Transparencia Total
  III. Nativo, Local y Privado
  IV. Núcleo Testeable Separado de la UI
  V. Respuesta y Rendimiento
  VI. Simplicidad
- Added sections: Restricciones Técnicas; Flujo de Desarrollo y Puertas de Calidad; Governance
- Removed sections: none
- Templates requiring updates:
  ✅ .specify/templates/plan-template.md — "Constitution Check" lee este archivo en runtime; sin cambios
  ✅ .specify/templates/spec-template.md — sin secciones obligatorias nuevas
  ✅ .specify/templates/tasks-template.md — tareas de tests ya contempladas
- Follow-up TODOs: none
-->

# CleanMac Constitution

## Core Principles

### I. Seguridad del Usuario Primero (NO NEGOCIABLE)

- Ninguna operación de borrado MUST ser permanente: todo elemento eliminado MUST moverse a la
  Papelera de macOS (`FileManager.trashItem`), nunca con `removeItem`, `rm` ni equivalentes.
- Toda eliminación MUST requerir confirmación explícita del usuario mostrando la lista final de
  rutas y el tamaño total a liberar.
- La app MUST mantener una lista de rutas protegidas que nunca se pueden seleccionar ni borrar:
  `/System`, `/usr`, `/bin`, `/sbin`, `/private`, `/Library` (raíz del sistema), las apps de
  Apple incluidas con macOS, la propia CleanMac y el directorio home en sí.
- La app MUST NOT solicitar privilegios de administrador ni ejecutar `sudo`.
- Ante duda sobre si un archivo pertenece a una app (coincidencia ambigua), la app MUST marcarlo
  como "posible resto" y dejarlo desmarcado por defecto.

Razón: una herramienta de limpieza que borra lo que no debe destruye la confianza y los datos del
usuario; la Papelera da una red de seguridad recuperable.

### II. Transparencia Total

- Cada elemento propuesto para borrar MUST mostrar su ruta completa, su tamaño y el motivo por el
  que se propone (p. ej. "coincide con bundle ID `com.docker.docker`").
- Los tamaños MUST calcularse como espacio real en disco (tamaño asignado), no tamaño lógico.
- La app MUST permitir revelar cualquier elemento en Finder antes de borrarlo.
- Tras una limpieza, la app MUST informar el espacio liberado y los elementos que fallaron, con
  su error.

Razón: el usuario quiere saber *qué* borrar; la decisión es suya y debe estar informada.

### III. Nativo, Local y Privado

- La app MUST ser nativa: Swift + SwiftUI, sin frameworks de terceros salvo justificación
  aprobada en el plan.
- La app MUST NOT hacer peticiones de red ni enviar telemetría; todo análisis es local.
- La app MUST NOT ejecutar comandos de shell para borrar; los comandos externos de solo lectura
  (p. ej. consultar el uso de Docker) están permitidos únicamente si son opcionales y fallan con
  gracia cuando la herramienta no existe.

Razón: una app que lee todo el disco del usuario debe ser auditable y no sacar datos de la máquina.

### IV. Núcleo Testeable Separado de la UI

- La lógica (escaneo, cálculo de tamaños, detección de restos de apps, reglas de protección,
  borrado a Papelera) MUST vivir en un módulo de biblioteca (`CleanMacCore`) sin dependencias de
  SwiftUI.
- Las reglas de seguridad (rutas protegidas, coincidencia de restos, borrado a Papelera) MUST
  tener tests automatizados escritos antes o junto con su implementación y MUST pasar antes de
  integrar la UI.
- Los tests que tocan el sistema de archivos MUST usar directorios temporales, nunca rutas reales
  del usuario.

Razón: los errores en estas reglas son los que causan pérdida de datos; deben verificarse sin UI.

### V. Respuesta y Rendimiento

- Todo escaneo MUST ejecutarse fuera del hilo principal (Swift Concurrency), mostrar progreso y
  ser cancelable.
- La UI MUST permanecer interactiva durante escaneos de directorios con cientos de miles de
  archivos.
- Los errores de permisos (p. ej. sin Acceso Total al Disco) MUST omitirse sin abortar el escaneo
  y reportarse de forma agregada.

Razón: escanear `~/Library` completo puede tardar; una UI congelada parece una app rota.

### VI. Simplicidad

- Se implementa solo lo especificado; nada de funciones "por si acaso" (YAGNI).
- Se prefiere un único paquete Swift (SPM) ejecutable con `swift build` / `swift run`, sin
  proyecto Xcode, mientras sea suficiente.

Razón: es una herramienta personal; la complejidad extra no aporta valor.

## Restricciones Técnicas

- Plataforma: macOS 14 o superior, Apple Silicon (arm64) como objetivo principal.
- Lenguaje: Swift 6 con concurrencia estricta; UI en SwiftUI.
- Build: Swift Package Manager; se permite un script para empaquetar un `.app` firmado ad hoc.
- Testing: XCTest o Swift Testing ejecutables con `swift test`.
- Idioma de la UI: español.

## Flujo de Desarrollo y Puertas de Calidad

- Cada feature sigue el flujo Spec Kit: specify → clarify → plan → tasks → analyze → implement.
- Puertas antes de dar una feature por terminada:
  1. `swift build` sin errores ni warnings de concurrencia.
  2. `swift test` en verde, incluyendo los tests de reglas de seguridad.
  3. Verificación manual de que ningún flujo de borrado salta la confirmación ni usa borrado
     permanente.
- Commits pequeños y descriptivos por fase de tareas.

## Governance

- Esta constitución prevalece sobre cualquier otra práctica del proyecto.
- Toda enmienda MUST documentarse en este archivo con un Sync Impact Report y una versión nueva.
- Versionado semántico: MAJOR para eliminar o redefinir principios, MINOR para agregar principios o
  secciones, PATCH para aclaraciones de redacción.
- El "Constitution Check" de cada plan MUST verificar los principios I–VI; cualquier violación MUST
  justificarse en la tabla de Complexity Tracking del plan.

**Version**: 1.0.0 | **Ratified**: 2026-10-24 | **Last Amended**: 2026-10-24

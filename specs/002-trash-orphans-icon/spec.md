# Feature Specification: Vaciar Papelera, apps huérfanas e icono

**Feature Branch**: `002-trash-orphans-icon`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "Agrega un botón para vaciar papelera. Agrega en el menú una
funcionalidad para ver aplicaciones huérfanas, que se borraron hace tiempo pero quedaron archivos
sin purgar. Agrégale un icono a la aplicación para subirlo a GitHub personal."

## Clarifications

### Session 2026-10-24

- Q: ¿Vaciar la Papelera choca con "ningún borrado permanente" (principio I)? → A: Se enmienda la
  constitución (v1.3.0): vaciar la Papelera es la única operación permanente, solo con un botón
  explícito y confirmación que muestra el tamaño; el vaciado lo realiza Finder.
- Q: ¿Cómo se decide que unos archivos son de una app huérfana? → A: Elementos de `~/Library` cuyo
  nombre es un identificador de app (formato `dominio.empresa.app`), que no pertenecen a ninguna
  app instalada ni a ninguna app que macOS conozca, y que no son de Apple.
- Q: ¿Los huérfanos vienen marcados para borrar? → A: No; nada viene marcado. El usuario marca
  grupos o usa "Marcar los de confianza alta".
- Q: ¿Qué icono? → A: Diseño propio generado por código (sin SF Symbols, cuya licencia prohíbe
  usarlos en iconos de apps).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Vaciar la Papelera (Priority: P1)

El usuario ve cuánto ocupa la Papelera y la vacía con un botón, tras confirmar, para liberar de
verdad el espacio de lo que movió con CleanMac.

**Why this priority**: Todo lo que CleanMac borra va a la Papelera; sin vaciarla no se libera
espacio.

**Independent Test**: Mover un archivo de prueba a la Papelera, vaciarla desde CleanMac y comprobar
que el espacio disponible aumenta.

**Acceptance Scenarios**:

1. **Given** la Papelera con elementos, **When** el usuario abre CleanMac, **Then** ve el tamaño de
   la Papelera y un botón "Vaciar Papelera…".
2. **Given** el botón, **When** lo pulsa, **Then** ve una confirmación que dice que la acción es
   permanente e indica el tamaño; al aceptar la Papelera queda vacía y se actualiza el espacio libre.
3. **Given** la Papelera vacía, **Then** el botón está deshabilitado.

---

### User Story 2 - Encontrar restos de apps ya desinstaladas (Priority: P2)

El usuario abre "Huérfanos" en el menú lateral y ve los restos de apps que ya no están instaladas,
agrupados por app, con tamaño, ubicación y fecha de última modificación. Marca los que quiere y
los mueve a la Papelera tras confirmar.

**Why this priority**: Recupera espacio que ni el desinstalador encuentra porque la app ya no existe.

**Independent Test**: Crear en una Library de prueba carpetas con identificadores de apps
inexistentes y verificar que aparecen como huérfanos y las de apps instaladas no.

**Acceptance Scenarios**:

1. **Given** restos de una app desinstalada, **When** termina la búsqueda, **Then** aparecen
   agrupados por identificador, con tamaño total y fecha de última modificación.
2. **Given** un grupo, **When** el usuario lo despliega, **Then** ve cada elemento con su ruta y
   tamaño y puede mostrarlo en Finder.
3. **Given** grupos marcados, **When** confirma, **Then** se mueven a la Papelera y desaparecen de
   la lista.
4. **Given** restos que comparten empresa con una app instalada (p. ej. `com.microsoft.*` con
   Office instalado), **Then** aparecen como confianza "posible", no "alta".

---

### User Story 3 - Icono de la app (Priority: P3)

La app tiene un icono propio visible en Finder, el Dock y el README del repositorio.

**Independent Test**: Empaquetar la app y ver el icono en Finder y en el Dock.

**Acceptance Scenarios**:

1. **Given** la app empaquetada, **Then** Finder y el Dock muestran el icono de CleanMac.

### Edge Cases

- Papelera sin permiso de lectura (sin Acceso total al disco): se muestra "tamaño desconocido" y el
  botón sigue disponible (Finder la vacía).
- Elementos bloqueados en la Papelera: Finder los gestiona o informa.
- Identificadores de apps que viven fuera de Aplicaciones (Homebrew, apps de sistema): macOS las
  conoce, no se marcan como huérfanas.
- Helpers de una app instalada (`com.empresa.app.helper`): no son huérfanos.
- Elementos de Apple (`com.apple.*`, `group.com.apple.*`): nunca se listan.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: La app MUST mostrar el tamaño actual de la Papelera del usuario.
- **FR-002**: La app MUST ofrecer "Vaciar Papelera…" con confirmación que advierte que es
  permanente y muestra el tamaño; el vaciado lo realiza Finder.
- **FR-003**: Tras vaciar, la app MUST actualizar el espacio disponible y el tamaño de la Papelera.
- **FR-004**: La app MUST tener una sección "Huérfanos" en el menú lateral.
- **FR-005**: La búsqueda MUST revisar los hijos directos de Application Support, Containers,
  Group Containers, Caches, Preferences (y ByHost), Saved Application State, HTTPStorages, WebKit,
  Cookies, Logs y LaunchAgents de `~/Library`.
- **FR-006**: Un elemento MUST considerarse huérfano solo si su nombre contiene un identificador de
  app (≥ 3 componentes separados por puntos) que: no es de Apple, no coincide (ni como prefijo ni
  como helper) con ninguna app instalada ni en ejecución, y macOS no conoce ninguna app con ese
  identificador.
- **FR-007**: Confianza "alta" si ninguna app instalada comparte la empresa (dos primeros
  componentes); "posible" en caso contrario.
- **FR-008**: Los huérfanos MUST agruparse por identificador con tamaño total, número de elementos y
  fecha de última modificación, ordenados por tamaño; ninguno viene marcado.
- **FR-009**: El borrado de huérfanos MUST usar el mismo flujo seguro (confirmación, Papelera,
  política de protección).
- **FR-010**: La app MUST tener un icono propio en el paquete `.app`.

### Key Entities

- **OrphanGroup**: identificador, confianza, elementos (`Leftover`), tamaño total, fecha de última
  modificación.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Vaciar la Papelera requiere 2 acciones (botón + confirmar) y el espacio libre aumenta
  en el tamaño mostrado (±5 %).
- **SC-002**: 0 elementos de apps instaladas o de Apple aparecen como huérfanos en los tests.
- **SC-003**: La búsqueda de huérfanos termina en menos de 30 s en una Library de ~50 GB.
- **SC-004**: El icono se ve en Finder y Dock.

## Assumptions

- Solo se revisa la Library del usuario actual.
- Las carpetas con nombre libre (p. ej. `Application Support/Claude`) no se evalúan: no se puede
  saber con seguridad a qué app pertenecen.

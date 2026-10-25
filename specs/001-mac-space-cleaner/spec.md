# Feature Specification: CleanMac — Analizador de espacio y desinstalador para macOS

**Feature Branch**: `001-mac-space-cleaner`

**Created**: 2026-10-24

**Status**: Draft

**Input**: User description: "Construir una aplicación para desinstalar aplicaciones de mi Mac, como
CleanMyMac, ya que tengo mucho espacio ocupado pero no tanto instalado; quiero usar la app para saber
qué borrar. Debe incluir: análisis de espacio (ranking de carpetas), desinstalador que muestre el
tamaño real de cada app incluyendo sus restos en Library, limpieza de cachés de desarrollo (npm,
Docker, .cache, Xcode DerivedData) y borrado seguro (siempre a la Papelera, con confirmación)."

## Clarifications

### Session 2026-10-24

- Q: ¿Puede el usuario mover elementos a la Papelera directamente desde el análisis de espacio, o
  solo verlos? → A: Sí, puede marcar elementos del análisis y moverlos a la Papelera con la misma
  confirmación y protecciones que el resto de la app.
- Q: ¿En qué ubicaciones y con qué regla se buscan los restos de una app? → A: En las carpetas
  estándar de `~/Library` (Application Support, Containers, Group Containers, Caches, Preferences,
  Logs, Saved Application State, HTTPStorages, WebKit, Cookies, LaunchAgents); coincidencia exacta
  por identificador = confianza alta (marcado), coincidencia por nombre de la app o prefijo de
  identificador = ambigua (desmarcado).
- Q: ¿Se guardan los resultados del análisis entre sesiones? → A: No; cada apertura analiza de
  nuevo y los resultados viven solo en memoria.
- Q: ¿Cómo se muestran los elementos muy pequeños en el desglose de una carpeta? → A: Se listan
  individualmente los elementos de 1 MB o más; los menores se agrupan en una fila "Otros elementos
  pequeños" con su tamaño total.
- Q: ¿Cómo se instala y se abre la app? → A: Como aplicación `.app` normal generada por un script
  de empaquetado local, para que el usuario pueda concederle Acceso Total al Disco desde Ajustes del
  Sistema; también puede ejecutarse en modo desarrollo.

### Session 2026-10-24 (post-implementación)

- Q: ¿Qué hacer con elementos que macOS no deja mover sin autorización (apps instaladas por root)?
  → A: Reintentar con el mecanismo del Finder, que muestra el diálogo de autorización del sistema
  (contraseña o Touch ID); la app nunca maneja la credencial (constitución v1.1.0).
- Q: ¿Debe el análisis cubrir más que la carpeta personal y Aplicaciones? → A: Sí, también
  `/Library`, `/opt`, `/usr/local` y `/private/var` en modo solo lectura, y mostrar el espacio usado
  que ninguna app puede leer (sistema macOS y datos protegidos).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Ver qué está ocupando el espacio (Priority: P1)

El usuario abre la app y ve de inmediato el estado del disco (capacidad, usado, libre) y un ranking
de las ubicaciones que más espacio consumen dentro de su carpeta personal y de Aplicaciones, de
mayor a menor. Puede entrar en cualquier ubicación para ver su desglose interno (navegación tipo
"drill-down") y revelar cualquier elemento en Finder.

**Why this priority**: Es la necesidad principal expresada: "quiero saber qué borrar". Por sí sola
ya permite al usuario descubrir que, por ejemplo, el disco de Docker ocupa 35 GB.

**Independent Test**: Abrir la app, lanzar el análisis y verificar que el ranking muestra las
ubicaciones más grandes con tamaños coherentes con los que reporta el sistema.

**Acceptance Scenarios**:

1. **Given** la app abierta, **When** el usuario inicia el análisis, **Then** ve el progreso del
   escaneo y puede seguir usando la app o cancelarlo.
2. **Given** un análisis terminado, **When** el usuario mira el resumen, **Then** ve capacidad
   total, espacio usado, espacio libre y la lista de ubicaciones ordenadas por tamaño.
3. **Given** el ranking, **When** el usuario selecciona una ubicación, **Then** ve sus
   subcarpetas/archivos ordenados por tamaño y puede volver al nivel anterior.
4. **Given** una ubicación sin permiso de lectura, **When** termina el análisis, **Then** la app
   indica cuántas ubicaciones no pudo leer y sugiere conceder Acceso Total al Disco.
5. **Given** el desglose de una ubicación, **When** el usuario marca uno o varios elementos y pide
   moverlos a la Papelera, **Then** ve la confirmación con la lista y el total, y tras aceptar los
   elementos se mueven a la Papelera y los tamaños se actualizan.

---

### User Story 2 - Desinstalar una app junto con sus restos (Priority: P2)

El usuario ve la lista de aplicaciones instaladas con su tamaño real: el paquete de la app más los
datos asociados que deja en su Library (soporte, contenedores, cachés, preferencias, registros,
estado guardado, etc.). Selecciona una app, revisa qué elementos se eliminarían y, tras confirmar,
todos se mueven a la Papelera.

**Why this priority**: Es la función de "desinstalador" pedida explícitamente; los restos (p. ej.
11 GB de datos de una app) son lo que la desinstalación normal deja atrás.

**Independent Test**: Instalar o simular una app de prueba con restos en Library, desinstalarla
desde CleanMac y comprobar que el paquete y los restos están en la Papelera.

**Acceptance Scenarios**:

1. **Given** la lista de apps, **When** el usuario la ordena por tamaño total, **Then** ve primero
   las apps cuyo paquete + restos suman más.
2. **Given** una app seleccionada, **When** el usuario abre el detalle, **Then** ve cada elemento
   relacionado con su ruta, tamaño y motivo de la coincidencia, con los restos seguros marcados y
   los ambiguos desmarcados.
3. **Given** el detalle de una app, **When** el usuario confirma la desinstalación, **Then** todos
   los elementos marcados se mueven a la Papelera y la app informa el espacio liberado.
4. **Given** una app que está en ejecución, **When** el usuario intenta desinstalarla, **Then** la
   app le pide cerrarla primero y no borra nada mientras siga abierta.
5. **Given** una app del sistema de Apple o la propia CleanMac, **When** aparece en la lista,
   **Then** no puede seleccionarse para desinstalar.

---

### User Story 3 - Limpiar cachés y datos de desarrollo regenerables (Priority: P3)

El usuario ve una sección de "Limpieza" con categorías conocidas de datos regenerables (caché de
npm, cachés generales en `~/.cache` y `~/Library/Caches`, datos derivados de Xcode, registros, y el
uso de Docker), cada una con su tamaño y una explicación de qué es y qué pasa si se borra. Marca
las que quiere limpiar y, tras confirmar, se mueven a la Papelera.

**Why this priority**: Libera mucho espacio con bajo riesgo, pero el usuario necesita primero
entender dónde está el espacio (P1).

**Independent Test**: Crear cachés de prueba, limpiar la categoría desde CleanMac y verificar que
el contenido está en la Papelera y que la carpeta raíz de la caché sigue existiendo.

**Acceptance Scenarios**:

1. **Given** la sección Limpieza, **When** termina el cálculo, **Then** cada categoría muestra
   tamaño, descripción y nivel de riesgo.
2. **Given** categorías marcadas, **When** el usuario confirma, **Then** se mueve a la Papelera el
   contenido de cada categoría y se informa el total liberado.
3. **Given** la categoría Docker, **When** el usuario la revisa, **Then** la app explica que el
   disco virtual de Docker no debe borrarse como archivo y le indica cómo recuperar espacio desde
   Docker (sin ejecutarlo por él).
4. **Given** una categoría inexistente en el equipo (p. ej. sin Xcode), **When** se muestra la
   lista, **Then** esa categoría aparece como "no encontrada" o se oculta, sin errores.

---

### Edge Cases

- Rutas que no se pueden leer por permisos: se omiten, se cuentan y se reportan; el análisis no se
  aborta.
- Enlaces simbólicos: no se siguen, para no contar ni borrar dos veces ni salir del área analizada.
- Archivos que cambian o desaparecen durante el escaneo: se ignoran sin error.
- Un elemento no se puede mover a la Papelera (bloqueado, sin permiso): se reporta el fallo y se
  continúa con el resto.
- Una app con bundle ID ausente o inválido: solo se ofrece eliminar el paquete; no se buscan restos.
- Restos cuyo nombre coincide parcialmente con otra app (p. ej. "Google" para Chrome y Drive): se
  marcan como ambiguos y quedan desmarcados por defecto.
- Volumen casi lleno: la app no debe necesitar escribir archivos grandes para funcionar.
- Archivos con tamaño en disco muy diferente a su tamaño lógico (archivos dispersos como discos
  virtuales): se muestra el tamaño real ocupado.

## Requirements *(mandatory)*

### Functional Requirements

**Análisis de espacio**

- **FR-001**: La app MUST mostrar la capacidad total, el espacio usado y el espacio disponible del
  volumen de inicio.
- **FR-002**: La app MUST analizar la carpeta personal del usuario, la carpeta de Aplicaciones y,
  en modo solo lectura, `/Library`, `/opt`, `/usr/local` y `/private/var`, presentar un ranking de
  ubicaciones ordenadas por tamaño ocupado en disco y mostrar el espacio usado no analizable.
- **FR-003**: Los usuarios MUST poder navegar dentro de cualquier ubicación para ver su desglose y
  volver atrás.
- **FR-004**: El análisis MUST mostrar progreso, permitir cancelación y no bloquear la interfaz.
- **FR-005**: La app MUST reportar el número de ubicaciones que no pudo leer y explicar cómo
  conceder Acceso Total al Disco.
- **FR-006**: Los usuarios MUST poder revelar cualquier elemento listado en Finder.
- **FR-006a**: Los usuarios MUST poder marcar elementos del análisis y moverlos a la Papelera,
  sujeto a FR-015–FR-018; los elementos protegidos no pueden marcarse.
- **FR-006b**: En el desglose, los elementos de 1 MB o más MUST listarse individualmente y los
  menores MUST agruparse en una fila "Otros elementos pequeños" (no seleccionable) con su total.
- **FR-006c**: Los resultados del análisis MUST mantenerse solo en memoria durante la sesión; no
  se guardan en disco.

**Desinstalador**

- **FR-007**: La app MUST listar las aplicaciones instaladas en las carpetas de Aplicaciones del
  sistema y del usuario, con nombre, icono, versión, tamaño del paquete, tamaño de restos y total.
- **FR-008**: La app MUST localizar los restos de cada app en estas carpetas de la Library del
  usuario: Application Support, Containers, Group Containers, Caches, Preferences, Logs, Saved
  Application State, HTTPStorages, WebKit, Cookies y LaunchAgents, usando el identificador de la
  app y su nombre.
- **FR-009**: Cada resto MUST mostrar ruta, tamaño y motivo de la coincidencia. Confianza alta
  (marcado por defecto): el nombre del elemento es exactamente el identificador, o el identificador
  seguido de una extensión o sufijo (p. ej. `.plist`, `.savedState`). Confianza ambigua (desmarcado
  por defecto): el nombre coincide con el nombre visible de la app, o el elemento comparte el
  prefijo de organización del identificador (p. ej. Group Containers con prefijo de equipo).
- **FR-010**: La app MUST impedir desinstalar una app que esté en ejecución, apps del sistema de
  Apple y la propia CleanMac.
- **FR-011**: Los usuarios MUST poder buscar apps por nombre y ordenar por nombre o tamaño.

**Limpieza**

- **FR-012**: La app MUST ofrecer categorías de limpieza predefinidas, cada una con descripción,
  tamaño y nivel de riesgo: caché de npm, `~/.cache`, cachés de usuario en Library, datos derivados
  de Xcode, registros de usuario y Docker (solo informativa).
- **FR-013**: Limpiar una categoría MUST mover a la Papelera el *contenido* de su carpeta, no la
  carpeta raíz.
- **FR-014**: La categoría Docker MUST ser solo informativa: mostrar el tamaño y las instrucciones
  para recuperar espacio desde Docker, sin borrar archivos.

**Borrado seguro (transversal)**

- **FR-015**: Toda eliminación MUST mover los elementos a la Papelera; ninguna MUST ser permanente.
- **FR-015a**: Si macOS deniega el movimiento por permisos, la app MUST reintentar mediante el
  mecanismo del Finder, que solicita autorización del sistema (contraseña o Touch ID); si aun así
  falla, MUST indicar al usuario que active «Gestión de apps» para CleanMac.
- **FR-016**: Toda eliminación MUST requerir una confirmación que muestre la lista de elementos y el
  tamaño total.
- **FR-017**: La app MUST rechazar cualquier eliminación de rutas protegidas (rutas de sistema, la
  carpeta personal en sí, carpetas raíz de Library, apps de Apple, la propia CleanMac), incluso si
  llegan a solicitarse.
- **FR-018**: Tras una eliminación, la app MUST informar el espacio liberado y los elementos que
  fallaron con su motivo.
- **FR-019**: La app MUST funcionar sin conexión a internet y MUST NOT enviar datos fuera del
  equipo.

### Key Entities

- **Volumen**: disco de inicio; capacidad, usado, disponible.
- **Elemento de disco**: archivo o carpeta con ruta, nombre, tamaño ocupado, si es carpeta, y sus
  hijos cuando se ha analizado.
- **Aplicación instalada**: nombre, identificador, versión, ruta del paquete, tamaño del paquete,
  si es de Apple, si está en ejecución, lista de restos.
- **Resto (leftover)**: ruta, tamaño, tipo de ubicación (soporte, caché, preferencias, etc.),
  motivo de coincidencia, confianza (exacta / ambigua), marcado sí/no.
- **Categoría de limpieza**: nombre, descripción, rutas, tamaño, nivel de riesgo, si es solo
  informativa.
- **Resultado de eliminación**: elementos movidos, elementos fallidos con motivo, espacio liberado.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: En menos de 2 minutos desde abrir la app, el usuario identifica las 10 ubicaciones
  que más espacio ocupan en su equipo.
- **SC-002**: El tamaño reportado para una ubicación difiere menos de un 5 % del reportado por las
  herramientas del sistema para la misma ubicación.
- **SC-003**: La interfaz responde a la interacción (cancelar, navegar) en menos de 0,5 segundos
  durante un análisis en curso.
- **SC-004**: El 100 % de los elementos eliminados terminan en la Papelera y pueden restaurarse.
- **SC-005**: 0 eliminaciones ocurren sin pasar por la confirmación del usuario.
- **SC-006**: Al desinstalar una app, el espacio total liberado (paquete + restos) es al menos el
  tamaño total mostrado antes de confirmar menos los elementos que el usuario desmarcó o que
  fallaron.
- **SC-007**: El usuario puede liberar al menos 10 GB en una sesión en un equipo con cachés de
  desarrollo acumuladas, sin borrar nada que no haya revisado.

## Assumptions

- Usuario único y técnico (desarrollador) en un Mac personal con macOS 14 o superior y Apple
  Silicon.
- La app no se ejecuta con privilegios de administrador; para elementos que lo requieren, macOS
  muestra su propio diálogo de autorización.
- El análisis cubre la carpeta personal y las carpetas de Aplicaciones; no se analiza el sistema
  operativo ni otros volúmenes en esta versión.
- Vaciar la Papelera es responsabilidad del usuario; la app le recuerda que el espacio se libera al
  vaciarla.
- La interfaz está en español.
- La app se distribuye como un `.app` generado localmente por un script de empaquetado (firma ad
  hoc, sin notarización) para poder recibir Acceso Total al Disco; también se ejecuta en modo
  desarrollo.
- No se incluyen en esta versión: limpieza programada, monitorización en segundo plano, detección
  de duplicados, malware ni optimización de memoria.

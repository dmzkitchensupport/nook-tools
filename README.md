# nook-tools

Herramientas internas de NOOK World Cuisine (VOCO Surfside Aruba), hospedadas como
páginas estáticas vía GitHub Pages (público, gratis — sin repo privado, sin plan pago).

## Mapa del sitio

`index.html` (raíz) es el menú principal, con 4 secciones — íconos propios (sin
emojis), logo real recortado de `Nook_Brandbook.pdf` (`assets/nook-logo-navy.png`),
paleta de la marca (navy `#2b4a5e`, tostado `#9a7367`/`#b8935a`, crema `#faf9f6`):

- **`cocina/`** — el flujo de 3 pasos + Recetario, descrito abajo. Los archivos de
  cada herramienta (`fichas/`, `recetario/`, `organizador/`, `generador/`) **no se
  movieron de la raíz** — `cocina/index.html` solo enlaza a ellos — para no romper
  ningún bookmark existente ni rutas internas.
- **`bitacora/`** — Bitácora Diaria A&B, herramienta real (ver sección propia abajo).
- **`formatos/`, `salon-barra/`** — secciones nuevas, en placeholder ("Próximamente")
  hasta que Mario defina su contenido real. No se inventó funcionalidad para ellas.

## Bitácora Diaria A&B (`bitacora/`)

Reemplaza el PDF/Excel que Roberto (Gerente A&B) llenaba a mano y mandaba por WhatsApp.
Réplica 1:1 de los campos del PDF original (Área General, Cocina, Caja, Cheque
Promedio, Gerencia, Barra, Venta por Áreas, Totales) más 5 campos de ocupación que el
PDF no traía (Guest in House/Incl./No Show/Pay/Locales), agregados para poder generar
solos los dos cortes que antes vivían en Excel aparte.

- **Captura**: autoguardado en `localStorage`, una entrada por fecha. "Ventas totales"
  se calcula solo (suma de Room Service+Bar+Market Place+Desayuno+Comidas y cenas);
  "Ventas en efectivo" se captura a mano (no es derivable).
- **Historial**: abrir/editar/borrar cualquier día capturado; Exportar/Importar JSON
  como respaldo (mismo patrón que las otras 4 herramientas).
- **Cortes**: "Ventas y proyección diaria" y "Comparativo desayunos/ocupación", ambos
  recalculados solos por mes a partir de lo ya capturado — nunca hay que llevarlos
  aparte en Excel. **La fórmula del % de ocupación está marcada como SIN VERIFICAR**
  en la propia herramienta (Total Guest = Incl. − No Show + Pay; % = Total Guest ÷
  Guest in House) — no coincidió exacto contra el ejemplo real de Roberto al probarla;
  no usar como reporte oficial hasta que él confirme el criterio real.
- **PDF**: generado de verdad con jsPDF (vía CDN), no solo `window.print()`.
- **Envío a WhatsApp**: un toque vía Web Share API — el botón abre el panel nativo de
  compartir del teléfono con el PDF ya adjunto, y WhatsApp aparece como opción (decisión
  explícita de Mario, frente a conectar el puente de WhatsApp/Baileys existente para
  cero-toques, que habría requerido decidir su hosting 24/7 — queda como posible
  mejora futura, no descartada, solo no construida todavía).

## Cocina — flujo de trabajo en 3 pasos

El Generador de Ficheros es el que dicta el rumbo: es el producto final (la ficha
exportada), y su esquema JSON universal es el que las otras herramientas deben poder
hablar. `organizador/` y `fichas/` existen para llegar preparados a ese paso 3; el
Recipe Master Book es la fuente de referencia (insumos/procedimiento) y se consulta
aparte — no es un paso numerado, porque ya está completo (83 recetas) y no se rehace
por cada foto nueva.

- **Paso 1 — `organizador/`** (Organizador de Fotos): organiza fotos sueltas —
  renombra el platillo, arrastra para asignar familia (LUN/POOL/DIN/OTROS/SIN) y
  orden. Exporta/importa el esquema universal (solo `id`/`platillo`/`familia` — no
  maneja receta/precio/descripción/insumos).
- **Paso 2 — `fichas/`** (Fichas de Platillos): captura de foto + platillo + insumos,
  con casilla de "no disponible". Se guarda solo (localStorage del navegador). Botón
  "Descargar copia actualizada" para respaldar el progreso. Su catálogo de platillos
  (autocompletar descripción/insumos al elegir un platillo) se genera desde
  `catalogo-canonico.json`.
- **Paso 3 — `generador/`** (Generador de Ficheros): arma las fichas finales con foto
  + texto y las exporta como PNG (ZIP) o PDF. Tiene su propio `.json` de proyecto (con
  fotos, sin tocar) y exporta/importa el esquema universal (sin fotos).

### Referencia (fuera de la secuencia)

- `recetario/` — Recipe Master Book: 83 recetas + 56 sub-recetas, con modo edición,
  registro de cambios y conversión de unidades (oz/g/lb). **Fuente única de verdad**
  del catálogo — auditada 1:1 contra Cockpit.

## Esquema JSON universal ("proyecto NOOK universal")

Un array de objetos con esta forma es el formato común que las 4 herramientas
pueden exportar/importar entre sí:

```json
{
  "id": "01_LUN_TORTILLA_SOUP.jpg",
  "platillo": "Tortilla Soup",
  "familia": "LUNCH",
  "receta": "R-29",
  "precio": "12",
  "descripcion": "...",
  "insumos": ["..."],
  "disponible": true
}
```

- **id** — nombre de archivo de la foto (convención `##_FAMILIA_NOMBRE.jpg`). Es la
  clave de match entre `organizador/` y `fichas/`, que comparten la misma librería de
  fotos. `generador/` no tiene esa librería (cualquier imagen se puede arrastrar ahí),
  así que no tiene un namespace de `id` compartido — su export deja `id` vacío y su
  import matchea por **nombre de platillo** normalizado, no por `id`.
- **platillo** — nombre del platillo.
- **familia** — ver la tabla de códigos abajo.
- **receta** — código `R-##` del recetario (fuente única para insumos/procedimiento).
- **precio** — precio de carta, como texto (para permitir formatos como `"12 / 20"`).
- **descripcion** — texto de carta.
- **insumos** — arreglo de strings, un insumo por línea (`"NOMBRE — cantidad unidad"`).
- **disponible** — `true`/`false`/`null`. `null` = la herramienta no maneja ese dato
  (p. ej. el organizador, que solo conoce foto/nombre/familia).

Un campo que una herramienta no maneja se exporta vacío (`""`, `[]` o `null` según el
tipo) — nunca se inventa un valor.

### Códigos de familia — tabla de equivalencia

Las 4 herramientas no nacieron con el mismo vocabulario. En vez de forzar una
migración de datos ya capturados, cada quien conserva su código nativo y se
normaliza al importar:

| Código          | Dónde es nativo         | Equivale a               |
|------------------|--------------------------|---------------------------|
| `LUNCH`          | `fichas/`, `catalogo-canonico.json`, `generador/` (cat `lunch`) | almuerzo |
| `POOL`           | las 4 herramientas       | Pool Bar |
| `DIN`            | las 4 herramientas       | Dinner |
| `BREAKFAST`      | `fichas/`, `catalogo-canonico.json`, `generador/` (cat `breakfast`) | desayuno |
| `OTROS`          | las 4 herramientas       | recetario interno / buffet / misceláneo |
| `LUN`            | `organizador/` (`NOOK_Editor_Completo.html`) | igual que `LUNCH` — el organizador no separa desayuno, así que `BREAKFAST` importado también cae en `LUN` |
| `SIN`            | `organizador/`           | foto sin familia asignada todavía (no existe en `generador/`, que solo tiene los 4 servicios reales) |

Al importar, cada herramienta normaliza el valor entrante a su propio vocabulario
(ver `FAMILIA_NORMALIZE` / `FAMILIA_BY_CAT` / `CAT_BY_FAMILIA` en cada `index.html`).

## `catalogo-canonico.json`

Generado el 13 sep 2026 a partir de `recetario/index.html` (83 recetas `R-01`…`R-83`,
la fuente más confiable — auditada 1:1 contra Cockpit). Es la fuente única para el
catálogo de las demás herramientas: **`fichas/index.html` reconstruye su `CATALOG`
interno a partir de este archivo** en cada actualización.

Notas reales sobre esta extracción (para que quien lo use no se sorprenda):

- **`precio` y `descripcion` vienen vacíos** — el recetario es un libro de cocina
  (ingredientes + procedimiento), no la carta impresa. `fichas/` antes tenía precios
  y descripciones reales tomados de las cartas (capturados en una auditoría previa),
  pero esos datos vivían en una estructura de la carta con nombres/variantes que no
  coinciden 1:1 con las 83 recetas del recetario (p. ej. "Avocado Toast" vs "Avocado
  Toast with Poached Egg", ambas R-01). Se optó por no fusionarlos a ciegas — mezclar
  dos fuentes con nombres distintos para el mismo código de receta es exactamente el
  tipo de dato de negocio que le toca decidir a Mario, no inventarlo. **Pendiente:
  decidir si se recapturan precio/descripción por receta sobre este archivo.**
- **`platillo` usa el nombre del recetario** (nombre de cocina), que en varias recetas
  es distinto al nombre de carta que ve el huésped — p. ej. R-07 se llama en el
  recetario "Quinoa / Rice Bowl" pero en la carta es "Healthy Bowl"; R-09 "Elote Ribs"
  vs. "Corn Ribs"; R-20 "Tender" vs. "Chicken Tenders". No es un error de extracción:
  es el nombre real que trae el recetario. `receta` (el código `R-##`) es la clave
  confiable para reconciliar contra Cockpit u otra fuente, no `platillo`.
- **R-07 (Healthy Bowl / Quinoa Rice Bowl)** — sin insumos en el recetario (ya
  documentado en `ESTADO.md`, no es un bug de esta extracción).
- **R-82 y R-83** — siguen literalmente como "RECETA POR DEFINIR — CHEF MARIO" (así
  vienen en el recetario). No se tocan — es de los 3 puntos de negocio que Mario
  revisa a mano.
- **R-43 / R-44** — incluidos tal cual el recetario (ver bloqueador de nombre/costeo
  en `ESTADO.md`, no se corrige aquí).

Para regenerar este archivo si el recetario cambia: releer `recetario/index.html`,
extraer cada tarjeta `id="R-##"` (nombre en `h2.dtitle`, familia en `span.ftag`,
insumos en las filas `td.nm`/`td.qt`/`td.ut` de sus tablas `table.it`) y mapear la
familia con la tabla de arriba.

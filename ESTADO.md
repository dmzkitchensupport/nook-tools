# ESTADO — nook-tools

> Fuente única de verdad de este repo.
> Se actualiza en el mismo commit que el cambio, nunca aparte.
> Regla: si no se puede verificar, se escribe "SIN VERIFICAR", no se inventa.

**Última actualización:** 2026-09-17
**Actualizado por:** TECH (Master Agent), vía Cla, a petición de Mario
**Cliente:** NOOK World Cuisine (VOCO Surfside Aruba)

> Nota: un intento anterior de interconectar las 4 herramientas se cayó por un error
> de conexión a mitad de las pruebas, sin dejar nada a medias comiteado (el repo
> siguió en `9e2b984`). Esta entrada documenta el intento que sí se completó.

---

## 1. Qué es esto

Hospedaje estático (GitHub Pages, repo público, gratis) para herramientas internas de
NOOK. Tiene "Fichas de Platillos" (`fichas/`) y ahora "Recipe Master Book" (`recetario/`);
Mario planea subir más herramientas aquí mismo.

## 2. Dónde vive

| Recurso | Valor | Verificado |
|---|---|---|
| Repo | `dmzkitchensupport/nook-tools` | ✅ público, creado 13 sep 2026 |
| Producción (URL) | `https://dmzkitchensupport.github.io/nook-tools/` | ✅ (ver bloqueador #1 — confirmar tras el primer deploy) |
| Backend | Ninguno — sin Supabase/Vercel, solo archivos estáticos | ✅ |
| CI / Actions | Ninguno todavía (regla 10 no aplica — sin datos sensibles/pagos) | ✅ |

## 3. Historial de cambios reales

| Fecha | Qué cambió | Commit |
|---|---|---|
| 2026-09-13 | Repo creado, primera herramienta cargada: `fichas/index.html` (Fichas de Platillos — captura foto+platillo+insumos+casilla "no disponible", autoguardado en localStorage). Corregido antes de subir un bug real de sintaxis que traía el archivo original (línea corrupta que rompía todo el script, ver detalle en la sesión) y el bug de un solo argumento en `downloadUpdatedCopy()`. Verificado con `node --check` + render real en Chrome headless (6 fichas cargando, checkbox presente) antes de commitear. | *(commit anterior)* |
| 2026-09-13 | Segunda herramienta: `recetario/index.html` — "NOOK Recipe Master Book" (83 recetas + 56 sub-recetas, tal como fue recibido por WhatsApp). Se le agregó: (1) Modo edición (✏️) — nombre/cantidad/unidad de cada ingrediente y cada paso de procedimiento se vuelven editables in situ; (2) autoguardado en `localStorage` con el mismo patrón `queueSave`/`setStat` de `fichas/`; (3) Registro de cambios (📋) — panel con receta, campo, valor anterior → nuevo y fecha/hora real de cada edición, persistente; (4) las 141+1 menciones de "April 2026"/"APRIL 2026" del header y pies de tarjeta se corrigieron a la fecha real (13 sep 2026) — las recetas editadas llevan además su propio sello "· editado <fecha real>"; (5) 3 botones de conversión global de unidades [ONZAS][GRAMOS][LIBRAS] — convierten las cantidades de las 83+56 recetas a la vez, siempre recalculando desde el valor original (nunca desde el valor ya convertido, para no acumular error de redondeo), con `1 oz = 28.3495 g` y `1 lb = 453.592 g`; unidades no convertibles (`pcs`, `pinch`, `to coat molds`) se dejan intactas en los 3 modos; el modo elegido se recuerda en `localStorage`. El buscador que ya traía el archivo no se tocó y sigue funcionando igual. | *(commit anterior)* |
| 2026-09-13 | **Interconexión de las 4 herramientas NOOK** (esquema JSON universal, documentado en `README.md`). (1) `catalogo-canonico.json` — 83 recetas extraídas de `recetario/index.html` (nombre, familia, código `R-##`, insumos; precio/descripción vacíos a propósito, el recetario no los trae — ver notas reales en `README.md`, incluye 2 correcciones de un bug propio de extracción: R-83 arrastraba de más los insumos de las 56 sub-recetas por un split de HTML mal delimitado, y R-44 perdía sus 9 insumos por un atributo `style` extra en la celda — ambos corregidos y verificados antes de generar el archivo final). (2) `fichas/index.html` — su `CATALOG` interno ahora se reconstruye desde `catalogo-canonico.json` (antes tenía ~88 filas con precios/descripciones de la carta real, capturadas en una auditoría previa — **se dejaron de usar a propósito**, mezclarlas a ciegas con las 83 recetas del recetario habría requerido reconciliar nombres que no coinciden 1:1 entre code R-## y nombre de carta, ver "Pendiente" abajo); se agregó botón "Importar JSON" (matchea por `id` de foto) y se corrigió `exportJSON()` para usar las claves exactas del esquema universal (`carta`→`familia`, `no_disponible`→`disponible`, invirtiendo la polaridad). El `data` real ya capturado por Mario (61 fotos con platillo/descripción/insumos propios) **no se tocó**. (3) `organizador/index.html` (nuevo, antes `NOOK_Editor_Completo.html` en el Desktop de Mario) — botones reales "Exportar JSON"/"Importar JSON" agregados sobre el `DISHES`/`state` existente; el import matchea por `id` de foto y normaliza familias entrantes (`LUNCH`/`BREAKFAST`→`LUN`). (4) `generador/index.html` (nuevo, antes el archivo de "NOOK RECIPE 2026" en el Desktop de Mario) — botones "Exportar universal"/"Importar universal" agregados sin tocar su `.json` de proyecto propio (con fotos) ni el `SEED` embebido; export sin fotos, import matchea por nombre de platillo normalizado (este archivo no tiene un namespace de `id` de foto compartido con los otros 3). Los 4 archivos finales pasaron `node --check` (0 errores) sobre su script embebido. | *(este commit)* |

| 2026-09-17 | **Fix real: `generador/index.html` no dejaba editar el campo "Procedure" en fichas nuevas/recién importadas (reportado por Mario con captura de pantalla).** Diagnóstico verificado con Playwright real (no supuesto): en Chromium el campo funcionaba; en WebKit (motor de Safari/iPad — el entorno probable de uso en cocina) el campo recibía el foco al tocarlo pero el texto tecleado no se insertaba nunca. Causa raíz aislada con pruebas controladas: WebKit no acepta entrada de teclado en un elemento `contenteditable` vacío cuyo CSS computado es `display:inline` (afecta por igual a `<span>` o `<div>`, no es un problema de la etiqueta). El propio archivo ya tenía la solución aplicada en otro campo (`.f-meta .ed{display:inline-block}` para Portion/Time/Rush) pero no se había aplicado al campo Procedure. Fix de una línea: agregada `.f-proc .ed{display:inline-block; min-width:1.2ch}` (mismo patrón). Verificado antes de subir: `node --check` sobre el script embebido (0 errores), prueba real de tap+escritura en WebKit/iPad (ahora sí guarda el texto) y en Chromium (sin regresión), y captura de pantalla de una ficha para confirmar que el layout visual no se rompió. | *(este commit)* |

| 2026-09-17 | **Reordenamiento del flujo de trabajo a 3 pasos numerados**, a petición explícita de Mario (confirmado con él: el Recetario queda fuera de la secuencia, como referencia). `index.html` (portal) ahora muestra Paso 1 → Organizador de Fotos, Paso 2 → Fichas de Platillos, Paso 3 → Generador de Ficheros, con el Recipe Master Book en una sección aparte de "Referencia". `README.md` documenta la misma lógica: el Generador es el producto final y su esquema JSON universal es el que las otras 2 herramientas del flujo deben poder hablar; el Recetario es fuente de insumos/procedimiento, ya completo, no se rehace por cada foto. Verificado visualmente con captura de pantalla antes de subir. | *(este commit)* |

## 4. Bloqueadores

- [x] **#1 — RESUELTO 13 sep 2026:** verificado con `curl` real — `/` y `/fichas/` responden HTTP 200, contenido correcto (`<h1>NOOK — Herramientas</h1>` y `<title>NOOK · Fichas de Platillos</title>`), build de Pages en estado `built` sin error (`gh api .../pages/builds/latest`).
- [x] **#2 — Contenido público a propósito, sin dato sensible (revisado de nuevo con `recetario/`):** el Recipe Master Book trae nombre/familia/ingredientes/cantidades/unidades y procedimiento — no trae precios de venta, costos, ni credenciales. Igual de público-apropiado que `fichas/`.
- [ ] **#3 — Auditoría de datos de negocio (NO corregida por el agente, requiere decisión de Mario):** al cotejar este Recipe Master Book contra Cockpit (`recetas_maestras` tenant NOOK), se encontró que el código **R-43** tiene nombres distintos en cada sistema — este libro dice "TORTA BASCA (150G PORTION)" (y los insumos de Cockpit para R-43 — TARTA BASCA PORTION, COOKIE CRUMBLE, BERRY SAUCE — coinciden con esa receta, no con un platillo separado); Cockpit tiene guardado el nombre "COOKIE CRUMBLE" para R-43. Todo indica que el nombre en Cockpit está mal cargado (se usó el nombre de un insumo como nombre del platillo), pero no se corrigió — es dato de negocio en producción y la regla de gobernanza pide que lo decida Mario, no el agente. Además: **R-44 BROWNIE A LA MODE** (9 insumos reales, en gramos) y **R-82/R-83** (marcados en el propio libro como "RECETA POR DEFINIR — CHEF MARIO") no tienen insumos cargados en Cockpit — R-82/R-83 es consistente (el libro mismo dice que faltan), pero R-44 sí tiene receta completa aquí y cero costeo en Cockpit.
- [ ] **#4 — `fichas/` perdió precio/descripción de carta al cambiar de fuente (requiere decisión de Mario):** su `CATALOG` viejo (~88 filas) traía precio y descripción reales, capturados en una auditoría previa de las cartas impresas. El nuevo `CATALOG` (generado desde `catalogo-canonico.json`, ver README) no los trae porque el recetario es un libro de cocina, no la carta — y fusionar ambas fuentes a ciegas habría requerido resolver por código de receta nombres que no coinciden 1:1 (mismo caso que R-01/R-12/R-30 documentado en `NOOK_Auditoria_Catalogo_Base_2026-09-13.md` del Desktop de Mario). Los datos viejos siguen recuperables en el historial de git (commit `9e2b984`, antes de este cambio) por si Mario quiere reconciliarlos receta por receta más adelante.

## 5. Qué sigue

Mario subirá más herramientas NOOK a este mismo repo (cada una en su propia subcarpeta,
con su propio `index.html`, enlazada desde la portada raíz). Pendiente que Mario resuelva
el bloqueador #3 antes de que Cockpit se use como fuente de costeo definitiva de R-43/R-44,
y el #4 si quiere recuperar precio/descripción de carta en `fichas/`.

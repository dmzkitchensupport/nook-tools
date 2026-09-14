# ESTADO — nook-tools

> Fuente única de verdad de este repo.
> Se actualiza en el mismo commit que el cambio, nunca aparte.
> Regla: si no se puede verificar, se escribe "SIN VERIFICAR", no se inventa.

**Última actualización:** 2026-09-13
**Actualizado por:** TECH (Master Agent), vía Lita/BEI, a petición de Mario
**Cliente:** NOOK World Cuisine (VOCO Surfside Aruba)

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
| 2026-09-13 | Segunda herramienta: `recetario/index.html` — "NOOK Recipe Master Book" (83 recetas + 56 sub-recetas, tal como fue recibido por WhatsApp). Se le agregó: (1) Modo edición (✏️) — nombre/cantidad/unidad de cada ingrediente y cada paso de procedimiento se vuelven editables in situ; (2) autoguardado en `localStorage` con el mismo patrón `queueSave`/`setStat` de `fichas/`; (3) Registro de cambios (📋) — panel con receta, campo, valor anterior → nuevo y fecha/hora real de cada edición, persistente; (4) las 141+1 menciones de "April 2026"/"APRIL 2026" del header y pies de tarjeta se corrigieron a la fecha real (13 sep 2026) — las recetas editadas llevan además su propio sello "· editado <fecha real>"; (5) 3 botones de conversión global de unidades [ONZAS][GRAMOS][LIBRAS] — convierten las cantidades de las 83+56 recetas a la vez, siempre recalculando desde el valor original (nunca desde el valor ya convertido, para no acumular error de redondeo), con `1 oz = 28.3495 g` y `1 lb = 453.592 g`; unidades no convertibles (`pcs`, `pinch`, `to coat molds`) se dejan intactas en los 3 modos; el modo elegido se recuerda en `localStorage`. El buscador que ya traía el archivo no se tocó y sigue funcionando igual. | *(este commit)* |

## 4. Bloqueadores

- [x] **#1 — RESUELTO 13 sep 2026:** verificado con `curl` real — `/` y `/fichas/` responden HTTP 200, contenido correcto (`<h1>NOOK — Herramientas</h1>` y `<title>NOOK · Fichas de Platillos</title>`), build de Pages en estado `built` sin error (`gh api .../pages/builds/latest`).
- [x] **#2 — Contenido público a propósito, sin dato sensible (revisado de nuevo con `recetario/`):** el Recipe Master Book trae nombre/familia/ingredientes/cantidades/unidades y procedimiento — no trae precios de venta, costos, ni credenciales. Igual de público-apropiado que `fichas/`.
- [ ] **#3 — Auditoría de datos de negocio (NO corregida por el agente, requiere decisión de Mario):** al cotejar este Recipe Master Book contra Cockpit (`recetas_maestras` tenant NOOK), se encontró que el código **R-43** tiene nombres distintos en cada sistema — este libro dice "TORTA BASCA (150G PORTION)" (y los insumos de Cockpit para R-43 — TARTA BASCA PORTION, COOKIE CRUMBLE, BERRY SAUCE — coinciden con esa receta, no con un platillo separado); Cockpit tiene guardado el nombre "COOKIE CRUMBLE" para R-43. Todo indica que el nombre en Cockpit está mal cargado (se usó el nombre de un insumo como nombre del platillo), pero no se corrigió — es dato de negocio en producción y la regla de gobernanza pide que lo decida Mario, no el agente. Además: **R-44 BROWNIE A LA MODE** (9 insumos reales, en gramos) y **R-82/R-83** (marcados en el propio libro como "RECETA POR DEFINIR — CHEF MARIO") no tienen insumos cargados en Cockpit — R-82/R-83 es consistente (el libro mismo dice que faltan), pero R-44 sí tiene receta completa aquí y cero costeo en Cockpit.

## 5. Qué sigue

Mario subirá más herramientas NOOK a este mismo repo (cada una en su propia subcarpeta,
con su propio `index.html`, enlazada desde la portada raíz). Pendiente que Mario resuelva
el bloqueador #3 antes de que Cockpit se use como fuente de costeo definitiva de R-43/R-44.

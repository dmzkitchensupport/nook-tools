# ESTADO — nook-tools

> Fuente única de verdad de este repo.
> Se actualiza en el mismo commit que el cambio, nunca aparte.
> Regla: si no se puede verificar, se escribe "SIN VERIFICAR", no se inventa.

**Última actualización:** 2026-09-13
**Actualizado por:** Cla (Chief of Staff), a petición de Mario
**Cliente:** NOOK World Cuisine (VOCO Surfside Aruba)

---

## 1. Qué es esto

Hospedaje estático (GitHub Pages, repo público, gratis) para herramientas internas de
NOOK. Empieza con "Fichas de Platillos" (`fichas/`); Mario planea subir más herramientas
aquí mismo.

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
| 2026-09-13 | Repo creado, primera herramienta cargada: `fichas/index.html` (Fichas de Platillos — captura foto+platillo+insumos+casilla "no disponible", autoguardado en localStorage). Corregido antes de subir un bug real de sintaxis que traía el archivo original (línea corrupta que rompía todo el script, ver detalle en la sesión) y el bug de un solo argumento en `downloadUpdatedCopy()`. Verificado con `node --check` + render real en Chrome headless (6 fichas cargando, checkbox presente) antes de commitear. | *(este commit)* |

## 4. Bloqueadores

- [x] **#1 — RESUELTO 13 sep 2026:** verificado con `curl` real — `/` y `/fichas/` responden HTTP 200, contenido correcto (`<h1>NOOK — Herramientas</h1>` y `<title>NOOK · Fichas de Platillos</title>`), build de Pages en estado `built` sin error (`gh api .../pages/builds/latest`).
- [ ] **#2 — Contenido público a propósito, sin dato sensible** — antes de subir la próxima herramienta a este repo, confirmar que tampoco lleva precios de costeo interno, credenciales, ni dato de cliente real (ver regla del CLAUDE.md).

## 5. Qué sigue

Mario subirá más herramientas NOOK a este mismo repo (cada una en su propia subcarpeta,
con su propio `index.html`, enlazada desde la portada raíz).

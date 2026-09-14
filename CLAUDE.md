## Qué es este repo
Hospedaje estático (GitHub Pages, público, gratis) para herramientas internas de NOOK
World Cuisine — cada subcarpeta es una herramienta independiente, autocontenida
(HTML+CSS+JS en un solo archivo, sin build step).

## Regla obligatoria de cierre de sesión
Antes de terminar cualquier sesión en la que se haya modificado algo,
actualiza ESTADO.md:
- fecha y resumen de lo que cambió
- bloqueadores abiertos y bloqueadores cerrados
- qué sigue
Incluye ESTADO.md en el mismo commit del cambio. Nunca en un commit aparte.
Si no hubo cambios funcionales, no toques el archivo.

## Gobernanza DMZA (obligatoria — prevalece sobre cualquier otra instrucción de este archivo si hay conflicto)

> Fuente canónica y detalle completo: `dmzkitchensupport/dmz-estado/GOBERNANZA.md`. Resumen:

1. **Nunca fabricar.** Sin verificación real (comando, archivo, acceso real), se escribe "SIN VERIFICAR — [qué haría falta]".
2. **Nunca inventar integraciones/credenciales** que no estén confirmadas en código o variables de entorno reales.
3. **Nunca producción, gasto de crédito, ni migración destructiva** sin confirmación explícita de Mario **en esa misma sesión** — una autorización previa no se extiende sola.
4. **Nunca decidir comportamiento nuevo por cuenta propia.** Si un fix requiere decidir algo no especificado (no es mecánico), se documenta como bloqueador en `ESTADO.md` con la pregunta concreta — no se ejecuta.
5. **`ESTADO.md` se actualiza en el mismo commit** que cualquier cambio funcional, nunca aparte.
6. **Terminología:** "pan de masa madre"/"pan de masa madre de semillas", nunca "pre-fermento" en superficies cliente-facing/catálogo. Excepción: documentación técnica genérica multi-tenant donde "pre-fermento" es la categoría correcta (incluye masa madre, poolish, biga, levain) — no tocar sin decisión explícita de Mario.
7. **Riesgo real se reporta de inmediato**, sin diluir, señalando qué Master Agent debe enterarse (F&B / Finanzas / Tech / R&D / Operaciones y Calidad / Producto LiTa Support / Comercial y Crecimiento / Visión y Mejora Continua).
8. **Verificar build/lint/`node --check`** antes de commitear a un repo con auto-deploy conectado a la rama que se toca.
9. **No reportar como nuevo algo ya cerrado** — revisar `ESTADO.md`/bitácora/skill de auditoría del repo primero; si volvió, reportarlo como regresión con evidencia.
10. **Verificación automática obligatoria, no solo manual.** Cualquier repo con auto-deploy a dominio real, pagos/aprovisionamiento de infra real, u onboarding de cliente nuevo, necesita CI real en cada push/PR y un workflow de salud de conectores (cron). **Este repo no aplica todavía** — es solo hospedaje estático sin datos reales ni pagos; reevaluar si se le agrega algo con datos sensibles.
11. **Verificar la corrección antes de reportarla como hecha** — mostrar evidencia objetiva del artefacto real (`git diff`/`gh api`/`git merge-tree`/query real a la BD), nunca el propio resumen del turno, antes de escribir "ya está hecho". Aplica a lo que se cierre bajo Protocolo de Cierre y toque producción, dinero o dato de cliente. El auditado es Lita, antes del VoBo. (Añadido 13 sep 2026.)

## Contenido público — sin datos sensibles
Este repo es **público a propósito** (gratis, decisión de Mario 13 sep 2026). No subir
aquí nada que no deba verse sin login: precios internos de costeo, credenciales, datos
de clientes reales, información financiera. Las fichas de platillos (nombre, foto,
descripción, insumos, precio de venta al público) son información de menú — equivalente
a lo que ya está impreso en la carta física, no confidencial.

/* NOOK · Resultados — lector de los Excel del cierre (navegador y Node).
   Reconoce 4 tipos de archivo por su contenido, no por su nombre:
     balance   — estado de resultados del hotel (primera celda "Account", columnas "Balance <Month>")
     ventas    — reporte de Symphony ("Fechas de negocio")
     consumos  — LOG Inventory Consumption con detalle por insumo ("Cousumption center")
     resumen   — LOG Inventory Consumption resumido por mes (fila "Month" + números de mes)
   No contiene datos. */
(function (root) {
  'use strict';
  var NOMBRES = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
  var EN = ['january','february','march','april','may','june','july','august','september','october','november','december'];
  var ABR = ['ENE','FEB','MAR','ABR','MAY','JUN','JUL','AGO','SEP','OCT','NOV','DIC'];
  var MAJ = ['Food','Liquor','Non-Alcoholic Beverages','Retail','Beer','Wine','Miscellaneous'];
  var LIN = [['ingreso','F&B INCOME'],['vFood','4112000001 FOOD SALES'],['vAlc','4112000002 ALCOHOLIC BEVERAGE SALES'],['vNoAlc','4112000003 NO ALCOHOLIC BEVERAGE'],['vMarket','4112000004 FOOD SALES MARKET'],
    ['costoDirecto','F&B DIRECT EXPENSES'],['cFood','5111100004 FOOD CONSUMPTION'],['cAlc','5111100005 ALCOHOLIC BEVERAGES CONSUMPTION'],['cNoAlc','5111100006 NON-ALCOHOLIC BEVERAGES CONSUMPTION'],['cAudit','5111100007 QUALITY F&B AUDIT'],
    ['utilidadBruta','GROSS PROFIT'],['personal','F&B PERSONNEL EXPENSES'],['contractLabor','F&B CONTRACT LABOR'],['mantenimiento','F&B REPAIR AND MAINTENANCE EXPENSES'],['generales','F&B GENERAL EXPENSES'],
    ['gastoOperativo','TOTAL OPERATING EXPENSES'],['resultado','OPERATING RESULT']];

  function clave(y, m) { return y + '-' + (m < 9 ? '0' : '') + (m + 1); }          // m: 0-11
  function norm(s) { return String(s == null ? '' : s).replace(/ /g, ' ').replace(/\s+/g, ' ').trim(); }
  function num(v) { return typeof v === 'number' ? v : null; }
  function r2(v) { return Math.round(v * 100) / 100; }
  function filas(XLSX, wb) { var ws = wb.Sheets[wb.SheetNames[0]]; return XLSX.utils.sheet_to_json(ws, { header: 1, raw: true, defval: null, blankrows: true }); }
  function limpia(r) { return (r || []).filter(function (c) { return c !== null; }); }
  function mesDeTexto(t) { t = norm(t).toUpperCase(); for (var i = 0; i < 12; i++) { if (t.indexOf(ABR[i]) === 0 || new RegExp('(^|[^A-Z])' + ABR[i] + '([^A-Z]|$)').test(t) || t.indexOf(EN[i].toUpperCase()) >= 0) return i; } return -1; }

  function tipo(R) {
    var a = norm(R[0] && R[0][0]);
    if (a === 'Account') return 'balance';
    for (var i = 0; i < Math.min(R.length, 8); i++) {
      var f = R[i] || [];
      if (norm(f[0]) === 'Fechas de negocio') return 'ventas';
      if (f.some(function (c) { return norm(c) === 'Cousumption center'; })) return 'consumos';
      if (norm(f[1]) === 'Month') return 'resumen';
    }
    return null;
  }

  function balance(R, anio) {
    var h = R[0], cols = [], out = {}, mapa = {};
    h.forEach(function (c, j) { var m = /^Balance\s+(\w+)/i.exec(norm(c)); if (m) { var i = EN.indexOf(m[1].toLowerCase()); if (i >= 0) cols.push([j, i]); } });
    R.slice(1).forEach(function (f) { if (f && f[0]) mapa[norm(f[0])] = f; });
    cols.forEach(function (c) {
      var b = {};
      LIN.forEach(function (l) { var f = mapa[l[1]], v = f ? num(f[c[0]]) : null; b[l[0]] = l[0] === 'resultado' ? r2(v || 0) : r2(Math.abs(v || 0)); });
      if (!b.ingreso && !b.costoDirecto && !b.gastoOperativo) return;
      out[clave(anio, c[1])] = b;
    });
    return out;
  }

  function ventas(R) {
    var F = R.map(limpia).filter(function (r) { return r.length; });
    var fp = F.find(function (r) { return r[0] === 'Fechas de negocio'; }) || [], per = norm(fp[1]), m = /^(\d{1,2})\/(\d{1,2})\/(\d{4})/.exec(per);
    if (!m) throw new Error('No se reconoce el periodo del reporte de ventas: "' + per + '".');
    var k = clave(+m[3], +m[2] - 1), kv = {};
    F.slice(0, 66).forEach(function (r) { if (r.length >= 2 && typeof r[0] === 'string' && typeof r[r.length - 1] === 'number' && !(r[0] in kv)) kv[r[0]] = r.length > 2 ? r.slice(1) : r[1]; });
    function tabla(h0) {
      var i = F.findIndex(function (r) { return r[0] === h0; }), out = [];
      if (i < 0) return out;
      for (var j = i + 1; j < F.length; j++) { var r = F[j]; if (typeof r[0] !== 'string' || r[0] === '' || r.length < 2 || typeof r[1] !== 'number') break; out.push(r); }
      return out;
    }
    var vn = kv['Ventas netas'];
    var centros = tabla('Nombre de centro de venta').filter(function (r) { return r[0] !== 'Total'; }).map(function (r) { return { n: r[0], venta: r2(r[1]), clientes: Math.round(r[3]), tickets: Math.round(r[6]) }; });
    var pagos = tabla('Tipo de medio de pago').filter(function (r) { return r[0] !== 'Total'; }).map(function (r) { return { n: r[0], total: r2(r[1]), n_ops: Math.round(r[2]) }; });
    var horas = {};
    tabla('Nombre de franja horaria').forEach(function (r) { var mm = /^(\d{1,2}):\d{2}$/.exec(r[0]); if (mm) horas[+mm[1]] = (horas[+mm[1]] || 0) + r[1]; });
    // Articulos: los renglones de grupo (categoria mayor o familia) valen la suma de los siguientes
    var i0 = F.findIndex(function (r) { return r[1] === 'Cantidad vendida'; }), i1 = F.findIndex(function (r) { return r[0] === 'Tipos de medios de pago'; });
    var A = F.slice(i0 + 1, i1 < 0 ? undefined : i1).filter(function (r) { return typeof r[0] === 'string' && typeof r[1] === 'number' && r[0] !== 'Total'; })
      .map(function (r) { return { n: norm(r[0]), q: r[1], neta: r[4], desc: r[3] }; });
    // Estructura del reporte: categoria mayor > familia > articulo. Cada familia vale la suma
    // de sus articulos, asi que dentro de cada mayor el primer renglon es familia y se acumula
    // hasta igualarla; el siguiente renglon abre la familia siguiente.
    var cats = {}, items = [], bloques = [], cur = null;
    A.forEach(function (a) {
      if (MAJ.indexOf(a.n) >= 0) { cur = { m: a, rows: [] }; bloques.push(cur); cats[a.n] = { cant: a.q, neta: r2(a.neta), desc: r2(a.desc) }; }
      else if (cur) cur.rows.push(a);
    });
    var cero = function (x) { return Math.abs(x.q) < 0.001 && Math.abs(x.neta) < 0.005; };
    bloques.forEach(function (bq) {
      var R2 = bq.rows, i = 0, fallo = false, salida = [];
      while (i < R2.length) {
        var f = R2[i], sq = 0, sn = 0, j = i + 1, ok = false;
        for (; j < R2.length; j++) {
          sq += R2[j].q; sn += R2[j].neta;
          if (Math.abs(sq - f.q) < 0.001 && Math.abs(sn - f.neta) < 0.011) { ok = true; j++; break; }
        }
        if (!ok) { fallo = true; break; }
        while (j < R2.length && cero(R2[j]) && !cero(f)) j++;
        for (var k = i + 1; k < j; k++) salida.push({ n: R2[k].n, cat: bq.m.n, fam: f.n, q: R2[k].q, neta: r2(R2[k].neta), desc: r2(R2[k].desc) });
        i = j;
      }
      if (fallo) salida = R2.map(function (x) { return { n: x.n, cat: bq.m.n, fam: null, q: x.q, neta: r2(x.neta), desc: r2(x.desc) }; });
      items = items.concat(salida);
    });
    var sc = 0; Object.keys(cats).forEach(function (c) { sc += cats[c].neta; });
    var si = 0; items.forEach(function (x) { si += x.neta; });
    var avisos = [];
    if (Math.abs(sc - vn) > 0.05 || Math.abs(si - vn) > 0.05) avisos.push('Los artículos de ' + k + ' suman ' + r2(si) + ' y la venta neta es ' + r2(vn) + '; revisar el archivo.');
    var par = function (x) { return { n: Math.round(x[0]), m: r2(x[1]) }; };
    return { clave: k, avisos: avisos, datos: {
      periodo: per, ventaNeta: r2(vn), servicio: r2(kv['Cargos por servicio'] || 0), ingresos: r2(kv['Total de ingresos'] || 0),
      descuentos: r2(kv['Total de descuentos'] || 0), clientes: Math.round(kv['Recuento de clientes'] || 0), tickets: Math.round(kv['Recuento de tickets'] || 0),
      propinas: r2(kv['Total de propinas'] || 0), anulaciones: par(kv['Anulaciones'] || [0, 0]), anulMgr: par(kv['Anulaciones de mánager'] || [0, 0]),
      correcciones: par(kv['Correcciones'] || [0, 0]), cancelaciones: par(kv['Cancelaciones'] || [0, 0]),
      centros: centros, pagos: pagos, categorias: cats,
      horas: Object.keys(horas).map(Number).sort(function (a, b) { return a - b; }).map(function (h) { return { h: h, venta: r2(horas[h]) }; }),
      items: items.sort(function (a, b) { return b.neta - a.neta; }) } };
  }

  function consumos(R, hoja, archivo, anio) {
    var hi = R.findIndex(function (f) { return (f || []).some(function (c) { return norm(c) === 'Cousumption center'; }); });
    var h = R[hi].map(norm), cF = h.indexOf('Date'), cC = h.indexOf('Cousumption center'), cD = h.indexOf('Description'), cK = h.indexOf('Cost'), cQ = h.indexOf('Quantity');
    var cen = null, dia = null, total = null, centros = {}, prod = {}, dias = {}, mesFecha = -1, anioFecha = null, n = 0;
    R.slice(hi + 1).forEach(function (f) {
      if (!f) return;
      if (norm(f[0]) === 'Totals') { total = num(f[cK]); return; }
      if (cF >= 0 && f[cF]) { dia = norm(f[cF]); var md = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(dia); if (md) { mesFecha = +md[2] - 1; anioFecha = +md[3]; } }
      if (f[cC]) { var c = norm(f[cC]); if (c !== 'Totals') cen = c; }
      var d = norm(f[cD]); if (!d || d === 'Totals' || norm(f[cC]) === 'Totals') return;
      var costo = num(f[cK]) || 0, cant = num(f[cQ]) || 0;
      centros[cen] = (centros[cen] || 0) + costo; n++;
      var key = d.replace(/ Qty\.$/, '') + '|' + cen; if (!prod[key]) prod[key] = [0, 0]; prod[key][0] += costo; prod[key][1] += cant;
      if (dia) dias[dia] = (dias[dia] || 0) + costo;
    });
    var suma = 0; Object.keys(centros).forEach(function (c) { suma += centros[c]; });
    var avisos = [];
    if (total !== null && Math.abs(suma - total) > 0.05) avisos.push('Las líneas de ' + archivo + ' suman ' + r2(suma) + ' y el total del archivo es ' + r2(total) + '.');
    var mH = mesDeTexto(hoja), mA = mesDeTexto(archivo), mes = mesFecha >= 0 ? mesFecha : (mH >= 0 ? mH : mA);
    if (mesFecha < 0 && mH >= 0 && mA >= 0 && mH !== mA) avisos.push('El archivo ' + archivo + ' dice ' + NOMBRES[mA].toLowerCase() + ' en el nombre pero su hoja dice ' + NOMBRES[mH].toLowerCase() + '. Se tomó como ' + NOMBRES[mH].toLowerCase() + '; si no es correcto, pide el archivo de nuevo.');
    if (mes < 0) throw new Error('No se pudo saber de qué mes es ' + archivo + ': no trae fechas y ni el nombre ni la hoja dicen el mes.');
    var out = { total: r2(total !== null ? total : suma), centros: {}, lineas: n,
      top: Object.keys(prod).map(function (k) { var p = k.split('|'); return { n: p[0], c: p[1], costo: r2(prod[k][0]), cant: Math.round(prod[k][1] * 100) / 100 }; }).sort(function (a, b) { return b.costo - a.costo; }).slice(0, 25) };
    Object.keys(centros).forEach(function (c) { out.centros[c] = r2(centros[c]); });
    var nd = Object.keys(dias).length; if (nd) { out.dias = nd; out.porDia = Object.keys(dias).map(function (d) { return { d: d, costo: r2(dias[d]) }; }); }
    return { clave: clave(anioFecha || anio, mes), avisos: avisos, datos: out };
  }

  function resumen(R, anio) {
    var hm = R.findIndex(function (f) { return f && norm(f[1]) === 'Month'; }), meses = R[hm + 1], hc = hm + 2, out = {};
    var cols = []; (meses || []).forEach(function (v, j) { if (typeof v === 'number' && v >= 1 && v <= 12) cols.push([j, v - 1]); });
    cols.forEach(function (c) { out[clave(anio, c[1])] = { total: 0, centros: {}, top: [], lineas: 0, sinDetalle: true }; });
    R.slice(hc + 1).forEach(function (f) {
      if (!f || !f[0]) return; var n = norm(f[0]);
      cols.forEach(function (c) { var v = num(f[c[0]]); if (v === null) return; var o = out[clave(anio, c[1])]; if (n === 'Totals') o.total = r2(v); else o.centros[n] = r2(v); });
    });
    return out;
  }

  /* archivos: [{nombre, wb}] ; base: payload actual o null ; anio: año para balance/consumos sin fecha */
  function procesar(XLSX, archivos, base, anio) {
    var P = migrar(base), log = [], avisos = [], firmas = {}, det = [];
    function asegura(k) { if (P.meses.indexOf(k) < 0) P.meses.push(k); var mi = +k.slice(5) - 1; P.nombres[k] = NOMBRES[mi] + (+k.slice(0, 4) !== anio ? ' ' + k.slice(0, 4) : ''); }
    var orden = { resumen: 0, balance: 1, ventas: 2, consumos: 3 }, lista = [];
    archivos.forEach(function (a) { var R = filas(XLSX, a.wb); lista.push({ a: a, R: R, t: tipo(R) }); });
    lista.sort(function (x, y) { return (orden[x.t] == null ? 9 : orden[x.t]) - (orden[y.t] == null ? 9 : orden[y.t]); });
    lista.forEach(function (x) {
      var a = x.a, R = x.R;
      try {
        if (!x.t) { det.push({ nombre: a.nombre, tipo: null, meses: [], error: 'No es un balance, un reporte de ventas de Symphony ni un reporte de consumos.' }); avisos.push(a.nombre + ': no se reconoce el tipo de archivo; se ignoró.'); return; }
        if (x.t === 'balance') { var b = balance(R, anio); Object.keys(b).forEach(function (k) { asegura(k); P.balance[k] = b[k]; }); det.push({ nombre: a.nombre, tipo: 'balance', meses: Object.keys(b) }); log.push(a.nombre + ': balance de ' + Object.keys(b).map(function (k) { return P.nombres[k]; }).join(', ') + '.'); }
        if (x.t === 'ventas') { var v = ventas(R); asegura(v.clave); P.symphony[v.clave] = v.datos; det.push({ nombre: a.nombre, tipo: 'ventas', meses: [v.clave], error: v.avisos[0] }); avisos = avisos.concat(v.avisos); log.push(a.nombre + ': ventas de ' + P.nombres[v.clave] + ' (' + v.datos.items.length + ' artículos).'); }
        if (x.t === 'resumen') { var s = resumen(R, anio); Object.keys(s).forEach(function (k) { asegura(k); if (!P.consumos[k] || P.consumos[k].sinDetalle) P.consumos[k] = s[k]; }); det.push({ nombre: a.nombre, tipo: 'resumen', meses: Object.keys(s) }); log.push(a.nombre + ': resumen de consumos de ' + Object.keys(s).map(function (k) { return P.nombres[k]; }).join(', ') + '.'); }
        if (x.t === 'consumos') {
          var c = consumos(R, a.wb.SheetNames[0], a.nombre, anio), f = c.datos.total + '|' + c.datos.lineas;
          if (firmas[f]) { det.push({ nombre: a.nombre, tipo: 'consumos', meses: [], error: 'Es idéntico a ' + firmas[f] + '; se ignoró.' }); avisos.push(a.nombre + ' es idéntico a ' + firmas[f] + '; se ignoró. Pide el archivo correcto.'); return; }
          firmas[f] = a.nombre; asegura(c.clave); P.consumos[c.clave] = c.datos; avisos = avisos.concat(c.avisos); det.push({ nombre: a.nombre, tipo: 'consumos', meses: [c.clave], error: c.avisos[0] });
          log.push(a.nombre + ': consumos de ' + P.nombres[c.clave] + ' (' + c.datos.lineas + ' líneas).');
        }
      } catch (e) { det.push({ nombre: a.nombre, tipo: x.t, meses: [], error: e.message }); avisos.push(a.nombre + ': ' + e.message); }
    });
    P.meses.sort();
    P.meses.forEach(function (k) {
      if (!P.balance[k]) avisos.push(P.nombres[k] + ' no tiene balance todavía; no se mostrará hasta que se cargue.');
      if (!P.consumos[k]) P.consumos[k] = { total: 0, centros: {}, top: [], lineas: 0, sinDetalle: true };
    });
    P.meses = P.meses.filter(function (k) { return !!P.balance[k]; });
    P.generado = new Date().toISOString().slice(0, 10);
    return { payload: P, log: log, avisos: avisos, archivos: det };
  }

  /* Convierte el formato viejo (claves JUL, AGO...) a AAAA-MM. SUPUESTO: año 2026. */
  function migrar(base) {
    var P = { moneda: 'USD', meses: [], nombres: {}, balance: {}, symphony: {}, consumos: {} };
    if (!base || !base.meses) return P;
    base.meses.forEach(function (m) {
      var k = /^\d{4}-\d{2}$/.test(m) ? m : clave(2026, ABR.indexOf(m));
      if (k.indexOf('-00') > 0 || /NaN|-0-/.test(k)) return;
      P.meses.push(k); P.nombres[k] = (base.nombres && base.nombres[m]) || NOMBRES[+k.slice(5) - 1];
      if (base.balance && base.balance[m]) P.balance[k] = base.balance[m];
      if (base.symphony && base.symphony[m]) P.symphony[k] = base.symphony[m];
      if (base.consumos && base.consumos[m]) P.consumos[k] = base.consumos[m];
    });
    return P;
  }

  var api = { procesar: procesar, migrar: migrar, tipo: tipo, clave: clave, NOMBRES: NOMBRES };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.NookResultadosParser = api;
})(this);

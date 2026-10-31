# La Vaca Original · Inventario de Materia Prima

App web (un solo `index.html`) para controlar la materia prima de bodega: entradas, salidas del día, alertas de stock e historial. Backend en Supabase, publicada en GitHub Pages.

## Bodegas (Valle y Quindío)
Una sola app para las dos bodegas. Al abrirla se elige la bodega y todo lo que se registra queda en esa: stock, alertas, entradas, salidas, historial y pedidos. Se cambia con el botón 📍 de arriba.
El catálogo de insumos (nombres, categorías y presentaciones) es el mismo para las dos; los niveles de alerta son de cada bodega.
Para agregar otra bodega: en Supabase → Table Editor → `mp_bodegas` → Insert row.

## Presentaciones y conversión
Cada insumo guarda su stock en una **unidad base** (kg, litros, unidades o metros) y tiene sus **presentaciones**:
- Azúcar → base **kg**, presentación **Bulto = 50 kg**. Kilo, libra (500 g), gramo y arroba vienen incluidos.
- Tarrinas 12 oz → base **und**, presentación **Caja = 500 und**.

Si entran 10 bultos de azúcar el stock queda en 500 kg (10 bultos). Si salen 10 kilos queda 490 kg, y la app lo muestra como *9 bultos + 40 kg · 980 lb*.
El historial guarda la presentación con que se registró cada movimiento y se puede filtrar por ella.

Las presentaciones se editan tocando el insumo → *Presentaciones, alertas y datos*.

## Averías
Lo que se descarta por estar dañado (vencido, roto, humedad, plaga, llegó malo…) se registra como **⚠ Avería**: dentro del insumo o en *Del día → Averías*. Descuenta del stock como una salida pero exige motivo y queda separada en el historial (filtro *Averías* + total perdido por insumo del periodo).

## Semáforo
- 🟢 **Suficiente**: stock por encima del nivel amarillo.
- 🟡 **Por agotarse**: stock ≤ nivel amarillo (por defecto 2 presentaciones, ej. 2 bultos).
- 🔴 **Crítico**: stock ≤ nivel rojo (por defecto 1 presentación). Aparece en **Pedido** para pedir con urgencia.

Cada insumo tiene sus propios niveles (tocar el insumo → "Niveles de alerta"), porque no es lo mismo 2 bultos de harina que 2 cajas de tarrinas.

## Pedido
Pestaña **Pedido** (abajo): aparecen los insumos en rojo y amarillo. Escribe cuánto pedir y en qué presentación (las del producto, o cualquier otra: bulto, caja, rollo, lata, galón… o ✏️ *Otra*), o usa *Sugerir cantidades*. Con *Agregar otro insumo* (o el botón 🛒 dentro de cada insumo) se puede pedir cualquier producto aunque esté en verde. El botón fijo **Enviar pedido por WhatsApp** arma el mensaje por categorías y lo guarda en *Pedidos enviados*, desde donde se puede reenviar o reutilizar.

## Instalación

### 1. Supabase
1. Abre tu proyecto en Supabase → **SQL Editor** → **New query**.
2. Pega todo el contenido de `supabase.sql` y dale **Run**. ⚠️ Si ya habías corrido la versión anterior, este script la reemplaza y borra los datos de prueba.
   Crea las tablas `mp_insumos` y `mp_movimientos`, la función `mp_registrar_movimiento` la tabla `mp_pedidos` y carga los 144 insumos del Excel (los repetidos por presentación, como Arroz bulto/arroba, quedan unidos).
   Si ya lo habías corrido antes, NO lo vuelvas a correr: corre solo los que falten, en orden: `bodegas.sql` y luego `averias.sql` (no borran nada).
3. En **Project Settings → API** copia la **Project URL** y la **anon public key**.

### 2. GitHub
1. Crea un repositorio nuevo, por ejemplo `inventario-materia-prima`, en la cuenta Lavacaoriginal.
2. Sube `index.html`, `supabase.sql`, `bodegas.sql`, `averias.sql` y este `README.md` (Add file → Upload files).
3. `index.html` ya trae la URL y la publishable key del proyecto **Materia Prima** (líneas 336–337). No hay que editarlo.
4. **Settings → Pages** → Source: `main` / root → Save.
   Queda en `https://lavacaoriginal.github.io/inventario-materia-prima/`.

> Si no pegas las claves en el archivo, se pueden poner desde el botón ⚙︎ de la app (quedan guardadas solo en ese dispositivo). Sin claves la app funciona en **modo demo**.

## Uso diario
- **Inventario**: ver stock por categoría, filtrar por amarillos/rojos, tocar un insumo para registrar salida, entrada o ajuste por conteo.
- **Del día**: escribir las cantidades de todo lo que salió (o entró) y registrarlas de una vez.
- **Pedido**: lista de rojos y amarillos lista para enviar por WhatsApp.
- **Historial**: consultar por fechas, tipo e insumo, y exportar a CSV (Excel). El historial no se puede editar ni borrar desde la app.
- **＋ Nuevo**: agregar insumos o categorías nuevas. Los insumos que ya no se usan se **desactivan** (no se borran) para no perder su historial.

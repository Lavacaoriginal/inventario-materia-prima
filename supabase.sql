-- =====================================================
-- LA VACA ORIGINAL · Inventario de Materia Prima  (v2: presentaciones)
-- Ejecutar completo en Supabase > SQL Editor
-- ⚠️ Instalación inicial: BORRA las tablas mp_ si ya existían (datos de prueba)
-- =====================================================

drop function if exists mp_registrar_movimiento(bigint,text,numeric,text,text);
drop function if exists mp_registrar_movimiento(bigint,text,numeric,text,numeric,text,text);
drop table if exists mp_movimientos;
drop table if exists mp_insumos;

create table mp_insumos (
  id                     bigint generated always as identity primary key,
  categoria              text not null,
  nombre                 text not null unique,
  unidad_base            text not null default 'und',  -- kg, L, und, m (o un empaque: Cuñete, Poma…)
  presentaciones         jsonb not null default '[]',  -- [{"n":"Bulto","f":50}]  f = cuántas unidades base trae
  presentacion_principal text,                          -- cómo se muestra el stock (ej. Bulto)
  stock                  numeric not null default 0,    -- SIEMPRE en unidad base (kg, L, und…)
  nivel_alerta           numeric not null default 0,    -- amarillo (en unidad base)
  nivel_critico          numeric not null default 0,    -- rojo (en unidad base)
  activo                 boolean not null default true,
  created_at             timestamptz not null default now()
);

create table mp_movimientos (
  id                     bigint generated always as identity primary key,
  insumo_id              bigint not null references mp_insumos(id),
  tipo                   text not null check (tipo in ('entrada','salida','ajuste','alta')),
  cantidad               numeric not null,   -- en unidad base
  presentacion           text,               -- cómo se registró: Bulto, Libra, Caja…
  cantidad_presentacion  numeric,            -- ej. 10 (bultos)
  stock_anterior         numeric not null,
  stock_resultante       numeric not null,
  detalle                text,
  responsable            text,
  created_at             timestamptz not null default now()
);
create index mp_mov_fecha_idx on mp_movimientos (created_at desc);
create index mp_mov_insumo_idx on mp_movimientos (insumo_id);

create or replace function mp_registrar_movimiento(
  p_insumo_id bigint, p_tipo text, p_cantidad numeric,
  p_presentacion text default null, p_cantidad_presentacion numeric default null,
  p_detalle text default null, p_responsable text default null
) returns numeric language plpgsql as $$
declare v_ant numeric; v_nuevo numeric;
begin
  select stock into v_ant from mp_insumos where id = p_insumo_id for update;
  if v_ant is null then raise exception 'Insumo no existe'; end if;
  if p_tipo = 'entrada' then v_nuevo := v_ant + p_cantidad;
  elsif p_tipo = 'salida' then
    if p_cantidad > v_ant + 0.000001 then raise exception 'Stock insuficiente (hay %)', round(v_ant,3); end if;
    v_nuevo := greatest(v_ant - p_cantidad, 0);
  elsif p_tipo in ('ajuste','alta') then v_nuevo := p_cantidad;
  else raise exception 'Tipo inválido'; end if;
  update mp_insumos set stock = v_nuevo where id = p_insumo_id;
  insert into mp_movimientos (insumo_id,tipo,cantidad,presentacion,cantidad_presentacion,stock_anterior,stock_resultante,detalle,responsable)
  values (p_insumo_id,p_tipo,p_cantidad,p_presentacion,p_cantidad_presentacion,v_ant,v_nuevo,p_detalle,p_responsable);
  return v_nuevo;
end $$;

alter table mp_insumos enable row level security;
alter table mp_movimientos enable row level security;
create policy mp_ins_all on mp_insumos for all to anon using (true) with check (true);
create policy mp_mov_read on mp_movimientos for select to anon using (true);
create policy mp_mov_ins on mp_movimientos for insert to anon with check (true);

-- Historial de pedidos enviados
create table if not exists mp_pedidos (
  id          bigint generated always as identity primary key,
  items       jsonb not null,      -- [{insumo_id, nombre, cat, cantidad, presentacion, stock, unidad_base}]
  nota        text,
  responsable text,
  created_at  timestamptz not null default now()
);
alter table mp_pedidos enable row level security;
drop policy if exists mp_ped_read on mp_pedidos;
create policy mp_ped_read on mp_pedidos for select to anon using (true);
drop policy if exists mp_ped_ins on mp_pedidos;
create policy mp_ped_ins on mp_pedidos for insert to anon with check (true);

-- Niveles por defecto: amarillo = 2 presentaciones, rojo = 1 (ajústalos en la app)
-- Catálogo inicial (144 insumos). Revisa en la app las presentaciones marcadas como aproximadas.
insert into mp_insumos (categoria, nombre, unidad_base, presentaciones, presentacion_principal, nivel_alerta, nivel_critico) values
  ('HARINAS', 'ARROZ', 'kg', '[{"n": "Bulto", "f": 50}]'::jsonb, 'Bulto', 100, 50),
  ('HARINAS', 'AZUCAR', 'kg', '[{"n": "Bulto", "f": 50}]'::jsonb, 'Bulto', 100, 50),
  ('HARINAS', 'FECULA', 'kg', '[{"n": "Bulto", "f": 50}]'::jsonb, 'Bulto', 100, 50),
  ('HARINAS', 'LECHE EN POLVO', 'kg', '[{"n": "Bulto", "f": 25}]'::jsonb, 'Bulto', 50, 25),
  ('HARINAS', 'GELATINA SIN SABOR', 'kg', '[{"n": "Bulto", "f": 25}, {"n": "Empaque 500 g", "f": 0.5}]'::jsonb, 'Bulto', 50, 25),
  ('HARINAS', 'HARINA', 'kg', '[{"n": "Bulto", "f": 50}]'::jsonb, 'Bulto', 100, 50),
  ('HARINAS', 'PREMEZCLA BISCOCHUELO', 'kg', '[{"n": "Bulto", "f": 12.5}]'::jsonb, 'Bulto', 25.0, 12.5),
  ('GALLETERIA', 'DUCALES', 'und', '[{"n": "Taco", "f": 3.0}]'::jsonb, 'Taco', 6.0, 3.0),
  ('GALLETERIA', 'GALLETA OREO', 'und', '[{"n": "Paquete", "f": 12.0}]'::jsonb, 'Paquete', 24.0, 12.0),
  ('GALLETERIA', 'GALLETA MILO', 'und', '[{"n": "Paquete", "f": 12.0}]'::jsonb, 'Paquete', 24.0, 12.0),
  ('GALLETERIA', 'RECREO TRITURADO', 'und', '[{"n": "Caja", "f": 6.0}]'::jsonb, 'Caja', 12.0, 6.0),
  ('GALLETERIA', 'SULTANA', 'und', '[{"n": "Caja", "f": 6.0}]'::jsonb, 'Caja', 12.0, 6.0),
  ('GALLETERIA', 'MILO EN POLVO', 'kg', '[{"n": "Bolsa", "f": 2.0}]'::jsonb, 'Bolsa', 4.0, 2.0),
  ('GALLETERIA', 'CAFÉ INSTANTANEO', 'kg', '[{"n": "Frasco", "f": 0.17}]'::jsonb, 'Frasco', 0.34, 0.17),
  ('GALLETERIA', 'CAFÉ EN GRANO', 'kg', '[{"n": "Bolsa 500 g", "f": 0.5}, {"n": "Bolsa 1 kg", "f": 1.0}, {"n": "Bolsa 2.5 kg", "f": 2.5}]'::jsonb, 'Bolsa 2.5 kg', 5.0, 2.5),
  ('GALLETERIA', 'OBLEAS', 'Paquete', '[]'::jsonb, null, 5, 2),
  ('GALLETERIA', 'SUSPIROS', 'Paquete', '[]'::jsonb, null, 5, 2),
  ('GALLETERIA', 'DURAZNOS', 'kg', '[{"n": "Lata 360 g", "f": 0.36}, {"n": "Lata 3.06 kg", "f": 3.06}]'::jsonb, 'Lata 3.06 kg', 6.12, 3.06),
  ('CONSERVANTES', 'ZUCAR PLUS', 'und', '[]'::jsonb, null, 5, 2),
  ('CONSERVANTES', 'NATAMICINA', 'und', '[]'::jsonb, null, 5, 2),
  ('CONSERVANTES', 'BENZOATO DE SODIO', 'kg', '[]'::jsonb, null, 5, 2),
  ('CONSERVANTES', 'SEMILLAS AMAPOLA', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'AMARETTO', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'BRANDY', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'CUAJO LIQUIDO', 'L', '[{"n": "Botella", "f": 1.0}]'::jsonb, 'Botella', 2.0, 1.0),
  ('ADITIVOS', 'LECHE CONDENSADA', 'Cuñete', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'AREQUIPE DULCE MANJAR BLANCO', 'Cuñete', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'GLASEADO MORA', 'L', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'GLASEADO FRESA', 'L', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'GLASEADO MARACUYA', 'L', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'GELATINA SABOR FRESA', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'GELATINA SABOR MORA', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'GELATINA SABOR LIMON', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'CANELA EN ASTILLA', 'Paquete', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'CANELA EN POLVO', 'kg', '[{"n": "Empaque", "f": 1.0}]'::jsonb, 'Empaque', 2.0, 1.0),
  ('ADITIVOS', 'PANELA', 'Atado', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'CHOCOLATE', 'Caja', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'ACEITE', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'CREMA DE LECHE', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'LECHE DESLACTOSADA', 'und', '[]'::jsonb, null, 5, 2),
  ('ADITIVOS', 'LECHE LIQUIDA', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'AMARILLO CLARO', 'kg', '[{"n": "Empaque", "f": 0.5}]'::jsonb, 'Empaque', 1.0, 0.5),
  ('COLORANTES Y SABORES', 'AMARILLO HUEVO', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'SABOR GUANABANA PL', 'kg', '[{"n": "Empaque 100 g", "f": 0.1}, {"n": "Empaque 1 kg", "f": 1}]'::jsonb, 'Empaque 1 kg', 2, 1),
  ('COLORANTES Y SABORES', 'SABOR LACTEO MELOCOTON', 'L', '[{"n": "Garrafa", "f": 3.0}]'::jsonb, 'Garrafa', 6.0, 3.0),
  ('COLORANTES Y SABORES', 'SABOR MANGO A14', 'L', '[{"n": "Garrafa", "f": 3.0}]'::jsonb, 'Garrafa', 6.0, 3.0),
  ('COLORANTES Y SABORES', 'SABOR MANGO A13', 'L', '[{"n": "Envase", "f": 0.5}]'::jsonb, 'Envase', 1.0, 0.5),
  ('COLORANTES Y SABORES', 'SABOR MANGO PL', 'kg', '[{"n": "Empaque", "f": 0.1}]'::jsonb, 'Empaque', 0.2, 0.1),
  ('COLORANTES Y SABORES', 'SABOR LACTEO MORA', 'L', '[{"n": "Garrafa", "f": 3.0}]'::jsonb, 'Garrafa', 6.0, 3.0),
  ('COLORANTES Y SABORES', 'SABOR LACTEO FRESA', 'L', '[{"n": "Garrafa", "f": 3.0}]'::jsonb, 'Garrafa', 6.0, 3.0),
  ('COLORANTES Y SABORES', 'SABOR LACTEO PIÑA', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'SABORIZANTE KIWI', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'COLOR VERDE MANZANA', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'COLOR VERDE LIMON PAYASITO', 'L', '[{"n": "Envase", "f": 0.39}]'::jsonb, 'Envase', 0.78, 0.39),
  ('COLORANTES Y SABORES', 'COLOR VERDE NAVIDAD', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'ROJO ESCARLATA EN POLVO', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'PASTAROMA', 'und', '[]'::jsonb, null, 5, 2),
  ('COLORANTES Y SABORES', 'QUEMADO DE PANELA', 'kg', '[{"n": "Empaque", "f": 0.5}]'::jsonb, 'Empaque', 1.0, 0.5),
  ('PANADERIA', 'CERNIDO DE GUAYABA', 'Caja', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'AREQUIPE TAPA VERDE', 'L', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'AREQUIPE TAPA ROJA', 'L', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'LEVADURA', 'kg', '[{"n": "Empaque", "f": 0.5}]'::jsonb, 'Empaque', 1.0, 0.5),
  ('PANADERIA', 'POLVO PARA HORNEAR', 'und', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'MARGARINA', 'und', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'GRASA HIDROGENADA', 'und', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'COCO RAYADO DULCE', 'kg', '[{"n": "Empaque", "f": 1.0}]'::jsonb, 'Empaque', 2.0, 1.0),
  ('PANADERIA', 'ESENCIA VAINILLA BLANCA', 'L', '[{"n": "Envase", "f": 3.85}]'::jsonb, 'Envase', 7.7, 3.85),
  ('PANADERIA', 'ESENCIA VAINILLA NEGRA', 'L', '[{"n": "Envase", "f": 3.85}]'::jsonb, 'Envase', 7.7, 3.85),
  ('PANADERIA', 'ESENCIA BANANO', 'und', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'ESENCIA COCO', 'und', '[]'::jsonb, null, 5, 2),
  ('PANADERIA', 'ESENCIA PONQUE', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'TARRINAS 12 OZ', 'und', '[{"n": "Caja", "f": 500.0}]'::jsonb, 'Caja', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'TARRINAS 8 OZ', 'und', '[{"n": "Caja", "f": 500.0}]'::jsonb, 'Caja', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'TARIINAS 6 OZ', 'und', '[{"n": "Caja", "f": 500.0}]'::jsonb, 'Caja', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'TARRINAS 16 OZ', 'und', '[{"n": "Caja", "f": 500.0}]'::jsonb, 'Caja', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'TARRINA DOBLE USO', 'und', '[{"n": "Caja", "f": 200.0}]'::jsonb, 'Caja', 400.0, 200.0),
  ('TARRINAS Y DESECHABLES', 'TARRINA TRIANGULAR TAPA BAJA', 'und', '[{"n": "Caja", "f": 200.0}]'::jsonb, 'Caja', 400.0, 200.0),
  ('TARRINAS Y DESECHABLES', 'TAPA CRISTAL BANDEJA # 1', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BANDEJA # 1', 'und', '[{"n": "Paca", "f": 500.0}]'::jsonb, 'Paca', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'BANDEJA # 4', 'und', '[{"n": "Paca", "f": 500.0}]'::jsonb, 'Paca', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'BANDEJA # 6', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BLONDA # 24', 'und', '[{"n": "Paca", "f": 200.0}]'::jsonb, 'Paca', 400.0, 200.0),
  ('TARRINAS Y DESECHABLES', 'DOMO CIRCULAR # 25', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'DOMO CIRCULAR TAPA CRISTAL # 25', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'MOLDE ALUMNIO 8 OZ', 'und', '[{"n": "Caja", "f": 500.0}]'::jsonb, 'Caja', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'TAPA CRISTAL MOLDE ALUMNIO 8 OZ', 'und', '[{"n": "Caja", "f": 500.0}]'::jsonb, 'Caja', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'BASE HELADO MULTIUSOS 8 OZ', 'und', '[{"n": "Paquete", "f": 50.0}]'::jsonb, 'Paquete', 100.0, 50.0),
  ('TARRINAS Y DESECHABLES', 'TAPA BASE HELADO MULTIUSOS 8 OZ', 'und', '[{"n": "Paquete", "f": 50.0}]'::jsonb, 'Paquete', 100.0, 50.0),
  ('TARRINAS Y DESECHABLES', 'CUCHARA CHIC BLANCA', 'und', '[{"n": "Paquete", "f": 100.0}]'::jsonb, 'Paquete', 200.0, 100.0),
  ('TARRINAS Y DESECHABLES', 'CUCHARA TAMI 11 CM BLANCA', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'SERVILLETAS PLUS', 'und', '[{"n": "Paquete", "f": 100.0}]'::jsonb, 'Paquete', 200.0, 100.0),
  ('TARRINAS Y DESECHABLES', 'CUCHARA POSTRERA BLANCA', 'und', '[{"n": "Paquete", "f": 1000}]'::jsonb, 'Paquete', 2000, 1000),
  ('TARRINAS Y DESECHABLES', 'COPA VENECIANA 8 OZ', 'und', '[{"n": "Caja", "f": 500.0}]'::jsonb, 'Caja', 1000.0, 500.0),
  ('TARRINAS Y DESECHABLES', 'BOLSAS EMPACADO AL VACIO 18X22', 'und', '[{"n": "Paquete", "f": 250.0}]'::jsonb, 'Paquete', 500.0, 250.0),
  ('TARRINAS Y DESECHABLES', 'BOLSAS EMPACADO AL VACIO 15X20', 'und', '[{"n": "Paquete", "f": 250.0}]'::jsonb, 'Paquete', 500.0, 250.0),
  ('TARRINAS Y DESECHABLES', 'BOLSATINAS', 'und', '[{"n": "Rollo", "f": 40.0}]'::jsonb, 'Rollo', 80.0, 40.0),
  ('TARRINAS Y DESECHABLES', 'BOLSAS BARCO OBLEAS', 'und', '[{"n": "Paquete", "f": 100.0}]'::jsonb, 'Paquete', 200.0, 100.0),
  ('TARRINAS Y DESECHABLES', 'GUANTES PARA OBLEAS', 'und', '[{"n": "Paquete", "f": 100.0}]'::jsonb, 'Paquete', 200.0, 100.0),
  ('TARRINAS Y DESECHABLES', 'BOLSAS PARA PAN TRANSPARENTES', 'und', '[{"n": "Paquete", "f": 100.0}]'::jsonb, 'Paquete', 200.0, 100.0),
  ('TARRINAS Y DESECHABLES', 'BOLSAS DE PAPEL GRANDES', 'Fajo', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BOLSAS DE PAPEL PEQUEÑAS', 'Fajo', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BOLSAS BIODEGRADABLES T19', 'Rollo', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BOLSAS BIODEGRADABLES T25', 'Rollo', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BOLSAS BIODEGRADABLES T30', 'Rollo', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BOLSA INDUSTRIAL GRANDE', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'BOLSA INDUSTRIAL PEQUEÑA', 'und', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'VASOS DE CARTON 6 OZ', 'und', '[{"n": "Paquete", "f": 50.0}]'::jsonb, 'Paquete', 100.0, 50.0),
  ('TARRINAS Y DESECHABLES', 'VASOS DE CARTON 9 OZ', 'und', '[{"n": "Paquete", "f": 40.0}]'::jsonb, 'Paquete', 80.0, 40.0),
  ('TARRINAS Y DESECHABLES', 'VASOS DE CARTON 14 OZ', 'und', '[{"n": "Paquete", "f": 50.0}]'::jsonb, 'Paquete', 100.0, 50.0),
  ('TARRINAS Y DESECHABLES', 'VASOS DESECHABLES', 'und', '[{"n": "Paquete", "f": 50.0}]'::jsonb, 'Paquete', 100.0, 50.0),
  ('TARRINAS Y DESECHABLES', 'VINIPEL', 'm', '[{"n": "Rollo", "f": 1000.0}]'::jsonb, 'Rollo', 2000.0, 1000.0),
  ('TARRINAS Y DESECHABLES', 'MATES DE MEDIA', 'Bulto', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'MATES DE LIBRA', 'Bulto', '[]'::jsonb, null, 5, 2),
  ('TARRINAS Y DESECHABLES', 'TARROS YOGURT 1 LITRO', 'und', '[{"n": "Paca", "f": 80.0}]'::jsonb, 'Paca', 160.0, 80.0),
  ('TARRINAS Y DESECHABLES', 'TARROS YOGURT 1,8 LITROS', 'und', '[{"n": "Paca", "f": 50.0}]'::jsonb, 'Paca', 100.0, 50.0),
  ('TARRINAS Y DESECHABLES', 'TARROS YOGURT PERSONAL', 'und', '[{"n": "Paca", "f": 170.0}]'::jsonb, 'Paca', 340.0, 170.0),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO FRESA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO MORA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO MANGO', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO PIÑA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO MELOCOTON', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO GUANABANA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO KIWI', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1 LITRO KUMIS', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO FRESA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO MORA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO MANGO', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO PIÑA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO MELOCOTON', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO GUANABANA', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO KIWI', 'und', '[]'::jsonb, null, 5, 2),
  ('ETIQUETAS', 'ETIQUETAS 1.8 LITRO KUMIS', 'und', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'PAPEL HIGIENICO', 'und', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'DESENGRASANTE', 'L', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'HIPOCLORITO', 'Poma', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'AMBIENTADOR', 'L', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'LAVA LOSA', 'kg', '[{"n": "Tarro", "f": 3.5}]'::jsonb, 'Tarro', 7.0, 3.5),
  ('ASEO', 'ESPONJAS', 'und', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'TRAPOS', 'und', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'ESCOBA', 'und', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'RECOGEDOR', 'und', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'TRAPEADOR', 'und', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'JABON MANOS', 'L', '[]'::jsonb, null, 5, 2),
  ('ASEO', 'ALCOHOL', 'Poma', '[]'::jsonb, null, 5, 2);

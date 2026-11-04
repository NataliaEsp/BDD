/* 4. Realizar una consulta que muestre para todos los artículos código, detalle y cantidad de 
artículos que lo componen. Mostrar solo aquellos artículos para los cuales el stock 
promedio por depósito sea mayor a 100. */
SELECT 
	p.prod_codigo AS Cod_Prod,
	p.prod_detalle AS Detalle_Prod,
	ISNULL(SUM(c.comp_cantidad)	,0) AS Cant_Componentes
FROM Producto p
LEFT JOIN Composicion c ON p.prod_codigo = c.comp_producto
GROUP BY p.prod_codigo, p.prod_detalle
HAVING (
	SELECT AVG(s.stoc_cantidad) 
	FROM STOCK s
	WHERE s.stoc_producto = p.prod_codigo 
	) > 100

/* 7. Generar una consulta que muestre para cada artículo código, detalle, mayor precio 
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio = 
10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que posean stock. */
SELECT
	p.prod_codigo AS Cod_Prod,
	p.prod_detalle AS Detalle_Prod,
	MAX(i.item_precio) AS Max_Precio,
	MIN(i.item_precio) AS Min_Precio,
	(MAX(i.item_precio) - MIN(i.item_precio)) * 100.0 / NULLIF(MIN(i.item_precio), 0)
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE EXISTS (
		SELECT *
		FROM STOCK s
		WHERE p.prod_codigo = s.stoc_producto AND s.stoc_cantidad > 0)
GROUP BY p.prod_codigo, p.prod_detalle
/* 11. Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de 
productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán 
ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga, 
solo se deberán mostrar las familias que tengan una venta superior a 20000 pesos para 
el año 2012. */
SELECT 
	fa.fami_detalle AS Detalle_Fam,
	COUNT(DISTINCT p.prod_codigo) AS Cant_Dif_Prod,
	SUM(i.item_cantidad * i.item_precio) AS Monto_Ventas
FROM Producto p
JOIN Familia fa ON p.prod_familia = fa.fami_id
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY fa.fami_id, fa.fami_detalle
HAVING SUM(i.item_cantidad * i.item_precio) > 20000
ORDER BY COUNT(p.prod_codigo) DESC

/* 12. Mostrar nombre de producto, cantidad de clientes distintos que lo compraron, importe 
promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del producto 
y stock actual del producto en todos los depósitos. Se deberán mostrar 
aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán 
ordenarse de mayor a menor por monto vendido del producto. */
SELECT
	p.prod_detalle AS Nombre_Prod,
	COUNT(DISTINCT f.fact_cliente) AS Cant_Cliente,
	SUM(i.item_cantidad * i.item_precio)/SUM(i.item_cantidad) AS Promedio_Pagado,
	ISNULL((SELECT COUNT(*)
            FROM Stock s
            WHERE s.stoc_producto = p.prod_codigo
              AND s.stoc_cantidad > 0), 0) AS Cant_Depositos_Con_Stock,
    ISNULL((SELECT SUM(s.stoc_cantidad)
            FROM Stock s
            WHERE s.stoc_producto = p.prod_codigo), 0) AS Stock_Actual
FROM Producto p
JOIN Item_Factura i on P.prod_codigo = I.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
JOIN STOCK s ON p.prod_codigo = s.stoc_producto
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY SUM(i.item_cantidad * i.item_precio) DESC

/* 10. Mostrar los 10 productos más vendidos en la historia y también los 10 productos menos 
vendidos en la historia. Además mostrar de esos productos, quien fue el cliente que 
mayor compra realizo. */
SELECT 
    CASE 
        WHEN p.prod_codigo IN (
            SELECT TOP 10 
                i3.item_producto
            FROM Item_Factura i3
            GROUP BY i3.item_producto
            ORDER BY SUM(i3.item_cantidad) DESC )
        THEN 'MAS VENDIDO'
        ELSE 'MENOS VENDIDO'
    END AS Ranking,
    p.prod_codigo AS Cod_Producto,
    p.prod_detalle AS Producto,
    SUM(i.item_cantidad) AS Cantidad_Total_Vendida,
    (SELECT TOP 1 
        f2.fact_cliente
     FROM Factura f2
     JOIN Item_Factura i2
            ON i2.item_tipo = f2.fact_tipo
           AND i2.item_sucursal = f2.fact_sucursal
           AND i2.item_numero = f2.fact_numero
     WHERE i2.item_producto = p.prod_codigo
     GROUP BY f2.fact_cliente
     ORDER BY SUM(i2.item_cantidad) DESC, f2.fact_cliente) AS Cliente_Que_Mas_Compro
FROM Producto p
JOIN Item_Factura i
    ON p.prod_codigo = i.item_producto
WHERE p.prod_codigo IN (
        SELECT TOP 10 
            i3.item_producto
        FROM Item_Factura i3
        GROUP BY i3.item_producto
        ORDER BY SUM(i3.item_cantidad) DESC )
   OR p.prod_codigo IN (
        SELECT TOP 10 
            i4.item_producto
        FROM Item_Factura i4
        GROUP BY i4.item_producto
        ORDER BY SUM(i4.item_cantidad) ASC )
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY SUM(i.item_cantidad) DESC



/* 30. Se desea obtener una estadistica de ventas del año 2012, para los empleados que sean 
jefes, o sea, que tengan empleados a su cargo, para ello se requiere que realice la 
consulta que retorne las siguientes columnas: 
 Nombre del Jefe 
 Cantidad de empleados a cargo 
 Monto total vendido de los empleados a cargo 
 Cantidad de facturas realizadas por los empleados a cargo 
 Nombre del empleado con mejor ventas de ese jefe 
Debido a la perfomance requerida, solo se permite el uso de una subconsulta si fuese 
necesario. 
Los datos deberan ser ordenados por de mayor a menor por el Total vendido y solo se 
deben mostrarse los jefes cuyos subordinados hayan realizado más de 10 facturas. */
SELECT 
    j.empl_nombre AS Nombre_Jefe,
    COUNT(DISTINCT e.empl_codigo) AS Cant_Empleados,
    ISNULL(SUM(f.fact_total), 0) AS Monto_Total,
    COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) AS Cant_Facturas,
    (SELECT TOP 1 e2.empl_nombre
     FROM Empleado e2
     JOIN Factura f2 ON f2.fact_vendedor = e2.empl_codigo
     WHERE e2.empl_jefe = j.empl_codigo
       AND YEAR(f2.fact_fecha) = 2012
     GROUP BY e2.empl_codigo, e2.empl_nombre
     ORDER BY SUM(f2.fact_total) DESC, e2.empl_codigo) AS Empl_Mejor_Ventas
FROM Empleado j
JOIN Empleado e ON e.empl_jefe = j.empl_codigo
JOIN Factura f ON e.empl_codigo = f.fact_vendedor /* o hacer LEFT JOIN ... AND YEAR(f.fact_fecha) = 2012*/
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY j.empl_codigo, j.empl_nombre
HAVING COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) > 10
ORDER BY SUM(f.fact_total) DESC

/* 33. Se requiere obtener una estadística de venta de productos que sean componentes. Para 
ello se solicita que realiza la siguiente consulta que retorne la venta de los 
componentes del producto más vendido del año 2012.  Se deberá mostrar: 
a. Código de producto 
b. Nombre del producto 
c. Cantidad de unidades vendidas 
d. Cantidad de facturas en la cual se facturo 
e. Precio promedio facturado de ese producto. 
f. Total facturado para ese producto 
El resultado deberá ser ordenado por el total vendido por producto para el año 2012. */
-- Supuestos:
--  * "producto más vendido" = el compuesto con más unidades vendidas en 2012
--  * "componentes" = componentes directos (primer nivel de Composicion)
--  * total facturado del producto = cantidad * precio de sus ítems
SELECT
    p.prod_codigo AS Cod_Prod,
    p.prod_detalle AS Nombre_Prod,
    SUM(i.item_cantidad) AS Cant_Uni_Vendidas,
    COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) AS Cant_Facturas,
    SUM(i.item_cantidad * i.item_precio) / SUM(i.item_cantidad) AS Precio_Prom,
    SUM(i.item_cantidad * i.item_precio) AS Total_Facturado
FROM Producto p
JOIN Composicion c ON c.comp_componente = p.prod_codigo
JOIN Item_Factura i ON i.item_producto = p.prod_codigo
JOIN Factura f ON f.fact_tipo = i.item_tipo
              AND f.fact_sucursal = i.item_sucursal
              AND f.fact_numero = i.item_numero
WHERE YEAR(f.fact_fecha) = 2012
  AND c.comp_producto = (SELECT TOP 1 i2.item_producto
                         FROM Item_Factura i2
                         JOIN Factura f2 ON f2.fact_tipo = i2.item_tipo
                                        AND f2.fact_sucursal = i2.item_sucursal
                                        AND f2.fact_numero = i2.item_numero
                         WHERE YEAR(f2.fact_fecha) = 2012
                           AND i2.item_producto IN (SELECT comp_producto FROM Composicion)
                         GROUP BY i2.item_producto
                         ORDER BY SUM(i2.item_cantidad) DESC, i2.item_producto)
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY SUM(i.item_cantidad * i.item_precio) DESC
-- Consultas sobre compuestos por compuestos
SELECT
    comp_producto,
    comp_componente,
    p.prod_detalle,
    comp_cantidad,
    p2.prod_detalle
FROM Composicion c
JOIN Producto p ON c.comp_componente = p.prod_codigo
JOIN Producto p2 ON c.comp_producto = p2.prod_codigo 
WHERE comp_componente = '00001420'

-- ¿Hay compuestos dentro de compuestos?
SELECT DISTINCT
    c1.comp_producto   AS Producto_Padre,
    c1.comp_componente AS Componente_Que_Es_Compuesto
FROM Composicion c1
JOIN Composicion c2 ON c2.comp_producto = c1.comp_componente

SELECT DISTINCT c1.comp_producto
FROM Composicion c1
JOIN Composicion c2 ON c2.comp_producto = c1.comp_componente
JOIN Composicion c3 ON c3.comp_producto = c2.comp_componente

SELECT TOP 1 i.item_producto, SUM(i.item_cantidad) AS Unidades
FROM Item_Factura i
JOIN Factura f ON f.fact_tipo = i.item_tipo
              AND f.fact_sucursal = i.item_sucursal
              AND f.fact_numero = i.item_numero
WHERE YEAR(f.fact_fecha) = 2012
  AND i.item_producto IN (SELECT comp_producto FROM Composicion)
GROUP BY i.item_producto
ORDER BY SUM(i.item_cantidad) DESC, i.item_producto

SELECT comp_componente, comp_cantidad
FROM Composicion
WHERE comp_producto = '00001718'

SELECT DISTINCT i.item_producto
FROM Item_Factura i
JOIN Factura f ON f.fact_tipo = i.item_tipo
              AND f.fact_sucursal = i.item_sucursal
              AND f.fact_numero = i.item_numero
WHERE YEAR(f.fact_fecha) = 2012
  AND i.item_producto IN ('00001475', '00001420')

/* 26. Escriba una consulta sql que retorne un ranking de empleados devolviendo las 
siguientes columnas: 
 Empleado 
 Depósitos que tiene a cargo 
 Monto total facturado en el año corriente 
 Codigo de Cliente al que mas le vendió 
 Producto más vendido 
 Porcentaje de la venta de ese empleado sobre el total vendido ese año. 
Los datos deberan ser ordenados por venta del empleado de mayor a menor. */
-- Supuestos:
--  * monto y porcentaje: año corriente (GETDATE())
--  * cliente y producto: histórico (la consigna no los limita al año)
--  * "al que más le vendió" = mayor monto facturado; "producto más vendido" = más unidades
-- SOLUCION FINAL
SELECT
    e.empl_codigo AS Cod_Empl, --RTRIM(e.empl_apellido) + ' ' + RTRIM(e.empl_nombre) AS Empleado,
    (SELECT COUNT(*)
     FROM DEPOSITO d
     WHERE d.depo_encargado = e.empl_codigo) AS Cant_Depositos,
    ISNULL(SUM(f.fact_total
	), 0) AS Monto_Anio_Corriente,
    ISNULL((SELECT TOP 1 f4.fact_cliente
     FROM Factura f4
     WHERE f4.fact_vendedor = e.empl_codigo
     GROUP BY f4.fact_cliente
     ORDER BY SUM(f4.fact_total) DESC, f4.fact_cliente)
	 , 0) AS Cliente_Que_Mas_Le_Compro,
    ISNULL((SELECT TOP 1 i.item_producto
     FROM Item_Factura i
     JOIN Factura f3 ON f3.fact_tipo = i.item_tipo
                    AND f3.fact_sucursal = i.item_sucursal
                    AND f3.fact_numero = i.item_numero
     WHERE f3.fact_vendedor = e.empl_codigo
     GROUP BY i.item_producto
     ORDER BY SUM(i.item_cantidad) DESC, i.item_producto
	 ), 0) AS Prod_Mas_Vendido,
    ISNULL(SUM(f.fact_total), 0) * 100.0 / NULLIF((SELECT SUM(f5.fact_total)
												  FROM Factura f5
												  WHERE YEAR(f5.fact_fecha) = YEAR(GETDATE())
	), 0) AS Porc_Venta
FROM Empleado e
LEFT JOIN Factura f ON f.fact_vendedor = e.empl_codigo
                   AND YEAR(f.fact_fecha) = YEAR(GETDATE())
GROUP BY e.empl_codigo, e.empl_apellido, e.empl_nombre
ORDER BY SUM(f.fact_total) DESC

/* Parcial Práctico de Gestión de Datos - 12/07/2025
1. El objetivo es realizar una consulta SQL que identifique a los productos que fueron comprados en todos los años impares que hay registrados en la base.
De esos productos se debe mostrar los siguientes datos:
El número de fila (orden correlativo).
El nombre del producto
Monto comprado en ARS.

El resultado debe estar ordenado en forma descendente según el cantidad total de comprado (de mayor a menor) en el último año.
Nota: No se permiten select en el from, es decir, select … from (select …) as T,...     Ni WITH, ni tablas temporales. */
SELECT 
    ROW_NUMBER() OVER (ORDER BY ISNULL((
            SELECT SUM(i1.item_cantidad)
            FROM Item_Factura i1
            JOIN Factura f1 ON i1.item_tipo = f1.fact_tipo AND i1.item_sucursal = f1.fact_sucursal AND i1.item_numero = f1.fact_numero
            WHERE i1.item_producto = p.prod_codigo
              AND YEAR(f1.fact_fecha) = (
                    SELECT MAX(YEAR(fx.fact_fecha))
                    FROM Factura fx
                    WHERE YEAR(fx.fact_fecha) % 2 != 0) 
            ), 0) DESC, p.prod_codigo) AS Nro_Fila,
    p.prod_detalle AS Nombre_Prod,
    SUM(i.item_cantidad * i.item_precio) AS Monto_Comprado_ARS
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
GROUP BY p.prod_codigo, p.prod_detalle
HAVING COUNT(DISTINCT CASE WHEN YEAR(f.fact_fecha) % 2 != 0 
                THEN YEAR(f.fact_fecha)
                END) = (
            SELECT COUNT(DISTINCT YEAR(f2.fact_fecha))
            FROM Factura f2
            WHERE YEAR(f2.fact_fecha) % 2 != 0 )
ORDER BY Nro_Fila

SELECT
    DISTINCT YEAR(f.fact_fecha), f.fact_tipo, f.fact_sucursal, f.fact_numero, f.fact_fecha
FROM Factura f
GROUP BY f.fact_tipo, f.fact_sucursal, f.fact_numero, f.fact_fecha

/* Realizar una consulta SQL que devuelva todos los clientes que durante
2 años consecutivos compraron al menos 5 productos distintos. De
esos clientes mostrar:
● El código de cliente
● El monto total comprado en el 2012
● La cantidad de unidades de productos compradas en el 2012
El resultado debe ser ordenado primero por aquellos clientes que compraron
solo productos compuestos en algún momento, luego el resto. */
SELECT
	cl.clie_codigo AS Cod_Cliente,
	ISNULL((SELECT SUM(f2.fact_total) 
			FROM Factura f2 
			WHERE YEAR(f2.fact_fecha) = 2012 AND f2.fact_cliente = cl.clie_codigo)
	, 0) AS Monto_Total,
	ISNULL((SELECT SUM(i.item_cantidad)
			FROM Factura f
			JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = I.item_numero
			WHERE cl.clie_codigo = f.fact_cliente)
	, 0) AS Cant_Unid_Prod
FROM Cliente cl
WHERE cl.clie_codigo IN (
    SELECT fb.fact_cliente--,YEAR(fb.fact_fecha)
    FROM Factura fb
    GROUP BY fb.fact_cliente, YEAR(fb.fact_fecha) --order by fb.fact_cliente asc
    HAVING (SELECT COUNT(DISTINCT i1.item_producto)
            FROM Factura f1
            JOIN Item_Factura i1 ON f1.fact_tipo = i1.item_tipo AND f1.fact_sucursal = i1.item_sucursal AND f1.fact_numero = i1.item_numero
            WHERE f1.fact_cliente = fb.fact_cliente
              AND YEAR(f1.fact_fecha) = YEAR(fb.fact_fecha) ) >= 5
       AND (SELECT COUNT(DISTINCT i2.item_producto)
            FROM Factura f2
            JOIN Item_Factura i2 ON f2.fact_tipo = i2.item_tipo AND f2.fact_sucursal = i2.item_sucursal AND f2.fact_numero = i2.item_numero
            WHERE f2.fact_cliente = fb.fact_cliente
              AND YEAR(f2.fact_fecha) = YEAR(fb.fact_fecha) + 1) >= 5
            )
ORDER BY 
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM Factura fc
            WHERE fc.fact_cliente = cl.clie_codigo
              AND EXISTS (
                    SELECT 1
                    FROM Item_Factura ic
                    WHERE ic.item_tipo = fc.fact_tipo AND ic.item_sucursal = fc.fact_sucursal AND ic.item_numero = fc.fact_numero )
              AND NOT EXISTS (
                    SELECT 1
                    FROM Item_Factura ic2
                    WHERE ic2.item_tipo = fc.fact_tipo AND ic2.item_sucursal = fc.fact_sucursal AND ic2.item_numero = fc.fact_numero
                      AND ic2.item_producto NOT IN (
                            SELECT comp_producto
                            FROM Composicion) )
            ) THEN 0 ELSE 1
    END, cl.clie_codigo

/* Parcial 08/07/2026 Bases de Datos 1C-2026
SQL
Realice una consulta SQL que devuelva, para cada cliente, la siguiente información:
a. Razón social del cliente.
b. El período (formato AAAAMM) en el que realizó la mayor cantidad de compras (en cantidades).
c. La cantidad de productos distintos adquiridos.
d. El importe total facturado.
La consulta deberá ordenar los resultados en forma descendente según la cantidad de facturas emitidas para cada cliente.
Nota: No se permiten sub-select en el from ni CTEs. */
SELECT
	c.clie_razon_social AS Raz_Soc_Cli,
	ISNULL((SELECT TOP 1
        CAST(YEAR(fp.fact_fecha) AS CHAR(4)) +
            RIGHT('0' + CAST(MONTH(fp.fact_fecha) AS VARCHAR(2)), 2)
     FROM Factura fp
	 JOIN Item_Factura i1 ON fp.fact_tipo = i1.item_tipo AND fp.fact_sucursal = i1.item_sucursal AND fp.fact_numero = i1.item_numero
     WHERE fp.fact_cliente = c.clie_codigo
     GROUP BY YEAR(fp.fact_fecha), MONTH(fp.fact_fecha)
     ORDER BY SUM(i1.item_cantidad) DESC,
            YEAR(fp.fact_fecha), MONTH(fp.fact_fecha)
    ), 0) AS Periodo,
	COUNT(DISTINCT i.item_producto) AS Cant_Prod_Dist,
	ISNULL((
		SELECT SUM(f1.fact_total)
		FROM Factura f1
		WHERE f1.fact_cliente = c.clie_codigo
	), 0) AS Total_Fact
FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
GROUP BY c.clie_codigo, c.clie_razon_social
ORDER BY COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) DESC


/* Parcial 01/07/2026 Bases de Datos 1C-2026
SQL
Realizar una consulta que identifique a los productos del mismo rubro y envase que durante el año 2011 se vendieron juntos en la misma factura más de 50 veces.

La consulta debe devolver los siguientes datos:
- El número de fila (orden correlativo empezando en 1)
- El nombre del producto 1.
- El nombre del producto 2.
- Rubro.
- Envase.
- Porcentaje total de las unidades vendidas de ese par respecto al total de unidades vendidas de todos los productos en el mismo año.

Alfabéticamente, el nombre del producto 1 debe estar antes que el nombre del producto 2.

Ningún dato del resultado puede ser NULL, se debe ordenar alfabéticamente por el nombre del producto 1. */
SELECT
	ROW_NUMBER() OVER(ORDER BY p1.prod_detalle ASC),
	p1.prod_detalle AS Nombre_Prod1,
	p2.prod_detalle AS Nombre_Prod2,
	r.rubr_detalle AS Detalle_Rubro,
	en.enva_detalle AS Detalle_Envase,
	(COUNT(*) * 100.0 / NULLIF((SELECT SUM(i.item_cantidad)
																	  FROM Item_Factura i 
																	  JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero 
																	  WHERE YEAR(f.fact_fecha) = 2011)
																	  , 0) ) AS Porcentaje
FROM Producto p1
JOIN Producto p2 ON p1.prod_rubro = p2.prod_rubro AND p1.prod_envase = p2.prod_envase AND (p1.prod_detalle < p2.prod_detalle
																							OR (p1.prod_detalle = p2.prod_detalle
																								AND p1.prod_codigo < p2.prod_codigo)
																						)
JOIN Rubro r ON p1.prod_rubro = r.rubr_id
JOIN Envases en ON p1.prod_envase = en.enva_codigo
JOIN Item_Factura i1 ON i1.item_producto = p1.prod_codigo
JOIN Item_Factura i2 ON i2.item_producto = p2.prod_codigo 
	AND i1.item_tipo = i2.item_tipo AND i1.item_sucursal = i2.item_sucursal AND i1.item_numero = i2.item_numero
		AND i1.item_producto < i2.item_producto
JOIN Factura f ON i1.item_tipo = f.fact_tipo AND i1.item_sucursal = f.fact_sucursal AND i1.item_numero = f.fact_numero
				AND i2.item_tipo = f.fact_tipo AND i2.item_sucursal = f.fact_sucursal AND i2.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2011
GROUP BY p1.prod_codigo, p1.prod_detalle,
		 p2.prod_codigo, p2.prod_detalle,
		 r.rubr_detalle, en.enva_detalle
HAVING COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) > 5
ORDER BY p1.prod_detalle ASC

-- RESOLUCION CON 9
SELECT
    ROW_NUMBER() OVER (ORDER BY p1.prod_detalle)  AS nro_fila,
    p1.prod_detalle AS producto_1,
    p2.prod_detalle AS producto_2,
    Rubro.rubr_detalle AS rubro,
    Envases.enva_detalle AS envase,
    CAST(
        COUNT(*) * 100.0 /
        (
            SELECT SUM(ISNULL(item_cantidad, 0))
            FROM Item_Factura JOIN Factura
            ON fact_tipo = item_tipo AND fact_sucursal = item_sucursal AND fact_numero = item_numero
            WHERE YEAR(fact_fecha) = 2011
        )
    AS DECIMAL(10, 2)) AS porcentaje_unidades

FROM Item_Factura AS ItemA 
    JOIN Item_Factura AS ItemB
    ON ItemA.item_tipo = ItemB.item_tipo AND ItemA.item_sucursal = ItemB.item_sucursal AND ItemA.item_numero = ItemB.item_numero
        AND ItemA.item_producto < ItemB.item_producto --evito comparar con el mismo  
    JOIN Factura ON fact_tipo = ItemA.item_tipo AND fact_sucursal = ItemA.item_sucursal AND fact_numero = ItemA.item_numero
    JOIN Producto AS p1 ON p1.prod_codigo = ItemA.item_producto
    JOIN Producto AS p2 ON p2.prod_codigo = ItemB.item_producto
    JOIN Rubro ON Rubro.rubr_id = p1.prod_rubro
    JOIN Envases ON Envases.enva_codigo = p1.prod_envase

WHERE YEAR(fact_fecha) = 2011
    AND p1.prod_rubro = p2.prod_rubro
    AND p1.prod_envase = p2.prod_envase
    AND p1.prod_detalle < p2.prod_detalle --Evito la comparacion con sigo mismo 

GROUP BY
    p1.prod_detalle,
    p2.prod_detalle,
    Rubro.rubr_detalle,
    Envases.enva_detalle
HAVING COUNT(*) > 5
ORDER BY p1.prod_detalle;



/* <<<<<<<<<<<<<<<<<<<<<<<----------TSQL------------->>>>>>>>>>>>>>>>>>>>*/
/* 2. Suponiendo que se aplican los siguientes cambios en el modelo de
datos:
Cambio 1) create table provincia (id int primary key, nombre char(100)) ;
Cambio 2) alter table cliente add pcia_id int null;
Crear el/los objetos necesarios para implementar el concepto de foreign
key entre 2 cliente y provincia.
Nota: No se permite agregar una constraint de tipo FOREIGN KEY entre la
tabla y el campo agregado.*/
drop table provincia
CREATE TABLE provincia (
    id     int        primary key, 
    nombre char(100)
)
ALTER TABLE cliente add pcia_id int null
-- Intento de insertar o updatear con un id de provincia inexistente
CREATE OR ALTER TRIGGER TR_CLIENTE_FK_PROVINCIA ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM inserted i
               WHERE i.pcia_id IS NOT NULL
                 AND NOT EXISTS (SELECT 1
                                 FROM Provincia p
                                 WHERE p.id = i.pcia_id))
    BEGIN
        RAISERROR('La provincia indicada no existe.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO 
-- Cuando se intenta borrar una provincia que ya es referenciada por un cliente
CREATE TRIGGER TR_PROVINCIA ON Provincia
AFTER DELETE, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM deleted d
               JOIN Cliente c ON c.pcia_id = d.id
               WHERE NOT EXISTS (SELECT 1
                             FROM Provincia p
                             WHERE p.id = d.id))
    BEGIN
        RAISERROR('No se puede borrar ni updatear el id de provincia: hay clientes con esa provincia.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO 
-- Tercer caso a cubrir de un FK real, cuando se hace update de un id_prov y un cliente se queda referenciando al id viejo
-- cuando ya tiene un nuevo valor en la tabla provincia, por el profe:
CREATE TRIGGER TRIGGER_PUNTO2_1 ON Provincia
AFTER UPDATE
AS
BEGIN TRANSACTION

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE 

    if EXISTS ( SELECT 1 FROM DELETED WHERE ID NOT IN (SELECT ID FROM INSERTED) ) 
    BEGIN  
        IF EXISTS(
                    SELECT 1
                    FROM CLIENTE 
                        WHERE 
                            pcia_id in (select id from deleted ) and 
                            pcia_id NOT IN ( SELECT id from inserted ) 
                    )
        BEGIN
            PRINT 'NO SE PUEDE BORRAR UNA PROVINCIA CON CLIENTES ASIGNADOS.'
            ROLLBACK
            RETURN
        END 
    END 
COMMIT TRANSACTION
-------------------
INSERT INTO Provincia VALUES (1, 'Buenos Aires')
UPDATE Cliente SET pcia_id = 1 WHERE clie_codigo = '000001'

UPDATE Provincia SET id = 50 WHERE id = 1          -- debe dar error
UPDATE Provincia SET nombre = 'BA' WHERE id = 1    -- debe pasar
DELETE FROM Provincia WHERE id = 1                 -- debe dar error

/* Parcial 17/07/2026 Bases de Datos 1C-2026
SQL
Realice una consulta SQL que devuelva, para cada producto con STOCK positivo (stoc_cantidad >), la siguiente información:
a. Nombre del producto
b. El período (formato AAAAMM) en el que realizó la mayor cantidad de compras en unidades
c. La cantidad de productos compuestos distintos que tiene
La consulta deberá ordenar los resultados en forma descendente según la cantidad de facturas en las que se encuentra.
Nota: No se permiten sub-select en el from ni CTES

T-SQL
Implementar los objetos de base de datos necesarios (por ejemplo, triggers, procedimientos, funciones u otros mecanismos 
que considere apropiados) para mantener permanentemente actualizada una tabla denominada ProductosAcumulados
La tabla deberá almacenar, para cada producto y período (formato AAAAMM), la siguiente información:
Código del producto
Período (AAAAMM)
Cantidad total vendida en el período
Precio máximo de venta del producto registrado en el período
Precio mínimo de venta del producto registrado en el período
Importe total vendido en el período
La actualización de la tabla deberá realizarse en tiempo real, reflejando automáticamente cada alta, modificación o 
eliminación de ventas, de manera que la información permanezca siempre consistente con los datos operacionales. */ 
--SQL
SELECT 
    -- a
	p.prod_detalle AS Nombre_Prod,
	-- b
    ISNULL((
        SELECT TOP 1
            CAST(YEAR(fp.fact_fecha) AS CHAR(4)) +
            RIGHT('0' + CAST(MONTH(fp.fact_fecha) AS VARCHAR(2)), 2)
        FROM Factura fp
        JOIN Item_Factura i2 ON fp.fact_tipo = i2.item_tipo AND fp.fact_sucursal = i2.item_sucursal AND fp.fact_numero = i2.item_numero
        WHERE i2.item_producto = p.prod_codigo
        GROUP BY 
            YEAR(fp.fact_fecha),
            MONTH(fp.fact_fecha)
        ORDER BY
            SUM(i.item_cantidad) DESC,
            YEAR(fp.fact_fecha),
            MONTH(fp.fact_fecha)
    ), '000000') AS Periodo,
    -- c
    ISNULL(COUNT(DISTINCT c.comp_componente)
    ,0) AS Cantidad_Compuestos
FROM Producto p
JOIN STOCK s ON s.stoc_producto = p.prod_codigo
left JOIN Composicion c ON c.comp_producto = p.prod_codigo
JOIN Item_Factura i ON i.item_producto = p.prod_codigo
WHERE s.stoc_cantidad > 0 
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY COUNT(DISTINCT i.item_tipo + i.item_sucursal + i.item_numero) DESC
	
--TSQL
CREATE TABLE ProductosAcumulados (
    producto CHAR(8),
    periodo CHAR(6),
    cantidad_total DECIMAL(12,2),
    precio_maximo DECIMAL(12,2),
    precio_minimo DECIMAL(12,2),
    importe_total DECIMAL(12,2),

    PRIMARY KEY (producto, periodo)
);
GO

CREATE OR ALTER PROCEDURE SP_ACTUALIZAR_PRODUCTOS_ACUMULADOS
AS
BEGIN
    DELETE FROM ProductosAcumulados;

    INSERT INTO ProductosAcumulados (
        producto,
        periodo,
        cantidad_total,
        precio_maximo,
        precio_minimo,
        importe_total
    )
    SELECT
        i.item_producto,
        LEFT(CONVERT(CHAR(8), f.fact_fecha, 112), 6),
        SUM(i.item_cantidad),
        MAX(i.item_precio),
        MIN(i.item_precio),
        SUM(i.item_cantidad * i.item_precio)
    FROM Item_Factura i
    JOIN Factura f
        ON f.fact_tipo = i.item_tipo
       AND f.fact_sucursal = i.item_sucursal
       AND f.fact_numero = i.item_numero
    GROUP BY
        i.item_producto,
        LEFT(CONVERT(CHAR(8), f.fact_fecha, 112), 6);
END;
GO

CREATE OR ALTER TRIGGER TR_ACTUALIZAR_PRODUCTOS_ACUMULADOS
ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    EXEC SP_ACTUALIZAR_PRODUCTOS_ACUMULADOS;
END;
GO

CREATE OR ALTER TRIGGER TR_ACTUALIZAR_PRODUCTOS_ACUMULADOS_FACTURA
ON Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    EXEC SP_ACTUALIZAR_PRODUCTOS_ACUMULADOS;
END;
GO

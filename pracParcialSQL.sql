--------------------------
------ PRACTICA SQL ------
--------------------------
/* Guia SQL
Ejercicio 5) Realizar una consulta  que muestre
    Código de artículo,
    Detalle y Cantidad de Egresos de Stock que se realizaron para ese artículo 
    en el año 2012 (egresan los productos que fueron vendidos).
    Mostrar SOLO aquellos que hayan tenido MAS EGRESOS que en el año 2011   */
SELECT 
    prod_codigo AS Codigo,
    prod_detalle AS Detalle,
    SUM(i.item_cantidad) AS Cant_Egresos
FROM Producto p 
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND 
                  i.item_sucursal = f.fact_sucursal AND
                  i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
HAVING SUM(i.item_cantidad) > ISNULL((
    SELECT SUM(i2.item_cantidad) 
    FROM Item_Factura i2
    JOIN Factura f ON i2.item_tipo = f.fact_tipo AND 
                  i2.item_sucursal = f.fact_sucursal AND
                  i2.item_numero = f.fact_numero
    WHERE i2.item_producto = p.prod_codigo AND YEAR(f.fact_fecha) = 2011), 0)

/* Mostrar código, razón social y límite de crédito de los clientes 
    cuyo límite sea mayor a 1000. Ordenar por código de cliente.*/
SELECT
    c.clie_codigo AS Codigo,
    c.clie_razon_social AS Nombre,
    c.clie_limite_credito AS Lim_Cred
FROM Cliente c
WHERE clie_limite_credito > 1000
ORDER BY Codigo ASC

/* Mostrar código, detalle y precio de los productos cuyo precio sea mayor a 50. Ordenar de mayor a menor precio.*/
SELECT 
    p.prod_codigo,
    p.prod_detalle,
    p.prod_precio
FROM Producto p
WHERE p.prod_precio > 50
ORDER BY p.prod_precio DESC

/* Mostrar las facturas del año 2012 con número de factura, fecha, cliente y total.*/
SELECT 
    f.fact_numero,
    f.fact_fecha,
    f.fact_cliente,
    f.fact_total
FROM Factura f
WHERE YEAR(f.fact_fecha) = 2012

/* Mostrar número de factura, fecha, código de cliente y razón social del cliente.*/
SELECT 
    f.fact_numero,
    f.fact_fecha,
    f.fact_cliente,
    c.clie_razon_social
FROM Factura f
JOIN Cliente c ON f.fact_cliente = c.clie_codigo

/* Mostrar código de producto, detalle de producto, cantidad vendida y precio facturado de cada ítem.*/
SELECT 
    i.item_producto,
    p.prod_detalle,
    i.item_cantidad AS Cant_Vendida,
    i.item_precio
FROM Item_Factura i
JOIN Producto p ON i.item_producto = p.prod_codigo
JOIN Factura f ON i.item_tipo = f.fact_tipo 
        AND i.item_sucursal = f.fact_sucursal 
        AND i.item_numero = f.fact_numero

/* Mostrar por producto: código, detalle y cantidad total vendida en toda la historia.*/
SELECT 
    p.prod_codigo,
    p.prod_detalle,
    SUM(i.item_cantidad)
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
GROUP BY p.prod_codigo, p.prod_detalle

/* El único detalle: con JOIN, solo aparecen productos que fueron vendidos alguna vez. 
Si el ejercicio quisiera todos los productos, incluso los nunca vendidos, sería con LEFT JOIN: */
SELECT 
    p.prod_codigo,
    p.prod_detalle,
    ISNULL(SUM(i.item_cantidad), 0) AS Cantidad_Total_Vendida
FROM Producto p
LEFT JOIN Item_Factura i 
    ON p.prod_codigo = i.item_producto
GROUP BY 
    p.prod_codigo, 
    p.prod_detalle

/* Mostrar por cliente: código de cliente y monto total comprado en 2012.*/
SELECT 
    c.clie_codigo AS Cod_Cliente,
    SUM(f.fact_total) AS Monto_Total
FROM Cliente c 
JOIN Factura f ON c.clie_codigo = f.fact_cliente
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY c.clie_codigo

/* Mostrar por rubro: código de rubro, detalle y cantidad de productos que pertenecen a ese rubro.*/
SELECT 
    r.rubr_id AS Cod_Rubro,
    r.rubr_detalle AS Detalle_Rubro,
    COUNT(p.prod_codigo) AS Cant_Prod_En_Rubro
FROM Rubro r
JOIN Producto p ON r.rubr_id = p.prod_rubro
GROUP BY r.rubr_id, r.rubr_detalle

/* Mostrar los productos que hayan vendido más de 100 unidades en total.*/
SELECT
    p.prod_codigo AS Cod_Prod,
    p.prod_detalle AS Detalle_Prod,
    SUM(i.item_cantidad) AS Cantidad_Total_Vendida
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
GROUP BY p.prod_codigo, p.prod_detalle
HAVING SUM(i.item_cantidad) > 100

/* Mostrar los clientes que hayan comprado más de 5 veces en 2012.*/
SELECT
    c.clie_codigo AS Cod_Cliente,
    COUNT(f.fact_cliente) AS Cant_Veces_Que_Compro
FROM Cliente c
JOIN Factura f ON c.clie_codigo = f.fact_cliente
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY c.clie_codigo
HAVING COUNT(f.fact_cliente) > 5

/* Mostrar los rubros cuyo stock total sea mayor a 1000.*/
SELECT 
    r.rubr_id AS Cod_Rubro,
    SUM(s.stoc_cantidad) AS Stock_Total
FROM Rubro r
JOIN Producto p ON r.rubr_id = p.prod_rubro
JOIN STOCK s ON p.prod_codigo = s.stoc_producto
GROUP BY r.rubr_id
HAVING SUM(s.stoc_cantidad) > 1000

/* Mostrar por cliente cuántos productos distintos compró en 2012.*/
SELECT 
    f.fact_cliente AS Cod_Cliente,
    COUNT(DISTINCT i.item_producto) AS Cant_Prod_Distintos
FROM Factura f
JOIN Item_Factura i ON f.fact_tipo = i.item_tipo
AND f.fact_sucursal = i.item_sucursal
AND f.fact_numero = i.item_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY f.fact_cliente

/* Mostrar por producto cuántos clientes distintos lo compraron en 2012.*/
SELECT 
    p.prod_codigo AS Cod_Prod,
    COUNT(DISTINCT f.fact_cliente) AS Cant_Clientes
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND 
                  i.item_sucursal = f.fact_sucursal AND
                  i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_codigo
-- tambien puedo hacerlo por item_producto directamente si solo quiero el codigo del producto
SELECT 
    i.item_producto AS Cod_Prod,
    COUNT(DISTINCT f.fact_cliente) AS Cant_Clientes
FROM Item_Factura i 
JOIN Factura f ON i.item_tipo = f.fact_tipo AND 
                  i.item_sucursal = f.fact_sucursal AND
                  i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY i.item_producto

/* Mostrar los productos que tienen composición.*/
SELECT 
    p.prod_codigo AS Cod_Prod
FROM Producto p
WHERE p.prod_codigo IN (
    SELECT 
        c.comp_producto
    FROM Composicion c)
-- Esta consulta devuelve a los productos que son componentes de productos compuestos
SELECT 
    p.prod_codigo AS Cod_Prod
FROM Producto p
WHERE p.prod_codigo IN (
    SELECT 
        c.comp_componente
    FROM Composicion c)
/* Mostrar los productos que NO tienen composición.*/
SELECT 
    p.prod_codigo AS Cod_Prod
FROM Producto p
WHERE p.prod_codigo NOT IN (
    SELECT 
        c.comp_producto
    FROM Composicion c)

/* Mostrar los clientes que compraron productos compuestos en 2012.*/
SELECT 
    cl.clie_codigo AS Cod_Cliente
FROM Cliente cl
JOIN Factura f ON cl.clie_codigo = f.fact_cliente
JOIN Item_Factura i ON f.fact_tipo = i.item_tipo
    AND f.fact_sucursal = i.item_sucursal
    AND f.fact_numero = i.item_numero
WHERE i.item_producto IN (
    SELECT 
        c.comp_producto
    FROM Composicion c)
    AND YEAR(f.fact_fecha) = 2012
GROUP BY clie_codigo -- PARA NO MOSTRAR REPETIDOS CLIENTES

/* Clientes que compraron más de 5 productos compuestos distintos y ningún producto simple.*/
SELECT 
    c.clie_codigo AS Cod_Cliente,
    c.clie_razon_social AS Cliente,
    COUNT(DISTINCT i.item_producto) AS Cant_Productos_Compuestos
FROM Cliente c
JOIN Factura f
    ON c.clie_codigo = f.fact_cliente
JOIN Item_Factura i
    ON f.fact_tipo = i.item_tipo
   AND f.fact_sucursal = i.item_sucursal
   AND f.fact_numero = i.item_numero
WHERE i.item_producto IN (
        SELECT comp_producto
        FROM Composicion )
    AND YEAR(f.fact_fecha) = 2012
GROUP BY
    c.clie_codigo,
    c.clie_razon_social
HAVING COUNT(DISTINCT i.item_producto) > 5
   AND NOT EXISTS (
        SELECT 1
        FROM Factura f2
        JOIN Item_Factura i2
            ON f2.fact_tipo = i2.item_tipo
           AND f2.fact_sucursal = i2.item_sucursal
           AND f2.fact_numero = i2.item_numero
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
          AND i2.item_producto NOT IN (
                SELECT comp_producto
                FROM Composicion ) 
                )

/* Mostrar por cliente: código, razón social y monto total comprado en 2012, usando una subconsulta en el SELECT.*/
-- Opcion A: Devuelve TODOS los clientes tengan factura o no
SELECT
    c.clie_codigo AS Cod_Cliente,
    c.clie_razon_social AS Raz_Soc_Cliente,
    ISNULL(( SELECT
        SUM(f.fact_total)
      FROM Factura f
      WHERE c.clie_codigo = f.fact_cliente AND YEAR(f.fact_fecha) = 2012
     ), 0) AS Monto_2012
FROM Cliente c
-- Opcion B: Solo devuelve clientes que sí compraron, o sea, que tienen factura
SELECT
    c.clie_codigo AS Cod_Cliente,
    c.clie_razon_social AS Raz_Soc_Cliente,
    ( SELECT
        SUM(f.fact_total)
      FROM Factura f
      WHERE c.clie_codigo = f.fact_cliente AND YEAR(f.fact_fecha) = 2012
     ) AS Monto_2012
FROM Cliente c
WHERE ( SELECT
        SUM(f.fact_total)
      FROM Factura f
      WHERE c.clie_codigo = f.fact_cliente AND YEAR(f.fact_fecha) = 2012
     ) IS NOT NULL
-- Opcion C: Sin Subconsulta, usando GROUP BY, devuelve lo mismo que Opcion B
SELECT 
    c.clie_codigo AS Cod_Cliente, 
    c.clie_razon_social AS Raz_Soc_Cliente,
    SUM(f.fact_total) AS Monto_2012
FROM Cliente c
JOIN Factura f ON c.clie_codigo = f.fact_cliente
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY c.clie_codigo, c.clie_razon_social
-- Opcion D: Sin Subconsulta, usando GROUP BY, devuelve lo mismo que Opcion A
SELECT 
    c.clie_codigo AS Cod_Cliente, 
    c.clie_razon_social AS Raz_Soc_Cliente,
    ISNULL(SUM(f.fact_total), 0) AS Monto_2012 -- El ISNULL es importante para clientes que no tienen facturas
FROM Cliente c
LEFT JOIN Factura f 
    ON c.clie_codigo = f.fact_cliente
   AND YEAR(f.fact_fecha) = 2012 -- Se pone el filtro de YEAR() = 2012 porque sino te devuelve lo mismo que Opcion C
GROUP BY 
    c.clie_codigo, 
    c.clie_razon_social

/* Mostrar por producto: código, detalle y cantidad total vendida, usando subconsulta en el SELECT.*/
    SELECT 
        p.prod_codigo AS Cod_Prod,
        p.prod_detalle AS Det_Prod,
        ISNULL((SELECT
            SUM(i.item_cantidad)
         FROM Item_Factura i
         WHERE p.prod_codigo = i.item_producto), 0) AS Cant_Total_Vendido
    FROM Producto p

/* Mostrar ranking de productos más vendidos, con número de fila, código, detalle y cantidad vendida.*/
SELECT
    ROW_NUMBER() OVER(ORDER BY SUM(i.item_cantidad) DESC) AS Mas_Vendidos,
    p.prod_codigo AS Cod_Prod,
    p.prod_detalle AS Det_Prod,
    SUM(i.item_cantidad) AS Cant_Vendida
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
GROUP BY p.prod_codigo, p.prod_detalle

/* Mostrar ranking de clientes por monto comprado en 2012.*/
SELECT
    ROW_NUMBER() OVER(ORDER BY SUM(f.fact_total) DESC) AS Ranking_Monto_2012,
    f.fact_cliente AS Cod_Cliente,
    SUM(f.fact_total) AS Monto_Comprado_2012
FROM Factura f
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY f.fact_cliente
ORDER BY Monto_Comprado_2012 DESC -- para que quede prolijo agregamos el ORDER BY

/* Mostrar productos con una columna que diga si son compuestos o simples.*/
SELECT
    CASE WHEN p.prod_codigo IN (SELECT
        c.comp_producto
        FROM Composicion c)
        THEN 'SI' ELSE 'NO'
        END AS Es_Prod_Compuesto,
    *
FROM Producto p

/* Mostrar clientes con una columna que diga COMPRO EN 2012 o NO COMPRO EN 2012.*/
SELECT
    CASE WHEN cl.clie_codigo IN (
        SELECT 
        f.fact_cliente
        FROM Factura f
        WHERE YEAR(f.fact_fecha) = 2012
    ) THEN 'Si compro en 2012' ELSE 'No compro en 2012'
    END AS Compro_En_2012,
    cl.clie_codigo AS Cod_Cliente,
    cl.clie_razon_social AS Raz_Soc_Cliente
FROM Cliente cl
-- Version con EXISTS
SELECT
    CASE WHEN EXISTS (
        SELECT 1
        FROM Factura f
        WHERE f.fact_cliente = cl.clie_codigo
          AND YEAR(f.fact_fecha) = 2012
    ) THEN 'SI COMPRO EN 2012' ELSE 'NO COMPRO EN 2012' 
    END AS Compro_En_2012,
    cl.clie_codigo AS Cod_Cliente,
    cl.clie_razon_social AS Raz_Soc_Cliente
FROM Cliente cl

/* Mostrar los 10 productos más vendidos en 2012.*/
SELECT TOP 10
    ROW_NUMBER() OVER(ORDER BY SUM(i.item_cantidad) DESC) Mas_Vendidos,
    i.item_producto AS Cod_Producto,
    SUM(i.item_cantidad) AS Cant_Vendida
FROM Item_Factura i
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY i.item_producto
ORDER BY SUM(i.item_cantidad) DESC

/* Mostrar clientes que compraron productos compuestos en 2012.*/
SELECT
    f.fact_cliente AS Cod_Cliente/*,
    i.item_producto AS Cod_Prod_Comp*/
FROM Factura f
JOIN Item_Factura i ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
  AND i.item_producto IN (
        SELECT c.comp_producto
        FROM Composicion c
  )
GROUP BY f.fact_cliente /*, i.item_producto*/ --Si quisiera ver el Cliente con los productos compuestos que compró
                        -- también uso el item_producto, pero la consigna solo pide mostrar a los CLIENTES

/* Mostrar por rubro el monto vendido en 2012.*/
SELECT
    r.rubr_id AS Cod_Rubro,
    SUM(i.item_cantidad * i.item_precio) AS Monto_Vendido
FROM Rubro r
JOIN Producto p ON r.rubr_id = p.prod_rubro
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY r.rubr_id
ORDER BY r.rubr_id

/* 14. Escriba una consulta que retorne una estadística de ventas por cliente. Los campos que 
debe retornar son: 
 
Código del cliente 
Cantidad de veces que compro en el último año 
Promedio por compra en el último año 
Cantidad de productos diferentes que compro en el último año 
Monto de la mayor compra que realizo en el último año 
 
Se deberán retornar todos los clientes ordenados por la cantidad de veces que compro en 
el último año. 
No se deberán visualizar NULLs en ninguna columna */
SELECT
    c.clie_codigo AS Cod_Cliente,
    ISNULL((
        SELECT 
            COUNT(*) 
        FROM Factura f
    WHERE f.fact_cliente = c.clie_codigo 
        AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx)), 0) AS Cant_Veces_Que_Compro,
    ISNULL((
        SELECT
            AVG(f.fact_total)
        FROM Factura f
        WHERE f.fact_cliente = c.clie_codigo 
        AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx)),0) AS Promedio_Por_Compra,
    ISNULL((    
    SELECT
        COUNT(DISTINCT i.item_producto) 
    FROM Item_Factura i
    JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
    WHERE f.fact_cliente = c.clie_codigo 
        AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx)),0) AS Cant_Prod_Comprados,
    ISNULL((
    SELECT
        MAX(f.fact_total)
    FROM Factura f
    WHERE f.fact_cliente = c.clie_codigo 
        AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx)),0)AS Mayor_Compra
FROM Cliente c
GROUP BY c.clie_codigo
ORDER BY Cant_Veces_Que_Compro DESC

/* 13. Realizar una consulta que retorne para cada producto que posea composición:
nombre del producto, 
precio del producto, 
precio de la sumatoria de los precios por la cantidad de los productos que lo componen. 
Solo se deberán mostrar los productos que estén compuestos por más de 2 productos 
y deben ser ordenados de mayor a menor por cantidad de productos que lo componen. */
SELECT 
    p.prod_detalle AS Nombre_Prod,
    p.prod_precio AS Precio_Prod,
    SUM(pc.prod_precio * c.comp_cantidad) AS Precio_Sumatoria_Componentes
FROM Producto p
JOIN Composicion c ON p.prod_codigo = c.comp_producto
JOIN Producto pc ON pc.prod_codigo = c.comp_componente
GROUP BY p.prod_detalle, p.prod_precio
HAVING COUNT(DISTINCT c.comp_componente) > 2
ORDER BY COUNT(DISTINCT c.comp_componente) DESC

/* 15. Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos (en la misma factura) 
    más de 500 veces. 
El resultado debe mostrar: 
el código y descripción de cada uno de los productos y la cantidad de veces que fueron vendidos juntos. 
El resultado debe estar ordenado por la cantidad de veces que se vendieron juntos dichos productos. 
Los distintos pares no deben retornarse más de una vez. 
 
Ejemplo de lo que retornaría la consulta: 
  
PROD1 DETALLE1 PROD2 DETALLE2 VECES 
1731 MARLBORO KS 1 7 1 8 P H ILIPS MORRIS KS 5 0 7 
1718 PHILIPS MORRIS KS 1 7 0 5 P H I L I P S MORRIS BOX 10 5 6 2*/
SELECT
    p1.prod_codigo AS PROD1,
    p1.prod_detalle AS DETALLE1,
    p2.prod_codigo AS PROD2,
    p2.prod_detalle AS DETALLE2,
    COUNT(*) AS VECES
FROM Item_Factura i1
JOIN Item_Factura i2
    ON i1.item_tipo = i2.item_tipo
   AND i1.item_sucursal = i2.item_sucursal
   AND i1.item_numero = i2.item_numero
   AND i1.item_producto < i2.item_producto -- Para que no se repitan pares (PROD_A-PROD_B = PROD_B-PROD_A)
JOIN Producto p1
    ON p1.prod_codigo = i1.item_producto
JOIN Producto p2
    ON p2.prod_codigo = i2.item_producto
GROUP BY p1.prod_codigo, p1.prod_detalle,
         p2.prod_codigo, p2.prod_detalle
HAVING COUNT(*) > 500
ORDER BY COUNT(*) DESC

/* 17. Escriba una consulta que retorne una estadística de ventas por año y mes para cada 
producto. 
 
La consulta debe retornar: 
 
PERIODO: Año y mes de la estadística con el formato YYYYMM 
PROD: Código de producto 
DETALLE: Detalle del producto 
CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo 
VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo 
pero del año anterior 
CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el 
periodo 
La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada 
por periodo y código de producto.*/
SELECT 
    CAST(YEAR(f.fact_fecha) AS CHAR(4)) 
        + RIGHT('0' + CAST(MONTH(f.fact_fecha) AS VARCHAR(2)), 2) AS PERIODO,
    p.prod_codigo AS PROD,
    p.prod_detalle AS DETALLE,
    SUM(i.item_cantidad) AS CANTIDAD_VENDIDA,
    ISNULL((
        SELECT SUM(i2.item_cantidad)
        FROM Item_Factura i2
        JOIN Factura f2
            ON i2.item_tipo = f2.fact_tipo
           AND i2.item_sucursal = f2.fact_sucursal
           AND i2.item_numero = f2.fact_numero
        WHERE i2.item_producto = p.prod_codigo
          AND YEAR(f2.fact_fecha) = YEAR(f.fact_fecha) - 1
          AND MONTH(f2.fact_fecha) = MONTH(f.fact_fecha) ), 0) AS VENTAS_ANIO_ANT,
    COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) AS CANT_FACTURAS
FROM Factura f
JOIN Item_Factura i ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
JOIN Producto p ON p.prod_codigo = i.item_producto
GROUP BY YEAR(f.fact_fecha), MONTH(f.fact_fecha),p.prod_codigo,p.prod_detalle
ORDER BY PERIODO, p.prod_codigo

/* 21. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al 
menos una factura:
la cantidad de clientes a los que se les facturo de manera incorrecta al menos una factura y
que cantidad de facturas se realizaron de manera incorrecta.

Se considera que una factura es incorrecta cuando la diferencia entre el total de la factura 
menos el total de impuesto tiene una diferencia mayor a $ 1 respecto a la sumatoria de 
los costos de cada uno de los items de dicha factura. Las columnas que se deben mostrar 
son: 
 Año 
 Clientes a los que se les facturo mal en ese año 
 Facturas mal realizadas en ese año*/
SELECT 
    YEAR(f.fact_fecha) AS Anio,
    ISNULL((
        SELECT COUNT(DISTINCT f2.fact_cliente)
        FROM Factura f2
        WHERE YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)
          AND ABS( (f2.fact_total - f2.fact_total_impuestos) -
                ISNULL((
                    SELECT SUM(i2.item_cantidad * i2.item_precio)
                    FROM Item_Factura i2
                    WHERE i2.item_tipo = f2.fact_tipo
                      AND i2.item_sucursal = f2.fact_sucursal
                      AND i2.item_numero = f2.fact_numero), 0) ) > 1 ), 0) AS Clientes_Facturados_Mal,
    ISNULL((
        SELECT COUNT(*)
        FROM Factura f3
        WHERE YEAR(f3.fact_fecha) = YEAR(f.fact_fecha)
          AND ABS( (f3.fact_total - f3.fact_total_impuestos) -
                ISNULL((
                    SELECT SUM(i3.item_cantidad * i3.item_precio)
                    FROM Item_Factura i3
                    WHERE i3.item_tipo = f3.fact_tipo
                      AND i3.item_sucursal = f3.fact_sucursal
                      AND i3.item_numero = f3.fact_numero ), 0) ) > 1 ), 0) AS Facturas_Mal_Realizadas
FROM Factura f
GROUP BY YEAR(f.fact_fecha)
ORDER BY YEAR(f.fact_fecha)

/* 34. Escriba una consulta sql que retorne para todos los rubros: 
la cantidad de facturas mal facturadas por cada mes del año 2011
Se considera que una factura es incorrecta cuando en la misma factura se facturan productos de dos rubros diferentes.  
Si no hay facturas mal hechas se debe retornar 0. Las columnas que se deben mostrar son: 
1- Codigo de Rubro 
2- Mes 
3- Cantidad de facturas mal realizadas.*/
SELECT
    r.rubr_id AS Cod_Rubro,
    MONTH(f.fact_fecha) AS Mes,
    ISNULL((
        SELECT COUNT(DISTINCT f2.fact_tipo + f2.fact_sucursal + f2.fact_numero)
        FROM Factura f2
        JOIN Item_Factura i2 ON i2.item_tipo = f2.fact_tipo AND i2.item_sucursal = f2.fact_sucursal AND i2.item_numero = f2.fact_numero
        JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
        WHERE YEAR(f2.fact_fecha) = 2011
          AND MONTH(f2.fact_fecha) = MONTH(f.fact_fecha)
          AND p2.prod_rubro = r.rubr_id
          AND EXISTS (
                SELECT 1
                FROM Item_Factura i3
                JOIN Producto p3 ON p3.prod_codigo = i3.item_producto
                WHERE i3.item_tipo = f2.fact_tipo AND i3.item_sucursal = f2.fact_sucursal AND i3.item_numero = f2.fact_numero
                  AND p3.prod_rubro != r.rubr_id )  ), 0) AS Cant_Facturas_Mal_Realizadas

FROM Rubro r
JOIN Producto p ON p.prod_rubro = r.rubr_id
JOIN Item_Factura i ON p.prod_codigo = i.item_producto 
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2011
GROUP BY r.rubr_id, MONTH(f.fact_fecha)

/* 1. El objetivo es realizar una consulta SQL que identifique a los productos que fueron comprados 
en todos los años impares que hay registrados en la base.
De esos productos se debe mostrar los siguientes datos:

El número de fila (orden correlativo).
El nombre del producto
Monto comprado en ARS.

El resultado debe estar ordenado en forma descendente según el cantidad total de comprado 
(de mayor a menor) en el último año.*/
SELECT 
    ROW_NUMBER() OVER (ORDER BY ISNULL((
            SELECT SUM(iu.item_cantidad)
            FROM Item_Factura iu
            JOIN Factura fu ON iu.item_tipo = fu.fact_tipo AND iu.item_sucursal = fu.fact_sucursal AND iu.item_numero = fu.fact_numero
            WHERE iu.item_producto = p.prod_codigo
              AND YEAR(fu.fact_fecha) = (
                    SELECT MAX(YEAR(fx.fact_fecha))
                    FROM Factura fx) ), 0) DESC, p.prod_codigo) AS Nro_Fila,
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
-- Fail lo mío de abajo
SELECT 
    ROW_NUMBER() OVER(ORDER BY SUM(i.item_cantidad * i.item_precio) DESC) AS Nro_Fila,
    p.prod_detalle AS Nombre_Prod,
    SUM(i.item_cantidad * i.item_precio) AS Monto_Comprado
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
GROUP BY i.item_producto, p.prod_detalle, f.fact_fecha
HAVING i.item_producto IN (
    SELECT 
        i2.item_producto
    FROM Item_Factura i2
    JOIN Factura f2 ON i2.item_tipo = f2.fact_tipo AND i2.item_sucursal = f2.fact_sucursal AND i2.item_numero = f2.fact_numero
    WHERE f.fact_fecha = f2.fact_fecha
        AND (YEAR(f2.fact_fecha) % 2) != 0)
ORDER BY (SELECT
            SUM(i.item_cantidad)
          FROM Item_Factura i
          /*JOIN Factura ON ... Todo mal*/) DESC

/* Parcial Practico de Gestión de Datos - 28/06/2025
1. El objetivo es realizar una consulta SQL que identifique a los clientes que compraron productos que pertenezcan 
a dos rankings distintos del año 2012:
·Los 10 productos más vendidos en 2012.
·Los 10 productos menos vendidos en 2012 (considerando únicamente los 10 productos con menor cantidad vendida, incluso
si hay más de 10 productos con el mismo valor mínimo).

La consulta debe devolver los siguientes datos:
El número de fila (orden correlativo).
El nombre del cliente.
Si es cliente en el Ranking de los más vendidos.
Cantidad total de Facturas del cliente
El resultado debe estar ordenado en forma descendente según el monto total de compras del cliente (de mayor a menor).*/
SELECT
    ROW_NUMBER() OVER(ORDER BY ISNULL(
        (SELECT SUM(f2.fact_total)
        FROM Factura f2
        WHERE c.clie_codigo = f2.fact_cliente AND YEAR(f2.fact_fecha) = 2012), 0) DESC) AS Nro_Fila,
    c.clie_razon_social AS Nombre_Cliente,
    CASE 
        WHEN EXISTS (
            SELECT 1
            FROM Factura f
            JOIN Item_Factura i ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
            WHERE f.fact_cliente = c.clie_codigo
              AND YEAR(f.fact_fecha) = 2012
              AND i.item_producto IN (
                    SELECT TOP 10
                        i2.item_producto
                    FROM Item_Factura i2
                    JOIN Factura f2 ON f2.fact_tipo = i2.item_tipo AND f2.fact_sucursal = i2.item_sucursal AND f2.fact_numero = i2.item_numero
                    WHERE YEAR(f2.fact_fecha) = 2012
                    GROUP BY i2.item_producto
                    ORDER BY SUM(i2.item_cantidad) DESC )
        ) THEN 'SI' ELSE 'NO'
    END AS Cliente_En_Ranking_Mas_Vendidos,
    ISNULL(
       (SELECT COUNT(*)
        FROM Factura fc
        WHERE fc.fact_cliente = c.clie_codigo AND YEAR(fc.fact_fecha) = 2012 ), 0) AS Cant_Total_Facturas
FROM Cliente c
WHERE EXISTS (
    SELECT 1
    FROM Factura f
    JOIN Item_Factura i ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
    WHERE f.fact_cliente = c.clie_codigo
      AND YEAR(f.fact_fecha) = 2012
      AND ( i.item_producto IN (
                SELECT TOP 10
                    i3.item_producto
                FROM Item_Factura i3
                JOIN Factura f3 ON f3.fact_tipo = i3.item_tipo AND f3.fact_sucursal = i3.item_sucursal AND f3.fact_numero = i3.item_numero
                WHERE YEAR(f3.fact_fecha) = 2012
                GROUP BY i3.item_producto
                ORDER BY SUM(i3.item_cantidad) DESC 
        ) OR i.item_producto IN (
                SELECT TOP 10
                    i4.item_producto
                FROM Item_Factura i4
                JOIN Factura f4 ON f4.fact_tipo = i4.item_tipo AND f4.fact_sucursal = i4.item_sucursal AND f4.fact_numero = i4.item_numero
                WHERE YEAR(f4.fact_fecha) = 2012
                GROUP BY i4.item_producto
                ORDER BY SUM(i4.item_cantidad) ASC ) ) )
ORDER BY Nro_Fila

/* PARCIAL GESTIÓN DE DATOS - 06/07/2022
1. Realizar una consulta SQL que muestra a aquellos clientes que no compraron productos compuestos en el 2011 
pero si en el 2012, retornar:
a. Número de Fila: Se considera número 1 al cliente que menos compro y N al que más compro.
b. Monto total comprado del cliente en 2012.
c. Cantidad de rubros distintos comprados en el 2012. */
-- Al fin una me salió
SELECT 
    ROW_NUMBER() OVER(ORDER BY ISNULL(
        (SELECT SUM(f.fact_total) 
        FROM Factura f
        WHERE f.fact_cliente = c.clie_codigo AND YEAR(f.fact_fecha) = 2012), 0) ASC) AS Nro_Fila,
    ISNULL(
           (SELECT
               SUM(f.fact_total)
             FROM FACTURA f
             WHERE c.clie_codigo = f.fact_cliente
                AND YEAR(f.fact_fecha) = 2012),0) AS Monto_Total_2012,
    COUNT(DISTINCT r.rubr_id) AS Cant_Rubros
FROM Cliente c
JOIN Factura f ON c.clie_codigo = f.fact_cliente
JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
JOIN Producto p ON i.item_producto = p.prod_codigo
JOIN Rubro r ON r.rubr_id = p.prod_rubro
WHERE YEAR(f.fact_fecha) = 2012 
GROUP BY c.clie_codigo
HAVING c.clie_codigo IN(
    SELECT f.fact_cliente
    FROM Factura f
    JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
    JOIN Producto p ON i.item_producto = p.prod_codigo
    WHERE YEAR(f.fact_fecha) = 2012
        AND p.prod_codigo IN(
            SELECT c.comp_producto
            FROM Composicion c))
    AND c.clie_codigo NOT IN(
    SELECT f.fact_cliente
    FROM Factura f
    JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
    JOIN Producto p ON i.item_producto = p.prod_codigo
    WHERE YEAR(f.fact_fecha) = 2011
        AND p.prod_codigo IN(
            SELECT c.comp_producto
            FROM Composicion c))
ORDER BY Nro_Fila
-- Respuesta de clase
SELECT 
        ROW_NUMBER() OVER(ORDER BY ISNULL(
          (SELECT SUM(f.fact_total)
            FROM FACTURA f
            WHERE c.clie_codigo = f.fact_cliente
            AND YEAR(f.fact_fecha) = 2012
        ), 0) ASC) AS Numero_de_fila,
        ISNULL(
           (SELECT
               SUM(f.fact_total)
             FROM FACTURA f
             WHERE c.clie_codigo = f.fact_cliente
                AND YEAR(f.fact_fecha) = 2012),0) AS Monto_Total,
        ISNULL(
            (SELECT
                COUNT(DISTINCT r.rubr_detalle)
             FROM FACTURA f2 
             JOIN ITEM_FACTURA i2 ON f2.fact_tipo = i2.item_tipo AND f2.fact_sucursal = i2.item_sucursal AND f2.fact_numero = i2.item_numero
             JOIN PRODUCTO p2 ON i2.item_producto = p2.prod_codigo
             JOIN RUBRO r ON p2.prod_rubro = r.rubr_id
             WHERE f2.fact_cliente = c.clie_codigo
                AND YEAR(f2.fact_fecha) = 2012), 0) AS Cantidad_Rubros
FROM CLIENTE c
WHERE (SELECT COUNT(i3.item_producto)
       FROM FACTURA f3
       JOIN ITEM_FACTURA i3 ON f3.fact_tipo = i3.item_tipo AND f3.fact_sucursal = i3.item_sucursal AND f3.fact_numero = i3.item_numero
       WHERE f3.fact_cliente = c.clie_codigo
            AND YEAR(f3.fact_fecha) = 2012
            AND i3.item_producto IN (
            SELECT comp_producto 
            FROM COMPOSICION)) >= 1
        AND (SELECT COUNT(i4.item_producto)
            FROM FACTURA f4
            JOIN ITEM_FACTURA i4 ON f4.fact_tipo = i4.item_tipo AND f4.fact_sucursal = i4.item_sucursal AND f4.fact_numero = i4.item_numero
            WHERE f4.fact_cliente = c.clie_codigo AND YEAR(f4.fact_fecha) = 2011
                AND i4.item_producto IN (
                    SELECT comp_producto 
                    FROM COMPOSICION)
        ) = 0

/* 23. Realizar una consulta SQL que para cada año muestre : 
 Año 
 El producto con composición más vendido para ese año. 
 Cantidad de productos que componen directamente al producto más vendido 
 La cantidad de facturas en las cuales aparece ese producto. 
 El código de cliente que más compro ese producto. 
 El porcentaje que representa la venta de ese producto respecto al total de venta 
del año. 
El resultado deberá ser ordenado por el total vendido por año en forma descendente.*/
SELECT
    YEAR(f.fact_fecha) AS Anio,
    p.prod_codigo AS Cod_Producto,
    p.prod_detalle AS Detalle_Producto,
    COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) AS Cant_Facturas,
    COUNT(DISTINCT f.fact_vendedor) AS Cant_Vendedores_Diferentes,
    ISNULL(
       (SELECT COUNT(DISTINCT c.comp_producto)
        FROM Composicion c
        WHERE c.comp_componente = p.prod_codigo), 0) AS Cant_Productos_A_Los_Que_Compone,
    CAST(SUM(i.item_cantidad * i.item_precio) * 100.0 /
           (SELECT SUM(i2.item_cantidad * i2.item_precio)
            FROM Factura f2
            JOIN Item_Factura i2
                ON i2.item_tipo = f2.fact_tipo
               AND i2.item_sucursal = f2.fact_sucursal
               AND i2.item_numero = f2.fact_numero
            WHERE YEAR(f2.fact_fecha) = YEAR(f.fact_fecha)) AS DECIMAL(12,2)
    ) AS Porcentaje_Venta_Anio
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
GROUP BY YEAR(f.fact_fecha), p.prod_codigo, p.prod_detalle
ORDER BY YEAR(f.fact_fecha), SUM(i.item_cantidad) DESC

/* Parcial Practico de Gestion de Datos - 28/07/2023
1.    Realizar una consulta SQL que devuelva todos los clientes que durante 2 años consecutivos 
compraron al menos 5 productos distintos. De esos clientes mostrar:
●     El código de cliente
●     El monto total comprado en el 2012
●     La cantidad de unidades de productos compradas en el 2012
El resultado debe ser ordenado primero por aquellos clientes que compraron 
solo productos compuestos en algún momento,luego el resto.*/
--Version con WHERE IN
SELECT 
    c.clie_codigo AS Cod_Cliente,
    ISNULL(
        (SELECT SUM(f.fact_total)
        FROM Factura f
        WHERE f.fact_cliente = c.clie_codigo AND YEAR(f.fact_fecha) = 2012)
        ,0) AS Monto_Total_2012,
    ISNULL(
        (SELECT SUM(i.item_cantidad)
        FROM Factura f
        JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        WHERE f.fact_cliente = c.clie_codigo AND YEAR(f.fact_fecha) = 2012)
        ,0) AS Cant_Uni_Prod
FROM Cliente c
WHERE c.clie_codigo IN (
    SELECT fb.fact_cliente
    FROM Factura fb
    GROUP BY fb.fact_cliente, YEAR(fb.fact_fecha)
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
        -- Existe alguna factura del cliente actual
            SELECT 1
            FROM Factura fc
            WHERE fc.fact_cliente = c.clie_codigo
             -- La factura tiene al menos un producto
              AND EXISTS (
                    SELECT 1
                    FROM Item_Factura ic
                    WHERE ic.item_tipo = fc.fact_tipo AND ic.item_sucursal = fc.fact_sucursal AND ic.item_numero = fc.fact_numero )
             -- En esa factura NO existe ningún producto simple
              AND NOT EXISTS (
                    SELECT 1
                    FROM Item_Factura ic2
                    WHERE ic2.item_tipo = fc.fact_tipo AND ic2.item_sucursal = fc.fact_sucursal AND ic2.item_numero = fc.fact_numero
                      AND ic2.item_producto NOT IN (
                            SELECT comp_producto
                            FROM Composicion) )
            ) THEN 0 /* cumple: va primero */ ELSE 1 -- no cumple: va después
    END, c.clie_codigo
-- Version con WHERE EXISTS
SELECT 
    c.clie_codigo AS Cod_Cliente,
    ISNULL(
        (SELECT SUM(f.fact_total)
        FROM Factura f
        WHERE f.fact_cliente = c.clie_codigo AND YEAR(f.fact_fecha) = 2012)
        ,0) AS Monto_Total_2012,
    ISNULL(
        (SELECT SUM(i.item_cantidad)
        FROM Factura f
        JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        WHERE f.fact_cliente = c.clie_codigo AND YEAR(f.fact_fecha) = 2012)
        ,0) AS Cant_Uni_Prod
FROM Cliente c
WHERE EXISTS (
    SELECT 1
    FROM Factura fb
    WHERE fb.fact_cliente = c.clie_codigo
      AND ( SELECT COUNT(DISTINCT i1.item_producto)
            FROM Factura f1
            JOIN Item_Factura i1 ON f1.fact_tipo = i1.item_tipo AND f1.fact_sucursal = i1.item_sucursal AND f1.fact_numero = i1.item_numero
            WHERE f1.fact_cliente = c.clie_codigo
              AND YEAR(f1.fact_fecha) = YEAR(fb.fact_fecha) ) >= 5
      AND ( SELECT COUNT(DISTINCT i2.item_producto)
            FROM Factura f2
            JOIN Item_Factura i2 ON f2.fact_tipo = i2.item_tipo AND f2.fact_sucursal = i2.item_sucursal AND f2.fact_numero = i2.item_numero
            WHERE f2.fact_cliente = c.clie_codigo
              AND YEAR(f2.fact_fecha) = YEAR(fb.fact_fecha) + 1) >= 5
            )
ORDER BY
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM Factura fc
            WHERE fc.fact_cliente = c.clie_codigo
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
    END, c.clie_codigo

/* 2do  Recuperatorio Gestión de Datos - SQL/PL-SQL
1) SQL
Realizar una consulta que, para los productos que tienen más de un nivel de composición, 
retorne únicamente los siguientes campos:
Campos:
· El código de producto
· La cantidad de clientes que lo compraron en el 2012.
· La cantidad de facturas en las que fue vendido
· El  menor precio en el que se vendió en el 2012.
· Cantidad de productos de primer nivel que los compone.
Aclaración:
Para esta estadística, se deberán considerar únicamente las ventas que no tengan composición.
(Aclaración de la aclaración:
para los campos de ventas usás el valor del producto compuesto final vendido, 
no la suma ni la cantidad de sus componentes.)
El resultado deberá estar ordenado por el monto total facturado, de menor a mayor.*/
SELECT
    p.prod_codigo AS Cod_Prod,
    ISNULL( 
        (SELECT COUNT(DISTINCT f.fact_cliente)
        FROM Factura f
        JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        WHERE i.item_producto = p.prod_codigo AND YEAR(f.fact_fecha) = 2012)
        , 0) AS Cant_Clie_Que_Compraron_Prod,
    ISNULL(
        (SELECT COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) 
        FROM Factura f
        JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        WHERE i.item_producto = p.prod_codigo) --¿AND YEAR(f.fact_fecha) = 2012?
        , 0) AS Cant_Fact,
    ISNULL(
        (SELECT MIN(i.item_precio)
        FROM Factura f
        JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        WHERE i.item_producto = p.prod_codigo AND YEAR(f.fact_fecha) = 2012)
        , 0) AS Menor_Precio,
    ISNULL(
        (SELECT COUNT(DISTINCT c.comp_componente)
        FROM Composicion c
        WHERE c.comp_producto = p.prod_codigo)
        ,0) AS Cant_Componentes
FROM Producto p
WHERE EXISTS (
    SELECT 1
    FROM Composicion c1
    JOIN Composicion c2 ON c1.comp_componente = c2.comp_producto
    WHERE p.prod_codigo = c1.comp_producto)
ORDER BY ISNULL(
        (SELECT SUM(f.fact_total)
        FROM Factura f
        JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        WHERE i.item_producto = p.prod_codigo) -- ¿AND YEAR(f.fact_fecha) = 2012?
        , 0) ASC

/* Parcial BDD 1C-2026
SQL
Realizar una consulta que identifique a los productos del mismo rubro y envase que durante el año 2011 
se vendieron juntos en la misma factura más de 50 veces.

La consulta debe devolver los siguientes datos:
- El número de fila (orden correlativo empezando en 1)
- El nombre del producto 1.
- El nombre del producto 2.
- Rubro.
- Envase.
- Porcentaje total de las unidades vendidas de ese par respecto al total de unidades vendidas de todos los productos en el mismo año.

Alfabéticamente, el nombre del producto 1 debe estar antes que el nombre del producto 2.
Ningún dato del resultado puede ser NULL, se debe ordenar alfabéticamente por el nombre del producto 1.
*/
SELECT
    ROW_NUMBER() OVER(ORDER BY p1.prod_detalle ASC) AS Nro_Fila,
    p1.prod_detalle AS Nombre_Prod1,
    p2.prod_detalle AS Nombre_Prod2,
    r.rubr_id AS Cod_Rubro,
    e.enva_codigo AS Cod_Envase,
    ISNULL(CAST(
        SUM(i1.item_cantidad + i2.item_cantidad) * 100.0 /
           (SELECT SUM(i3.item_cantidad)
            FROM Factura f3
            JOIN Item_Factura i3 ON i3.item_tipo = f3.fact_tipo AND i3.item_sucursal = f3.fact_sucursal AND i3.item_numero = f3.fact_numero
            WHERE YEAR(f3.fact_fecha) = 2011) AS DECIMAL(12, 2))
            , 0) AS Porcentaje_Unidades_2011
FROM Factura f
JOIN Item_Factura i1 ON f.fact_tipo = i1.item_tipo AND f.fact_sucursal = i1.item_sucursal AND f.fact_numero = i1.item_numero
JOIN Producto p1 ON i1.item_producto = p1.prod_codigo
JOIN Item_Factura i2 ON f.fact_tipo = i2.item_tipo AND f.fact_sucursal = i2.item_sucursal AND f.fact_numero = i2.item_numero
JOIN Producto p2 ON i2.item_producto = p2.prod_codigo -- AND p1.prod_detalle < p2.prod_detalle
JOIN Rubro r ON p1.prod_rubro = r.rubr_id AND p2.prod_rubro = r.rubr_id
JOIN Envases e ON p1.prod_envase = e.enva_codigo AND p2.prod_envase = e.enva_codigo
WHERE YEAR(f.fact_fecha) = 2011 
    --AND p1.prod_rubro = p2.prod_rubro -- Tambien podrían haber quedado en el JOIN ... AND p2.prod_rubro = r.rubr_id
    --AND p1.prod_envase = p2.prod_envase                                         -- AND p2.prod_envase = e.enva_codigo
    AND p1.prod_detalle < p2.prod_detalle /* 1. Evita que el producto se compare consigo mismo.
       (También puede ir en el JOIN...       2. Evita duplicar pares: A-B y B-A.
        con JOIN Producto p2 ON... AND...)   3. Garantiza que producto 1 quede alfabéticamente antes que producto 2.*/
GROUP BY p1.prod_codigo, p1.prod_detalle,
         p2.prod_codigo, p2.prod_detalle,
         r.rubr_id, e.enva_codigo
HAVING COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) > 50
ORDER BY Nombre_Prod1 ASC

/* Parcial Practico de Gestion de Datos - 28/07/2023
1. Realizar una consulta SQL que devuelva todos los clientes que durante 2 años consecutivos 
compraron al menos 5 productos distintos. De esos clientes mostrar:
● El código de cliente
● El monto total comprado en el 2012
● La cantidad de unidades de productos compradas en el 2012
El resultado debe ser ordenado primero por aquellos clientes que compraron 
solo productos compuestos en algún momento,luego el resto.*/
SELECT 
    c.clie_codigo AS Cod_Cliente,
    ISNULL(
       (SELECT SUM(f12.fact_total)
        FROM Factura f12
        WHERE f12.fact_cliente = c.clie_codigo AND YEAR(f12.fact_fecha) = 2012 )
        , 0) AS Monto_Total_2012,
    ISNULL(
       (SELECT SUM(i12.item_cantidad)
        FROM Factura f12
        JOIN Item_Factura i12 ON f12.fact_tipo = i12.item_tipo AND f12.fact_sucursal = i12.item_sucursal AND f12.fact_numero = i12.item_numero
        WHERE f12.fact_cliente = c.clie_codigo AND YEAR(f12.fact_fecha) = 2012 )
        , 0) AS Cant_Unidades_2012
FROM Cliente c
WHERE EXISTS (
    SELECT 1
    FROM Factura fb
    WHERE fb.fact_cliente = c.clie_codigo
      AND (SELECT COUNT(DISTINCT i1.item_producto)
            FROM Factura f1
            JOIN Item_Factura i1 ON f1.fact_tipo = i1.item_tipo AND f1.fact_sucursal = i1.item_sucursal AND f1.fact_numero = i1.item_numero
            WHERE f1.fact_cliente = c.clie_codigo AND YEAR(f1.fact_fecha) = YEAR(fb.fact_fecha)
      ) >= 5
      AND (SELECT COUNT(DISTINCT i2.item_producto)
            FROM Factura f2
            JOIN Item_Factura i2 ON f2.fact_tipo = i2.item_tipo AND f2.fact_sucursal = i2.item_sucursal AND f2.fact_numero = i2.item_numero
            WHERE f2.fact_cliente = c.clie_codigo
              AND YEAR(f2.fact_fecha) = YEAR(fb.fact_fecha) + 1
      ) >= 5
    )
ORDER BY
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM Factura fc
            WHERE fc.fact_cliente = c.clie_codigo
              AND EXISTS ( -- Este EXISTS es solo para asegurarse que no haya facturas SIN items
                    SELECT 1
                    FROM Item_Factura ic
                    WHERE ic.item_tipo = fc.fact_tipo AND ic.item_sucursal = fc.fact_sucursal AND ic.item_numero = fc.fact_numero
              ) AND NOT EXISTS (
                    SELECT 1
                    FROM Item_Factura ic2
                    WHERE ic2.item_tipo = fc.fact_tipo AND ic2.item_sucursal = fc.fact_sucursal AND ic2.item_numero = fc.fact_numero
                      AND ic2.item_producto NOT IN (
                            SELECT comp_producto
                            FROM Composicion )
              )
        ) THEN 0 ELSE 1
    END, c.clie_codigo

-- Version empezando por Factura
SELECT
    f.fact_cliente AS Cod_Cliente,
    ISNULL((
        SELECT SUM(f12.fact_total)
        FROM Factura f12
        WHERE f12.fact_cliente = f.fact_cliente
          AND YEAR(f12.fact_fecha) = 2012
    ), 0) AS Monto_Total_2012,
    ISNULL((
        SELECT SUM(i12.item_cantidad)
        FROM Factura f12
        JOIN Item_Factura i12
            ON f12.fact_tipo = i12.item_tipo
           AND f12.fact_sucursal = i12.item_sucursal
           AND f12.fact_numero = i12.item_numero
        WHERE f12.fact_cliente = f.fact_cliente
          AND YEAR(f12.fact_fecha) = 2012
    ), 0) AS Cant_Unid_Prod_2012
FROM Factura f
GROUP BY f.fact_cliente
HAVING EXISTS (
    SELECT 1
    FROM Factura fb
    WHERE fb.fact_cliente = f.fact_cliente
      AND (SELECT COUNT(DISTINCT i1.item_producto)
            FROM Factura f1
            JOIN Item_Factura i1
                ON f1.fact_tipo = i1.item_tipo
               AND f1.fact_sucursal = i1.item_sucursal
               AND f1.fact_numero = i1.item_numero
            WHERE f1.fact_cliente = f.fact_cliente
              AND YEAR(f1.fact_fecha) = YEAR(fb.fact_fecha)
      ) >= 5
      AND (SELECT COUNT(DISTINCT i2.item_producto)
            FROM Factura f2
            JOIN Item_Factura i2
                ON f2.fact_tipo = i2.item_tipo
               AND f2.fact_sucursal = i2.item_sucursal
               AND f2.fact_numero = i2.item_numero
            WHERE f2.fact_cliente = f.fact_cliente
              AND YEAR(f2.fact_fecha) = YEAR(fb.fact_fecha) + 1
      ) >= 5
)
ORDER BY
    CASE 
        WHEN EXISTS (
            SELECT 1
            FROM Factura fx
            WHERE fx.fact_cliente = f.fact_cliente
              AND EXISTS (
                    SELECT 1
                    FROM Item_Factura ix
                    WHERE ix.item_tipo = fx.fact_tipo AND ix.item_sucursal = fx.fact_sucursal AND ix.item_numero = fx.fact_numero
              ) AND NOT EXISTS (
                    SELECT 1
                    FROM Item_Factura ix2
                    WHERE ix2.item_tipo = fx.fact_tipo AND ix2.item_sucursal = fx.fact_sucursal AND ix2.item_numero = fx.fact_numero
                      AND ix2.item_producto NOT IN (
                            SELECT comp_producto
                            FROM Composicion )
              )
        ) THEN 0 ELSE 1
    END, f.fact_cliente

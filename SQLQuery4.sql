/* Clase 15/04/2026
Hacer una consulta SQL que muestre:
El codigo de producto
Cantidad total vendida
El precio promedio
De los 10 productos más vendidos en cantidades.
Pista: La tabla es Item_Factura */
SELECT TOP 10
    i.item_producto AS Codigo_Producto ,
    SUM(i.item_cantidad) AS Cant_Total_Vendida,
    AVG(i.item_precio) AS Precio_Promedio
FROM Item_Factura i
GROUP BY i.item_producto
ORDER BY Codigo_Producto DESC -- DESC PORQUE NOS PIDEN LAS MAS VENDIDAS

/* Clase 22/04/2026
Hacer una consulta SQL que muestre:
El codigo de producto
El nombre del producto
Cantidad total vendida
El precio promedio
De los productos vendidos en el primer semestre del 2012
De los 10 productos más vendidos en cantidades.
Pista: La tabla es Item_Factura */
SELECT TOP 10
    i.item_producto AS Codigo_Producto ,
    p.prod_detalle as Nombre_Producto,
    SUM(i.item_cantidad) AS Cant_Total_Vendida,
    AVG(i.item_precio) AS Precio_Promedio
FROM Item_Factura i
    JOIN Producto p ON i.item_producto = p.prod_codigo
    JOIN Factura f ON i.item_tipo = f.fact_tipo 
                AND i.item_sucursal = f.fact_sucursal
                AND i.item_numero = f.fact_numero

WHERE YEAR(f.fact_fecha) = 2012 
    AND MONTH(f.fact_fecha) BETWEEN 1 AND 6
GROUP BY i.item_producto, p.prod_detalle
ORDER BY Cant_Total_Vendida DESC-- DESC PORQUE NOS PIDEN LAS MAS VENDIDAS

/* Guía SQL
Ejercicio 2) Mostrar el código, 
            detalle de todos los artículos vendidos en el año 2012 
            ordenados por cantidad vendida      */
SELECT 
    p.prod_codigo AS Cod_Prod,
    p.prod_detalle AS Cod_Detalle
FROM Producto p
    JOIN Item_Factura i ON p.prod_codigo = i.item_producto
    JOIN Factura f ON i.item_tipo = f.fact_tipo AND
                      i.item_sucursal = f.fact_sucursal AND
                      i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY SUM(i.item_cantidad) DESC

/* Clase 6/5/2026 : SUBSELECTs, ROW_NUMBER() OVER(PARTITION BY/ORDER BY...)
Ejercicio de Profe: Hacer una consulta SQL que muestre un campo nro, codigo cliente, nombre del cliente
El campo nro deberá ser un numerador de fila del cliente ordenado de menor codigo a mayor codigo
Ejemplo: Cliente A, B, C deberá mostrar
    nro  codigo  nombre
    1      A      ...
    2      B      ...
    3      C      ...   */
-- SOLUCION CON SUBSELECT
SELECT 
    (SELECT COUNT(*)
        FROM Cliente C2
        WHERE c2.clie_codigo <= c1.clie_codigo) AS Campo_Nro,
    c1.clie_codigo AS Cod_Cliente,
    c1.clie_razon_social
FROM Cliente C1
ORDER BY Campo_Nro ASC
-- SOLUCION CON OVER(ORDER BY)
SELECT
    ROW_NUMBER() OVER(ORDER BY c.clie_codigo ASC) AS Campo_Nro,
    ROW_NUMBER() OVER(ORDER BY c.clie_codigo DESC) AS Campo_Nro2, -- agregado para mostrar orden inverso nada mas, no aporta a la resolucion
    c.clie_codigo as Cod_Cliente,
    c.clie_razon_social as Razon_Social
FROM Cliente c
ORDER BY Campo_Nro

-- Mostramos uso del PARTITION BY; no agrupa, pero reconoce todos los datos que pertenezcan a un grupo 
-- (que sean iguales), y empieza a numerar por ese "grupo", luego vuelve a empezar a numerar cuando el grupo cambie.
SELECT
    ROW_NUMBER() OVER(ORDER BY f.fact_fecha ASC) AS Campo_Nro_Fila,
    ROW_NUMBER() OVER(PARTITION BY f.fact_cliente ORDER BY f.fact_fecha ASC) AS Campo_Nro_Partition,
    f.fact_cliente AS Cod_Cliente,
    f.fact_fecha AS Fecha
FROM Factura f 
ORDER BY Campo_Nro_Fila
-- Otro ejemplo con PARTITION BY
SELECT 
    ROW_NUMBER() OVER(PARTITION BY f.fact_cliente ORDER BY f.fact_fecha ASC) AS Numerador_X_Cli,
    SUM(f.fact_total) OVER(PARTITION BY f.fact_cliente) AS Total_Final_Acumulado,
    SUM(f.fact_total) OVER(PARTITION BY f.fact_cliente, YEAR(f.fact_fecha)) AS Total_X_Año,
    f.fact_cliente AS Cod_Cliente,
    f.fact_fecha AS Fact_Fecha
FROM Factura f

-- Otro ejemplo con PARTITION BY
SELECT 
    ROW_NUMBER() OVER(PARTITION BY f.fact_cliente ORDER BY f.fact_fecha ASC) AS Nro_Partition,
    SUM(f.fact_total) OVER(PARTITION BY f.fact_cliente ORDER BY f.fact_fecha ASC
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Total_Acumulado, -- ESTA LINEA SE VE QUE ES UTIL PORQUE FUNCIONA DE ACUMULADOR A LA VISTA DE LA CONSULTA
    f.fact_total,
    f.fact_cliente,
    f.fact_fecha
FROM Factura f

/* Guia SQL
Ejercicio 5) Realizar una consulta  que muestre
    Código de artículo,
    Detalle y Cantidad de Egresos de Stock que se realizaron para ese artículo 
    en el año 2012 (egresan los productos que fueron vendidos).
    Mostrar SOLO aquellos que hayan tenido MAS EGRESOS que en el año 2011   */
SELECT 
    p.prod_codigo AS Codigo_Prod,
    p.prod_detalle AS Detalle_Prod,
    SUM(CASE WHEN YEAR(fact_fecha) = 2012 
            THEN item_cantidad
            ELSE 0 
         END) AS Total_Vendido
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo 
    AND i.item_sucursal = f.fact_sucursal 
    AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) BETWEEN 2011 AND 2012
GROUP BY p.prod_codigo, p.prod_detalle
HAVING SUM(CASE WHEN YEAR(fact_fecha) = 2012 
                THEN i.item_cantidad 
                ELSE 0
            END) > 
ISNULL(SUM(CASE WHEN YEAR(fact_fecha) = 2011 
                THEN item_cantidad 
                ELSE 0
            END),0)
-- Ambas resoluciones estan bien
-- Resolucion punto 5 de compañero
select prod_codigo,
       prod_detalle,
       sum(item_cantidad) as totalVendido
From Producto p1 
    join Item_Factura on item_producto = prod_codigo 
    join Factura on fact_tipo = item_tipo AND 
                    fact_sucursal = item_sucursal AND 
                    fact_numero = item_numero
where year(fact_fecha) = 2012 
GROUP by prod_codigo, prod_detalle
having sum(item_cantidad) > 
isnull( (select sum(item_cantidad) 
            from Item_Factura 
            join Factura on fact_tipo = item_tipo AND 
                            fact_sucursal = item_sucursal AND 
                            fact_numero = item_numero
            where item_producto = p1.prod_codigo and year(fact_fecha) = 2011), 0 )

-- Resolucion punto 5 del profe
select 
    prod_codigo  , 
    prod_detalle, 
    sum(case when year(fact_fecha) = 2012 then item_cantidad else 0 end) as totalVendido
From Producto p1 
    join Item_Factura on item_producto = prod_codigo 
    join Factura on fact_tipo  = item_tipo AND 
                    fact_sucursal = item_sucursal AND 
                    fact_numero =  item_numero
where 
year(fact_fecha) in ( 2012 , 2011 )  
GROUP by 
    prod_codigo, 
    prod_detalle
having
     sum(case when year(fact_fecha) = 2012 then item_cantidad else 0 end) > 
     isnull(sum(case when year(fact_fecha) = 2011 then item_cantidad else 0 end),0)

/* Clase 13/5/2026 - Guia SQL
9) Mostrar el código del jefe, código del empleado que lo tiene como jefe, nombre del 
mismo y la cantidad de depósitos que ambos tienen asignados.    */
SELECT 
    j.empl_codigo AS Cod_Jefe,
    e.empl_codigo AS Cod_Empleado,
    e.empl_nombre AS Nombre_Empleado,
    COUNT(DISTINCT d.depo_codigo) AS Cant_Depositos_Asignados
FROM Empleado e
JOIN Empleado j
    ON e.empl_jefe = j.empl_codigo
LEFT JOIN Deposito d
    ON d.depo_encargado = e.empl_codigo
    OR d.depo_encargado = j.empl_codigo
GROUP BY
    j.empl_codigo,
    e.empl_codigo,
    e.empl_nombre
ORDER BY
    j.empl_codigo,
    e.empl_codigo
-- Por qué LEFT JOIN en vez de JOIN?
SELECT 
    j.empl_codigo AS Cod_Jefe,
    e.empl_codigo AS Cod_Empleado,
    e.empl_nombre AS Nombre_Empleado,
    COUNT(DISTINCT d.depo_codigo) AS Cant_Depositos_Asignados
FROM Empleado e
JOIN Empleado j
    ON e.empl_jefe = j.empl_codigo
JOIN Deposito d
    ON d.depo_encargado = e.empl_codigo
    OR d.depo_encargado = j.empl_codigo
GROUP BY
    j.empl_codigo,
    e.empl_codigo,
    e.empl_nombre
ORDER BY
    j.empl_codigo,
    e.empl_codigo
-- Otra variante que hizo una compañera
SELECT 
    e.empl_codigo AS Cod_Empl,
    e.empl_nombre AS Nombre_Empl,
    j.empl_codigo AS Cod_Jefe,
    COUNT(DISTINCT dj.depo_codigo) + COUNT(DISTINCT de.depo_codigo) AS Depositos_Empl_Jefe
FROM Empleado e
JOIN Empleado j ON e.empl_jefe = j.empl_codigo
LEFT JOIN DEPOSITO dj ON j.empl_codigo = dj.depo_encargado
LEFT JOIN DEPOSITO de ON e.empl_codigo = de.depo_encargado
GROUP BY 
    e.empl_codigo,
    e.empl_nombre,
    j.empl_codigo
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

-- El profe dejó planteado cómo obtener los 10 MAS y MENOS vendidos, falta unificar con el Cliente que más los compró
SELECT 
    *
FROM Producto p
WHERE p.prod_codigo IN (
    SELECT TOP 10
        i.item_producto
    FROM Item_Factura i
    GROUP BY i.item_producto
    ORDER BY SUM(i.item_cantidad) ASC )
    OR p.prod_codigo IN (
    SELECT TOP 10
        i.item_producto
    FROM Item_Factura i
    GROUP BY i.item_producto
    ORDER BY SUM(i.item_cantidad) DESC)
-- Mi intento de agregar al cliente que más compró tal producto
SELECT 
    (SELECT TOP 1
        f.fact_cliente
     FROM Item_Factura i
     JOIN Factura f ON i.item_tipo = f.fact_tipo 
                   AND i.item_sucursal = f.fact_sucursal  
                   AND i.item_numero = f.fact_numero
     WHERE i.item_producto = p.prod_codigo
     GROUP BY f.fact_cliente
     ORDER BY SUM(i.item_cantidad) DESC) AS Cliente,
    p.prod_codigo,
    p.prod_detalle
FROM Producto p
WHERE p.prod_codigo IN (
    SELECT TOP 10
        i.item_producto
    FROM Item_Factura i
    GROUP BY i.item_producto
    ORDER BY SUM(i.item_cantidad) ASC )
    OR p.prod_codigo IN (
    SELECT TOP 10
        i.item_producto
    FROM Item_Factura i
    GROUP BY i.item_producto
    ORDER BY SUM(i.item_cantidad) DESC)

/* 8. Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del 
artículo, stock del depósito que más stock tiene. */
SELECT 
    p.prod_detalle AS Nombre_Prod,
    MAX(s.stoc_cantidad) AS Stock_Deposito_Que_Mas_Tiene
FROM Producto p
JOIN STOCK s 
    ON p.prod_codigo = s.stoc_producto
WHERE s.stoc_cantidad > 0
GROUP BY 
    p.prod_codigo,
    p.prod_detalle
HAVING COUNT(DISTINCT s.stoc_deposito) = (
    SELECT COUNT(DISTINCT d.depo_codigo)
    FROM DEPOSITO d
);

/* 6. Mostrar para todos los rubros de artículos código, detalle, cantidad de artículos de ese 
rubro y stock total de ese rubro de artículos. Solo tener en cuenta aquellos artículos que 
tengan un stock mayor al del artículo ‘00000000’ en el depósito ‘00’. */
SELECT 
    r.rubr_id AS Codigo_Rubro,
    r.rubr_detalle AS Detalle_Rubro,
    COUNT(DISTINCT p.prod_codigo) AS Cantidad_Articulos,
    SUM(s.stoc_cantidad) AS Stock_Total_Rubro
FROM Rubro r
JOIN Producto p
    ON p.prod_rubro = r.rubr_id
JOIN Stock s
    ON s.stoc_producto = p.prod_codigo
WHERE (
    SELECT SUM(s2.stoc_cantidad)
    FROM Stock s2
    WHERE s2.stoc_producto = p.prod_codigo
) > (
    SELECT s3.stoc_cantidad
    FROM Stock s3
    WHERE s3.stoc_producto = '00000000'
      AND s3.stoc_deposito = '00'
)
GROUP BY r.rubr_id, r.rubr_detalle
ORDER BY r.rubr_id;

/* 7. Generar una consulta que muestre para cada artículo código, detalle, mayor precio 
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio = 
10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos artículos que posean 
stock. */
SELECT 
    p.prod_codigo, 
    p.prod_detalle,
    MAX(i.item_precio) AS Mayor_Precio,
    MIN(i.item_precio) AS Menor_Precio,
    (MAX(i.item_precio) - MIN(i.item_precio)) * 100 / MIN(i.item_precio) AS Porcentaje
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
WHERE p.prod_codigo IN (
    SELECT s.stoc_producto
    FROM STOCK s
    WHERE s.stoc_cantidad > 0
)
GROUP BY p.prod_codigo, p.prod_detalle

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
    ISNULL(
    (SELECT COUNT(*)
        FROM Factura f
     WHERE f.fact_cliente = c.clie_codigo
          AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx
          )
    ), 0) AS Veces_Compro_Ultimo_Anio,
    ISNULL(
    (SELECT AVG(f.fact_total)
        FROM Factura f
     WHERE f.fact_cliente = c.clie_codigo
          AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx
          )
    ), 0) AS Promedio_Por_Compra,
    ISNULL(
    (SELECT 
        COUNT(DISTINCT i.item_producto)
     FROM Factura f
        JOIN Item_Factura i
            ON i.item_tipo = f.fact_tipo
           AND i.item_sucursal = f.fact_sucursal
           AND i.item_numero = f.fact_numero
        WHERE f.fact_cliente = c.clie_codigo
          AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx
          )
    ), 0) AS Cant_Prod_Distintos,
    ISNULL((
        SELECT MAX(f.fact_total)
        FROM Factura f
        WHERE f.fact_cliente = c.clie_codigo
          AND YEAR(f.fact_fecha) = (
                SELECT MAX(YEAR(fx.fact_fecha))
                FROM Factura fx
          )
    ), 0) AS Mayor_Compra
FROM Cliente c
ORDER BY Veces_Compro_Ultimo_Anio DESC

/* Parcial Práctico de Gestión de Datos 12/07/2025
1. El objetivo es realizar una consulta SQL que identifique a los productos que
fueron comprados en todos los años impares que hay registrados en la base.
De esos productos se debe mostrar los siguientes datos:
    - El número de fila (orden correlativo).
    - El nombre del producto
    - Monto comprado en ARS.
El resultado debe estar ordenado en forma descendente según la cantidad total de comprado (de mayor a menor) 
en el último año.
Nota: No se permiten select en el from, es decir, select … from (select …) as T,... Ni WITH, ni tablas temporales.*/
SELECT
    ROW_NUMBER() OVER(ORDER BY ISNULL(
    (SELECT 
        SUM(i2.item_cantidad)
     FROM Item_Factura i2
     JOIN Factura f2 ON i2.item_tipo = f2.fact_tipo
                    AND i2.item_sucursal = f2.fact_sucursal
                    AND i2.item_numero = f2.fact_numero
     WHERE i2.item_producto = p.prod_codigo
              AND YEAR(f2.fact_fecha) = (
                    SELECT MAX(YEAR(f3.fact_fecha))
                    FROM Factura f3 ) ), 0) DESC,
        p.prod_codigo ) AS Nro_Fila,
    p.prod_detalle AS Nombre_Producto,
    SUM(i.item_cantidad * i.item_precio) AS Monto_Comprado_ARS
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo
              AND i.item_sucursal = f.fact_sucursal
              AND i.item_numero = f.fact_numero
GROUP BY p.prod_codigo, p.prod_detalle
HAVING COUNT(DISTINCT CASE
            WHEN YEAR(f.fact_fecha) % 2 != 0
            THEN YEAR(f.fact_fecha)
       END) = (
            SELECT COUNT(DISTINCT YEAR(f4.fact_fecha))
            FROM Factura f4
            WHERE YEAR(f4.fact_fecha) % 2 != 0 )
ORDER BY ISNULL((
    SELECT 
        SUM(i2.item_cantidad)
    FROM Item_Factura i2
    JOIN Factura f2 ON i2.item_tipo = f2.fact_tipo
                   AND i2.item_sucursal = f2.fact_sucursal
                   AND i2.item_numero = f2.fact_numero
    WHERE i2.item_producto = p.prod_codigo
      AND YEAR(f2.fact_fecha) = (
            SELECT MAX(YEAR(f3.fact_fecha))
            FROM Factura f3) ), 0) DESC;

/* Parcial Practico de Gestión de Datos 28/06/2025
1. El objetivo es realizar una consulta SQL que identifique a los clientes que compraron productos que pertenezcan 
 a dos rankings distintos del año 2012:
    - Los 10 productos más vendidos en 2012.
    - Los 10 productos menos vendidos en 2012 (considerando únicamente los 10 productos con menor cantidad vendida, 
    incluso si hay más de 10 productos con el mismo valor mínimo).
La consulta debe devolver los siguientes datos:
    1. El número de fila (orden correlativo).
    2. El nombre del cliente.
    3. Si es cliente en el Ranking de los más vendidos.
    4. Cantidad total de Facturas del cliente
El resultado debe estar ordenado en forma descendente según el monto total de compras del cliente 
(de mayor a menor).
Nota: No se permiten select en el from, es decir, select … from (select …) as T ...Ni WITH, ni tablas temporales.*/

-- Intento propio de resolución (NI CERCA)
SELECT 
    ROW_NUMBER() OVER(ORDER BY
    (SELECT TOP 10
        i.item_producto
     FROM Item_Factura i
     JOIN Factura f ON i.item_tipo = f.fact_tipo
                   AND i.item_sucursal = f.fact_sucursal
                   AND i.item_numero = f.fact_numero
     WHERE YEAR(f.fact_fecha) = 2012
     GROUP BY i.item_producto
     ORDER BY SUM(i.item_cantidad) DESC)
    ,
     (SELECT TOP 10
        i.item_producto
     FROM Item_Factura i
     JOIN Factura f ON i.item_tipo = f.fact_tipo
                   AND i.item_sucursal = f.fact_sucursal
                   AND i.item_numero = f.fact_numero
     WHERE YEAR(f.fact_fecha) = 2012
     GROUP BY i.item_producto
     ORDER BY SUM(i.item_cantidad) ASC) )
FROM Cliente c

-- GPT
SELECT
    ROW_NUMBER() OVER ( ORDER BY ISNULL(
       (SELECT SUM(fm.fact_total)
            FROM Factura fm
        WHERE fm.fact_cliente = c.clie_codigo), 0) DESC, c.clie_codigo) AS Nro_Fila,
    c.clie_razon_social AS Nombre_Cliente,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM Factura f
            JOIN Item_Factura i
                ON i.item_tipo = f.fact_tipo
               AND i.item_sucursal = f.fact_sucursal
               AND i.item_numero = f.fact_numero
            WHERE f.fact_cliente = c.clie_codigo
              AND YEAR(f.fact_fecha) = 2012
              AND i.item_producto IN (
                    SELECT TOP 10
                        i2.item_producto
                    FROM Item_Factura i2
                    JOIN Factura f2
                        ON i2.item_tipo = f2.fact_tipo
                       AND i2.item_sucursal = f2.fact_sucursal
                       AND i2.item_numero = f2.fact_numero
                    WHERE YEAR(f2.fact_fecha) = 2012
                    GROUP BY i2.item_producto
                    ORDER BY SUM(i2.item_cantidad) DESC))
        THEN 'SI' ELSE 'NO' END AS Cliente_Ranking_Mas_Vendidos,
    ISNULL((
        SELECT COUNT(*)
        FROM Factura fc
        WHERE fc.fact_cliente = c.clie_codigo
    ), 0) AS Cantidad_Total_Facturas
FROM Cliente c
WHERE EXISTS (
    SELECT 1
    FROM Factura f
    JOIN Item_Factura i
        ON i.item_tipo = f.fact_tipo
       AND i.item_sucursal = f.fact_sucursal
       AND i.item_numero = f.fact_numero
    WHERE f.fact_cliente = c.clie_codigo
      AND YEAR(f.fact_fecha) = 2012
      AND ( i.item_producto IN (
                SELECT TOP 10
                    i3.item_producto
                FROM Item_Factura i3
                JOIN Factura f3
                    ON i3.item_tipo = f3.fact_tipo
                   AND i3.item_sucursal = f3.fact_sucursal
                   AND i3.item_numero = f3.fact_numero
                WHERE YEAR(f3.fact_fecha) = 2012
                GROUP BY i3.item_producto
                ORDER BY SUM(i3.item_cantidad) DESC
            )
            OR
            i.item_producto IN (
                SELECT TOP 10
                    i4.item_producto
                FROM Item_Factura i4
                JOIN Factura f4
                    ON i4.item_tipo = f4.fact_tipo
                   AND i4.item_sucursal = f4.fact_sucursal
                   AND i4.item_numero = f4.fact_numero
                WHERE YEAR(f4.fact_fecha) = 2012
                GROUP BY i4.item_producto
                ORDER BY SUM(i4.item_cantidad) ASC ) ) )
ORDER BY ISNULL((
    SELECT SUM(fo.fact_total)
    FROM Factura fo
    WHERE fo.fact_cliente = c.clie_codigo
), 0) DESC;

/*==============NOTAS DE CLASES===============*/
--CREATE TABLE provincias 
--(	
--	id int NOT NULL primary key,
--	nombre char(50) NOT NULL
--)

INSERT INTO provincias ( id, nombre ) values (1, 'Ciudad de Buenos Aires');
INSERT INTO provincias ( id, nombre ) values (2, 'Buenos Aires');
INSERT INTO provincias ( id, nombre ) values (3, 'Cordoba');

INSERT INTO provincias ( id, nombre ) values( 1 , 'Santa Fe' ); -- Esto generará un error porque el id 1 ya existe en la tabla.
-- Como es una PK me olvido de validar esto, desde la teoria ya esta resuelto, la PK debe ser unica.

/*CREATE TABLE ALUMNO (
    id int NOT NULL PRIMARY KEY,
    nombre char(100) NOT NULL,
    edad int CHECK (edad > 0 and edad < 150) --restriccion 
)*/

ALTER TABLE ALUMNO ADD DNI int NOT NULL UNIQUE -- agrega una columna dni a la tabla
--UNIQUE hace que el campo sea unico y no se pueda repetir

INSERT INTO ALUMNO (id, nombre, edad, dni) values ( 1 , 'juan perez' , 10 , 1)
INSERT INTO ALUMNO (id, nombre, edad, dni) values ( 2 , 'maria perez' , 20 , 2)

-- DML

CREATE TABLE LOCALIDADES (
    id BIGINT PRIMARY KEY,
    provincia_id INT REFERENCES provincias,
    nombre NVARCHAR(255)
)


INSERT INTO localidades (id, provincia_id, nombre) values ( 1 , 1 , 'comuna 1' )
INSERT INTO localidades (id, provincia_id ,nombre) values ( 2 , 2 , 'Quilmes' )
INSERT INTO localidades (id, provincia_id ,nombre) values ( 3 , 2 , 'La Matanza' )
INSERT INTO localidades (id, provincia_id ,nombre) values ( 4 , 4 , 'Alguna comuna' ) -- Error, no existe una provincia con ID 4

DELETE FROM provincias WHERE id = 2 -- No puedo borrar id 2 porque Quiles lo está usando (INTEGRIDAD REFERENCIAL)



SELECT * FROM ALUMNO; --permite traer los datos planos o los enrriquecidos

SELECT clie_codigo, clie_razon_social FROM CLIENTE
ORDER BY clie_codigo ASC --a priori no estan ordenados de ninguna manera puntual salvo que lo especifique


SELECT * FROM ALUMNO
WHERE id > 1 --funciona como un filtro


ALTER TABLE ALUMNO ADD nota INT NULL

SELECT * FROM ALUMNO WHERE nota = null -- No funciona porque estoy comparando si un dato desconocido es igual a otro desconocido
SELECT * FROM ALUMNO WHERE nota is null -- Encambio aca pregunto si la nota es null

ALTER TABLE ALUMNO ADD fecha_nacimineto smalldatetime
insert into alumno (id, nombre, edad, dni, fecha_nacimineto) values (4, 'pedro', 10, 1234, '12-10-2026' ) --mes, dia año (depende de la configuracion) DBCC USEROPTIONS
insert into alumno (id, nombre, edad, dni, fecha_nacimineto) values (5, 'pedro', 10, 567, '20261210' ) -- año mes dia. es siempre igual

SELECT*FROM ALUMNO

-- Arreglaremos lo de arriba después

-- 15/4/2026 Clase BDD
SELECT * FROM Departamento

SELECT  depa_detalle Detalle, depa_zona Zona
FROM Departamento


SELECT 
    depa_detalle , depa_zona  , getdate() as fecha_hora,
    'constante' as string , 1 + 1 as suma
FROM DEPARTAMENTO
-- Me faltan líneas arriba (fue un poco rapido el profe o yo fui medio lenta)
SELECT 
    year(fact_fecha) as anio,
    fact_fecha as fecha,
    fact_vendedor as Vendedor,
    fact_cliente as Cliente
    FROM Factura
--    WHERE

select 
    year(fact_fecha) as anio ,
    fact_fecha as fecha, 
    fact_vendedor as Vendedor, 
    fact_cliente as Cliente
from factura
--
select 
   *
from factura  
where 
    fact_cliente is NULL

select 
   *
from factura  
where 
    fact_cliente is NULL and 
    fact_fecha >= '2024-01-01' and 
    fact_fecha <= '2024-12-31';
--
select 
   *
from cliente 
where 
   clie_telefono is null ;
--
select 
   *
from cliente 
where 
   clie_telefono is not null;
--
select * from factura

--
select 
    fact_cliente, 
    count(*) as cantidad_total,
    sum(fact_total) as monto_total
from factura 
group by 
    fact_cliente;
--
select 
    year(fact_fecha) as año, 
    fact_cliente,
    count(*) as cantidad_total,
    sum(fact_total) as monto_total
from factura 
group by 
     year(fact_fecha) , fact_cliente   
order by 
    1 asc, 2 desc
--
select 
    year(fact_fecha) as año, 
    fact_cliente,
    count(*) as cantidad_total,
    sum(fact_total) as monto_total,
    min(fact_fecha) as fecha_primera_compra,
    max(fact_fecha) as fecha_ultima_compra,
    avg(fact_total) as monto_promedio
from factura 
group by 
     year(fact_fecha) , fact_cliente   
order by 
    1 asc, 2 desc
--
--COUNT(CAMPO) = CUENTA LA CANTIDAD DE FIAS DONDE EL "CAMPO" NO ES NULL

---TABLA
--ID. NOMBRE
--1.  X1
--2.  X2
--3.  NULL
--4.  X4

--COUNT(*) = 4
--COUNT(NOMBRE) = 3 --NOMBRE es un campo. COUNT(campo)
--

select * from factura where fact_vendedor is NULL

select 
    fact_cliente,
    count(*) as cantidad_total,
    count(fact_vendedor) as cantidad_vendedor
from factura 
group by 
      fact_cliente   
order by 
    1 asc
--
select 
    fact_cliente,

    count(*) as cantidad_total,
    count(fact_vendedor) as cantidad_vendedor,
    count(distinct fact_vendedor) as cantidad_vendedor_distinto,
    count(1) as cantidad_1
from factura 
where 
    fact_fecha >= '2011-01-01' and fact_fecha <= '2011-12-31'
group by 
      fact_cliente   
order by 
    1 asc
--
select 
    fact_cliente,
    sum(fact_total) as suma_total,
    count(*) as cantidad_total,
    count(fact_vendedor) as cantidad_vendedor,
    count(distinct fact_vendedor) as cantidad_vendedor_distinto,
    count(1) as cantidad_1
from factura 
where 
    fact_fecha >= '2011-01-01' and fact_fecha <= '2011-12-31'
group by 
      fact_cliente
having 
    sum(fact_total) < 1000
order by 
    1 asc

--
SELECT 
    DISTINCT fact_cliente
from factura
order by 1 asc
--
SELECT top 10 * FROM factura
order by fact_cliente asc
--
select clie_codigO  from cliente
UNION 
select fact_cliente from factura


-- EJERCICIOS GUIA "PRACTICA SQL"
-- 1) 1. Mostrar el código, razón social de todos los clientes cuyo límite de crédito sea mayor o
-- igual a $ 1000 ordenado por código de cliente.
SELECT * FROM Cliente

SELECT
    clie_codigo as Codigo_Cliente,
    clie_razon_social as Razon_Social
FROM Cliente
    WHERE
    clie_limite_credito >= 1000
    ORDER BY Codigo_Cliente asc

/*PRODUCTO                  ITEM_FACTURA 
 ID NOMBRE.                ID. ID_PRODUCTO CANTIDAD 
 1.  PROD1                  1.     1          100 
 2.  PROD2                  2.     1          200 
                            3.     NULL       100

 PRODUCTO INNER JOIN ITEM_FACTURA ID = ITEM_FACTURA.ID_PRODUCTO 

     ID NOMBRE.ID. ID_PRODUCTO CANTIDAD 
     1.  PROD1  1.     1          100 
     1.  PROD1  2.     1          200 
  ---> GROUP BY ID_PRODUCTO, NOMBRE 

   ID_PRODUCTO NOMBRE CANTIDAD 
       1.       PROD1.  300 

 PRODUCTO LEFT JOIN ITEM_FACTURA  ON  ID = ITEM_FACTURA.ID_PRODUCTO 

     ID NOMBRE.ID. ID_PRODUCTO CANTIDAD 
     1.  PROD1  1.     1          100 
     1.  PROD1  2.     1          200 
     2.  PROD2  NULL.  NULL.       NULL
PRODUCTO RIGHT JOIN ITEM_FACTURA  ON  ID = ITEM_FACTURA.ID_PRODUCTO 

     ID  NOMBRE.ID. ID_PRODUCTO CANTIDAD 
     1.   PROD1  1.     1          100 
     1.   PROD1  2.     1          200 
     NULL NULL  3.    NULL        100 

 PRODUCTO FULL OUTER JOIN ITEM_FACTURA  ON  ID = ITEM_FACTURA.ID_PRODUCTO 

     ID  NOMBRE.ID. ID_PRODUCTO CANTIDAD 
     1.   PROD1  1.     1          100 
     1.   PROD1  2.     1          200 
     2.   PROD2  NULL.  NULL.      NULL
     NULL NULL   3.     NULL.      100
     */

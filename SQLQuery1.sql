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
	SUM(f.fact_total) AS Monto,
	COUNT(DISTINCT f.fact_tipo  + f.fact_sucursal + f.fact_numero) AS Cant_Facturas,
	(SELECT TOP 1
		e2.empl_nombre
	 FROM Empleado e2 
	 JOIN Factura f2 ON e2.empl_codigo = f2.fact_vendedor
	 WHERE e2.empl_jefe = j.empl_codigo
	 GROUP BY e2.empl_codigo, e2.empl_nombre
	 ORDER BY SUM(f2.fact_total) DESC, e2.empl_codigo) AS Empl_Mas_Ventas
FROM Empleado j
JOIN Empleado e ON j.empl_codigo = e.empl_jefe
JOIN Factura f ON f.fact_vendedor = e.empl_codigo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY j.empl_codigo, j.empl_nombre
HAVING COUNT(DISTINCT f.fact_tipo  + f.fact_sucursal + f.fact_numero) > 10
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
JOIN Composicion c ON p.prod_codigo = c.comp_componente
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012 
	AND c.comp_producto IN (SELECT TOP 1
							i2.item_producto
						  FROM Item_Factura i2
						  JOIN Composicion c2 ON i2.item_producto = c2.comp_producto
						  WHERE i2.item_tipo = f.fact_tipo AND i2.item_sucursal = f.fact_sucursal AND i2.item_numero = f.fact_numero
							AND p.prod_codigo = c2.comp_componente
					      GROUP BY i2.item_producto
						  ORDER BY SUM(i2.item_cantidad) DESC, i2.item_producto)
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY SUM(i.item_cantidad * i.item_precio) DESC

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

-- PRAC TSQL: SP
CREATE OR ALTER PROCEDURE productos_por_rubro
    @codigo_rubro CHAR(4)
AS
BEGIN
    SELECT *
    FROM Producto p
    JOIN Rubro r ON r.rubr_id = p.prod_rubro
    WHERE r.rubr_id = @codigo_rubro;
END;

EXEC productos_por_rubro '0001'
-------------------------------------------
CREATE OR ALTER PROCEDURE actualizar_precio
    @codigo_prod CHAR(8),
    @nuevo_precio DECIMAL(12,2)
AS
BEGIN
    IF EXISTS (
            SELECT 1
            FROM Producto
            WHERE prod_codigo = @codigo_prod
            )
    BEGIN
        UPDATE Producto
        SET prod_precio = @nuevo_precio
        WHERE prod_codigo = @codigo_prod;
    END;
    ELSE
    BEGIN
        PRINT 'El producto no existe';
    END;
END;
----------------------------------------------
/* UPDATE nombre_tabla 
SET columna1 = valor1, columna2 = valor2 
WHERE condición; */
-------------------------------------------------
-- FUNCIONES
CREATE OR ALTER FUNCTION multiplicar
(
    @numero1 INT,
    @numero2 INT
)
RETURNS INT
AS
BEGIN
    DECLARE @resultado INT;

    SET @resultado = @numero1 * @numero2;

    RETURN @resultado;
END;
----------------------------------------
CREATE OR ALTER FUNCTION dbo.obtener_razon_social
(
    @cod_cli CHAR(100)
)
RETURNS CHAR(100)
AS
BEGIN
    DECLARE @raz_soc CHAR(100)

    SELECT @raz_soc = c.clie_razon_social
    FROM Cliente c
    WHERE c.clie_codigo = @cod_cli;

    RETURN @raz_soc;
END;
------------------------------------------
CREATE OR ALTER FUNCTION dbo.obtener_rubro
(
    @fact_tipo CHAR(1),
    @fact_sucursal CHAR(4),
    @fact_numero CHAR(8)
)
RETURNS CHAR(100)
AS
BEGIN
    DECLARE @raz_soc CHAR(100);

    SELECT @raz_soc = c.clie_razon_social
    FROM Cliente c
    JOIN Factura f ON f.fact_cliente = c.clie_codigo
    WHERE f.fact_tipo = @fact_tipo AND f.fact_sucursal = @fact_sucursal AND f.fact_numero = @fact_numero;

    RETURN @raz_soc;
END;
-------------------------------------------
/* 1. Hacer una función que dado un artículo y un deposito devuelva un string que 
indique el estado del depósito según el artículo. Si la cantidad almacenada es 
menor al límite retornar “OCUPACION DEL DEPOSITO XX %” siendo XX el 
% de ocupación. Si la cantidad almacenada es mayor o igual al límite retornar 
“DEPOSITO COMPLETO”. */
CREATE OR ALTER FUNCTION estado_depo
( @articulo CHAR(8),
  @depo CHAR(2)
) RETURNS CHAR(50)
AS
BEGIN
    DECLARE @estado CHAR(50)
    DECLARE @porcentaje DECIMAL(10,2);

    SELECT
        @porcentaje = s.stoc_cantidad * 100.0 / s.stoc_stock_maximo
    FROM STOCK s
    WHERE s.stoc_producto = @articulo
      AND s.stoc_deposito = @depo;

    IF @porcentaje >= 100
    BEGIN
        SET @estado = 'DEPOSITO COMPLETO';
    END
    ELSE
    BEGIN
        SET @estado = 'OCUPACION DEL DEPOSITO '
                    + CAST(@porcentaje AS VARCHAR(10))
                    + ' %';
    END;

    RETURN @estado;
END
--
SELECT dbo.estado_depo('00000032', '00');
----
/* 2. Realizar una función que dado un artículo y una fecha, retorne el stock que 
existía a esa fecha */
CREATE OR ALTER FUNCTION dbo.stock_fecha
(
    @articulo CHAR(8),
    @fecha SMALLDATETIME
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @stock DECIMAL(12,2);

    SELECT @stock = s.stoc_cantidad
    FROM STOCK s
    JOIN Item_Factura i ON s.stoc_producto = i.item_producto
    JOIN Factura f ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
    WHERE s.stoc_producto = @articulo AND f.fact_fecha = @fecha;

    RETURN @stock;
END;

/* 11. Cree el/los objetos de base de datos necesarios para que dado un código de 
empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o 
indirectamente). Solo contar aquellos empleados (directos o indirectos) que 
tengan un código mayor que su jefe directo. */
CREATE OR ALTER FUNCTION dbo.cantidad_empleados
(
    @cod_empleado NUMERIC(6)
)
RETURNS INT
AS
BEGIN
    DECLARE @cantidad INT;
    SET @cantidad = 0;

    SELECT @cantidad = @cantidad
        + CASE
            WHEN e.empl_codigo > @cod_empleado THEN 1
            ELSE 0
          END
        + dbo.cantidad_empleados(e.empl_codigo)
    FROM Empleado e
    WHERE e.empl_jefe = @cod_empleado;

    RETURN @cantidad;
END;

/* 13. Cree el/los objetos de base de datos necesarios para implantar la siguiente regla 
“Ningún jefe puede tener un salario mayor al 20% de las suma de los salarios de 
sus empleados totales (directos + indirectos)”. Se sabe que en la actualidad dicha 
regla se cumple y que la base de datos es accedida por n aplicaciones de 
diferentes tipos y tecnologías */
CREATE OR ALTER FUNCTION dbo.salarios_empleados
(
    @cod_empleado NUMERIC(6)
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total DECIMAL(12,2);

    SET @total = 0;

    SELECT @total = @total
        + e.empl_salario
        + dbo.salarios_empleados(e.empl_codigo)
    FROM Empleado e
    WHERE e.empl_jefe = @cod_empleado;

    RETURN @total;
END;

CREATE OR ALTER TRIGGER TR_VALIDAR_SALARIO_JEFE
ON Empleado
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Empleado e
        WHERE EXISTS (
            SELECT 1
            FROM Empleado sub
            WHERE sub.empl_jefe = e.empl_codigo
        )
        AND e.empl_salario >
            dbo.salarios_empleados(e.empl_codigo) * 0.20
    )
    BEGIN
        ROLLBACK TRANSACTION;

        RAISERROR(
            'El salario del jefe supera el 20%% de los salarios de sus empleados.',
            16, 1
        );

        RETURN;
    END;
END;

/* 14. Agregar el/los objetos necesarios para que si un cliente compra un producto 
compuesto a un precio menor  que la suma de los precios de sus componentes  
que imprima la  fecha, que cliente, que productos y a qué precio se realizó la 
compra. No se deberá permitir que dicho precio sea menor a la mitad de la suma 
de los componentes. */
CREATE OR ALTER FUNCTION dbo.precio_componentes
(
    @producto CHAR(8)
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total DECIMAL(12,2);

    SELECT @total = ISNULL(
        SUM(c.comp_cantidad * p.prod_precio),
        0
    )
    FROM Composicion c
    JOIN Producto p
        ON p.prod_codigo = c.comp_componente
    WHERE c.comp_producto = @producto;

    RETURN @total;
END;
GO

CREATE TABLE LOG_VENTAS_COMPUESTOS
(
    log_fecha SMALLDATETIME,
    log_cliente CHAR(6),
    log_razon_social CHAR(100),
    log_producto CHAR(8),
    log_detalle CHAR(50),
    log_precio_venta DECIMAL(12,2),
    log_precio_componentes DECIMAL(12,2)
);
GO

CREATE OR ALTER TRIGGER TR_VALIDAR_VENTA_COMPUESTO
ON Item_Factura
AFTER INSERT, UPDATE
AS
BEGIN

    -- PRIMER CONTROL:
    -- No permitir ventas por debajo de la mitad
    -- del precio total de los componentes.

    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE EXISTS (
            SELECT 1
            FROM Composicion c
            WHERE c.comp_producto = i.item_producto
        )
        AND i.item_precio < dbo.precio_componentes(i.item_producto) * 0.50
    )
    BEGIN
        ROLLBACK TRANSACTION;

        RAISERROR(
            'No se permite vender el producto por debajo de la mitad del precio de sus componentes.',
            16, 1
        );

        RETURN;
    END;


    -- SEGUNDO CONTROL:
    -- Registrar las ventas cuyo precio sea menor
    -- que la suma de los precios de sus componentes.

    INSERT INTO LOG_VENTAS_COMPUESTOS
    (
        log_fecha,
        log_cliente,
        log_razon_social,
        log_producto,
        log_detalle,
        log_precio_venta,
        log_precio_componentes
    )
    SELECT
        f.fact_fecha,
        cl.clie_codigo,
        cl.clie_razon_social,
        i.item_producto,
        p.prod_detalle,
        i.item_precio,
        dbo.precio_componentes(i.item_producto)
    FROM inserted i
    JOIN Factura f
        ON f.fact_tipo = i.item_tipo
        AND f.fact_sucursal = i.item_sucursal
        AND f.fact_numero = i.item_numero
    JOIN Cliente cl
        ON cl.clie_codigo = f.fact_cliente
    JOIN Producto p
        ON p.prod_codigo = i.item_producto
    WHERE EXISTS (
        SELECT 1
        FROM Composicion c
        WHERE c.comp_producto = i.item_producto
    )
    AND i.item_precio < dbo.precio_componentes(i.item_producto);

END;
GO


/* 15. Cree el/los objetos de base de datos necesarios para que el objeto principal 
reciba un producto como parametro y retorne el precio del mismo. 
Se debe prever que el precio de los productos compuestos sera la sumatoria de 
los componentes del mismo multiplicado por sus respectivas cantidades. No se 
conocen los nivles de anidamiento posibles de los productos. Se asegura que 
nunca un producto esta compuesto por si mismo a ningun nivel. El objeto 
principal debe poder ser utilizado como filtro en el where de una sentencia 
select. */
CREATE OR ALTER FUNCTION dbo.precio_producto
( @producto CHAR(8)
) RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @precio DECIMAL(12,2);

    IF EXISTS (
        SELECT 1
        FROM Composicion c
        WHERE c.comp_producto = @producto
    )
    BEGIN
        SELECT @precio = SUM(
            c.comp_cantidad * dbo.precio_producto(c.comp_componente)
        )
        FROM Composicion c
        WHERE c.comp_producto = @producto;
    END
    ELSE
    BEGIN
        SELECT @precio = p.prod_precio
        FROM Producto p
        WHERE p.prod_codigo = @producto;
    END;

    RETURN @precio;
END;

/* 16. Desarrolle el/los elementos de base de datos necesarios para que ante una venta 
automaticamante se descuenten del stock los articulos vendidos. Se descontaran 
del deposito que mas producto poseea y se supone que el stock se almacena 
tanto de productos simples como compuestos (si se acaba el stock de los 
compuestos no se arman combos) 
En caso que no alcance el stock de un deposito se descontara del siguiente y asi 
hasta agotar los depositos posibles. En ultima instancia se dejara stock negativo 
en el ultimo deposito que se desconto. */
CREATE OR ALTER TRIGGER TR_DESCONTAR_STOCK
ON Item_Factura
AFTER INSERT
AS
BEGIN
    DECLARE @producto CHAR(8);
    DECLARE @cantidad DECIMAL(12,2);
    DECLARE @pendiente DECIMAL(12,2);

    DECLARE @deposito CHAR(2);
    DECLARE @stock DECIMAL(12,2);

    DECLARE @ultimo_deposito CHAR(2);
    DECLARE @primer_deposito CHAR(2);

    -- Cursor para recorrer los productos vendidos
    DECLARE cur_ventas CURSOR FOR
        SELECT item_producto, item_cantidad
        FROM inserted;

    -- Cursor para recorrer los depósitos de un producto,
    -- ordenados desde el que más stock tiene.
    DECLARE cur_depositos CURSOR FOR
        SELECT stoc_deposito, stoc_cantidad
        FROM STOCK
        WHERE stoc_producto = @producto
        ORDER BY stoc_cantidad DESC;

    OPEN cur_ventas;

    FETCH NEXT FROM cur_ventas
    INTO @producto, @cantidad;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @pendiente = @cantidad;
        SET @ultimo_deposito = NULL;
        SET @primer_deposito = NULL;

        OPEN cur_depositos;

        FETCH NEXT FROM cur_depositos
        INTO @deposito, @stock;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Guardamos el depósito con mayor stock.
            IF @primer_deposito IS NULL
                SET @primer_deposito = @deposito;

            -- Solo descontamos de depósitos con stock positivo.
            IF @stock > 0 AND @pendiente > 0
            BEGIN
                SET @ultimo_deposito = @deposito;

                IF @stock >= @pendiente
                BEGIN
                    -- Este depósito alcanza para cubrir la venta.
                    UPDATE STOCK
                    SET stoc_cantidad = stoc_cantidad - @pendiente
                    WHERE stoc_producto = @producto
                      AND stoc_deposito = @deposito;

                    SET @pendiente = 0;
                END
                ELSE
                BEGIN
                    -- No alcanza: agotamos el stock del depósito.
                    UPDATE STOCK
                    SET stoc_cantidad = 0
                    WHERE stoc_producto = @producto
                      AND stoc_deposito = @deposito;

                    SET @pendiente = @pendiente - @stock;
                END
            END;

            FETCH NEXT FROM cur_depositos
            INTO @deposito, @stock;
        END;

        CLOSE cur_depositos;

        -- Si todavía queda cantidad pendiente,
        -- la descontamos del último depósito utilizado.
        IF @pendiente > 0
        BEGIN
            -- Si ningún depósito tenía stock positivo,
            -- elegimos el que más stock tenía.
            IF @ultimo_deposito IS NULL
                SET @ultimo_deposito = @primer_deposito;

            IF @ultimo_deposito IS NOT NULL
            BEGIN
                UPDATE STOCK
                SET stoc_cantidad = stoc_cantidad - @pendiente
                WHERE stoc_producto = @producto
                  AND stoc_deposito = @ultimo_deposito;
            END;
        END;

        FETCH NEXT FROM cur_ventas
        INTO @producto, @cantidad;
    END;

    CLOSE cur_ventas;

    DEALLOCATE cur_ventas;
    DEALLOCATE cur_depositos;
END;
GO

/* 17. Sabiendo que el punto de reposicion del stock es la menor cantidad de ese objeto 
que se debe almacenar en el deposito y que el stock maximo es la maxima 
cantidad de ese producto en ese deposito, cree el/los objetos de base de datos 
necesarios para que dicha regla de negocio se cumpla automaticamente. No se 
conoce la forma de acceso a los datos ni el procedimiento por el cual se 
incrementa o descuenta stock */
CREATE OR ALTER TRIGGER TR_VALIDAR_STOCK
ON STOCK
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE stoc_cantidad < stoc_punto_reposicion
           OR stoc_cantidad > stoc_stock_maximo
    )
    BEGIN
        ROLLBACK TRANSACTION;

        RAISERROR(
            'El stock debe estar entre el punto de reposicion y el stock maximo.',
            16, 1
        );

        RETURN;
    END;
END;
GO
--Ejemplo
UPDATE STOCK
SET stoc_cantidad = 150
WHERE stoc_producto = '90000001'
  AND stoc_deposito = '01';

/* 19. Cree el/los objetos de base de datos necesarios para que se cumpla la siguiente 
regla de negocio automáticamente “Ningún jefe puede tener menos de 5 años de 
antigüedad y tampoco puede tener más del 50% del personal a su cargo 
(contando directos e indirectos) a excepción del gerente general”. Se sabe que en 
la actualidad la regla se cumple y existe un único gerente general. */
CREATE OR ALTER FUNCTION dbo.cantidad_empleados
(
    @cod_empleado NUMERIC(6)
)
RETURNS INT
AS
BEGIN
    DECLARE @cantidad INT;

    SET @cantidad = 0;

    SELECT @cantidad = @cantidad
        + 1
        + dbo.cantidad_empleados(e.empl_codigo)
    FROM Empleado e
    WHERE e.empl_jefe = @cod_empleado;

    RETURN @cantidad;
END;
GO

CREATE OR ALTER TRIGGER TR_VALIDAR_JEFES
ON Empleado
AFTER INSERT, UPDATE, DELETE
AS
BEGIN

    IF EXISTS (
        SELECT 1
        FROM Empleado e
        WHERE e.empl_jefe IS NOT NULL

        -- Verificamos que sea jefe.
        AND EXISTS (
            SELECT 1
            FROM Empleado sub
            WHERE sub.empl_jefe = e.empl_codigo
        )

        AND (
            -- Regla 1: no puede tener menos de 5 años.
            DATEADD(YEAR, 5, e.empl_ingreso) > GETDATE()

            OR

            -- Regla 2: no puede tener más del 50%
            -- del personal a su cargo.
            dbo.cantidad_empleados(e.empl_codigo) >
                (SELECT COUNT(*) * 0.50 FROM Empleado)
        )
    )
    BEGIN
        ROLLBACK TRANSACTION;

        RAISERROR(
            'El jefe no cumple con las condiciones de antiguedad o cantidad de personal a cargo.',
            16, 1
        );

        RETURN;
    END;

END;
GO

/* 31. Desarrolle el o los objetos de base de datos necesarios, para que un jefe no pueda 
tener más de 20 empleados a cargo, directa o indirectamente, si esto ocurre 
debera asignarsele un jefe que cumpla esa condición, si no existe un jefe para 
asignarle se le deberá colocar como jefe al gerente general que es aquel que no 
tiene jefe. */
CREATE OR ALTER FUNCTION dbo.cantidad_empleados
(
    @cod_empleado NUMERIC(6)
)
RETURNS INT
AS
BEGIN
    DECLARE @cantidad INT;

    SELECT @cantidad = ISNULL(
        SUM(1 + dbo.cantidad_empleados(e.empl_codigo)),
        0
    )
    FROM Empleado e
    WHERE e.empl_jefe = @cod_empleado;

    RETURN @cantidad;
END;
GO

CREATE OR ALTER FUNCTION dbo.es_descendiente
(
    @cod_empleado NUMERIC(6),
    @posible_jefe NUMERIC(6)
)
RETURNS BIT
AS
BEGIN
    DECLARE @resultado BIT;
    SET @resultado = 0;

    IF EXISTS (
        SELECT 1
        FROM Empleado e
        WHERE e.empl_jefe = @cod_empleado
          AND (
                e.empl_codigo = @posible_jefe
                OR dbo.es_descendiente(e.empl_codigo, @posible_jefe) = 1
          )
    )
        SET @resultado = 1;

    RETURN @resultado;
END;
GO

CREATE OR ALTER TRIGGER TR_REASIGNAR_JEFE
ON Empleado
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @empleado NUMERIC(6);
    DECLARE @jefe_actual NUMERIC(6);
    DECLARE @nuevo_jefe NUMERIC(6);

    DECLARE cur_empleados CURSOR FOR
        SELECT empl_codigo, empl_jefe
        FROM inserted;

    OPEN cur_empleados;

    FETCH NEXT FROM cur_empleados
    INTO @empleado, @jefe_actual;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Si tiene jefe y ese jefe supera los 20 empleados a cargo
        IF @jefe_actual IS NOT NULL
           AND dbo.cantidad_empleados(@jefe_actual) > 20
        BEGIN
            SET @nuevo_jefe = NULL;

            -- Buscamos otro jefe que pueda recibir al empleado
            SELECT TOP 1 @nuevo_jefe = e.empl_codigo
            FROM Empleado e
            WHERE e.empl_codigo <> @empleado
              AND EXISTS (
                    SELECT 1
                    FROM Empleado sub
                    WHERE sub.empl_jefe = e.empl_codigo
              )
              AND dbo.cantidad_empleados(e.empl_codigo)
                    + 1
                    + dbo.cantidad_empleados(@empleado) <= 20
              AND dbo.es_descendiente(@empleado, e.empl_codigo) = 0
            ORDER BY dbo.cantidad_empleados(e.empl_codigo);

            -- Si no encontramos otro jefe, asignamos al gerente general
            IF @nuevo_jefe IS NULL
            BEGIN
                SELECT @nuevo_jefe = empl_codigo
                FROM Empleado
                WHERE empl_jefe IS NULL;
            END;

            -- Reasignamos al empleado
            UPDATE Empleado
            SET empl_jefe = @nuevo_jefe
            WHERE empl_codigo = @empleado;
        END;

        FETCH NEXT FROM cur_empleados
        INTO @empleado, @jefe_actual;
    END;

    CLOSE cur_empleados;
    DEALLOCATE cur_empleados;
END;
GO

/* 28. Se requiere reasignar los vendedores a los clientes. Para ello se solicita que 
realice el o los objetos de base de datos necesarios para asignar a cada uno de los 
clientes el vendedor que le corresponda, entendiendo que el vendedor que le 
corresponde es aquel que le vendió más facturas a ese cliente, si en particular un 
cliente no tiene facturas compradas se le deberá asignar el vendedor con más 
venta de la empresa, o sea, el que en monto haya vendido más. */
CREATE OR ALTER PROCEDURE REASIGNAR_VENDEDORES
AS
BEGIN
    DECLARE @vendedor_general NUMERIC(6);

    -- Buscamos al vendedor que más vendió en monto
    SELECT TOP 1
        @vendedor_general = fact_vendedor
    FROM Factura
    WHERE fact_vendedor IS NOT NULL
    GROUP BY fact_vendedor
    ORDER BY SUM(fact_total) DESC, fact_vendedor;

    -- Reasignamos todos los clientes
    UPDATE Cliente
    SET clie_vendedor =
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM Factura f
                WHERE f.fact_cliente = Cliente.clie_codigo
            )
            THEN (
                SELECT TOP 1 f.fact_vendedor
                FROM Factura f
                WHERE f.fact_cliente = Cliente.clie_codigo
                  AND f.fact_vendedor IS NOT NULL
                GROUP BY f.fact_vendedor
                ORDER BY COUNT(*) DESC, f.fact_vendedor
            )
            ELSE @vendedor_general
        END;
END;
GO

/* 29. Desarrolle el/los elementos de base de datos necesarios para que se cumpla 
automaticamente la regla de que una factura no puede contener productos que 
sean componentes de diferentes productos.  En caso de que esto ocurra no debe 
grabarse esa factura y debe emitirse un error en pantalla. */
CREATE OR ALTER TRIGGER TR_VALIDAR_COMPONENTES_FACTURA
ON Item_Factura
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Item_Factura i1
        JOIN Item_Factura i2
            ON i1.item_tipo = i2.item_tipo
           AND i1.item_sucursal = i2.item_sucursal
           AND i1.item_numero = i2.item_numero
           AND i1.item_producto <> i2.item_producto
        JOIN Composicion c1
            ON c1.comp_componente = i1.item_producto
        JOIN Composicion c2
            ON c2.comp_componente = i2.item_producto
        JOIN inserted ins
            ON ins.item_tipo = i1.item_tipo
           AND ins.item_sucursal = i1.item_sucursal
           AND ins.item_numero = i1.item_numero
        WHERE c1.comp_producto <> c2.comp_producto
    )
    BEGIN
        ROLLBACK TRANSACTION;

        RAISERROR(
            'La factura no puede contener componentes de diferentes productos.',
            16, 1
        );

        RETURN;
    END;
END;
GO

------------------ VISTAS -------------------
CREATE VIEW nombre_vista
AS
    SELECT columnas
    FROM tabla
    WHERE condicion;
-----------------------------------
CREATE OR ALTER VIEW dbo.vista_clientes
AS
    SELECT
        clie_codigo,
        clie_razon_social,
        clie_cuit
    FROM Cliente;
-----------------------------------
SELECT *
FROM dbo.vista_clientes
WHERE clie_codigo = 'C00001';
-----------------------------------
CREATE OR ALTER VIEW dbo.productos_caros
AS
    SELECT 
        p.prod_codigo, 
        p.prod_detalle,
        p.prod_precio
    FROM Producto P
    WHERE p.prod_precio > 10000;
-----------------------------------
/* Creá una vista llamada vista_facturas_clientes que muestre:
- Tipo, sucursal y número de factura.
- Fecha de factura.
- Código del cliente.
- Razón social del cliente.
- Total de la factura.*/
CREATE OR ALTER VIEW vista_facturas_clientes
AS
    SELECT  
        f.fact_tipo + f.fact_sucursal + f.fact_numero AS COD_FACT,
        f.fact_fecha AS Fecha_Fact,
        f.fact_cliente AS Cod_Clie,
        c.clie_razon_social AS Razon_Soc_Clie,
        f.fact_total AS Total_Fact
    FROM Factura f
    JOIN Cliente c ON f.fact_cliente = c.clie_codigo
------------ STORED PROCEDURES ------------
/* 3. Cree el/los objetos de base de datos necesarios para corregir la tabla empleado 
en caso que sea necesario. Se sabe que debería existir un único gerente general 
(debería ser el único empleado sin jefe). Si detecta que hay más de un empleado 
sin jefe deberá elegir entre ellos el gerente general, el cual será seleccionado por 
mayor salario. Si hay más de uno se seleccionara el de mayor antigüedad en la 
empresa.  Al finalizar la ejecución del objeto la tabla deberá cumplir con la regla 
de un único empleado sin jefe (el gerente general) y deberá retornar la cantidad 
de empleados que había sin jefe antes de la ejecución. */
CREATE OR ALTER PROCEDURE corregir_gerente_general
AS
BEGIN
    DECLARE @cantidad_inicial INT;
    DECLARE @gerente_general NUMERIC(6);

    SELECT @cantidad_inicial = COUNT(e.empl_codigo)
    FROM Empleado e
    WHERE e.empl_jefe IS NULL;
    
    IF @cantidad_inicial > 1 
        BEGIN
            SELECT TOP 1
                @gerente_general = e.empl_codigo
            FROM Empleado e
            WHERE e.empl_jefe IS NULL
            ORDER BY e.empl_salario DESC, e.empl_ingreso ASC;
        END
    ELSE 
        BEGIN
            SET @gerente_general = (SELECT e.empl_codigo
                                    FROM Empleado e
                                    WHERE e.empl_jefe IS NULL)
        END
    
    UPDATE Empleado
    SET empl_jefe = @gerente_general
    WHERE empl_jefe IS NULL AND empl_codigo != @gerente_general;

    RETURN @cantidad_inicial;
END;
-- v2 (la mejor)
CREATE OR ALTER PROCEDURE corregir_gerente_generalV2
AS
BEGIN
    DECLARE @cantidad_inicial INT
    DECLARE @gerente_general NUMERIC(6)

    SELECT @cantidad_inicial = COUNT(*)
    FROM Empleado
    WHERE empl_jefe IS NULL

    -- mayor salario; si empatan, el más antiguo (menor fecha de ingreso)
    SELECT TOP 1 @gerente_general = empl_codigo
    FROM Empleado
    WHERE empl_jefe IS NULL
    ORDER BY empl_salario DESC, empl_ingreso ASC

    -- los demás pasan a depender del gerente general
    UPDATE Empleado
    SET empl_jefe = @gerente_general
    WHERE empl_jefe IS NULL
      AND empl_codigo <> @gerente_general

    RETURN @cantidad_inicial
END
GO
------------------------------------------------
/* 4. Cree el/los objetos de base de datos necesarios para actualizar la columna de 
empleado empl_comision con la sumatoria del total de lo vendido por ese 
empleado a lo largo del último año. Se deberá retornar el código del vendedor 
que más vendió (en monto) a lo largo del último año. */
CREATE OR ALTER PROCEDURE sp_actualizar_comisiones
AS
BEGIN
    -- supuesto: "último año" = el último año con facturas en la base
    DECLARE @anio INT = (SELECT MAX(YEAR(fact_fecha)) FROM Factura)
    DECLARE @mejor NUMERIC(6)

    UPDATE e
    SET e.empl_comision = ISNULL((SELECT SUM(f.fact_total)
                                  FROM Factura f
                                  WHERE f.fact_vendedor = e.empl_codigo
                                    AND YEAR(f.fact_fecha) = @anio), 0)
    FROM Empleado e

    -- el que más vendió = mayor comisión (desempate por código)
    SELECT TOP 1 @mejor = f.fact_vendedor
    FROM Factura f
    WHERE YEAR(f.fact_fecha) = @anio
    GROUP BY f.fact_vendedor
    ORDER BY SUM(f.fact_total) DESC, f.fact_vendedor

    RETURN @mejor
END
GO

-- uso
DECLARE @mejor INT
EXEC @mejor = sp_actualizar_comisiones
SELECT @mejor AS Vendedor_Que_Mas_Vendio


------ PARCIALES
/* =====================================================================
   PARCIALES T-SQL RESUELTOS (para estudiar: tapá la solución y reescribila)
   Orden: 1) CUIT 12/07/2025  2) Vista 28/06/2025  3) Recuperatorio  4) 06/07/2022
   Los de 2026 (01/07 compras con stock, 08/07 UNIQUE prod_detalle) y la FK
   Cliente-Provincia (28/07/2023) están en plantillas.sql.
   ===================================================================== */


/* =====================================================================
   1) PARCIAL 12/07/2025 - CUIT DUPLICADO
   Se agregó clie_cuit a Cliente y hay clientes con el mismo CUIT.
   Depurar dejando un único registro por CUIT + impedir duplicados a futuro.
   Supuestos: columna clie_cuit CHAR(13) NULL (los NULL no cuentan como duplicados).
              Criterio: se conserva el cliente de MENOR código.
   ===================================================================== */
-- ALTER TABLE Cliente ADD clie_cuit CHAR(13) NULL   -- (si la consigna no lo agrega ya)
-- GO

CREATE OR ALTER PROCEDURE SP_DEPURAR_CLIENTES_CUIT
AS
BEGIN
    BEGIN TRANSACTION   -- dos pasos que dependen entre sí: o se hacen los dos o ninguno

        -- 1) las facturas de los duplicados pasan al cliente que se conserva
        UPDATE f
        SET f.fact_cliente = (SELECT MIN(c2.clie_codigo)
                              FROM Cliente c2
                              WHERE c2.clie_cuit = c.clie_cuit)
        FROM Factura f
        JOIN Cliente c ON c.clie_codigo = f.fact_cliente
        WHERE c.clie_cuit IS NOT NULL
          AND c.clie_codigo <> (SELECT MIN(c3.clie_codigo)
                                FROM Cliente c3
                                WHERE c3.clie_cuit = c.clie_cuit)

        -- 2) borro los duplicados (ya no tienen facturas)
        DELETE c
        FROM Cliente c
        WHERE c.clie_cuit IS NOT NULL
          AND c.clie_codigo <> (SELECT MIN(c2.clie_codigo)
                                FROM Cliente c2
                                WHERE c2.clie_cuit = c.clie_cuit)

    COMMIT TRANSACTION
END
GO
-- EXEC SP_DEPURAR_CLIENTES_CUIT
-- Si Cliente tuviera otras tablas hijas (ej: otra FK a clie_codigo), habría que reasignarlas igual que Factura.

CREATE OR ALTER TRIGGER TR_CLIENTE_CUIT_UNICO ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM Cliente c
               JOIN inserted i ON c.clie_cuit = i.clie_cuit        -- clie_cuit (NULL = NULL no une: bien)
                              AND c.clie_codigo <> i.clie_codigo)
    BEGIN
        RAISERROR('No se puede repetir el CUIT del cliente.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO


/* =====================================================================
   2) PARCIAL 28/06/2025 - VISTA v_item_factura SIN item_precio EN LA TABLA
   Eliminar item_precio (e item_total, si existiera) de Item_Factura, sin agregar
   campos a Item_Factura, y que la vista siga mostrando todo (datos actuales y futuros).
   Nota: en el modelo de la cátedra Item_Factura NO tiene item_total, solo item_precio.
   Solución: tabla auxiliar con el precio + migración + vista + trigger.
   ORDEN IMPORTANTE: migrar los precios ANTES de borrar la columna.
   ===================================================================== */
CREATE TABLE Item_Factura_Precio (
    item_tipo       CHAR(1),
    item_sucursal   CHAR(4),
    item_numero     CHAR(8),
    item_producto   CHAR(8),
    precio_unitario DECIMAL(12,2),
    PRIMARY KEY (item_tipo, item_sucursal, item_numero, item_producto)
)
GO

-- a) migro los precios históricos
INSERT INTO Item_Factura_Precio (item_tipo, item_sucursal, item_numero, item_producto, precio_unitario)
SELECT item_tipo, item_sucursal, item_numero, item_producto, item_precio
FROM Item_Factura
GO

-- b) recién ahora elimino la columna
ALTER TABLE Item_Factura DROP COLUMN item_precio
GO

-- c) la vista (el total del ítem se calcula, no se guarda)
CREATE VIEW v_item_factura
AS
SELECT
    i.item_tipo,
    i.item_sucursal,
    i.item_numero,
    p.prod_detalle AS nombre_producto,
    ip.precio_unitario,
    i.item_cantidad,
    i.item_cantidad * ip.precio_unitario AS total_item
FROM Item_Factura i
JOIN Producto p ON p.prod_codigo = i.item_producto
JOIN Item_Factura_Precio ip ON ip.item_tipo = i.item_tipo
                           AND ip.item_sucursal = i.item_sucursal
                           AND ip.item_numero = i.item_numero
                           AND ip.item_producto = i.item_producto
GO

-- d) datos futuros: al insertar un ítem, guardo el precio vigente del producto
--    (supuesto: el precio facturado es prod_precio al momento de la venta)
CREATE TRIGGER TR_ITEM_FACTURA_PRECIO_INS ON Item_Factura
AFTER INSERT
AS
BEGIN
    INSERT INTO Item_Factura_Precio (item_tipo, item_sucursal, item_numero, item_producto, precio_unitario)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero, i.item_producto, p.prod_precio
    FROM inserted i
    JOIN Producto p ON p.prod_codigo = i.item_producto
END
GO

-- e) si se borra un ítem, borro su precio (si no, quedaría huérfano y chocaría con un reinsert)
CREATE TRIGGER TR_ITEM_FACTURA_PRECIO_DEL ON Item_Factura
AFTER DELETE
AS
BEGIN
    DELETE ip
    FROM Item_Factura_Precio ip
    JOIN deleted d ON d.item_tipo = ip.item_tipo
                  AND d.item_sucursal = ip.item_sucursal
                  AND d.item_numero = ip.item_numero
                  AND d.item_producto = ip.item_producto
END
GO
-- Por qué NO usar solo prod_precio en la vista: si el precio del producto cambia,
-- cambiarían también las facturas viejas. La tabla auxiliar congela el precio facturado.
-- Ojo: cualquier objeto que use item_precio (ej: triggers de INSTEAD OF anteriores) deja de compilar.


/* =====================================================================
   3) RECUPERATORIO - VENTA DE COMPUESTOS: GUARDAR SOLO PRIMER NIVEL
   Cada vez que se vende un compuesto, registrar sus componentes de primer nivel.
   Supuesto: en lugar del compuesto se guardan sus componentes (producto, cantidad * comp_cantidad).
   (Lectura alternativa: guardar el compuesto Y sus componentes; sería sacar el filtro NOT IN del primer INSERT.)
   ===================================================================== */
CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_PRIMER_NIVEL ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN
    -- productos simples: se insertan tal cual
    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero, i.item_producto, i.item_cantidad, i.item_precio
    FROM inserted i
    WHERE i.item_producto NOT IN (SELECT comp_producto FROM Composicion)

    -- compuestos: se insertan sus componentes de primer nivel
    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero,
           c.comp_componente,
           i.item_cantidad * c.comp_cantidad,
           p.prod_precio
    FROM inserted i
    JOIN Composicion c ON c.comp_producto = i.item_producto
    JOIN Producto p ON p.prod_codigo = c.comp_componente
END
GO
-- Cuidado: si el mismo componente ya está en la misma factura (o sale de dos compuestos),
-- chocaría con la PK (tipo, sucursal, numero, producto). Para ese borde habría que agrupar con SUM.


/* =====================================================================
   4) PARCIAL 06/07/2022 - PRECIO DEL COMPUESTO = SUMA(precio componente * cantidad)
   "Nunca el precio de un producto compuesto puede ser distinto..."
   Hay que cubrir TODOS los puntos que pueden romper la regla:
     - cambia la composición (Composicion: insert / update / delete)
     - cambia el precio de un producto (que puede ser componente de otro)
     - se inserta un producto
   La base tiene anidamiento (ej: 00006402 se compone de 6404 y 6411, que son compuestos),
   así que recalculo en un LOOP hasta que no quede nada por corregir (supone que no hay ciclos).
   ===================================================================== */
CREATE OR ALTER PROCEDURE SP_RECALCULAR_PRECIOS_COMPUESTOS
AS
BEGIN
    DECLARE @n INT = 1
    WHILE @n > 0
    BEGIN
        UPDATE p
        SET p.prod_precio = x.precio
        FROM Producto p
        JOIN (SELECT c.comp_producto AS prod,
                     SUM(pc.prod_precio * c.comp_cantidad) AS precio
              FROM Composicion c
              JOIN Producto pc ON pc.prod_codigo = c.comp_componente
              GROUP BY c.comp_producto) x ON x.prod = p.prod_codigo
        WHERE p.prod_precio <> x.precio

        SET @n = @@ROWCOUNT        -- tiene que ir justo después del UPDATE
    END
END
GO

-- 1) datos existentes mal calculados
EXEC SP_RECALCULAR_PRECIOS_COMPUESTOS
GO

-- 2) cambia la composición
CREATE OR ALTER TRIGGER TR_COMPOSICION_PRECIO ON Composicion
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    EXEC SP_RECALCULAR_PRECIOS_COMPUESTOS
END
GO

-- 3) cambia/inserta el precio de un producto
CREATE OR ALTER TRIGGER TR_PRODUCTO_PRECIO ON Producto
AFTER INSERT, UPDATE
AS
BEGIN
    EXEC SP_RECALCULAR_PRECIOS_COMPUESTOS
END
GO
-- El UPDATE de Producto dentro del procedure no re-dispara este mismo trigger
-- (RECURSIVE_TRIGGERS viene en OFF por defecto), y el loop resuelve los niveles.
-- Versión simple (si el profe no pide multinivel): un solo UPDATE sin WHILE.

/* Parcial 2C2017 
Agregar el/los objetos necesarios para que se permita mantener la siguiente restricción:
Nunca un jefe va a poder tener más de 20 personas a cargo y menos de 1
Nota: considerar solo 1 nivel de la relación empleado-jefe */
CREATE OR ALTER FUNCTION dbo.cant_personas_a_cargo (@cod_jefe NUMERIC(6))
RETURNS INT
AS
BEGIN
    RETURN (SELECT COUNT(*)
            FROM Empleado
            WHERE empl_jefe = @cod_jefe)
END
GO
-- V1
CREATE TRIGGER tr_empleados ON Empleado
AFTER INSERT, UPDATE, DELETE
AS
    BEGIN TRANSACTION
        IF((SELECT COUNT(*) FROM inserted i) > 0) --Significa que es un INSERT / UPDATE
            BEGIN
                IF(EXISTS(SELECT 1 FROM inserted WHERE dbo.cant_personas_a_cargo(empl_jefe) < 1))
                    BEGIN
                        RAISERROR('Un jefe no puede tener menos de una persona a cargo.', 16, 1)
                        ROLLBACK
                        RETURN
                    END

                IF(EXISTS(SELECT 1 FROM inserted WHERE dbo.cant_personas_a_cargo(empl_jefe) > 20))
                    BEGIN
                        RAISERROR('Un jefe no puede tener más de 20 personas a cargo.', 16, 1)
                        ROLLBACK
                        RETURN
                    END
            END
        ELSE --Es un DELETE
            BEGIN
                IF(EXISTS(SELECT 1 FROM deleted WHERE dbo.cant_personas_a_cargo(empl_jefe) < 1))
                    BEGIN
                        RAISERROR('Un jefe no puede tener menos de una persona a cargo.', 16, 1)
                        ROLLBACK
                        RETURN
                    END
            END
        COMMIT TRANSACTION
--V2
CREATE OR ALTER TRIGGER tr_empleados ON Empleado
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- máximo: los jefes de las filas nuevas o modificadas
    IF EXISTS (SELECT 1
               FROM inserted
               WHERE empl_jefe IS NOT NULL
                 AND dbo.cant_personas_a_cargo(empl_jefe) > 20)
    BEGIN
        RAISERROR('Un jefe no puede tener más de 20 personas a cargo.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END

    -- mínimo: los jefes de las filas borradas o que cambiaron de jefe
    IF EXISTS (SELECT 1
               FROM deleted
               WHERE empl_jefe IS NOT NULL
                 AND dbo.cant_personas_a_cargo(empl_jefe) < 1)
    BEGIN
        RAISERROR('Un jefe no puede quedar con menos de una persona a cargo.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO

/* Parcial 2C2017
2. Es atributo clie_limite_credito, representa el monto máximo que puede venderse a un cliente
en el mes en curso. Implementar el/los objetos necesarios para que no se permita realizar 
una venta si el monto total facturado en el mes supera el atributo clie_limite_credito. 

Considerar que esta restricción debe cumplirse siempre y validar también que no se pueda hacer 
una factura de un mes anterior. */
CREATE OR ALTER FUNCTION dbo.total_vendido_mes (@cliente CHAR(6))
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN ISNULL((SELECT SUM(fact_total)
                   FROM Factura
                   WHERE fact_cliente = @cliente
                     AND YEAR(fact_fecha)  = YEAR(GETDATE())
                     AND MONTH(fact_fecha) = MONTH(GETDATE())), 0)
END
GO

-- Lado Factura: al insertar, el mes tiene que ser el actual y no se puede pasar del límite.
-- Como es AFTER, la función ya ve las facturas nuevas: se compara contra el límite directamente.
CREATE OR ALTER TRIGGER tr_limite_credito_factura ON Factura
AFTER INSERT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted
               WHERE YEAR(fact_fecha)  <> YEAR(GETDATE())
                  OR MONTH(fact_fecha) <> MONTH(GETDATE()))
    BEGIN
        RAISERROR('No se puede facturar un mes distinto del actual.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN Cliente c ON c.clie_codigo = i.fact_cliente
               WHERE dbo.total_vendido_mes(i.fact_cliente) > c.clie_limite_credito)
    BEGIN
        RAISERROR('La venta supera el límite de crédito del cliente.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

-- Lado Cliente: no se puede bajar el límite por debajo de lo ya facturado en el mes
CREATE OR ALTER TRIGGER tr_limite_credito_cliente ON Cliente
AFTER UPDATE
AS
BEGIN
    IF UPDATE(clie_limite_credito)
       AND EXISTS (SELECT 1 FROM inserted i
                   WHERE dbo.total_vendido_mes(i.clie_codigo) > i.clie_limite_credito)
    BEGIN
        RAISERROR('El nuevo límite es menor a lo facturado en el mes.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

/* GUIA TSQL - 7. Hacer un procedimiento que dadas dos fechas complete la tabla Ventas. Debe 
insertar una línea por cada artículo con los movimientos de stock generados por 
las ventas entre esas fechas. La tabla se encuentra creada y vacía. 
Código : Código del articulo 
Detalle : Detalle del articulo 
Cant. Mov. : Cantidad de movimientos de ventas (Item factura) 
Precio de Venta : Precio promedio de venta 
Renglón : Nro. de línea de la tabla 
Ganancia : Precio de Venta – Cantidad * Costo Actual */
-- Supuestos:
--  * "Cant. Mov." = cantidad de renglones de Item_Factura (COUNT)
--  * "Costo actual" = prod_precio (el modelo no tiene costo)
--  * Ganancia = monto vendido - unidades vendidas * costo actual
--  * El rango de fechas es inclusivo en ambos extremos
CREATE TABLE Ventas
(   codigo char(8), 
    detalle char(50), 
    cant_mov int, 
    precio_venta decimal(12,2), 
    renglon int, 
    ganancia decimal(12,2)
)

CREATE OR ALTER PROCEDURE sp_completar_ventas
    @desde SMALLDATETIME,
    @hasta SMALLDATETIME
AS
BEGIN
    INSERT INTO Ventas (codigo, detalle, cant_mov, precio_venta, renglon, ganancia)
    SELECT
        p.prod_codigo,
        p.prod_detalle,
        COUNT(DISTINCT i.item_tipo + i.item_sucursal + i.item_numero),
        AVG(i.item_precio),
        ROW_NUMBER() OVER (ORDER BY p.prod_codigo),
        AVG(i.item_precio) - SUM(i.item_cantidad) * p.prod_precio
    FROM Producto p
    JOIN Item_Factura i ON i.item_producto = p.prod_codigo
    JOIN Factura f ON f.fact_tipo = i.item_tipo
                  AND f.fact_sucursal = i.item_sucursal
                  AND f.fact_numero = i.item_numero
    WHERE f.fact_fecha >= @desde
      AND f.fact_fecha <  DATEADD(DAY, 1, @hasta)
    GROUP BY p.prod_codigo, p.prod_detalle, p.prod_precio
END
GO

-- EXEC sp_completar_ventas '20120101', '20121231'

/* Encontré otro parcial del 15/11/2022:
1. Implementar una regla de negocio en línea que al realizar una venta 
(SOLO INSERCION) permita componer los productos descompuestos, es decir, 
si se guardan en la factura 2 hamb. 2 papas 2 gaseosas se deberá guardar 
en la factura 2 (DOS) COMBO1. Si 1 combo1 equivale a: 1 hamb. 1 papa y 1 gaseosa. 
Nota: Considerar que cada vez que se guardan los items, se mandan todos los 
productos de ese item a la vez, y no de manera parcial.*/
CREATE OR ALTER TRIGGER TR_ITEM_COMBO ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @tipo CHAR(1);
    DECLARE @sucursal CHAR(4);
    DECLARE @numero CHAR(8);

    DECLARE @producto CHAR(8);
    DECLARE @cantidad_combos DECIMAL(12,2);
    DECLARE @total_componentes INT;
    DECLARE @componentes_presentes INT;

    -- 1. Crear tabla temporal con los productos recibidos
    CREATE TABLE #Pendientes (
        tipo CHAR(1),
        sucursal CHAR(4),
        numero CHAR(8),
        producto CHAR(8),
        cantidad DECIMAL(12,2),
        precio DECIMAL(12,2)
    );

    -- 2. Crear tabla temporal para los productos compuestos
    CREATE TABLE #Compuestos (
        tipo CHAR(1),
        sucursal CHAR(4),
        numero CHAR(8),
        producto CHAR(8),
        cantidad DECIMAL(12,2),
        precio DECIMAL(12,2)
    );

    INSERT INTO #Pendientes
    SELECT
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        SUM(item_cantidad),
        MAX(item_precio)
    FROM inserted
    GROUP BY
        item_tipo, item_sucursal, item_numero, item_producto;

    -- 3. Recorrer los productos compuestos que aparecen
    --    en Composicion y cuyos componentes fueron recibidos
    DECLARE cursor_combos CURSOR FOR
        SELECT DISTINCT
            p.tipo, p.sucursal, p.numero, c.comp_producto
        FROM #Pendientes p
        JOIN Composicion c
            ON c.comp_componente = p.producto
        ORDER BY
            p.tipo, p.sucursal, p.numero, c.comp_producto;

    OPEN cursor_combos;

    FETCH NEXT FROM cursor_combos
    INTO @tipo, @sucursal, @numero, @producto;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- 4. Contar componentes necesarios
        SELECT @total_componentes = COUNT(*)
        FROM Composicion
        WHERE comp_producto = @producto;

        -- 5. Contar componentes disponibles
        SELECT @componentes_presentes = COUNT(*)
        FROM Composicion c
        JOIN #Pendientes p
            ON p.producto = c.comp_componente
        WHERE c.comp_producto = @producto
          AND p.tipo = @tipo
          AND p.sucursal = @sucursal
          AND p.numero = @numero
          AND p.cantidad > 0;

        SET @cantidad_combos = 0;

        -- 6. Verificar que estén todos los componentes
        IF @total_componentes = @componentes_presentes
        BEGIN
            -- Calcular cuántos productos compuestos se pueden formar
            SELECT @cantidad_combos =
                MIN(FLOOR(p.cantidad / c.comp_cantidad))
            FROM Composicion c
            JOIN #Pendientes p
                ON p.producto = c.comp_componente
            WHERE c.comp_producto = @producto
              AND p.tipo = @tipo
              AND p.sucursal = @sucursal
              AND p.numero = @numero;

            -- 7. Si se puede formar al menos uno
            IF @cantidad_combos > 0
            BEGIN
                -- Guardar el producto compuesto
                INSERT INTO #Compuestos
                SELECT
                    @tipo,
                    @sucursal,
                    @numero,
                    @producto,
                    @cantidad_combos,
                    prod_precio
                FROM Producto
                WHERE prod_codigo = @producto;

                -- Descontar las cantidades utilizadas
                UPDATE p
                SET p.cantidad =
                    p.cantidad -
                    (@cantidad_combos * c.comp_cantidad)
                FROM #Pendientes p
                JOIN Composicion c
                    ON c.comp_componente = p.producto
                WHERE c.comp_producto = @producto
                  AND p.tipo = @tipo
                  AND p.sucursal = @sucursal
                  AND p.numero = @numero;
            END;
        END;

        FETCH NEXT FROM cursor_combos
        INTO @tipo, @sucursal, @numero, @producto;
    END;

    CLOSE cursor_combos;
    DEALLOCATE cursor_combos;

    -- 8. Insertar los productos compuestos
    INSERT INTO Item_Factura (
        item_tipo, item_sucursal, item_numero,
        item_producto, item_cantidad, item_precio
    )
    SELECT
        tipo, sucursal, numero,
        producto, cantidad, precio
    FROM #Compuestos;

    -- 9. Insertar los productos originales sobrantes
    INSERT INTO Item_Factura (
        item_tipo, item_sucursal, item_numero,
        item_producto, item_cantidad, item_precio
    )
    SELECT
        tipo, sucursal, numero,
        producto, cantidad, precio
    FROM #Pendientes
    WHERE cantidad > 0;

    -- 10. Eliminar las tablas temporales
    DROP TABLE #Compuestos;
    DROP TABLE #Pendientes;
END;


/* 2. Implementar una regla de negocio de validación en línea que permita
validar el STOCK al realizarse una venta. Cada venta se debe
descontar sobre el depósito 00. En caso de que se venda un producto
compuesto, el descuento de stock se debe realizar por sus
componentes. Si no hay STOCK para ese artículo, no se deberá
guardar ese articulo, pero si los otros en los cuales hay stock positivo.
Es decir, solamente se deberán guardar aquellos para los cuales si hay
stock, sin guardarse los que no poseen cantidades suficientes. */

CREATE OR ALTER TRIGGER TR_VALIDAR_STOCK
ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @tipo CHAR(1);
    DECLARE @sucursal CHAR(4);
    DECLARE @numero CHAR(8);
    DECLARE @producto CHAR(8);
    DECLARE @cantidad DECIMAL(12,2);
    DECLARE @precio DECIMAL(12,2);

    -- 1. Recorrer los artículos que se quieren vender
    DECLARE cursor_ventas CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            item_tipo,
            item_sucursal,
            item_numero,
            item_producto,
            item_cantidad,
            item_precio
        FROM inserted;

    OPEN cursor_ventas;

    FETCH NEXT FROM cursor_ventas
    INTO @tipo, @sucursal, @numero,
         @producto, @cantidad, @precio;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        -- 2. Verificar si el producto es compuesto
        IF EXISTS (
            SELECT 1
            FROM Composicion
            WHERE comp_producto = @producto
        )
        BEGIN

            -- 3. Verificar que haya stock suficiente
            --    de TODOS sus componentes en el depósito 00
            IF NOT EXISTS (
                SELECT 1
                FROM Composicion c
                LEFT JOIN STOCK s
                    ON s.stoc_producto = c.comp_componente
                   AND s.stoc_deposito = '00'
                WHERE c.comp_producto = @producto
                  AND (
                        s.stoc_producto IS NULL
                        OR s.stoc_cantidad < @cantidad * c.comp_cantidad
                  )
            )
            BEGIN

                -- 4. Insertar el producto compuesto vendido
                INSERT INTO Item_Factura
                VALUES (
                    @tipo, @sucursal, @numero,
                    @producto, @cantidad, @precio
                );

                -- 5. Descontar el stock de sus componentes
                UPDATE s
                SET s.stoc_cantidad =
                    s.stoc_cantidad - (@cantidad * c.comp_cantidad)
                FROM STOCK s
                JOIN Composicion c
                    ON c.comp_componente = s.stoc_producto
                WHERE c.comp_producto = @producto
                  AND s.stoc_deposito = '00';

            END;
        END

        ELSE
        BEGIN

            -- 6. Si es un producto simple, verificar su stock
            IF EXISTS (
                SELECT 1
                FROM STOCK
                WHERE stoc_producto = @producto
                  AND stoc_deposito = '00'
                  AND stoc_cantidad >= @cantidad
            )
            BEGIN

                -- 7. Insertar el producto vendido
                INSERT INTO Item_Factura
                VALUES (
                    @tipo, @sucursal, @numero,
                    @producto, @cantidad, @precio
                );

                -- 8. Descontar su stock
                UPDATE STOCK
                SET stoc_cantidad = stoc_cantidad - @cantidad
                WHERE stoc_producto = @producto
                  AND stoc_deposito = '00';

            END;
        END;

        FETCH NEXT FROM cursor_ventas
        INTO @tipo, @sucursal, @numero,
             @producto, @cantidad, @precio;

    END;

    CLOSE cursor_ventas;
    DEALLOCATE cursor_ventas;
END;

/* 6. Realizar un procedimiento que si en alguna factura se facturaron componentes 
que conforman un combo determinado (o sea que juntos componen otro 
producto de mayor nivel), en cuyo caso deberá reemplazar las filas 
correspondientes a dichos productos por una sola fila con el producto que 
componen con la cantidad de dicho producto que corresponda. */
CREATE PROCEDURE SP_REEMPLAZAR_POR_COMBO
    @tipo CHAR(1),
    @sucursal CHAR(4),
    @numero CHAR(8),
    @combo CHAR(8)
AS
BEGIN
    DECLARE @cantidad_combo DECIMAL(12,2);
    DECLARE @precio DECIMAL(12,2);

    -- Verificamos que todos los componentes tengan stock facturado suficiente
    IF NOT EXISTS (
        SELECT 1
        FROM Composicion c
        WHERE c.comp_producto = @combo
          AND NOT EXISTS (
              SELECT 1
              FROM Item_Factura i
              WHERE i.item_tipo = @tipo
                AND i.item_sucursal = @sucursal
                AND i.item_numero = @numero
                AND i.item_producto = c.comp_componente
                AND i.item_cantidad >= c.comp_cantidad
          )
    )
    BEGIN
        -- Calculamos la cantidad de combos que se pueden formar
        SELECT @cantidad_combo =
            MIN(FLOOR(i.item_cantidad / c.comp_cantidad))
        FROM Composicion c
        JOIN Item_Factura i
            ON i.item_producto = c.comp_componente
        WHERE c.comp_producto = @combo
          AND i.item_tipo = @tipo AND i.item_sucursal = @sucursal AND i.item_numero = @numero;

        -- Obtenemos el precio del combo
        SELECT @precio = prod_precio
        FROM Producto
        WHERE prod_codigo = @combo;

        -- Descontamos las cantidades utilizadas de cada componente
        UPDATE i
        SET i.item_cantidad =
            i.item_cantidad - (@cantidad_combo * c.comp_cantidad)
        FROM Item_Factura i
        JOIN Composicion c
            ON c.comp_componente = i.item_producto
        WHERE c.comp_producto = @combo
          AND i.item_tipo = @tipo AND i.item_sucursal = @sucursal AND i.item_numero = @numero;

        -- Eliminamos los componentes que quedaron en cero
        DELETE FROM Item_Factura
        WHERE item_tipo = @tipo AND item_sucursal = @sucursal AND item_numero = @numero
          AND item_cantidad = 0;

        -- Si el combo ya estaba facturado, acumulamos la cantidad
        IF EXISTS (
            SELECT 1
            FROM Item_Factura
            WHERE item_tipo = @tipo AND item_sucursal = @sucursal AND item_numero = @numero
              AND item_producto = @combo
        )
        BEGIN
            UPDATE Item_Factura
            SET item_cantidad = item_cantidad + @cantidad_combo,
                item_precio = @precio
            WHERE item_tipo = @tipo AND item_sucursal = @sucursal AND item_numero = @numero
              AND item_producto = @combo;
        END
        ELSE
        BEGIN
            INSERT INTO Item_Factura (
                item_tipo, item_sucursal, item_numero,
                item_producto, item_cantidad, item_precio
            )
            VALUES (
                @tipo, @sucursal, @numero,
                @combo, @cantidad_combo, @precio
            );
        END;
    END;
END;

/* 2.  Realizar un stored procedure que reciba un código de producto y una fecha y devuelva la mayor cantidad de
    días consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad en el día, el
    sistema de ventas on line está habilitado 24-7 por lo que se deben evaluar todos los días incluyendo domingos y feriados.*/
CREATE PROCEDURE SP_DIAS_CONSECUTIVOS_VENTA
    @producto CHAR(8),
    @fecha DATE
AS
BEGIN
    DECLARE @fecha_venta DATE;
    DECLARE @fecha_esperada DATE;
    DECLARE @dias INT;

    SET @dias = 0;
    SET @fecha_esperada = @fecha;

    DECLARE cursor_ventas CURSOR FOR
        SELECT CAST(f.fact_fecha AS DATE)
        FROM Factura f
        JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        WHERE i.item_producto = @producto
          AND f.fact_fecha >= @fecha
        GROUP BY CAST(f.fact_fecha AS DATE)
        HAVING SUM(i.item_cantidad) >= 1
        ORDER BY CAST(f.fact_fecha AS DATE);

    OPEN cursor_ventas;

    FETCH NEXT FROM cursor_ventas INTO @fecha_venta;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Si la fecha no es la que esperábamos, se cortó la racha
        IF @fecha_venta <> @fecha_esperada
            BREAK;

        SET @dias = @dias + 1;
        SET @fecha_esperada = DATEADD(DAY, 1, @fecha_esperada);

        FETCH NEXT FROM cursor_ventas INTO @fecha_venta;
    END;

    CLOSE cursor_ventas;
    DEALLOCATE cursor_ventas;

    SELECT @dias AS dias_consecutivos;
END;


/* 2do  Recuperatorio Gestión de Datos
2. El sistema actual permite vender productos compuestos directamente. Sin embargo, 
de ahora en adelante no queremos guardar la composición completa, sino únicamente 
los productos y cantidades correspondientes al primer nivel de composición. 
Se debe implementar una lógica para que, cada vez que se realice la venta de 
un producto compuesto, se registren sus componentes del primer nivel en las 
tablas correspondientes.*/
CREATE OR ALTER TRIGGER TR_REGISTRAR_COMPONENTES
ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @tipo CHAR(1);
    DECLARE @sucursal CHAR(4);
    DECLARE @numero CHAR(8);
    DECLARE @producto CHAR(8);
    DECLARE @cantidad DECIMAL(12,2);
    DECLARE @precio DECIMAL(12,2);

    DECLARE @componente CHAR(8);
    DECLARE @cantidad_componente DECIMAL(12,2);
    DECLARE @precio_componente DECIMAL(12,2);
    DECLARE @cantidad_final DECIMAL(12,2);

    -- Cursor para recorrer los productos vendidos
    DECLARE cursor_producto CURSOR FOR
        SELECT item_tipo, item_sucursal, item_numero,
               item_producto, item_cantidad, item_precio
        FROM inserted;

    OPEN cursor_producto;

    FETCH NEXT FROM cursor_producto
    INTO @tipo, @sucursal, @numero,
         @producto, @cantidad, @precio;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        -- Si el producto no es compuesto, lo guardamos normalmente
        IF NOT EXISTS (
            SELECT 1
            FROM Composicion
            WHERE comp_producto = @producto
        )
        BEGIN
            INSERT INTO Item_Factura (
                item_tipo, item_sucursal, item_numero,
                item_producto, item_cantidad, item_precio
            )
            VALUES (
                @tipo, @sucursal, @numero,
                @producto, @cantidad, @precio
            );
        END
        ELSE
        BEGIN
            -- Si es compuesto, recorremos solamente sus componentes directos
            DECLARE cursor_componente CURSOR FOR
                SELECT comp_componente, comp_cantidad
                FROM Composicion
                WHERE comp_producto = @producto;

            OPEN cursor_componente;

            FETCH NEXT FROM cursor_componente
            INTO @componente, @cantidad_componente;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @cantidad_final = @cantidad * @cantidad_componente;

                SELECT @precio_componente = prod_precio
                FROM Producto
                WHERE prod_codigo = @componente;

                -- Si el componente ya está en la factura, acumulamos
                IF EXISTS (
                    SELECT 1
                    FROM Item_Factura
                    WHERE item_tipo = @tipo
                      AND item_sucursal = @sucursal
                      AND item_numero = @numero
                      AND item_producto = @componente
                )
                BEGIN
                    UPDATE Item_Factura
                    SET item_cantidad = item_cantidad + @cantidad_final
                    WHERE item_tipo = @tipo
                      AND item_sucursal = @sucursal
                      AND item_numero = @numero
                      AND item_producto = @componente;
                END
                ELSE
                BEGIN
                    INSERT INTO Item_Factura (
                        item_tipo, item_sucursal, item_numero,
                        item_producto, item_cantidad, item_precio
                    )
                    VALUES (
                        @tipo, @sucursal, @numero,
                        @componente, @cantidad_final,
                        @precio_componente
                    );
                END;

                FETCH NEXT FROM cursor_componente
                INTO @componente, @cantidad_componente;
            END;

            CLOSE cursor_componente;
            DEALLOCATE cursor_componente;
        END;

        FETCH NEXT FROM cursor_producto
        INTO @tipo, @sucursal, @numero,
             @producto, @cantidad, @precio;
    END;

    CLOSE cursor_producto;
    DEALLOCATE cursor_producto;
END;

/* Parcial 19/11/2022
1. Implementar una regla de negocio en línea donde nunca una factura
nueva tenga un precio de producto distinto al que figura en la tabla
PRODUCTO. Registrar en una estructura adicional todos los casos
donde se intenta guardar un precio distinto. */
CREATE TABLE LOG_PRECIOS
( log_tipo CHAR(1), 
  log_sucursal CHAR(4), 
  log_numero CHAR(8),
  log_producto CHAR(8), 
  log_precio_ingresado DECIMAL(12,2),
  log_precio_correcto DECIMAL(12,2), 
  log_fecha SMALLDATETIME
)
CREATE OR ALTER TRIGGER TR_VALIDAR_PRECIO
ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN

    -- Registrar los intentos con precios incorrectos
    INSERT INTO LOG_PRECIOS (
        log_tipo, log_sucursal, log_numero,
        log_producto, log_precio_ingresado,
        log_precio_correcto, log_fecha
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        i.item_precio,
        p.prod_precio,
        GETDATE()
    FROM inserted i
    INNER JOIN Producto p
        ON p.prod_codigo = i.item_producto
    WHERE i.item_precio <> p.prod_precio;


    -- Insertar solamente los renglones con precio correcto
    INSERT INTO Item_Factura (
        item_tipo, item_sucursal, item_numero,
        item_producto, item_cantidad, item_precio
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        i.item_cantidad,
        i.item_precio
    FROM inserted i
    INNER JOIN Producto p
        ON p.prod_codigo = i.item_producto
    WHERE i.item_precio = p.prod_precio;

END;

/* Parcial 1C2018
2) implementar el/los objetos necesarios para mantener siempre actualizado al instante ante cualquier evento el campo fact_total de la tabla Factura
Nota: se sabe que actualmente el campo fact_total presenta esta propiedad*/
CREATE OR ALTER TRIGGER TR_ACTUALIZAR_TOTAL
ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN

    UPDATE Factura
    SET fact_total = (
        SELECT ISNULL(SUM(i.item_cantidad * i.item_precio), 0)
        FROM Item_Factura i
        WHERE i.item_tipo = Factura.fact_tipo
          AND i.item_sucursal = Factura.fact_sucursal
          AND i.item_numero = Factura.fact_numero
    )
    WHERE EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.item_tipo = Factura.fact_tipo
          AND i.item_sucursal = Factura.fact_sucursal
          AND i.item_numero = Factura.fact_numero
    )
    OR EXISTS (
        SELECT 1
        FROM deleted d
        WHERE d.item_tipo = Factura.fact_tipo
          AND d.item_sucursal = Factura.fact_sucursal
          AND d.item_numero = Factura.fact_numero
    );

END;
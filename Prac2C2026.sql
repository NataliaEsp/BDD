/*------------------------------------------PRACTICA SQL----------------------------------------------------------*/
 
 /* 1. Mostrar el código, razón social de todos los clientes cuyo límite de crédito sea mayor o igual a $ 1000 
 ordenado por código de cliente. */
SELECT 
	c.clie_codigo  AS Cod_Cliente,
	c.clie_razon_social AS Razon_Social_Cliente
FROM Cliente c
WHERE c.clie_limite_credito >= 1000
ORDER BY c.clie_codigo

/* 2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados por cantidad vendida. */
SELECT 
	i.item_producto AS Cod_Prod,
	p.prod_detalle AS Detalle_Prod
FROM Item_Factura i 
JOIN Producto p ON i.item_producto = p.prod_codigo
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY i.item_producto, p.prod_detalle
ORDER BY SUM(i.item_cantidad)

/* 3. Realizar una consulta que muestre código de producto, nombre de producto y el stock 
total, sin importar en que deposito se encuentre, los datos deben ser ordenados por 
nombre del artículo de menor a mayor. */
SELECT
	p.prod_codigo AS Cod_Prod,
	p.prod_detalle AS Nombre_Prod,
	SUM(s.stoc_cantidad) AS Cant_Stock_Total
FROM Producto p
JOIN STOCK s ON p.prod_codigo = s.stoc_producto
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY p.prod_detalle ASC

/* 4. Realizar una consulta que muestre para todos los artículos código, detalle y cantidad de 
artículos que lo componen. Mostrar solo aquellos artículos para los cuales el stock 
promedio por depósito sea mayor a 100. */
---- Solución profe
SELECT 
    Producto.prod_codigo, 
    Producto.prod_detalle, 
    ISNULL(SUM (comp_cantidad) / COUNT (DISTINCT stoc_deposito),0) AS Componentes
FROM Producto
LEFT JOIN Composicion ON Producto.prod_codigo = Composicion.comp_producto
JOIN Stock ON Producto.prod_codigo = Stock.stoc_producto
GROUP BY Producto.prod_codigo, Producto.prod_detalle
HAVING AVG (Stock.stoc_cantidad) > 100

/* 5. Realizar una consulta que muestre código de artículo, detalle y cantidad de egresos de 
stock que se realizaron para ese artículo en el año 2012 (egresan los productos que 
fueron vendidos). Mostrar solo aquellos que hayan tenido más egresos que en el 2011. */
SELECT 
	p.prod_codigo AS Cod_Prod,
	p.prod_detalle AS Nombre_Prod,
	SUM(i.item_cantidad) AS Cant_Egresos
FROM Producto p 
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY p.prod_codigo, p.prod_detalle
HAVING SUM(i.item_cantidad) > ISNULL((
	SELECT SUM(i2.item_cantidad)
	FROM Item_Factura i2
	JOIN Factura f2 ON i2.item_tipo = f2.fact_tipo AND i2.item_sucursal = f2.fact_sucursal AND i2.item_numero = f2.fact_numero
	WHERE i2.item_producto = p.prod_codigo AND YEAR (F2.fact_fecha) = 2011 
	), 0)
--- El having de abajo está mal porque falla si no hay producto vendido en 2011
/*HAVING p.prod_codigo IN (
	SELECT i2.item_producto
	FROM Item_Factura i2
	JOIN Factura f2 ON i2.item_tipo = f2.fact_tipo AND i2.item_sucursal = f2.fact_sucursal AND i2.item_numero = f2.fact_numero
	WHERE i2.item_producto = p.prod_codigo 
		AND YEAR(f2.fact_fecha) = 2011
	GROUP BY i2.item_producto
	HAVING SUM(i2.item_cantidad) < SUM(i.item_cantidad)
	)*/
--Resolucion profe
SELECT
    prod_codigo,
    prod_detalle,
    sum(case when year(fact_fecha) = 2012 then i.item_cantidad else 0 end) fact_2012
FROM Item_Factura i 
JOIN Factura f ON i.item_tipo = f.fact_tipo and i.item_sucursal = f.fact_sucursal and i.item_numero = f.fact_numero
JOIN producto p on p.prod_codigo = item_producto
WHERE YEAR(f.fact_fecha) in ( 2011, 2012)
group by prod_codigo, prod_detalle
having
sum( case when year(fact_fecha) = 2011 then i.item_cantidad else 0 end) <
sum(case when year(fact_fecha) = 2012 then i.item_cantidad else 0 end)
order by
 prod_codigo

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
-- V2
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
GROUP BY r.rubr_id, r.rubr_detalle
HAVING SUM(s.stoc_cantidad) > (
    SELECT s3.stoc_cantidad
    FROM Stock s3
    WHERE s3.stoc_producto = '00000000'
      AND s3.stoc_deposito = '00'
	)
ORDER BY r.rubr_id;

/* 8.Mostrar para el o los artículos que tengan stock en todos los depósitos, nombre del artículo, 
stock del depósito que más stock tiene.*/
SELECT
	p.prod_detalle AS Nombre_Prod,
	MAX(s.stoc_cantidad) AS Stock_Max
FROM Producto p 
JOIN STOCK s ON p.prod_codigo = s.stoc_producto
GROUP BY p.prod_codigo, p.prod_detalle
HAVING COUNT(DISTINCT s.stoc_deposito) = 
	(SELECT COUNT(d2.depo_codigo)
	 FROM DEPOSITO d2)

/* 10. Mostrar los 10 productos más vendidos en la historia y también los 10 productos menos vendidos 
en la historia. Además mostrar de esos productos, quien fue el cliente que mayor compra realizo.*/
SELECT
    p.prod_codigo,
    p.prod_detalle,
    SUM(i.item_cantidad) AS Cantidad_Vendida,
    (SELECT TOP 1
            f.fact_cliente
     FROM Item_Factura i2
     JOIN Factura f ON i2.item_tipo = f.fact_tipo AND i2.item_sucursal = f.fact_sucursal AND i2.item_numero = f.fact_numero
     WHERE i2.item_producto = p.prod_codigo
     GROUP BY f.fact_cliente
     ORDER BY SUM(i2.item_cantidad) DESC
    ) AS Cliente_Mayor_Compra
FROM Producto p
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
WHERE p.prod_codigo IN (
    SELECT TOP 10
        i2.item_producto
    FROM Item_Factura i2
    GROUP BY i2.item_producto
    ORDER BY SUM(i2.item_cantidad) DESC
    ) OR p.prod_codigo IN (
    SELECT TOP 10
        i3.item_producto
    FROM Item_Factura i3
    GROUP BY i3.item_producto
    ORDER BY SUM(i3.item_cantidad) ASC
    )
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY SUM(i.item_cantidad) DESC

/* 11. Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de 
productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán 
ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga, 
solo se deberán mostrar las familias que tengan una venta superior a 20000 pesos para 
el año 2012. */
SELECT 
    fa.fami_detalle AS Detalle_Fam,
    COUNT(DISTINCT i.item_producto) AS Cant_Prod,
    SUM(i.item_cantidad * i.item_precio) AS Monto
FROM Familia fa
JOIN Producto p ON fa.fami_id = p.prod_familia
JOIN Item_Factura i ON p.prod_codigo = i.item_producto
JOIN Factura f ON i.item_numero = f.fact_numero AND i.item_sucursal = f.fact_sucursal AND i.item_tipo = f.fact_tipo
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY fa.fami_id, fa.fami_detalle
HAVING SUM(i.item_cantidad * i.item_precio) > 20000
ORDER BY COUNT(DISTINCT i.item_producto) DESC;
----Viendo tabla-----
SELECT 
    F.fact_numero, F.fact_sucursal, F.fact_tipo, F.fact_total, i.item_precio, i.item_producto,
    f.fact_total_impuestos
FROM Factura f
JOIN Item_Factura i ON i.item_numero = f.fact_numero AND i.item_sucursal = f.fact_sucursal AND i.item_tipo = f.fact_tipo
WHERE f.fact_total_impuestos = 0
GROUP BY f.fact_numero, F.fact_sucursal, F.fact_tipo,i.item_producto, F.fact_total, i.item_precio, f.fact_total_impuestos
ORDER BY f.fact_numero
---------------------
/* 12. Mostrar nombre de producto, cantidad de clientes distintos que lo compraron importe 
promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del 
producto y stock actual del producto en todos los depósitos. Se deberán mostrar 
aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán 
ordenarse de mayor a menor por monto vendido del producto. */

/* 15. TODO*/


/*================ TSQL =================*/
-- CURSORES
DECLARE @clie char(6)
DECLARE @detalle char(100)
DECLARE mi_cursor CURSOR FOR
SELECT clie_codigo, clie_razon_social
FROM CLIENTE
WHERE
 CLIE_CODIGO BETWEEN '00000' AND '00003'
open mi_cursor
fetch next from mi_cursor into @clie, @detalle
WHILE @@FETCH_STATUS = 0
BEGIN
PRINT 'Codigo: ' + @clie + ' Razon Social: ' + @detalle
fetch next from mi_cursor into @clie, @detalle
END
CLOSE mi_cursor
DEALLOCATE mi_cursor
----------------------------------------------
DECLARE @clie char(6)
DECLARE @detalle char(100)
DECLARE mi_cursor CURSOR FOR
SELECT clie_codigo, clie_razon_social
FROM CLIENTE
WHERE
 CLIE_CODIGO BETWEEN '00000' AND '00003'
FOR UPDATE
 OF clie_razon_social
open mi_cursor
fetch next from mi_cursor into @clie, @detalle
WHILE @@FETCH_STATUS = 0
BEGIN
IF @clie = '00001'
BEGIN
UPDATE CLIENTE
SET clie_razon_social = 'NUEVA RAZON SOCIAL'
WHERE CURRENT OF mi_cursor
END
PRINT 'Codigo: ' + @clie + ' Razon Social: ' + @detalle
fetch next from mi_cursor into @clie, @detalle
END
CLOSE mi_cursor
DEALLOCATE mi_cursor

-- Clase TSQL - TRIGGERS - 14/10/2026
---------------
PRINT @@TRANCOUNT
 BEGIN TRANSACTION
PRINT @@TRANCOUNT
BEGIN TRANSACTION
PRINT @@TRANCOUNT
COMMIT
PRINT @@TRANCOUNT
COMMIT
PRINT @@TRANCOUNT

----
PRINT @@TRANCOUNT
 BEGIN TRANSACTION
PRINT @@TRANCOUNT
BEGIN TRANSACTION
PRINT @@TRANCOUNT
ROLLBACK
PRINT @@TRANCOUNT
---------------
CREATE TRIGGER [dbo].[TR_INSERT_CLIE] ON [dbo].[Cliente]
AFTER INSERT
AS
BEGIN TRANSACTION
select 'inserted', * from inserted
COMMIT

insert into cliente (clie_codigo, clie_razon_social, clie_telefono,
 clie_domicilio, clie_limite_credito, clie_vendedor) values ('0---1',' cliente nuevo', 'tel',
'domicilio', 1000, 1)
---------------
CREATE TRIGGER [dbo].[tr_delete] ON [dbo].[Cliente]
AFTER DELETE, INSERT, UPDATE
AS
BEGIN TRANSACTION
SELECT 'INSERTED VALORES NUEVOS', * FROM INSERTED
SELECT 'DELETED VALORES VIEJOS',* FROM DELETED
COMMIT

insert into cliente (clie_codigo, clie_razon_social, clie_telefono,
 clie_domicilio, clie_limite_credito, clie_vendedor) values ('0---1',' cliente nuevo', 'tel',
'domicilio', 1000, 1)
delete from cliente where clie_codigo = '0---1'
update cliente set clie_razon_social = 'valor razon nueva' where clie_codigo = '00000'

/* Realizar un trigger que cada vez que se inserte una factura del mes en curso.
Actualice la comision del vendedor con la sgte formula: 
suma del monto total de las facturas del mes en curso * 0.1  */
CREATE TRIGGER INSERT_FACTURA ON Factura
AFTER INSERT
AS
BEGIN
    UPDATE e
    SET e.empl_comision = ISNULL((
            SELECT SUM(f.fact_total) * 0.1
            FROM Factura f
            WHERE f.fact_vendedor = e.empl_codigo
              AND YEAR(f.fact_fecha)  = YEAR(GETDATE())
              AND MONTH(f.fact_fecha) = MONTH(GETDATE())
        ), 0)
    FROM Empleado e
    WHERE e.empl_codigo IN (
            SELECT i.fact_vendedor
            FROM inserted i
            WHERE YEAR(i.fact_fecha)  = YEAR(GETDATE())
              AND MONTH(i.fact_fecha) = MONTH(GETDATE())
    )
END
GO

insert into factura ( fact_cliente, fact_fecha, fact_numero, fact_sucursal,
 fact_tipo , fact_total, fact_total_impuestos ,
 fact_vendedor )
values('00000', '20261014', '00000000','0000','A', 100, 100, 1 )

select * from Empleado

insert into factura ( fact_cliente, fact_fecha, fact_numero, fact_sucursal,
 fact_tipo , fact_total, fact_total_impuestos ,
 fact_vendedor )
values('00000', '20251014', '00000000','0000','B', 100, 100, 1 )

insert into factura ( fact_cliente, fact_fecha, fact_numero, fact_sucursal,
 fact_tipo , fact_total, fact_total_impuestos ,
 fact_vendedor )
values('00000', '20261014', '00000000','0000','C', 100, 100, 1 )
---------- 21/10
/*REALIZAR UN TRIGGER QUE APLIQUE UN DELETE EN CASCADA SOBRE LA TABLA CLIENTE
"DELETE FROM CLIENTE" */

CREATE TRIGGER DELETE_CASCADA_CLIENTE ON CLIENTE
INSTEAD OF DELETE
AS
BEGIN TRANSACTION
    SELECT c.clie_codigo
    FROM Cliente c
    JOIN Factura f ON c.clie_codigo = f.fact_cliente
    JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
    WHERE c.clie_codigo IN (
        SELECT d.clie_codigo
        FROM DELETED d)
COMMIT TRANSACTION
-- Soluci{on compañero
CREATE TRIGGER borrarEnCascada ON Cliente INSTEAD OF DELETE
AS
BEGIN TRANSACTION
DECLARE @tipo char(1)
DECLARE @sucursal char(4)
DECLARE @numero char(8)
DECLARE recorrerItemClientePorBorrar CURSOR FOR
SELECT fact_tipo, fact_sucursal, fact_numero
FROM Factura
WHERE fact_cliente IN (SELECT clie_codigo FROM Deleted)
OPEN recorrerItemClientePorBorrar
FETCH NEXT FROM recorrerItemClientePorBorrar INTO @tipo, @surcusal, @numero
WHILE @@FETCH_STATUS = 0
BEGIN
DELETE FROM Item_Factura
WHERE item_tipo = @tipo and
 item_sucursal = @sucursal and
 item_numero = @numero
FETCH NEXT FROM recorrerItemClientePorBorrar INTO @tipo, @surcusal, @numero
END
CLOSE recorrerItemClientePorBorrar
DEALLOCATE recorrerItemClientePorBorrar
DELETE FROM Factura
WHERE fact_cliente IN (SELECT clie_codigo FROM Deleted)
DELETE FROM Cliente
WHERE clie_codigo IN (SELECT clie_codigo FROM Deleted)
COMMIT

--Solución Profe
CREATE TRIGGER [dbo].[TR_DELETED_EN_CASCADA] ON [dbo].[Cliente]
INSTEAD OF DELETE
AS
BEGIN TRANSACTION
-- Eliminar los item_factura del cliente
DELETE IFact
FROM Item_Factura IFact
INNER JOIN Factura F
ON IFact.item_tipo = F.fact_tipo
AND IFact.item_sucursal = F.fact_sucursal
AND IFact.item_numero = F.fact_numero
INNER JOIN deleted D
ON F.fact_cliente = D.clie_codigo;
-- Eliminar las facturas del cliente
DELETE F
FROM Factura F
INNER JOIN deleted D
ON F.fact_cliente = D.clie_codigo;
-- Eliminar el cliente
DELETE C
FROM Cliente C
INNER JOIN deleted D
ON C.clie_codigo = D.clie_codigo;
COMMIT

/* 18. Sabiendo que el limite de credito de un cliente es el monto maximo que se le puede facturar mensualmente, 
cree el/los objetos de base de datos necesarios para que dicha regla de negocio se cumpla automaticamente. 
No se conoce la forma de acceso a los datos ni el procedimiento por el cual se emiten las facturas */
CREATE TRIGGER TR_EJE_18 ON factura 
AFTER insert, UPDATE
AS
BEGIN TRANSACTION 

    IF EXISTS ( SELECT 1 FROM inserted f join cliente c on 
                    fact_cliente = clie_codigo 
                WHERE 
                    year(fact_fecha) = year(getdate()) and 
                    month(fact_fecha) = month( getdate())
                GROUP BY 
                    fact_cliente, clie_limite_credito
                HAVING 
                     sum(fact_total) > clie_limite_credito 
               )
    BEGIN 

            ROLLBACK 
            RETURN 

    END 

COMMIT
--
CREATE TRIGGER TR_EJE_18_c ON CLIENTE 
AFTER UPDATE
AS
BEGIN TRANSACTION 

    IF EXISTS ( SELECT 1 FROM FACTURA f join inserted i on
                    fact_cliente = clie_codigo 
                WHERE 
                    year(fact_fecha) = year(getdate()) and 
                    month(fact_fecha) = month( getdate())
                GROUP BY 
                    fact_cliente, clie_limite_credito
                HAVING 
                     sum(fact_total) > clie_limite_credito 
               )
    BEGIN 

            ROLLBACK 
            RETURN 

    END 

COMMIT

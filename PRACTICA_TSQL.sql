-- TSQL
/*Calentamiento: sentencias sueltas
1) Subir 10% el precio de los productos de una familia. (Pista: UPDATE ... SET ... WHERE. Probalo antes con un SELECT.) */
CREATE OR ALTER PROCEDURE SUBIR_10_PORCIENTO
    @familia CHAR(3)
AS
BEGIN
    UPDATE Producto
    SET prod_precio = prod_precio * 1.1
    WHERE prod_familia = @familia
END
GO

/* 2) Insertar un cliente nuevo cargando solo código y razón social. (Pista: lista de columnas en el INSERT.) */
CREATE OR ALTER PROCEDURE Insertar_Cliente_Nuevo
    @codigo CHAR(6),
    @razon  CHAR(100)
AS
BEGIN
    INSERT INTO Cliente (clie_codigo, clie_razon_social)
    VALUES (@codigo, @razon)
END
GO

/* Funciones (devuelven un valor)
3) Dado un cliente, devolver la cantidad de facturas que tiene. (Plantilla: fn_stock_total.) */
CREATE OR ALTER FUNCTION Cantidad_Facturas
( @cliente CHAR(6)
) RETURNS INT
AS
BEGIN
    DECLARE @resultado INT    

    SELECT @resultado = COUNT(f.fact_tipo + f.fact_sucursal + f.fact_numero)
    FROM Factura f
    WHERE f.fact_cliente = @cliente

    RETURN @resultado
END
GO

/* 4) Dado un producto, devolver 'COMPUESTO' o 'SIMPLE'. (Pista: IF EXISTS sobre Composicion.) */
CREATE OR ALTER FUNCTION dbo.Compuesto_O_Simple (@prod_cod CHAR(8))
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @respuesta VARCHAR(10)

    IF EXISTS (SELECT 1 FROM Composicion WHERE comp_producto = @prod_cod)
        SET @respuesta = 'COMPUESTO'
    ELSE
        SET @respuesta = 'SIMPLE'

    RETURN @respuesta
END
GO

SELECT 
    p.prod_codigo,
    CASE WHEN p.prod_codigo IN (SELECT c.comp_producto
                                FROM Composicion c)
        THEN 'Compuesto'
        ELSE 'Simple'
        end
FROM Producto p
GO 

select co.comp_producto from Composicion co where co.comp_producto = '00001104'
go
/* 5) Dado un empleado, devolver cuántos subordinados directos tiene. (Es la base del trigger de jefes.) */
CREATE OR ALTER FUNCTION dbo.Cant_Sub (@jefe_cod NUMERIC(6,0))
RETURNS INT
AS
BEGIN
    RETURN (SELECT COUNT(*)
            FROM Empleado
            WHERE empl_jefe = @jefe_cod)
END
GO
-- Si quiero saber cantidad de subordinados directos e indirectos:
CREATE OR ALTER FUNCTION dbo.cant_subordinados_total (@jefe NUMERIC(6,0))
RETURNS INT
AS
BEGIN
    DECLARE @total INT

    -- directos + los subordinados de cada directo (la función se llama a sí misma)
    SELECT @total = COUNT(*) + ISNULL(SUM(dbo.cant_subordinados_total(empl_codigo)), 0)
    FROM Empleado
    WHERE empl_jefe = @jefe

    RETURN @total
END
GO
--
SELECT empl_codigo, dbo.cant_subordinados_total(empl_codigo) FROM Empleado
go
/* Procedures (se ejecutan con EXEC)
6) Recibe una familia y un porcentaje, y aumenta el precio de sus productos. (Pista: parámetros más un UPDATE.) */
CREATE OR ALTER PROCEDURE Aumento_Precio
@fam_id CHAR(3), @porcentaje DECIMAL(5,2)
AS
BEGIN
    UPDATE Producto
    SET prod_precio = prod_precio * (1 + @porcentaje / 100.0)
    WHERE prod_familia = @fam_id
END
GO

/* 7) Recibe un producto y devuelve con RETURN en cuántos depósitos hay stock. (Pista: COUNT y RETURN, para practicar cómo se devuelve un valor.) */
CREATE OR ALTER PROCEDURE Cant_Depo
    @prod_cod CHAR(8)
AS
BEGIN
    RETURN (SELECT COUNT(*)
            FROM Stock
            WHERE stoc_producto = @prod_cod
              AND stoc_cantidad > 0)
END
GO

------------------------------------------------------CONSULTA PROBANDO APARTE-------------------------------------------
SELECT 
    COUNT(f.fact_tipo + f.fact_sucursal + f.fact_numero) AS Cant_Fact_Repetidas_X_ItemProd, 
    f.fact_tipo, 
    f.fact_sucursal, 
    f.fact_numero, 
    SUM(item_cantidad) AS Cant_Total_De_Productos_X_Fact
FROM Factura f
JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
GROUP BY f.fact_tipo, f.fact_sucursal, f.fact_numero
ORDER BY f.fact_tipo, f.fact_sucursal, f.fact_numero ASC

SELECT COUNT(*)
FROM Factura f

SELECT *
FROM Factura f

SELECT *
FROM Item_Factura i
GROUP BY i.item_tipo, i.item_sucursal, i.item_numero
-- Facturas sin ITEMS
SELECT f.fact_tipo, f.fact_sucursal, f.fact_numero, f.fact_fecha, f.fact_total, *
FROM Factura f
LEFT JOIN Item_Factura i ON i.item_tipo = f.fact_tipo
                        AND i.item_sucursal = f.fact_sucursal
                        AND i.item_numero = f.fact_numero
WHERE i.item_tipo IS NULL
GO
--------------------------------------------------FIN:CONSULTA PROBANDO APARTE-------------------------------------------

/* 8) Transferir stock: recibe producto, depósito origen, depósito destino y cantidad. 
Resta en el origen y suma en el destino. 
Si el origen no tiene suficiente, tira un error y no hace nada. 
(Plantilla: el procedure de compras, porque son dos UPDATE que dependen entre sí, o sea BEGIN TRANSACTION.) */
CREATE OR ALTER PROCEDURE Transferir_Stock
    @prod_cod     CHAR(8),
    @depo_origen  CHAR(2),
    @depo_destino CHAR(2),
    @cantidad     DECIMAL(12,2)
AS
BEGIN
    SET XACT_ABORT ON      -- si algo falla en runtime (ej: depósito inexistente), deshace todo
    --OPCIONAL
    IF @depo_origen = @depo_destino OR @cantidad <= 0
        BEGIN
            RAISERROR('Depósitos distintos y cantidad positiva.', 16, 1)
            RETURN
        END
    --FIN:OPCIONAL
    BEGIN TRANSACTION

        IF NOT EXISTS (SELECT 1
                       FROM Stock
                       WHERE stoc_producto = @prod_cod
                         AND stoc_deposito = @depo_origen
                         AND stoc_cantidad >= @cantidad)
        BEGIN
            RAISERROR('Stock insuficiente en el depósito origen.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END

        -- destino: no superar el stock máximo
        IF EXISTS (SELECT 1
                   FROM Stock
                   WHERE stoc_producto = @prod_cod
                     AND stoc_deposito = @depo_destino
                     AND ISNULL(stoc_cantidad, 0) + @cantidad > stoc_stock_maximo)
        BEGIN
            RAISERROR('La transferencia supera el stock máximo del depósito destino.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END

        -- resto en el origen
        UPDATE Stock
        SET stoc_cantidad = stoc_cantidad - @cantidad
        WHERE stoc_producto = @prod_cod
          AND stoc_deposito = @depo_origen

        -- sumo en el destino (si no tiene fila de ese producto, la creo)
        IF EXISTS (SELECT 1 FROM Stock
                   WHERE stoc_producto = @prod_cod AND stoc_deposito = @depo_destino)
            UPDATE Stock
            SET stoc_cantidad = ISNULL(stoc_cantidad, 0) + @cantidad
            WHERE stoc_producto = @prod_cod
              AND stoc_deposito = @depo_destino
        ELSE
            INSERT INTO Stock (stoc_producto, stoc_deposito, stoc_cantidad,
                               stoc_punto_reposicion, stoc_stock_maximo)
            VALUES (@prod_cod, @depo_destino, @cantidad, 0, @cantidad)

    COMMIT TRANSACTION
END
GO

-- ADICIONAL PARA CONTROLAR LOS LIMITES MINIMOS Y MAXIMOS DE LA CANTIDAD DE STOCK POR PRODUCTO
CREATE OR ALTER TRIGGER TR_STOCK_LIMITES ON Stock
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM inserted
               WHERE stoc_cantidad > stoc_stock_maximo
                  OR stoc_cantidad < stoc_punto_reposicion)
    BEGIN
        RAISERROR('El stock debe estar entre el punto de reposición y el stock máximo.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

/* Triggers AFTER que validan y revierten
9) El salario de un empleado no puede ser negativo. (Plantilla: el de límite de crédito negativo.) */
CREATE OR ALTER TRIGGER TR_SALARIO_NEGATIVO ON Empleado
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM inserted ins
               WHERE ins.empl_salario < 0)
    BEGIN
        RAISERROR('Error: Salario Negativo', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

/* 10) stoc_cantidad no puede ser negativa. */
CREATE OR ALTER TRIGGER TR_STOCK_NEGATIVO ON STOCK
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM inserted ins
               WHERE ins.stoc_cantidad < 0)
    BEGIN
        RAISERROR('Error: stoc_cantidad Negativo', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

/* 11) Un producto no puede componerse de sí mismo (comp_producto = comp_componente). */
CREATE OR ALTER TRIGGER TR_PROD_COMPUESTO ON Composicion
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM inserted ins
               WHERE ins.comp_producto = ins.comp_componente)
    BEGIN
        RAISERROR('Error: comp_producto = comp_componente', 16, 1)
        ROLLBACK TRANSACTION
    END    
END
GO

/* 12) No se puede borrar un cliente que tenga facturas. (Plantilla: el lado padre de la FK, con deleted y un JOIN.) */
CREATE OR ALTER TRIGGER TR_BORRAR_CLIENTE ON Cliente
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM deleted d
               JOIN Factura f ON f.fact_cliente = d.clie_codigo)
    BEGIN
        RAISERROR('El cliente posee facturas, no puede ser borrado.', 16, 1)
        RETURN -- el DELETE original nunca ocurrió: no hace falta ROLLBACK
    END

    DELETE c
    FROM Cliente c
    JOIN deleted d ON d.clie_codigo = c.clie_codigo
END
GO

/* Triggers que modifican datos
13) Al insertar un ítem de factura, descontar la cantidad del stock del depósito '00'. 
(Pista: UPDATE ... FROM Stock s JOIN inserted i .... Si el mismo producto entra dos veces en el lote, agrupá con SUM.) */
CREATE OR ALTER TRIGGER TR_ITEM_FACT ON ITEM_FACTURA
AFTER INSERT
AS
BEGIN
    -- 0. Validamos si algún producto del lote queda por debajo del punto de reposición (estoy forzando un chequeo sin que la consigna lo pida, no es invalido pero ojo)
    IF EXISTS (
            SELECT 1
            FROM Stock s
            WHERE s.stoc_deposito = '00'
              AND (s.stoc_cantidad - (SELECT SUM(i.item_cantidad)
                                     FROM inserted i
                                     WHERE i.item_producto = s.stoc_producto)) < s.stoc_punto_reposicion
        )
    BEGIN
        RAISERROR('No se puede proceder: el stock del deposito 00 quedaria menor al punto de reposicion', 16, 1)
        ROLLBACK TRANSACTION
        RETURN -- ¡Fundamental para cortar la ejecución!
    END

    -- 1. Rechazo la venta si algún producto no tiene fila de stock en el depósito 00 (no es necesario ya que no se descuenta nada si el prod no esta en el depo 00, pero completa a la resolucion)
    IF EXISTS (SELECT 1
               FROM inserted i
               WHERE NOT EXISTS (SELECT 1
                                 FROM Stock s
                                 WHERE s.stoc_producto = i.item_producto
                                   AND s.stoc_deposito = '00'))
    BEGIN
        RAISERROR('Hay productos sin stock cargado en el depósito 00.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END

    -- 2. Descontamos el stock sumando todas las apariciones del producto en inserted (esto es suficiente como respuesta)
    UPDATE s
    SET s.stoc_cantidad = s.stoc_cantidad - (
        SELECT SUM(i.item_cantidad)
        FROM inserted i
        WHERE i.item_producto = s.stoc_producto
    )
    FROM STOCK s
    WHERE s.stoc_deposito = '00'                                    -- 1} si el producto no tiene fila en el depósito 00,
      AND s.stoc_producto IN (SELECT item_producto FROM inserted)   -- 1} no se descuenta nada
END
GO

SELECT * FROM STOCK
GO

-- Variantes a la consigna original:
/* Variante 1: Descontar del primer depósito donde alcance el stock
Regla: Al insertar ítems en Item_Factura, descontar la cantidad vendida de cualquier depósito
que tenga stock suficiente para cubrir el total vendido de ese producto en el lote. 
Si para algún producto ningún depósito tiene stock suficiente, cancelar toda la operación. */
CREATE OR ALTER TRIGGER tr_descontar_primer_deposito_disponible
ON Item_Factura
AFTER INSERT
AS
BEGIN
    -- 1. Validar que para CADA producto del lote exista al menos un depósito con stock suficiente
    IF EXISTS (
        SELECT i.item_producto
        FROM inserted i
        GROUP BY i.item_producto
        HAVING NOT EXISTS (
            SELECT 1
            FROM STOCK s
            WHERE s.stoc_producto = i.item_producto
              AND s.stoc_cantidad >= SUM(i.item_cantidad)
        )
    )
    BEGIN
        RAISERROR('No hay ningun deposito con stock suficiente para cubrir uno de los productos.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 2. Descontar del primer depósito que tenga stock suficiente
    UPDATE s
    SET s.stoc_cantidad = s.stoc_cantidad - (
        SELECT SUM(i.item_cantidad)
        FROM inserted i
        WHERE i.item_producto = s.stoc_producto
    )
    FROM STOCK s
    WHERE s.stoc_producto IN (SELECT item_producto FROM inserted)
      -- Elegimos solo UN depósito (el primero que cumpla la condición)
      AND s.stoc_deposito = (
          SELECT TOP 1 s2.stoc_deposito
          FROM STOCK s2
          WHERE s2.stoc_producto = s.stoc_producto
            AND s2.stoc_cantidad >= (
                SELECT SUM(i2.item_cantidad)
                FROM inserted i2
                WHERE i2.item_producto = s.stoc_producto
            )
          ORDER BY s2.stoc_deposito ASC
      );
END;
GO

/* Variante 2: Descontar según la Zona del vendedor
Regla: Al insertar ítems en Item_Factura, descontar el stock del depósito que pertenezca a la misma zona 
que el departamento del vendedor que emitió la factura (si hay más de uno en esa zona, elegir el de menor código).
¿Cómo lo pensamos?
Esta variante evalúa si sabés unir todas las tablas del diagrama:
Item_Factura -> Factura -> Empleado -> Departamento -> Zona -> DEPOSITO -> STOCK.
1. Agrupación clave: Acá ya no alcanza con agrupar solo por item_producto, 
porque dos facturas en el mismo lote pueden ser de vendedores de distintas zonas. 
Agrupamos por (producto, zona_del_vendedor).
2. Actualización: Actualizamos STOCK buscando el depósito (TOP 1) que coincida con la zona de cada grupo*/
CREATE OR ALTER TRIGGER tr_descontar_por_zona_vendedor
ON Item_Factura
AFTER INSERT
AS
BEGIN
    -- Actualizamos el stock cruzando la zona del vendedor de cada factura
    UPDATE s
    SET s.stoc_cantidad = s.stoc_cantidad - (
        SELECT SUM(i.item_cantidad)
        FROM inserted i
        JOIN Factura f ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        JOIN Empleado e ON e.empl_codigo = f.fact_vendedor
        JOIN Departamento d ON d.depa_codigo = e.empl_departamento
        WHERE i.item_producto = s.stoc_producto
          AND d.depa_zona = dep.depo_zona
    )
    FROM STOCK s
    JOIN DEPOSITO dep ON dep.depo_codigo = s.stoc_deposito
    WHERE EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Factura f ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
        JOIN Empleado e ON e.empl_codigo = f.fact_vendedor
        JOIN Departamento d ON d.depa_codigo = e.empl_departamento
        WHERE i.item_producto = s.stoc_producto
          AND d.depa_zona = dep.depo_zona
          -- Si una zona tiene varios depósitos, nos quedamos con el primero
          AND dep.depo_codigo = (
              SELECT TOP 1 dep2.depo_codigo
              FROM DEPOSITO dep2
              JOIN STOCK s2 ON s2.stoc_deposito = dep2.depo_codigo
              WHERE dep2.depo_zona = d.depa_zona
                AND s2.stoc_producto = i.item_producto
              ORDER BY dep2.depo_codigo ASC
          )
    );
END;
GO
/* 14) INSTEAD OF INSERT sobre Cliente: insertar solo los que tengan límite de crédito mayor o igual a 0. (Plantilla: el INSTEAD OF de precios.) */
CREATE OR ALTER TRIGGER TR_LIM_CREDIT ON Cliente
INSTEAD OF INSERT
AS
BEGIN
    -- aviso (no corta) si hay filas que se descartan
    IF EXISTS (SELECT 1 FROM inserted WHERE clie_limite_credito < 0)
        RAISERROR('Se descartaron clientes con límite de crédito negativo.', 10, 1)

    -- inserto solo los válidos
    INSERT INTO Cliente (clie_codigo, clie_razon_social, clie_telefono,
                         clie_domicilio, clie_limite_credito, clie_vendedor)
    SELECT clie_codigo, clie_razon_social, clie_telefono,
           clie_domicilio, clie_limite_credito, clie_vendedor
    FROM inserted
    WHERE clie_limite_credito >= 0
END
GO
/* 15) fact_total tiene que ser la suma de los ítems. (Es el T-SQL del parcial del 04/11. Ya te dejé una solución: rehacelo sin mirar, para ver cómo lo pensarías ahora.) */
CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_TOTAL ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    UPDATE f
    SET f.fact_total = ISNULL((SELECT SUM(i.item_cantidad * i.item_precio)
                               FROM Item_Factura i
                               WHERE i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero), 0)
    FROM Factura f
    WHERE EXISTS (SELECT 1 FROM inserted x
                  WHERE x.item_tipo = f.fact_tipo AND x.item_sucursal = f.fact_sucursal AND x.item_numero = f.fact_numero)
       OR EXISTS (SELECT 1 FROM deleted x
                  WHERE x.item_tipo = f.fact_tipo AND x.item_sucursal = f.fact_sucursal AND x.item_numero = f.fact_numero)
END
GO
-- V1 PARA TRIGGER SOBRE FACTURA, MOSTRAMOS ERROR
CREATE OR ALTER TRIGGER TR_FACT_TOTAL ON Factura
AFTER UPDATE -- el INSERT no aporta: aún no hay ítems
AS
BEGIN
    IF UPDATE(fact_total)
       AND EXISTS (SELECT 1
                   FROM inserted ins
                   WHERE ins.fact_total != (SELECT SUM(i.item_cantidad * i.item_precio)
                                            FROM Item_Factura i
                                            WHERE i.item_tipo = ins.fact_tipo AND i.item_sucursal = ins.fact_sucursal AND i.item_numero = ins.fact_numero))
    BEGIN
        RAISERROR('El total de la factura debe ser la suma de sus ítems.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO
-- V2 PARA TRIGGER SOBRE FACTURA, ARREGLAMOS A MANO EL ERROR
CREATE OR ALTER TRIGGER TR_FACTURA_TOTAL ON Factura
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    -- Alta: el total siempre arranca en 0
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO Factura (fact_tipo, fact_sucursal, fact_numero, fact_fecha,
                             fact_vendedor, fact_total, fact_total_impuestos, fact_cliente)
        SELECT fact_tipo, fact_sucursal, fact_numero, fact_fecha,
               fact_vendedor, 0, fact_total_impuestos, fact_cliente
        FROM inserted;
        RETURN;
    END;

    IF UPDATE(fact_tipo) OR UPDATE(fact_sucursal) OR UPDATE(fact_numero)
        THROW 50001, 'No se permite modificar la clave de una factura.', 1;

    IF TRIGGER_NESTLEVEL(OBJECT_ID('TR_ITEM_FACTURA_TOTAL')) > 0
    BEGIN
        -- Viene del trigger de ítems: aplica solo la diferencia sobre el valor actual
        UPDATE F
        SET fact_total = F.fact_total + (I.fact_total - D.fact_total)
        FROM Factura F
        JOIN inserted I ON  I.fact_tipo = F.fact_tipo AND I.fact_sucursal = F.fact_sucursal AND I.fact_numero = F.fact_numero
        JOIN deleted D ON  D.fact_tipo = F.fact_tipo AND D.fact_sucursal = F.fact_sucursal AND D.fact_numero = F.fact_numero;
    END
    ELSE
    BEGIN
        -- Modificación directa: el total se recalcula desde los ítems
        UPDATE F
        SET fact_fecha = I.fact_fecha,
            fact_vendedor = I.fact_vendedor,
            fact_cliente = I.fact_cliente,
            fact_total_impuestos = I.fact_total_impuestos,
            fact_total = ISNULL((SELECT SUM(IT.item_cantidad * IT.item_precio)
                                 FROM Item_Factura IT
                                 WHERE IT.item_tipo     = F.fact_tipo
                                   AND IT.item_sucursal = F.fact_sucursal
                                   AND IT.item_numero   = F.fact_numero), 0)
        FROM Factura F
        JOIN inserted I ON I.fact_tipo = F.fact_tipo AND I.fact_sucursal = F.fact_sucursal AND I.fact_numero = F.fact_numero;
    END;
END;
GO

/* Parcial 17/07/2026 Bases de Datos 1C-2026
Implementar los objetos de base de datos necesarios (por ejemplo, triggers, procedimientos, 
funciones u otros mecanismos que considere apropiados) para mantener permanentemente actualizada 
una tabla denominada ProductosAcumulados
La tabla deberá almacenar, para cada producto y período (formato AAAAMM), la siguiente información:
- Código del producto
- Período (AAAAMM)
- Cantidad total vendida en el período
- Precio máximo de venta del producto registrado en el período
- Precio mínimo de venta del producto registrado en el período
- Importe total vendido en el período
La actualización de la tabla deberá realizarse en tiempo real, reflejando automáticamente cada alta, 
modificación o eliminación de ventas, de manera que la información permanezca siempre consistente 
con los datos operacionales. */
CREATE TABLE ProductosAcumulados1 (
    cod_prod CHAR(8) NOT NULL,
    periodo CHAR(6) NOT NULL,
    cantProdXperiodo DECIMAL(12,2),
    precioMax DECIMAL(12,2),
    precioMin DECIMAL(12,2),
    importeTotal DECIMAL(12,2),
    PRIMARY KEY(cod_prod, periodo)
)
GO

--V1 con variable tipo tabla local
CREATE OR ALTER TRIGGER TR_ACTU_ProdAcu ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @afectados TABLE (cod_prod CHAR(8), periodo CHAR(6))

    -- 1) pares (producto, período) tocados: los de las filas nuevas y los de las viejas
    INSERT INTO @afectados (cod_prod, periodo)
    SELECT x.item_producto,
           CAST(YEAR(f.fact_fecha) AS CHAR(4)) + RIGHT('0' + CAST(MONTH(f.fact_fecha) AS VARCHAR(2)), 2)
    FROM inserted x
    JOIN Factura f ON f.fact_tipo = x.item_tipo AND f.fact_sucursal = x.item_sucursal AND f.fact_numero = x.item_numero
    UNION
    SELECT x.item_producto,
           CAST(YEAR(f.fact_fecha) AS CHAR(4)) + RIGHT('0' + CAST(MONTH(f.fact_fecha) AS VARCHAR(2)), 2)
    FROM deleted x
    JOIN Factura f ON f.fact_tipo = x.item_tipo AND f.fact_sucursal = x.item_sucursal AND f.fact_numero = x.item_numero

    -- 2) borro lo acumulado de esos pares
    DELETE pa
    FROM ProductosAcumulados pa
    JOIN @afectados a ON a.cod_prod = pa.cod_prod AND a.periodo = pa.periodo

    -- 3) lo recalculo desde las ventas reales
    INSERT INTO ProductosAcumulados (cod_prod, periodo, cantProdXperiodo, precioMax, precioMin, importeTotal)
    SELECT i.item_producto, a.periodo,
           SUM(i.item_cantidad), MAX(i.item_precio), MIN(i.item_precio),
           SUM(i.item_cantidad * i.item_precio)
    FROM Item_Factura i
    JOIN Factura f ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
    JOIN @afectados a ON a.cod_prod = i.item_producto
                     AND a.periodo = CAST(YEAR(f.fact_fecha) AS CHAR(4)) + RIGHT('0' + CAST(MONTH(f.fact_fecha) AS VARCHAR(2)), 2)
    GROUP BY i.item_producto, a.periodo
END
GO
--V2 repito logica 4 veces pero no uso tabla temporal para borrar datos a modificar en ProductosAcumulados
CREATE OR ALTER TRIGGER TR_ACTU_ProdAcu ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- 1) borro lo acumulado de los (producto, período) tocados
    DELETE pa
    FROM ProductosAcumulados pa
    WHERE EXISTS (SELECT 1
                  FROM inserted x
                  JOIN Factura fx ON fx.fact_tipo = x.item_tipo AND fx.fact_sucursal = x.item_sucursal AND fx.fact_numero = x.item_numero
                  WHERE x.item_producto = pa.cod_prod
                    AND CONVERT(CHAR(6), fx.fact_fecha, 112) = pa.periodo)
       OR EXISTS (SELECT 1
                  FROM deleted x
                  JOIN Factura fx ON fx.fact_tipo = x.item_tipo AND fx.fact_sucursal = x.item_sucursal AND fx.fact_numero = x.item_numero
                  WHERE x.item_producto = pa.cod_prod
                    AND CONVERT(CHAR(6), fx.fact_fecha, 112) = pa.periodo)

    -- 2) recalculo esos mismos pares desde las ventas reales
    INSERT INTO ProductosAcumulados (cod_prod, periodo, cantProdXperiodo, precioMax, precioMin, importeTotal)
    SELECT i.item_producto,
           CONVERT(CHAR(6), f.fact_fecha, 112),
           SUM(i.item_cantidad), MAX(i.item_precio), MIN(i.item_precio),
           SUM(i.item_cantidad * i.item_precio)
    FROM Item_Factura i
    JOIN Factura f ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
    WHERE EXISTS (SELECT 1
                  FROM inserted x
                  JOIN Factura fx ON fx.fact_tipo = x.item_tipo AND fx.fact_sucursal = x.item_sucursal AND fx.fact_numero = x.item_numero
                  WHERE x.item_producto = i.item_producto
                    AND CONVERT(CHAR(6), fx.fact_fecha, 112) = CONVERT(CHAR(6), f.fact_fecha, 112))
       OR EXISTS (SELECT 1
                  FROM deleted x
                  JOIN Factura fx ON fx.fact_tipo = x.item_tipo AND fx.fact_sucursal = x.item_sucursal AND fx.fact_numero = x.item_numero
                  WHERE x.item_producto = i.item_producto
                    AND CONVERT(CHAR(6), fx.fact_fecha, 112) = CONVERT(CHAR(6), f.fact_fecha, 112))
    GROUP BY i.item_producto, CONVERT(CHAR(6), f.fact_fecha, 112)
END
GO

-- Consulta para probar que funcione la logica
SELECT
    ins.item_producto AS Cod_Prod,
    CAST(YEAR(f.fact_fecha) AS CHAR(4)) + RIGHT('0' + CAST(MONTH(f.fact_fecha) AS VARCHAR(2)), 2) AS Periodo,
    SUM(ins.item_cantidad) AS CantidadProds,
    MAX(ins.item_precio),
    MIN(ins.item_precio),
    SUM(ins.item_cantidad * ins.item_precio)
FROM Item_Factura ins
JOIN Factura f ON f.fact_tipo = ins.item_tipo AND f.fact_sucursal = ins.item_sucursal AND f.fact_numero = ins.item_numero
GROUP BY ins.item_producto, YEAR(f.fact_fecha), MONTH(f.fact_fecha)
-- HAVING MAX(ins.item_precio) <> MIN(ins.item_precio) corrobora con la cant de filas de la consulta de abajo
SELECT 
    i.item_producto, 
    YEAR(f.fact_fecha) AS Anio, 
    MONTH(f.fact_fecha) AS Mes,
    COUNT(DISTINCT i.item_precio) AS PreciosDistintos
FROM Item_Factura i
JOIN Factura f ON f.fact_tipo = i.item_tipo 
              AND f.fact_sucursal = i.item_sucursal 
              AND f.fact_numero = i.item_numero
GROUP BY i.item_producto, YEAR(f.fact_fecha), MONTH(f.fact_fecha)
HAVING COUNT(DISTINCT i.item_precio) > 1;
-- Fin consulta

-- SQL
/* Mostrar código y apellido de los jefes que tienen más de 2 empleados a cargo y ganan menos que el promedio de sueldo de sus subordinados. */ 
SELECT 
    j.empl_codigo AS Cod_Jefe,
    j.empl_apellido AS Apellido_Jefe
FROM Empleado j
JOIN Empleado e ON e.empl_jefe = j.empl_codigo
WHERE (j.empl_salario) < ( SELECT (SUM(e2.empl_salario)/ count(e2.empl_codigo)) 
                           FROM Empleado e2
                           WHERE e2.empl_jefe = J.empl_codigo)

GROUP BY j.empl_codigo, j.empl_apellido
HAVING COUNT(e.empl_codigo) > 2 
---------------
SELECT 
    j.empl_codigo AS Codigo_Jefe,
    e.empl_codigo AS Codigo_Empleado,
    RTRIM(e.empl_nombre) + ' ' + RTRIM(e.empl_apellido) AS Nombre_Empleado,
    (SELECT COUNT(*) FROM DEPOSITO d WHERE d.depo_encargado = j.empl_codigo) AS Depositos_Jefe,
    (SELECT COUNT(*) FROM DEPOSITO d WHERE d.depo_encargado = e.empl_codigo) AS Depositos_Empleado
FROM Empleado e
JOIN Empleado j ON e.empl_jefe = j.empl_codigo;

SELECT * FROM Empleado ORDER BY 1
-----
/* Parcial 04/11/2026 
1. SQL
Realizar una consulta SQL que retorne todos los clientes que nunca hayan comprado productos compuestos
y cuyo total de unidades compradas a lo largo de toda la historia sea superior a 10000.
De estos clientes mostrar:
- Razon Social del cliente
- La cantidad de productos distintos que compraron durante el año 2021
- La cantidad de facturas correspondientes al año 2021
- La fecha de la ultima compra realizada por el cliente
Nota: No se permiten SELECT en el FROM */
SELECT 
    c.clie_razon_social AS Razon_Social_Cli,
    ISNULL((SELECT COUNT(DISTINCT i.item_producto)
            FROM Factura f1
            JOIN Item_Factura i ON f1.fact_tipo = i.item_tipo AND f1.fact_sucursal = i.item_sucursal AND f1.fact_numero = i.item_numero
            WHERE f1.fact_cliente = c.clie_codigo
                AND YEAR(f1.fact_fecha) = 2012
            ),0) AS Cant_Prod_Dist_2021,
    ISNULL((SELECT COUNT(*)
            FROM Factura f1
            WHERE f1.fact_cliente = c.clie_codigo
                AND YEAR(f1.fact_fecha) = 2012
            ),0) AS Cant_Fact_2021,
    MAX(f.fact_fecha) AS Fecha_Ultima_Compra
FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura i ON f.fact_tipo = i.item_tipo AND f.fact_sucursal = i.item_sucursal AND f.fact_numero = i.item_numero
WHERE NOT EXISTS (SELECT 1
                  FROM Factura f3
                  JOIN Item_Factura i3 ON f3.fact_tipo = i3.item_tipo
                                      AND f3.fact_sucursal = i3.item_sucursal
                                      AND f3.fact_numero = i3.item_numero
                  WHERE f3.fact_cliente = c.clie_codigo
                    AND i3.item_producto IN (SELECT comp_producto FROM Composicion))
GROUP BY c.clie_codigo, c.clie_razon_social
HAVING SUM(i.item_cantidad) > 10000
GO
/* 
2. Implementar el/los objetos necesarios para que se cumpla siempre la siguiente regla de negocio:
El campo fact_total de una factura debe ser igual a la sumatoria de los importes de todos sus items,
calculados como item_cantidad * item_precio. */
-- 1) Depuración: dejo cada fact_total igual a la suma de sus ítems
-- Supuesto: las facturas sin ítems no se tocan (en la base hay algunas).
CREATE OR ALTER PROCEDURE SP_DEPURAR_FACT_TOTAL
AS
BEGIN
    UPDATE f
    SET f.fact_total = (SELECT SUM(i.item_cantidad * i.item_precio)
                        FROM Item_Factura i
                        WHERE i.item_tipo = f.fact_tipo
                          AND i.item_sucursal = f.fact_sucursal
                          AND i.item_numero = f.fact_numero)
    FROM Factura f
    WHERE EXISTS (SELECT 1
                  FROM Item_Factura i
                  WHERE i.item_tipo = f.fact_tipo
                    AND i.item_sucursal = f.fact_sucursal
                    AND i.item_numero = f.fact_numero)
      AND f.fact_total <> (SELECT SUM(i.item_cantidad * i.item_precio)
                           FROM Item_Factura i
                           WHERE i.item_tipo = f.fact_tipo
                             AND i.item_sucursal = f.fact_sucursal
                             AND i.item_numero = f.fact_numero)
END
GO

-- 2) se ejecuta una sola vez, antes de crear los triggers
EXEC SP_DEPURAR_FACT_TOTAL
GO

-- 3) después van los dos triggers (Item_Factura y Factura) que ya tenés
CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_TOTAL ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    UPDATE f
    SET f.fact_total = ISNULL((SELECT SUM(i.item_cantidad * i.item_precio)
                               FROM Item_Factura i
                               WHERE i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero), 0)
    FROM Factura f
    WHERE EXISTS (SELECT 1 FROM inserted x
                  WHERE x.item_tipo = f.fact_tipo AND x.item_sucursal = f.fact_sucursal AND x.item_numero = f.fact_numero)
       OR EXISTS (SELECT 1 FROM deleted x
                  WHERE x.item_tipo = f.fact_tipo AND x.item_sucursal = f.fact_sucursal AND x.item_numero = f.fact_numero)
END
GO
-- V1 PARA TRIGGER SOBRE FACTURA, MOSTRAMOS ERROR
CREATE OR ALTER TRIGGER TR_FACT_TOTAL ON Factura
AFTER UPDATE -- el INSERT no aporta: aún no hay ítems
AS
BEGIN
    IF UPDATE(fact_total)
       AND EXISTS (SELECT 1
                   FROM inserted ins
                   WHERE ins.fact_total != (SELECT SUM(i.item_cantidad * i.item_precio)
                                            FROM Item_Factura i
                                            WHERE i.item_tipo = ins.fact_tipo AND i.item_sucursal = ins.fact_sucursal AND i.item_numero = ins.fact_numero))
    BEGIN
        RAISERROR('El total de la factura debe ser la suma de sus ítems.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO
-- V2 PARA TRIGGER SOBRE FACTURA, ARREGLAMOS A MANO EL ERROR
CREATE OR ALTER TRIGGER TR_FACTURA_TOTAL ON Factura
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    -- Alta: el total siempre arranca en 0
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO Factura (fact_tipo, fact_sucursal, fact_numero, fact_fecha,
                             fact_vendedor, fact_total, fact_total_impuestos, fact_cliente)
        SELECT fact_tipo, fact_sucursal, fact_numero, fact_fecha,
               fact_vendedor, 0, fact_total_impuestos, fact_cliente
        FROM inserted;
        RETURN;
    END;

    IF UPDATE(fact_tipo) OR UPDATE(fact_sucursal) OR UPDATE(fact_numero)
        THROW 50001, 'No se permite modificar la clave de una factura.', 1;

    IF TRIGGER_NESTLEVEL(OBJECT_ID('TR_ITEM_FACTURA_TOTAL')) > 0
    BEGIN
        -- Viene del trigger de ítems: aplica solo la diferencia sobre el valor actual
        UPDATE F
        SET fact_total = F.fact_total + (I.fact_total - D.fact_total)
        FROM Factura F
        JOIN inserted I ON  I.fact_tipo = F.fact_tipo AND I.fact_sucursal = F.fact_sucursal AND I.fact_numero = F.fact_numero
        JOIN deleted D ON  D.fact_tipo = F.fact_tipo AND D.fact_sucursal = F.fact_sucursal AND D.fact_numero = F.fact_numero;
    END
    ELSE
    BEGIN
        -- Modificación directa: el total se recalcula desde los ítems
        UPDATE F
        SET fact_fecha = I.fact_fecha,
            fact_vendedor = I.fact_vendedor,
            fact_cliente = I.fact_cliente,
            fact_total_impuestos = I.fact_total_impuestos,
            fact_total = ISNULL((SELECT SUM(IT.item_cantidad * IT.item_precio)
                                 FROM Item_Factura IT
                                 WHERE IT.item_tipo     = F.fact_tipo
                                   AND IT.item_sucursal = F.fact_sucursal
                                   AND IT.item_numero   = F.fact_numero), 0)
        FROM Factura F
        JOIN inserted I ON I.fact_tipo = F.fact_tipo AND I.fact_sucursal = F.fact_sucursal AND I.fact_numero = F.fact_numero;
    END;
END;
GO
-----------------------------------------------------------------------------------------------------------------------------------
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


/* =====================================================================
   5) SIMULAR UNA PRIMARY KEY (sin constraint) - ej: Cliente.clie_codigo
   PK = ÚNICA + NO NULL. Dos controles en un trigger AFTER INSERT, UPDATE.
   (Es el mismo patrón que el UNIQUE de prod_detalle del parcial 08/07/2026,
   más el control de NULL.)
   Si ya hubiera datos que no cumplen, primero un procedure de depuración
   (ver SP_DEPURAR_CLIENTES_CUIT) y recién después el trigger.
   ===================================================================== */
CREATE OR ALTER TRIGGER TR_PK_CLIENTE ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
    -- 1) la clave no puede ser NULL
    IF EXISTS (SELECT 1 FROM inserted WHERE clie_codigo IS NULL)
    BEGIN
        RAISERROR('La clave primaria no puede ser NULL.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END

    -- 2) la clave no puede repetirse (se miran solo las claves tocadas)
    IF EXISTS (SELECT 1
               FROM Cliente
               WHERE clie_codigo IN (SELECT clie_codigo FROM inserted)
               GROUP BY clie_codigo
               HAVING COUNT(*) > 1)
    BEGIN
        RAISERROR('La clave primaria no puede repetirse.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO
-- Nota: no usé "c.clie_codigo <> i.clie_codigo" como en los UNIQUE de otras columnas, porque
-- justamente la clave es lo que se repite: sin constraint no hay otra columna que distinga las filas.
-- Si el enunciado dice que la columna ya es NOT NULL, el punto 1 sobra.
-- Si otra tabla referencia a esta (FK real), no se puede dar de baja la PK real: por eso se simula.


/* =====================================================================
   6) PARCIAL 15/11/2022 - COMPONER COMBOS AL INSERTAR (INSTEAD OF INSERT, solo inserción)
   Si en una factura se guardan 2 hamburguesas, 2 papas y 2 gaseosas, guardar 2 COMBO1
   (1 combo = 1 hamb + 1 papa + 1 gaseosa). Todos los ítems de la factura llegan en la
   misma sentencia INSERT.
   Idea: 1) detecto qué combos se pueden armar y cuántos  2) inserto los combos
         3) inserto lo que sobra (componentes que no entraron en un combo).
   ===================================================================== */
CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_COMPONER ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN
    DECLARE @combos TABLE (tipo CHAR(1), sucursal CHAR(4), numero CHAR(8),
                           combo CHAR(8), cant DECIMAL(12,2))

    -- 1) combos completos: la factura trae TODOS los componentes del compuesto,
    --    y la cantidad de combos es lo que alcanza del componente más escaso
    INSERT INTO @combos (tipo, sucursal, numero, combo, cant)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero, c.comp_producto,
           MIN(FLOOR(i.item_cantidad / c.comp_cantidad))
    FROM inserted i
    JOIN Composicion c ON c.comp_componente = i.item_producto
    GROUP BY i.item_tipo, i.item_sucursal, i.item_numero, c.comp_producto
    HAVING COUNT(DISTINCT c.comp_componente) = (SELECT COUNT(*)
                                                FROM Composicion c2
                                                WHERE c2.comp_producto = c.comp_producto)
       AND MIN(FLOOR(i.item_cantidad / c.comp_cantidad)) > 0

    -- 2) inserto los combos
    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT cb.tipo, cb.sucursal, cb.numero, cb.combo, cb.cant, p.prod_precio
    FROM @combos cb
    JOIN Producto p ON p.prod_codigo = cb.combo

    -- 3) inserto lo que sobra de cada ítem (cantidad original menos lo que se fue en combos)
    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero, i.item_producto,
           i.item_cantidad - ISNULL((SELECT SUM(cb.cant * c.comp_cantidad)
                                     FROM @combos cb
                                     JOIN Composicion c ON c.comp_producto = cb.combo
                                     WHERE cb.tipo = i.item_tipo
                                       AND cb.sucursal = i.item_sucursal
                                       AND cb.numero = i.item_numero
                                       AND c.comp_componente = i.item_producto), 0),
           i.item_precio
    FROM inserted i
    WHERE i.item_cantidad - ISNULL((SELECT SUM(cb.cant * c.comp_cantidad)
                                    FROM @combos cb
                                    JOIN Composicion c ON c.comp_producto = cb.combo
                                    WHERE cb.tipo = i.item_tipo
                                      AND cb.sucursal = i.item_sucursal
                                      AND cb.numero = i.item_numero
                                      AND c.comp_componente = i.item_producto), 0) > 0
END
GO
-- Cómo se lee: un componente "pertenece" a un combo si aparece en Composicion. Un combo se arma si
-- la factura trae todos sus componentes (COUNT DISTINCT = cantidad de componentes del combo).
-- Con 2 hamb / 2 papas / 2 gaseosas: MIN(2/1) = 2 combos y no sobra nada.
-- Con 3 hamb / 2 papas / 2 gaseosas: 2 combos y sobra 1 hamburguesa, que se inserta suelta.
-- Supuesto: un componente pertenece a un solo combo (si fuera de varios, habría que elegir cuál priorizar).
-- Un producto vendido solo (que no es componente de nada) no entra en la consulta de combos,
-- pero sí en el paso 3 (no tiene combos, entonces no resta nada y se inserta completo).

-----------------------------------------------------------------------------------------------------------------------------------
/* =====================================================================
   PARCIALES SQL RESUELTOS (restricción de todos: SIN sub-select en el FROM, SIN CTE)
   Para estudiar: tapá la solución, escribila vos y compará.
   Orden: 1) 04/11/2026  2) 01/07/2026  3) 08/07/2026  4) 12/07/2025  5) 28/06/2025
   Los demás (28/07/2023, 06/07/2022, recuperatorio, 2022 de noviembre) están en tu PracSQL.sql.
   ===================================================================== */


/* =====================================================================
   1) PARCIAL 04/11/2026
   Clientes que NUNCA compraron productos compuestos y cuyo total de unidades
   compradas en toda la historia sea > 10.000. Mostrar: razón social, productos
   distintos en 2021, cantidad de facturas de 2021, fecha de la última compra.
   CLAVE: "nunca" es una condición POR CLIENTE -> NOT EXISTS, no un filtro de filas.
   ===================================================================== */
SELECT
    c.clie_razon_social AS Razon_Social,
    (SELECT COUNT(DISTINCT i2.item_producto)
     FROM Factura f2
     JOIN Item_Factura i2 ON i2.item_tipo = f2.fact_tipo
                         AND i2.item_sucursal = f2.fact_sucursal
                         AND i2.item_numero = f2.fact_numero
     WHERE f2.fact_cliente = c.clie_codigo
       AND YEAR(f2.fact_fecha) = 2021) AS Productos_Distintos_2021,
    (SELECT COUNT(*)
     FROM Factura f1
     WHERE f1.fact_cliente = c.clie_codigo
       AND YEAR(f1.fact_fecha) = 2021) AS Facturas_2021,
    MAX(f.fact_fecha) AS Ultima_Compra
FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura i ON i.item_tipo = f.fact_tipo
                   AND i.item_sucursal = f.fact_sucursal
                   AND i.item_numero = f.fact_numero
WHERE NOT EXISTS (SELECT 1
                  FROM Factura f3
                  JOIN Item_Factura i3 ON i3.item_tipo = f3.fact_tipo
                                      AND i3.item_sucursal = f3.fact_sucursal
                                      AND i3.item_numero = f3.fact_numero
                  WHERE f3.fact_cliente = c.clie_codigo
                    AND i3.item_producto IN (SELECT comp_producto FROM Composicion))
GROUP BY c.clie_codigo, c.clie_razon_social
HAVING SUM(i.item_cantidad) > 10000
-- Variante sin subquery: sacar el NOT EXISTS y agregar al HAVING:
--   AND COUNT(CASE WHEN i.item_producto IN (SELECT comp_producto FROM Composicion) THEN 1 END) = 0


/* =====================================================================
   2) PARCIAL 01/07/2026 - pares del mismo rubro y envase vendidos juntos > 50 veces en 2011
   Columnas: nro de fila, producto 1, producto 2, rubro, envase, % de unidades del par
   sobre el total de unidades vendidas en el año. Sin NULL. Orden por nombre del producto 1.
   (La resolución del compañero tenía HAVING > 5 en vez de 50.)
   Supuesto: "unidades del par" = unidades de ambos productos en las facturas donde se vendieron juntos.
   ===================================================================== */
SELECT
    ROW_NUMBER() OVER (ORDER BY p1.prod_detalle, p2.prod_detalle) AS Nro_Fila,
    p1.prod_detalle AS Producto_1,
    p2.prod_detalle AS Producto_2,
    r.rubr_detalle  AS Rubro,
    e.enva_detalle  AS Envase,
    CAST(SUM(i1.item_cantidad + i2.item_cantidad) * 100.0 /
         (SELECT SUM(i3.item_cantidad)
          FROM Item_Factura i3
          JOIN Factura f3 ON f3.fact_tipo = i3.item_tipo
                         AND f3.fact_sucursal = i3.item_sucursal
                         AND f3.fact_numero = i3.item_numero
          WHERE YEAR(f3.fact_fecha) = 2011) AS DECIMAL(12,2)) AS Porcentaje_Unidades
FROM Factura f
JOIN Item_Factura i1 ON i1.item_tipo = f.fact_tipo
                    AND i1.item_sucursal = f.fact_sucursal
                    AND i1.item_numero = f.fact_numero
JOIN Item_Factura i2 ON i2.item_tipo = f.fact_tipo
                    AND i2.item_sucursal = f.fact_sucursal
                    AND i2.item_numero = f.fact_numero
JOIN Producto p1 ON p1.prod_codigo = i1.item_producto
JOIN Producto p2 ON p2.prod_codigo = i2.item_producto
JOIN Rubro r ON r.rubr_id = p1.prod_rubro
JOIN Envases e ON e.enva_codigo = p1.prod_envase
WHERE YEAR(f.fact_fecha) = 2011
  AND p1.prod_rubro  = p2.prod_rubro
  AND p1.prod_envase = p2.prod_envase
  AND p1.prod_detalle < p2.prod_detalle      -- evita el par con sí mismo, evita A-B y B-A, y deja el 1 antes que el 2
GROUP BY p1.prod_codigo, p1.prod_detalle, p2.prod_codigo, p2.prod_detalle, r.rubr_detalle, e.enva_detalle
HAVING COUNT(DISTINCT f.fact_tipo + f.fact_sucursal + f.fact_numero) > 50
ORDER BY p1.prod_detalle, p2.prod_detalle


/* =====================================================================
   3) PARCIAL 08/07/2026 - por cliente: razón social, período AAAAMM de mayor compra
   (en CANTIDADES), productos distintos adquiridos, importe total facturado.
   Orden: cantidad de facturas DESC. Sin sub-select en el FROM ni CTE.
   Supuesto: solo aparecen clientes con al menos una factura.
   ===================================================================== */
SELECT
    c.clie_razon_social AS Razon_Social,
    (SELECT TOP 1 CONVERT(CHAR(6), fp.fact_fecha, 112)
     FROM Factura fp
     JOIN Item_Factura ip ON ip.item_tipo = fp.fact_tipo
                         AND ip.item_sucursal = fp.fact_sucursal
                         AND ip.item_numero = fp.fact_numero
     WHERE fp.fact_cliente = c.clie_codigo
     GROUP BY CONVERT(CHAR(6), fp.fact_fecha, 112)
     ORDER BY SUM(ip.item_cantidad) DESC, CONVERT(CHAR(6), fp.fact_fecha, 112)) AS Periodo_Mayor_Cantidad,
    (SELECT COUNT(DISTINCT i2.item_producto)
     FROM Factura f2
     JOIN Item_Factura i2 ON i2.item_tipo = f2.fact_tipo
                         AND i2.item_sucursal = f2.fact_sucursal
                         AND i2.item_numero = f2.fact_numero
     WHERE f2.fact_cliente = c.clie_codigo) AS Productos_Distintos,
    SUM(f.fact_total) AS Importe_Total        -- fact_total OK: acá NO hay join con Item_Factura
FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
GROUP BY c.clie_codigo, c.clie_razon_social
ORDER BY COUNT(*) DESC                         -- COUNT(*) = cantidad de facturas del cliente


/* =====================================================================
   4) PARCIAL 12/07/2025 - productos comprados en TODOS los años impares registrados
   Columnas: nro de fila, nombre, monto comprado (ARS). Orden: cantidad comprada
   en el último año, DESC. Sin sub-select en el FROM, sin WITH.
   CLAVE: "todos los X" -> HAVING COUNT(DISTINCT x) = (total de X).
   ===================================================================== */
SELECT
    ROW_NUMBER() OVER (ORDER BY
        ISNULL((SELECT SUM(iu.item_cantidad)
                FROM Item_Factura iu
                JOIN Factura fu ON fu.fact_tipo = iu.item_tipo
                               AND fu.fact_sucursal = iu.item_sucursal
                               AND fu.fact_numero = iu.item_numero
                WHERE iu.item_producto = p.prod_codigo
                  AND YEAR(fu.fact_fecha) = (SELECT MAX(YEAR(fx.fact_fecha)) FROM Factura fx)), 0) DESC,
        p.prod_codigo) AS Nro_Fila,
    p.prod_detalle AS Nombre_Producto,
    SUM(i.item_cantidad * i.item_precio) AS Monto_Comprado_ARS
FROM Producto p
JOIN Item_Factura i ON i.item_producto = p.prod_codigo
JOIN Factura f ON f.fact_tipo = i.item_tipo
              AND f.fact_sucursal = i.item_sucursal
              AND f.fact_numero = i.item_numero
GROUP BY p.prod_codigo, p.prod_detalle
HAVING COUNT(DISTINCT CASE WHEN YEAR(f.fact_fecha) % 2 = 1 THEN YEAR(f.fact_fecha) END) =
       (SELECT COUNT(DISTINCT YEAR(f2.fact_fecha))
        FROM Factura f2
        WHERE YEAR(f2.fact_fecha) % 2 = 1)
ORDER BY Nro_Fila


/* =====================================================================
   5) PARCIAL 28/06/2025 - clientes que compraron productos de los 10 más vendidos de 2012
   O de los 10 menos vendidos (empates incluidos). Columnas: nro de fila, cliente,
   si está en el ranking de más vendidos, cantidad de facturas. Orden: monto total DESC.
   CLAVE: "incluso si hay más de 10 con el mismo valor mínimo" -> TOP 10 WITH TIES.
   Supuesto: monto y facturas del cliente de 2012.
   ===================================================================== */
SELECT
    ROW_NUMBER() OVER (ORDER BY
        ISNULL((SELECT SUM(f2.fact_total)
                FROM Factura f2
                WHERE f2.fact_cliente = c.clie_codigo
                  AND YEAR(f2.fact_fecha) = 2012), 0) DESC) AS Nro_Fila,
    c.clie_razon_social AS Cliente,
    CASE WHEN EXISTS (SELECT 1
                      FROM Factura f
                      JOIN Item_Factura i ON i.item_tipo = f.fact_tipo
                                         AND i.item_sucursal = f.fact_sucursal
                                         AND i.item_numero = f.fact_numero
                      WHERE f.fact_cliente = c.clie_codigo
                        AND YEAR(f.fact_fecha) = 2012
                        AND i.item_producto IN (SELECT TOP 10 i2.item_producto
                                                FROM Item_Factura i2
                                                JOIN Factura f2 ON f2.fact_tipo = i2.item_tipo
                                                               AND f2.fact_sucursal = i2.item_sucursal
                                                               AND f2.fact_numero = i2.item_numero
                                                WHERE YEAR(f2.fact_fecha) = 2012
                                                GROUP BY i2.item_producto
                                                ORDER BY SUM(i2.item_cantidad) DESC))
         THEN 'SI' ELSE 'NO' END AS En_Ranking_Mas_Vendidos,
    (SELECT COUNT(*)
     FROM Factura fc
     WHERE fc.fact_cliente = c.clie_codigo
       AND YEAR(fc.fact_fecha) = 2012) AS Cant_Facturas
FROM Cliente c
WHERE EXISTS (SELECT 1
              FROM Factura f
              JOIN Item_Factura i ON i.item_tipo = f.fact_tipo
                                 AND i.item_sucursal = f.fact_sucursal
                                 AND i.item_numero = f.fact_numero
              WHERE f.fact_cliente = c.clie_codigo
                AND YEAR(f.fact_fecha) = 2012
                AND (i.item_producto IN (SELECT TOP 10 i3.item_producto
                                         FROM Item_Factura i3
                                         JOIN Factura f3 ON f3.fact_tipo = i3.item_tipo
                                                        AND f3.fact_sucursal = i3.item_sucursal
                                                        AND f3.fact_numero = i3.item_numero
                                         WHERE YEAR(f3.fact_fecha) = 2012
                                         GROUP BY i3.item_producto
                                         ORDER BY SUM(i3.item_cantidad) DESC)
                  OR i.item_producto IN (SELECT TOP 10 WITH TIES i4.item_producto
                                         FROM Item_Factura i4
                                         JOIN Factura f4 ON f4.fact_tipo = i4.item_tipo
                                                        AND f4.fact_sucursal = i4.item_sucursal
                                                        AND f4.fact_numero = i4.item_numero
                                         WHERE YEAR(f4.fact_fecha) = 2012
                                         GROUP BY i4.item_producto
                                         ORDER BY SUM(i4.item_cantidad) ASC)))
ORDER BY Nro_Fila
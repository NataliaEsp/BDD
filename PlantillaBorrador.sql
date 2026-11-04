/* =====================================================================
   PLANTILLAS T-SQL PARA EL PARCIAL (carpeta abierta)
   Modelo: Cliente, Factura, Item_Factura, Producto, Stock, Composicion, etc.
   Regla de oro: pensar en CONJUNTOS (inserted / deleted), sin cursor.
   ===================================================================== */

/* ---------------------------------------------------------------------
   0. ¿QUÉ OBJETO USO?  (traducir el enunciado)
   ---------------------------------------------------------------------
   "siempre se cumpla" / "regla"                -> TRIGGER
   "rechazar / no permitir / cancelar"          -> AFTER + RAISERROR + ROLLBACK
   "guardar solo lo válido / reemplazar insert" -> INSTEAD OF
   "ya hay datos mal"                           -> PROCEDURE de depuración + trigger a futuro
   "en una sola transacción"                    -> PROCEDURE con BEGIN TRANSACTION
   "simular constraint (FK / UNIQUE)"           -> TRIGGER(s) en cada tabla que pueda romper la regla
   "dado X devolver Y" (usable en un SELECT)    -> FUNCTION
   --------------------------------------------------------------------- */

/* ---------------------------------------------------------------------
   1. TRIGGER AFTER: VALIDAR Y REVERTIR  (ej: FK Cliente -> Provincia)
   - El cambio YA se aplicó; si está mal, se deshace con ROLLBACK.
   - IF EXISTS pregunta "¿hay algún PROBLEMA?". Si no hay, no hace nada.
   - Con BEGIN TRANSACTION explícito, el RETURN después del ROLLBACK
     es OBLIGATORIO (si no, el COMMIT falla: ya no hay transacción).
   - Sin BEGIN TRANSACTION alcanza con BEGIN ... END (más corto, menos riesgo).
   --------------------------------------------------------------------- */

-- Lado hijo: cliente no puede apuntar a provincia inexistente
CREATE TRIGGER TR_CLIENTE_FK_PROVINCIA ON Cliente
AFTER INSERT, UPDATE
AS
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE   -- por si el profe lo pide (va ANTES del BEGIN TRANSACTION)
BEGIN TRANSACTION
    IF EXISTS (SELECT 1
               FROM inserted i
               WHERE i.pcia_id IS NOT NULL          -- una FK nullable permite NULL
                 AND NOT EXISTS (SELECT 1 FROM Provincia p WHERE p.id = i.pcia_id))
    BEGIN
        RAISERROR('La provincia indicada no existe.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
COMMIT TRANSACTION
GO

-- Lado padre (1): no borrar una provincia usada por clientes
CREATE TRIGGER TR_PROVINCIA_DELETE ON Provincia
AFTER DELETE
AS
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRANSACTION
    IF EXISTS (SELECT 1
               FROM deleted d
               JOIN Cliente c ON c.pcia_id = d.id)
    BEGIN
        RAISERROR('No se puede borrar: hay clientes con esa provincia.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
COMMIT TRANSACTION
GO

-- Lado padre (2): no cambiar el id de una provincia usada (versión del profe)
-- En un UPDATE: deleted = valores viejos, inserted = valores nuevos.
-- "id viejo que no está entre los nuevos" = el id cambió.
CREATE TRIGGER TR_PROVINCIA_UPDATE ON Provincia
AFTER UPDATE
AS
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRANSACTION
    IF EXISTS (SELECT 1 FROM deleted WHERE id NOT IN (SELECT id FROM inserted))
    BEGIN
        IF EXISTS (SELECT 1
                   FROM Cliente
                   WHERE pcia_id IN (SELECT id FROM deleted)
                     AND pcia_id NOT IN (SELECT id FROM inserted))
        BEGIN
            RAISERROR('No se puede cambiar el id: hay clientes con esa provincia.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END
    END
COMMIT TRANSACTION
GO

-- Alternativa "a lo bruto" (un solo trigger por tabla, revisa el estado final):
--   IF EXISTS (SELECT 1 FROM Cliente WHERE pcia_id NOT IN (SELECT id FROM Provincia)) ...
-- (NULL NOT IN (...) da desconocido, así que los NULL no se marcan: correcto para una FK)


/* ---------------------------------------------------------------------
   2. TRIGGER INSTEAD OF: REEMPLAZA LA OPERACIÓN
   - El INSERT/DELETE original NO ocurre: lo hago yo a mano.
   - Un INSTEAD OF sobre una tabla no se dispara a sí mismo
     (puedo insertar en la misma tabla sin recursión).
   --------------------------------------------------------------------- */

-- 2a. DELETE en cascada: borrar de HIJO a PADRE
--     Item_Factura -> Factura -> Cliente
CREATE TRIGGER TR_DELETE_CASCADA_CLIENTE ON Cliente
INSTEAD OF DELETE
AS
BEGIN
    DELETE i
    FROM Item_Factura i
    JOIN Factura f ON i.item_tipo = f.fact_tipo
                  AND i.item_sucursal = f.fact_sucursal
                  AND i.item_numero = f.fact_numero
    JOIN deleted d ON d.clie_codigo = f.fact_cliente

    DELETE f
    FROM Factura f
    JOIN deleted d ON d.clie_codigo = f.fact_cliente

    DELETE c
    FROM Cliente c
    JOIN deleted d ON d.clie_codigo = c.clie_codigo
END
GO

-- 2b. INSERT que corrige/filtra y deja registro (ej: precio siempre = prod_precio)
CREATE TABLE Log_Precio_Item_Factura (
    item_producto    CHAR(8),
    precio_intentado DECIMAL(12,2),
    precio_correcto  DECIMAL(12,2),
    fecha            SMALLDATETIME
)
GO

CREATE TRIGGER TR_ITEM_FACTURA_PRECIO ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN
    -- 1) registro los intentos con precio distinto
    INSERT INTO Log_Precio_Item_Factura (item_producto, precio_intentado, precio_correcto, fecha)
    SELECT i.item_producto, i.item_precio, p.prod_precio, GETDATE()
    FROM inserted i
    JOIN Producto p ON p.prod_codigo = i.item_producto
    WHERE i.item_precio <> p.prod_precio

    -- 2) inserto lo que corresponde (con el precio correcto)
    INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero,
                              item_producto, item_cantidad, item_precio)
    SELECT i.item_tipo, i.item_sucursal, i.item_numero,
           i.item_producto, i.item_cantidad, p.prod_precio
    FROM inserted i
    JOIN Producto p ON p.prod_codigo = i.item_producto
END
GO

-- 2c. Si hay que "rechazar o insertar" según una condición: IF EXISTS(<malo>) RAISERROR ... ELSE INSERT ... SELECT FROM inserted


/* ---------------------------------------------------------------------
   3. PROCEDURE CON TRANSACCIÓN ("en una sola transacción")
   - En un procedure NADIE abrió una transacción por vos: la abrís vos.
   - SET XACT_ABORT ON: si hay un error en runtime, se hace rollback solo.
   - Estructura: BEGIN (cuerpo) > BEGIN TRANSACTION > operaciones > COMMIT
   --------------------------------------------------------------------- */
CREATE TABLE Proveedor (
    prov_codigo INT PRIMARY KEY,
    prov_nombre CHAR(100)
)
CREATE TABLE Compra (
    comp_codigo    INT PRIMARY KEY,
    comp_fecha     SMALLDATETIME,
    comp_proveedor INT REFERENCES Proveedor(prov_codigo)
)
CREATE TABLE Detalle_Compra (
    comp_codigo INT      REFERENCES Compra(comp_codigo),
    prod_codigo CHAR(8)  REFERENCES Producto(prod_codigo),
    depo_codigo CHAR(2)  REFERENCES DEPOSITO(depo_codigo),
    cantidad    DECIMAL(12,2),
    precio      DECIMAL(12,2),
    PRIMARY KEY (comp_codigo, prod_codigo, depo_codigo)
)
GO

CREATE PROCEDURE SP_REGISTRAR_COMPRA
    @comp_codigo INT,
    @comp_fecha  SMALLDATETIME,
    @prov_codigo INT,
    @prod_codigo CHAR(8),
    @depo_codigo CHAR(2),
    @cantidad    DECIMAL(12,2),
    @precio      DECIMAL(12,2)
AS
BEGIN
    SET XACT_ABORT ON
    BEGIN TRANSACTION

        -- crear la compra si no existe
        IF NOT EXISTS (SELECT 1 FROM Compra WHERE comp_codigo = @comp_codigo)
            INSERT INTO Compra (comp_codigo, comp_fecha, comp_proveedor)
            VALUES (@comp_codigo, @comp_fecha, @prov_codigo)

        -- detalle (producto + depósito de destino)
        INSERT INTO Detalle_Compra (comp_codigo, prod_codigo, depo_codigo, cantidad, precio)
        VALUES (@comp_codigo, @prod_codigo, @depo_codigo, @cantidad, @precio)

        -- stock: si ya existe la fila suma, si no la crea
        IF EXISTS (SELECT 1 FROM Stock
                   WHERE stoc_producto = @prod_codigo AND stoc_deposito = @depo_codigo)
            UPDATE Stock
            SET stoc_cantidad = ISNULL(stoc_cantidad, 0) + @cantidad
            WHERE stoc_producto = @prod_codigo AND stoc_deposito = @depo_codigo
        ELSE
            INSERT INTO Stock (stoc_producto, stoc_deposito, stoc_cantidad,
                               stoc_punto_reposicion, stoc_stock_maximo)
            VALUES (@prod_codigo, @depo_codigo, @cantidad, 0, 0)

    COMMIT TRANSACTION
END
GO


/* ---------------------------------------------------------------------
   4. DEPURACIÓN + TRIGGER A FUTURO  (el patrón MÁS repetido del profe)
   Paso 1: procedure que arregla los datos que ya están mal.
   Paso 2: trigger que impide que vuelva a pasar.
   --------------------------------------------------------------------- */

-- 4a. UNIQUE simulado sobre Producto.prod_detalle
CREATE PROCEDURE SP_ARREGLAR_PROD_DETALLE
AS
BEGIN
    BEGIN TRANSACTION
        -- a los repetidos les agrego el código (único, es PK): 41 + '-' + 8 = 50 = tamaño de la columna
        UPDATE Producto
        SET prod_detalle = LEFT(RTRIM(prod_detalle), 41) + '-' + RTRIM(prod_codigo)
        WHERE prod_detalle IN (SELECT prod_detalle
                               FROM Producto
                               GROUP BY prod_detalle
                               HAVING COUNT(*) > 1)
    COMMIT TRANSACTION
END
GO
-- EXEC SP_ARREGLAR_PROD_DETALLE

CREATE TRIGGER TR_PRODUCTO_UNIQUE_DETALLE ON Producto
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM Producto p
               JOIN inserted i ON p.prod_detalle = i.prod_detalle
                              AND p.prod_codigo <> i.prod_codigo)
    BEGIN
        RAISERROR('No se puede repetir el detalle del producto.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO

-- 4b. UNIQUE simulado sobre Cliente.clie_cuit (columna agregada: ALTER TABLE Cliente ADD clie_cuit CHAR(13) NULL)
--     Criterio: me quedo con el cliente de menor código; paso sus facturas y borro el resto.
CREATE PROCEDURE SP_DEPURAR_CLIENTES_CUIT
AS
BEGIN
    BEGIN TRANSACTION
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

        DELETE c
        FROM Cliente c
        WHERE c.clie_cuit IS NOT NULL
          AND c.clie_codigo <> (SELECT MIN(c2.clie_codigo)
                                FROM Cliente c2
                                WHERE c2.clie_cuit = c.clie_cuit)
    COMMIT TRANSACTION
END
GO

CREATE TRIGGER TR_CLIENTE_CUIT_UNICO ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM Cliente c
               JOIN inserted i ON c.clie_cuit = i.clie_cuit      -- OJO: clie_cuit, no clie_telefono
                              AND c.clie_codigo <> i.clie_codigo)
    BEGIN
        RAISERROR('No se puede repetir el CUIT del cliente.', 16, 1)
        ROLLBACK TRANSACTION
    END
END
GO


/* ---------------------------------------------------------------------
   5. FUNCIÓN ESCALAR (devuelve un valor, se puede usar en un SELECT/WHERE)
   --------------------------------------------------------------------- */
CREATE FUNCTION fn_stock_total (@producto CHAR(8))
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @r DECIMAL(12,2)
    SELECT @r = SUM(stoc_cantidad)
    FROM Stock
    WHERE stoc_producto = @producto
    RETURN ISNULL(@r, 0)
END
GO
-- uso: SELECT prod_codigo, dbo.fn_stock_total(prod_codigo) FROM Producto


/* ---------------------------------------------------------------------
   6. SINTAXIS RÁPIDA
   --------------------------------------------------------------------- */
-- UPDATE: UPDATE -> SET -> (FROM) -> WHERE. Sin WHERE modifica TODO.
--   UPDATE Tabla SET col = valor WHERE condicion
--   UPDATE e SET e.col = ... FROM Empleado e JOIN inserted i ON ... WHERE ...
-- DELETE con JOIN:   DELETE alias FROM Tabla alias JOIN ... WHERE ...
-- INSERT:            INSERT INTO Tabla (col1, col2) VALUES (...)  /  INSERT INTO Tabla (...) SELECT ...
-- Error + deshacer:  RAISERROR('mensaje', 16, 1)  +  ROLLBACK TRANSACTION  (+ RETURN si hubo BEGIN TRANSACTION)
-- Detectar cambio de columna en UPDATE:  IF UPDATE(columna)
-- Probar un UPDATE/DELETE: primero escribir el SELECT con el mismo FROM/WHERE.
-- GO va SIEMPRE solo en su línea (separa lotes; no es T-SQL).

LEFT('20260715', 4)          -- 2026
RIGHT('20260715', 4)         -- 0715
SUBSTRING('20260715', 5, 2)  -- 07
/* El Ciclo de Vida de un Cursor
Un cursor en T-SQL consta de 5 pasos. 
Omitir cualquiera de estos pasos puede provocar errores de ejecución o dejar conexiones y memoria bloqueadas en el servidor.
1.	DECLARE: Se define el nombre del cursor y se le asigna la consulta SELECT que va a recorrer.
2.	OPEN: Se ejecuta la consulta asociada y se llena el cursor con los datos resultantes en memoria.
3.	FETCH NEXT: Se extrae la fila actual, se cargan sus valores en variables locales y el puntero avanza a la siguiente fila.
    • 0: El FETCH se ejecutó con éxito y devolvió una fila.
    • -1: La instrucción FETCH falló o la fila estaba más allá del conjunto de resultados (llegó al final).
    • -2: La fila recuperada no existe (por ejemplo, fue eliminada por otro proceso en simultáneo).

4. CLOSE: Se cierra el cursor, liberando el conjunto de resultados, pero la estructura del cursor sigue existiendo.
5. DEALLOCATE: Se destruye la definición del cursor y se libera por completo la memoria del servidor.

DECLARE @id_registro INT;
DECLARE @detalle_registro VARCHAR(100);
-- 1. DECLARE: Creación del cursor
DECLARE cur_ejemplo CURSOR FOR SELECT id, detalle FROM MiTabla WHERE estado = 'Activo';
-- 2. OPEN: Apertura del cursor
OPEN cur_ejemplo;
-- 3. FETCH: Lectura de la PRIMERA fila
FETCH NEXT FROM cur_ejemplo INTO @id_registro, @detalle_registro;
-- Bucle WHILE: Se ejecuta mientras @@FETCH_STATUS sea igual a 0
WHILE @@FETCH_STATUS = 0
    BEGIN
        -- LÓGICA A EJECUTAR POR CADA FILA 
        PRINT 'Procesando ID: ' + CAST(@id_registro AS VARCHAR) + ' - ' + @detalle_registro;
        -- IMPORTANTE: Lectura de la SIGUIENTE fila para evitar un bucle infinito
        FETCH NEXT FROM cur_ejemplo INTO @id_registro, @detalle_registro;
    END
-- 4. CLOSE: Cierre del cursor
CLOSE cur_ejemplo;
-- 5. DEALLOCATE: Liberación de memoria
DEALLOCATE cur_ejemplo;
GO */

/* En un sistema de E-Commerce, se requiere aplicar un descuento masivo de fidelidad en la 
tabla Clientes basado en sus puntos acumulados al final del día. 
Las reglas de negocio especifican:
•	Si el cliente tiene más de 100 puntos, se le aumenta el descuento un 5%.
•	Si tiene entre 50 y 100 puntos, se le aumenta un 2%.
•	Si tiene menos de 50 puntos, no se le realiza ninguna modificación. */
CREATE TABLE Clientes (
    id_cliente INT PRIMARY KEY,
    puntos_acumulados INT,
    porcentaje_descuento INT);
-- 1.
DECLARE @id_cte INT;
DECLARE @puntos INT;
-- 2. 
DECLARE cur_fidelidad CURSOR FOR
SELECT id_cliente, puntos_acumulados FROM Clientes;
-- 3. Abrimos cursor, lo recorremos y vamos haciendo lo que la logica del negocio nos pide
OPEN cur_fidelidad;
FETCH NEXT FROM cur_fidelidad INTO @id_cte, @puntos;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @puntos > 100
        UPDATE Clientes SET porcentaje_descuento = porcentaje_descuento + 5 WHERE id_cliente = @id_cte;
    ELSE IF @puntos >= 50 AND @puntos <= 100
        UPDATE Clientes SET porcentaje_descuento = porcentaje_descuento + 2 WHERE id_cliente = @id_cte;

    FETCH NEXT FROM cur_fidelidad INTO @id_cte, @puntos;   --> Avanzamos el puntero del cursor para posicionarlos en la proxima fila(registro)
END
-- 4. Cerrar y liberar memoria
CLOSE cur_fidelidad;
DEALLOCATE cur_fidelidad;

-- SIN CURSOR
UPDATE Clientes
   SET porcentaje_descuento = porcentaje_descuento + 
                              CASE 
                                   WHEN puntos_acumulados > 100 THEN 5
                                   WHEN puntos_acumulados >= 50 THEN 2
                                   ELSE 0
                               END;

/* Guia TSQL
6. Realizar un procedimiento que si en alguna factura se facturaron componentes 
que conforman un combo determinado (o sea que juntos componen otro 
producto de mayor nivel), en cuyo caso deberá reemplazar las filas 
correspondientes a dichos productos por una sola fila con el producto que 
componen con la cantidad de dicho producto que corresponda. 
Factura
  Item_factura         --> ELIMINAR
	  - 1 Linterna
	  - 1 Pila

Factura                --> INSERTAR
  Item_factura
	  - 1 Combo Linterna_pila */
CREATE PROCEDURE pr_composicion 
AS
BEGIN
	DECLARE @producto CHAR(8), @tipo CHAR(1), @sucursal CHAR(4), @numero CHAR(8)
	CREATE TABLE #insert_item(
		tempo_tipo CHAR(1),
		tempo_sucursal CHAR(4),
		tempo_numero CHAR(8),
		tempo_compuesto CHAR(8)
    )
    CREATE TABLE #delete_item(
        tempo_tipo CHAR(1),
        tempo_sucursal CHAR(4),
        tempo_numero CHAR(8),
        tempo_componente CHAR(8)
    )
	DECLARE cur_compuesto CURSOR FOR
			SELECT c.comp_producto, i.item_tipo, i.item_sucursal, i.item_numero 
			FROM Composicion c
			JOIN Item_Factura i ON i.item_producto = c.comp_componente
			WHERE i.item_cantidad = c.comp_cantidad
			GROUP BY c.comp_producto, i.item_tipo, i.item_sucursal, i.item_numero 
			HAVING COUNT(DISTINCT c.comp_componente) = 
					(SELECT COUNT(c2.comp_componente) 
					 FROM Composicion c2 
					 WHERE c2.comp_producto = c.comp_producto)
    OPEN cur_compuesto
	FETCH NEXT FROM cur_compuesto INTO @producto, @tipo, @sucursal, @numero 
	WHILE(@@FETCH_STATUS = 0)
	BEGIN
		INSERT INTO #insert_item VALUES (@tipo, @sucursal, @numero, @producto)

		INSERT INTO #delete_item 
		SELECT @tipo, @sucursal, @numero, comp_componente
		FROM Composicion c 
		WHERE c.comp_producto = @producto

		FETCH NEXT FROM cur_compuesto INTO @producto, @tipo, @sucursal, @numero
	END
	CLOSE cur_compuesto
	DEALLOCATE cur_compuesto

	BEGIN TRANSACTION
		INSERT item_Factura 
		SELECT tempo_tipo, tempo_sucursal, tempo_numero, tempo_compuesto, 1, p.prod_precio
		FROM #insert_item ii
		INNER JOIN Producto p ON p.prod_codigo = ii.tempo_compuesto
		
		DELETE Item_Factura 
		WHERE item_tipo+item_sucursal+item_numero+item_producto IN(
			SELECT 
			tempo_tipo+tempo_sucursal+tempo_numero+tempo_componente
			FROM #delete_item)
	 COMMIT TRANSACTION
END
GO

-- Otra versión más completa al ejercicio:
CREATE PROCEDURE pr_composicion
AS
BEGIN
    DECLARE @producto CHAR(8)
    DECLARE @tipo CHAR(1)
    DECLARE @sucursal CHAR(4)
    DECLARE @numero CHAR(8)
    DECLARE @cant_combo DECIMAL(12,2)

    DECLARE cur_compuesto CURSOR FOR
        SELECT 
            c.comp_producto,
            i.item_tipo,
            i.item_sucursal,
            i.item_numero
        FROM Composicion c
        JOIN Item_Factura i
            ON i.item_producto = c.comp_componente
        GROUP BY 
            c.comp_producto,
            i.item_tipo,
            i.item_sucursal,
            i.item_numero
        HAVING COUNT(DISTINCT c.comp_componente) = (
            SELECT COUNT(DISTINCT c2.comp_componente)
            FROM Composicion c2
            WHERE c2.comp_producto = c.comp_producto
        )

    BEGIN TRANSACTION

    OPEN cur_compuesto

    FETCH NEXT FROM cur_compuesto 
    INTO @producto, @tipo, @sucursal, @numero

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @cant_combo = 0

        SELECT 
            @cant_combo = MIN(FLOOR(i.item_cantidad / c.comp_cantidad))
        FROM Composicion c
        JOIN Item_Factura i
            ON i.item_producto = c.comp_componente
           AND i.item_tipo = @tipo
           AND i.item_sucursal = @sucursal
           AND i.item_numero = @numero
        WHERE c.comp_producto = @producto
        HAVING COUNT(DISTINCT c.comp_componente) = (
            SELECT COUNT(DISTINCT c2.comp_componente)
            FROM Composicion c2
            WHERE c2.comp_producto = @producto
        )

        IF ISNULL(@cant_combo, 0) > 0
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM Item_Factura
                WHERE item_tipo = @tipo
                  AND item_sucursal = @sucursal
                  AND item_numero = @numero
                  AND item_producto = @producto
            )
            BEGIN
                UPDATE Item_Factura
                SET item_cantidad = item_cantidad + @cant_combo
                WHERE item_tipo = @tipo
                  AND item_sucursal = @sucursal
                  AND item_numero = @numero
                  AND item_producto = @producto
            END
            ELSE
            BEGIN
                INSERT INTO Item_Factura (
                    item_tipo,
                    item_sucursal,
                    item_numero,
                    item_producto,
                    item_cantidad,
                    item_precio
                )
                SELECT
                    @tipo,
                    @sucursal,
                    @numero,
                    @producto,
                    @cant_combo,
                    p.prod_precio
                FROM Producto p
                WHERE p.prod_codigo = @producto
            END

            UPDATE i
            SET i.item_cantidad = i.item_cantidad - (@cant_combo * c.comp_cantidad)
            FROM Item_Factura i
            JOIN Composicion c
                ON c.comp_componente = i.item_producto
            WHERE c.comp_producto = @producto
              AND i.item_tipo = @tipo
              AND i.item_sucursal = @sucursal
              AND i.item_numero = @numero

            DELETE i
            FROM Item_Factura i
            JOIN Composicion c
                ON c.comp_componente = i.item_producto
            WHERE c.comp_producto = @producto
              AND i.item_tipo = @tipo
              AND i.item_sucursal = @sucursal
              AND i.item_numero = @numero
              AND i.item_cantidad <= 0
        END

        FETCH NEXT FROM cur_compuesto 
        INTO @producto, @tipo, @sucursal, @numero
    END

    CLOSE cur_compuesto
    DEALLOCATE cur_compuesto

    COMMIT TRANSACTION
END
GO
------------------
--- FIN CURSOR ---
------------------

-------------
-- TRIGGER --
-------------
ALTER TRIGGER TR_I_FACTURA ON FACTURA 
AFTER INSERT , DELETE
AS
BEGIN TRANSACTION 
DECLARE @vend int
DECLARE @monto decimal(12,2)
  -- SIN CURSOR
 /*SELECT 'INSERCION', * FROM INSERTED */
 /* SELECT 'INSERTED', * FROM INSERTED 
 UNION 
 SELECT 'DELETED', * FROM DELETED 
 
  UPDATE EMPLEADO SET 
  EMPL_COMISION = isnull(  (SELECT 0.1 * SUM(facT_total) from factura 
       where year(fact_fecha) = year(getdate()) and 
             month(fact_fecha) = month ( getdate() )  and 
             empl_codigo = fact_vendedor) ,0 ) */
  -- CON CURSOR
  DECLARE mi_cursor CURSOR  FOR 
  SELECT 
    fact_vendedor, fact_total 
  FROM INSERTED 
  WHERE  
   year(fact_fecha) = year(getdate()) and 
   month(fact_fecha) = month ( getdate() ) 
  UNION 
  SELECT 
   fact_vendedor, -1 * fact_total 
  FROM DELETED  
  WHERE  
   year(fact_fecha) = year(getdate()) and 
   month(fact_fecha) = month ( getdate() ) 
 OPEN mi_cursor 
 FETCH mi_cursor INTO @vend, @monto
 
 WHILE @@FETCH_STATUS = 0 
     BEGIN 
      UPDATE EMPLEADO SET 
       EMPL_COMISION =  EMPL_COMISION + ( 0.1 * @monto ) 
      WHERE 
       EMPL_CODIGO = @vend  
 
     FETCH mi_cursor INTO @vend, @monto
     END 
 CLOSE mi_cursor 
 DEALLOCATE mi_cursor 
COMMIT
--- Pruebas
INSERT INTO  Factura
(fact_tipo, fact_sucursal, fact_numero, fact_fecha, fact_vendedor, fact_total, fact_total_impuestos, fact_cliente) 
VALUES
 ('C', '0003', '00000014', '20260716', 1, 1000, 121, '00000')
SELECT * from empleado where empl_codigo = 1 
SELECT sum(fact_total) from factura where month(fact_fecha) = month ( getdate() ) and year(fact_fecha) = year(getdate()) 
                                            and fact_vendedor = 1                                             
DELETE factura where month(fact_fecha) = month ( getdate() ) and year(fact_fecha) = year(getdate()) 
                                            and fact_vendedor = 1 
                                            AND fact_tipo='C' AND fact_sucursal= '0003' and fact_numero='00000014'
--- Fin Pruebas

CREATE TRIGGER TR_DELETED_EN_CASCADA ON CLIENTE
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

/* Ejercicio de Parcial dado en clase practica
Implementar una regla de negocio en línea donde NUNCA una factura nueva 
tenga un precio de producto DISTINTO al que figura en la tabla PRODUCTO.
Registrar en una estructura adicional todos los casos donde se intenta guardar un precio distinto */
CREATE TABLE log_factura (
producto char(8),
precio decimal(12,2),
fecha smalldatetime
) -- falta agregar las PK, las FK ...

CREATE TRIGGER tr_parcial_1 ON item_factura 
INSTEAD OF INSERT 
AS
BEGIN TRANSACTION 
     INSERT INTO Item_Factura (item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, item_precio) 
        SELECT
            item_tipo, item_sucursal, item_numero, item_producto, item_cantidad, prod_precio 
        FROM inserted 
        JOIN Producto ON item_producto = prod_codigo

     INSERT INTO log_factura (producto, precio , fecha) 
        SELECT 
            item_producto, item_precio , getdate()
        FROM inserted 
        JOIN Producto ON item_producto = prod_codigo
        WHERE item_precio != prod_precio 
COMMIT

/* Parcial 08/07/2026 Bases de Datos 1C-2026
T-SQL
Implementar el/los objetos necesarios para simular una restricción UNIQUE sobre la columna prod_detalle de la tabla Producto.
Nota: no se permite agregar una constraint para resolver el problema. */

-- Nota: 6
CREATE or ALTER PROCEDURE arreglarDatos
AS
BEGIN   
    if exists (SELECT prod_detalle,  COUNT(*) AS CantidadRepeticiones FROM Producto 
                GROUP BY prod_detalle HAVING COUNT(*) > 1)
    BEGIN
        ALTER TABLE dbo.producto ALTER COLUMN prod_detalle char (60) --Se incrementa el tamaño de la columna para no tener problemas al concatenar el codigo de producto
        UPDATE Producto
        SET prod_detalle = concat(trim(prod_detalle), ' ', trim(prod_codigo))
        print('Detalle de producto corregido')
    END
END
EXEC arreglarDatos
GO

CREATE TRIGGER ejParcial on Producto 
AFTER INSERT, UPDATE
AS
BEGIN
    if EXISTS (SELECT prod_detalle, COUNT(*) AS CantidadRepeticiones FROM Producto 
                GROUP BY prod_detalle HAVING COUNT(*) > 1)
    BEGIN
        print('NO se puede ingresar producto con detalle duplicado')
        ROLLBACK
    END
END

-- Nota: 8
-- TSQL
CREATE OR ALTER PROCEDURE SP_ARREGLAR_REPETIDOS_prod_detalle_Producto (
	@detalle_producto_nuevo char(50)
)
AS
BEGIN
	DECLARE @prod_detalle char(50);
	DECLARE @prod_codigo char(8);
	DECLARE @ocurrencias INT;

	SELECT @ocurrencias=COUNT(*) FROM Producto where prod_detalle=@detalle_producto_nuevo; -- BUSCAMOS SOBRE LAS ENTRADAS EXISTENTES
    IF @ocurrencias <= 1
	    BEGIN 
		    RETURN; -- TERMINAMOS EL PROCEDURE, NO HAY NADA QUE HACER.
	    END
	ELSE -- PARA LOS CASOS DONDE LAS OCURRENCIAS SEAN MÁS DE 1 VEZ.
	    BEGIN 
		    DECLARE producto_cursor CURSOR FOR
			    SELECT prod_codigo, prod_detalle FROM Producto where prod_detalle=@detalle_producto_nuevo; -- para los repetidos con este valor
		    OPEN producto_cursor;
		    FETCH NEXT FROM producto_cursor INTO @prod_codigo, @prod_detalle;
		    WHILE @@FETCH_STATUS = 0 
		        BEGIN
			        -- Lógica a ejecutar por cada fila
			        IF @prod_detalle IN (SELECT P0.prod_detalle FROM Producto P0)
			            BEGIN
				            UPDATE Producto SET prod_detalle = CONCAT(LEFT(@prod_detalle,len(@prod_detalle)-2),cast(@ocurrencias as char(2)))
				            where prod_codigo=@prod_codigo
				            ;
			            END
			        FETCH NEXT FROM producto_cursor INTO @prod_codigo, @prod_detalle;
			        set @ocurrencias = @ocurrencias - 1;
		        END;
		    CLOSE producto_cursor;
		    DEALLOCATE producto_cursor;
	    END
END
/*
EXEC SP_ARREGLAR_REPETIDOS_prod_detalle_Producto @detalle_producto_nuevo='CHAUCHAU'
select * from Producto where prod_detalle like 'CHAUCH%'
INSERT INTO [dbo].[Producto] ([prod_codigo],[prod_detalle],[prod_precio],[prod_familia],[prod_rubro],[prod_envase])
VALUES ('A0000005','CHAUCHAU',0.00,'999','0042',1)
INSERT INTO [dbo].[Producto] ([prod_codigo],[prod_detalle],[prod_precio],[prod_familia],[prod_rubro],[prod_envase])
VALUES ('A0000004', 'CHAUCHAU', 0.00, '999','0042',1)
*/
CREATE OR ALTER TRIGGER TR_UNIQUE_prod_detalle_Producto 
ON Producto
INSTEAD OF INSERT, UPDATE
AS 
BEGIN
	DECLARE @prod_detalle_nuevo char(50);
	DECLARE @prod_codigo_nuevo char(8);
	DECLARE prod_detalle_nuevo_cursor CURSOR FOR
	-- no queremos que los nuevos insertados tengan mismo valor que algun prod_detalle existente
		SELECT prod_codigo, prod_detalle FROM INSERTED;
	OPEN prod_detalle_nuevo_cursor;
	FETCH NEXT FROM prod_detalle_nuevo_cursor INTO @prod_codigo_nuevo, @prod_detalle_nuevo;
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC SP_ARREGLAR_REPETIDOS_prod_detalle_Producto @detalle_producto_nuevo=@prod_detalle_nuevo
		-- Lógica a ejecutar por cada fila
		IF @prod_detalle_nuevo NOT IN (SELECT P0.prod_detalle FROM Producto P0)
		    BEGIN
			    INSERT INTO [dbo].[Producto]
			       ([prod_codigo]
			       ,[prod_detalle]
			       ,[prod_precio]
			       ,[prod_familia]
			       ,[prod_rubro]
			       ,[prod_envase])
			    (select 
				    p0.prod_codigo, 
				    p0.prod_detalle, 
				    p0.prod_precio, 
				    p0.prod_familia, 
				    p0.prod_rubro, 
				    p0.prod_envase
			       from Producto p0 
			       where p0.prod_codigo=@prod_codigo_nuevo)
		    END
		ELSE 
		    BEGIN 
			    RAISERROR ('prod_detalle=%s ya existente. Debes cambiar el valor prod_detalle, para poder insertar', 10, 1, @prod_detalle_nuevo)
		    END
		FETCH NEXT FROM prod_detalle_nuevo_cursor INTO @prod_codigo_nuevo, @prod_detalle_nuevo;
	END;

	CLOSE prod_detalle_nuevo_cursor;
	DEALLOCATE prod_detalle_nuevo_cursor;
END 
-- lista todos los prod_detalle existentes actualmente
-- SELECT P0.prod_detalle FROM Producto P0


/* No permitir que se inserte o modifique un cliente con clie_telefono repetido. */
CREATE OR ALTER TRIGGER TR_CLIE_TELEF_DUPLICADO
ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Cliente c
        JOIN inserted i
            ON c.clie_telefono = i.clie_telefono
           AND c.clie_codigo <> i.clie_codigo
    )
    BEGIN
        RAISERROR('No se puede repetir el telefono del cliente.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END

/*  Parcial Práctico de Gestión de Datos - 12/07/2025
2. Se agregó recientemente un campo CUIT a la tabla de clientes. Debido a un error, 
se generaron múltiples registros de clientes con el mismo CUIT.
Se deberá desarrollar un algoritmo de depuración de datos que identifique y corrija estos duplicados, 
manteniendo un único registro por CUIT. 
Será necesario definir un criterio de selección para determinar qué registro conservar y cuáles eliminar.

Adicionalmente, se deberá implementar una restricción que impida la creación futura de registros con CUIT duplicado. */
CREATE PROCEDURE SP_DEPURAR_CLIENTES_CUIT
AS
BEGIN
    BEGIN TRANSACTION
    -- Paso las facturas de clientes duplicados al cliente que voy a conservar
    UPDATE f
    SET fact_cliente = (
        SELECT MIN(c2.clie_codigo)
        FROM Cliente c2
        WHERE c2.clie_cuit = c.clie_cuit
    )
    FROM Factura f
    JOIN Cliente c ON f.fact_cliente = c.clie_codigo
    WHERE c.clie_cuit IS NOT NULL
      AND c.clie_codigo != (
            SELECT MIN(c3.clie_codigo)
            FROM Cliente c3
            WHERE c3.clie_cuit = c.clie_cuit
      )
    -- Elimino los clientes duplicados
    DELETE c
    FROM Cliente c
    WHERE c.clie_cuit IS NOT NULL
      AND c.clie_codigo != (
            SELECT MIN(c2.clie_codigo)
            FROM Cliente c2
            WHERE c2.clie_cuit = c.clie_cuit
      )
    COMMIT TRANSACTION
END
GO

CREATE TRIGGER TR_DUPLI_CUIT ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Cliente c
        JOIN inserted i
            ON c.clie_telefono = i.clie_telefono
           AND c.clie_codigo != i.clie_codigo
    )
    BEGIN
        RAISERROR('No se puede repetir el telefono del cliente.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END

/* Parcial Practico de Gestión de Datos - 28/06/2025
2. Se desea crear una vista denominada v_item_factura que permita visualizar, para cada ítem de una factura, 
la identificación de la factura, el nombre del producto, el precio unitario, la cantidad y 
el total correspondiente a ese ítem.

Sin embargo, se solicita eliminar físicamente los campos item_precio e item_total de la tabla item_factura, 
ya que se considera que dichos valores no deben almacenarse más en esa tabla. 
Además, no está permitido agregar nuevos campos a item_factura.

¿Qué debería implementarse para que la vista v_item_factura pueda mostrar en todo momento la información requerida, 
tanto para los datos actuales como para los futuros? */
CREATE TABLE Item_Factura_Precio ( -- Tabla auxiliar
    item_tipo CHAR(1),
    item_sucursal CHAR(4),
    item_numero CHAR(8),
    item_producto CHAR(8),
    precio_unitario DECIMAL(12,2),
    PRIMARY KEY (item_tipo, item_sucursal, item_numero, item_producto)
);

CREATE PROCEDURE migrarPrecioHistorico
AS 
BEGIN 
    INSERT INTO Item_Factura_Precio (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        precio_unitario
    )
        SELECT
            item_tipo,
            item_sucursal,
            item_numero,
            item_producto,
            item_precio
        FROM Item_Factura;
END
EXEC migrarPrecioHistorico

ALTER TABLE Item_Factura
DROP COLUMN item_precio;

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
JOIN Producto p
    ON p.prod_codigo = i.item_producto
JOIN Item_Factura_Precio ip
    ON ip.item_tipo = i.item_tipo
   AND ip.item_sucursal = i.item_sucursal
   AND ip.item_numero = i.item_numero
   AND ip.item_producto = i.item_producto;

CREATE TRIGGER TR_ITEM_FACTURA_PRECIO
ON Item_Factura
AFTER INSERT
AS
BEGIN
    INSERT INTO Item_Factura_Precio (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        precio_unitario
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        p.prod_precio
    FROM inserted i
    JOIN Producto p
        ON p.prod_codigo = i.item_producto;
END;

/* Parcial Practico de Gestion de Datos - 28/07/2023
2. Suponiendo que se aplican los siguientes cambios en el modelo de datos:
    Cambio 1) create table provincia (id int primary key, nombre char(100)) ;
    Cambio 2) alter table cliente add pcia_id int null;
Crear el/los objetos necesarios para implementar el concepto de foreign key entre 2 cliente y provincia.
Nota: No se permite agregar una constraint de tipo FOREIGN KEY entre la tabla y el campo agregado. */
CREATE OR ALTER TRIGGER TR_CLIENTE_FK_PROVINCIA
ON Cliente
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.pcia_id IS NOT NULL
          AND NOT EXISTS (
                SELECT 1
                FROM Provincia p
                WHERE p.id = i.pcia_id
          )
    )
    BEGIN
        RAISERROR('No existe la provincia indicada.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END

CREATE OR ALTER TRIGGER TR_PROVINCIA_NO_DELETE_REFERENCIADA
ON Provincia
AFTER DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN Cliente c
            ON c.pcia_id = d.id
    )
    BEGIN
        RAISERROR('No se puede eliminar una provincia referenciada por clientes.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
END
GO

/* PARCIAL GESTIÓN DE DATOS - 06/07/2022
2. Implementar el/los objetos necesarios para que siempre se cumplan las siguientes reglas de negocio.
  a. Nunca el precio de un producto compuesto puede ser distinto a la suma de los precios por las cantidades 
  de los productos que lo componen. */
-- Si ya existían precios mal calculados:
CREATE OR ALTER PROCEDURE SP_RECALCULAR_PRECIOS_COMPUESTOS
AS
BEGIN
    UPDATE p
    SET p.prod_precio = (
        SELECT SUM(pc.prod_precio * c.comp_cantidad)
        FROM Composicion c
        JOIN Producto pc ON pc.prod_codigo = c.comp_componente
        WHERE c.comp_producto = p.prod_codigo
    )
    FROM Producto p
    WHERE EXISTS (
        SELECT 1
        FROM Composicion c
        WHERE c.comp_producto = p.prod_codigo
    )
END
GO

EXEC SP_RECALCULAR_PRECIOS_COMPUESTOS
GO
-- Para responder a la consigna y evitar insertar precios mal calculados
CREATE OR ALTER TRIGGER TR_COMPOSICION_PRECIO
ON Composicion
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    UPDATE p
    SET p.prod_precio = (
        SELECT SUM(pc.prod_precio * c.comp_cantidad)
        FROM Composicion c
        JOIN Producto pc ON pc.prod_codigo = c.comp_componente
        WHERE c.comp_producto = p.prod_codigo
    )
    FROM Producto p
    WHERE p.prod_codigo IN (
        SELECT comp_producto FROM inserted
        UNION
        SELECT comp_producto FROM deleted
    )
END
-- Si cambia el precio de un componente, hay que recalcular el precio final del prod. compuesto
CREATE OR ALTER TRIGGER TR_PRODUCTO_PRECIO_COMPONENTE
ON Producto
AFTER UPDATE
AS
BEGIN
    IF UPDATE(prod_precio)
    BEGIN
        UPDATE p
        SET p.prod_precio = (
            SELECT SUM(pc.prod_precio * c.comp_cantidad)
            FROM Composicion c
            JOIN Producto pc ON pc.prod_codigo = c.comp_componente
            WHERE c.comp_producto = p.prod_codigo
        )
        FROM Producto p
        WHERE p.prod_codigo IN (
            SELECT i.prod_codigo
            FROM inserted i
            JOIN Composicion c ON c.comp_producto = i.prod_codigo
            UNION
            SELECT c.comp_producto
            FROM Composicion c
            JOIN inserted i ON i.prod_codigo = c.comp_componente
        )
    END
END
GO

/* 2do  Recuperatorio Gestión de Datos 
2)    T-SQL
El sistema actual permite vender productos compuestos directamente. Sin embargo, de ahora en adelante 
no queremos guardar la composición completa, sino únicamente los productos y cantidades correspondientes 
al primer nivel de composición. 
Se debe implementar una lógica para que, cada vez que se realice la venta de un producto compuesto, 
se registren sus componentes del primer nivel en las tablas correspondientes. */
CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_PRIMER_NIVEL
ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN TRANSACTION
    -- Inserto normalmente los productos simples
    INSERT INTO Item_Factura (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        item_cantidad,
        item_precio
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        i.item_cantidad,
        i.item_precio
    FROM inserted i
    WHERE i.item_producto NOT IN (
        SELECT c.comp_producto
        FROM Composicion c
    )
    -- Si el producto insertado era compuesto, inserto sus componentes de primer nivel
    INSERT INTO Item_Factura (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        item_cantidad,
        item_precio
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        c.comp_componente,
        i.item_cantidad * c.comp_cantidad,
        p.prod_precio
    FROM inserted i
    JOIN Composicion c
        ON c.comp_producto = i.item_producto
    JOIN Producto p
        ON p.prod_codigo = c.comp_componente
COMMIT TRANSACTION
GO

/* Parcial 01/07/2026 Bases de Datos 1C-2026
T-SQL
Se desea implementar a partir del año 2027, proveedores de productos de tal modo que pueda ser comprado a más de uno,
y un registro de las compras con los envíos a los distintos depósitos.
Realizar la implementación en el modelo de datos con su consecuente actualización, de tal modo que
en una sola transacción se realice la actualización del stock y el llenado de la/s nueva/s tablas. */
CREATE TABLE Proveedor (
    prov_codigo INT PRIMARY KEY,
    prov_nombre CHAR(100)
);

CREATE TABLE Proveedor_Producto (
    prov_codigo INT,
    prod_codigo CHAR(8),
    PRIMARY KEY (prov_codigo, prod_codigo)
);

CREATE TABLE Compra (
    comp_codigo INT PRIMARY KEY,
    comp_fecha SMALLDATETIME,
    comp_proveedor INT
);

CREATE TABLE Detalle_Compra (
    comp_codigo INT,
    prod_codigo CHAR(8),
    depo_codigo CHAR(2),
    cantidad DECIMAL(12,2),
    precio DECIMAL(12,2),
    PRIMARY KEY (comp_codigo, prod_codigo, depo_codigo)
);

CREATE OR ALTER PROCEDURE SP_REGISTRAR_COMPRA
    @comp_codigo INT,
    @comp_fecha SMALLDATETIME,
    @prov_codigo INT,
    @prod_codigo CHAR(8),
    @depo_codigo CHAR(2),
    @cantidad DECIMAL(12,2),
    @precio DECIMAL(12,2)
AS
BEGIN
    BEGIN TRANSACTION
    -- La consigna dice a partir de 2027
    IF YEAR(@comp_fecha) < 2027
    BEGIN
        RAISERROR('Las compras a proveedores se registran a partir de 2027.', 16, 1)
        ROLLBACK TRANSACTION
        RETURN
    END
    -- Si no existe la compra, la creo
    IF NOT EXISTS (
        SELECT 1
        FROM Compra
        WHERE comp_codigo = @comp_codigo
    )   
        BEGIN
            INSERT INTO Compra (comp_codigo,comp_fecha,comp_proveedor)
            VALUES (@comp_codigo,@comp_fecha,@prov_codigo)
        END
    -- Registro que ese proveedor vende ese producto
    IF NOT EXISTS (
        SELECT 1
        FROM Proveedor_Producto
        WHERE prov_codigo = @prov_codigo
          AND prod_codigo = @prod_codigo
    )
        BEGIN
            INSERT INTO Proveedor_Producto (prov_codigo,prod_codigo)
            VALUES (@prov_codigo,@prod_codigo)
        END
    -- Registro el detalle de la compra y el depósito al que llegó
    INSERT INTO Detalle_Compra (comp_codigo,prod_codigo,depo_codigo,cantidad,precio)
    VALUES (@comp_codigo,@prod_codigo,@depo_codigo,@cantidad,@precio)
    -- Actualizo el stock si ya existe ese producto en ese depósito
    IF EXISTS (
        SELECT 1
        FROM Stock
        WHERE stoc_producto = @prod_codigo
          AND stoc_deposito = @depo_codigo
    )
        BEGIN
            UPDATE Stock
            SET stoc_cantidad = stoc_cantidad + @cantidad
            WHERE stoc_producto = @prod_codigo
              AND stoc_deposito = @depo_codigo
        END
    ELSE
        BEGIN
            INSERT INTO Stock (stoc_producto,stoc_deposito,stoc_cantidad,stoc_punto_reposicion,stoc_stock_maximo)
            VALUES (@prod_codigo,@depo_codigo,@cantidad,0,0)
        END
    COMMIT TRANSACTION
END

/* Parcial 08/07/2026 Bases de Datos 1C-2026
T-SQL
Implementar el/los objetos necesarios para simular una restricción UNIQUE sobre la columna prod_detalle 
de la tabla Producto.
Nota: no se permite agregar una constraint para resolver el problema. */
-- 1) Procedure para arreglar datos ya existentes
CREATE OR ALTER PROCEDURE SP_ARREGLAR_PROD_DETALLE_REPETIDOS
AS
BEGIN
    BEGIN TRANSACTION
    UPDATE p
    SET prod_detalle = p.prod_codigo + '-' + LEFT(p.prod_detalle, 41)
    FROM Producto p
    WHERE p.prod_detalle IN (
        SELECT prod_detalle
        FROM Producto
        GROUP BY prod_detalle
        HAVING COUNT(*) > 1
    )
    COMMIT TRANSACTION
END
GO

EXEC SP_ARREGLAR_PROD_DETALLE_REPETIDOS
GO
-- 2) Trigger para evitar repetidos futuros
CREATE OR ALTER TRIGGER TR_PRODUCTO_UNIQUE_DETALLE
ON Producto
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Producto p
        JOIN inserted i
            ON p.prod_detalle = i.prod_detalle
           AND p.prod_codigo != i.prod_codigo
    )
        BEGIN
            RAISERROR('No se puede repetir el detalle del producto.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END
END
GO

/* Parcial Practico de Gestión de Datos
15/11/2022
1. Realizar una consulta SQL que permita saber los clientes que
compraron todos los rubros disponibles del sistema en el 2012.
De estos clientes mostrar, siempre para el 2012:
1. El código del cliente
2. Código de producto que en cantidades más compro.
3. El nombre del producto del punto 3.
4. Cantidad de productos distintos comprados por el
cliente.
5. Cantidad de productos con composición comprados
por el cliente.
El resultado deberá ser ordenado por razón social del cliente
alfabéticamente primero y luego, los clientes que compraron entre un
20% y 30% del total facturado en el 2012 primero, luego, los restantes.
Nota: No se permiten select en el from, es decir, select ... from (select ...) as T....

2. Implementar una regla de negocio en línea que al realizar una venta
(SOLO INSERCION) permita componer los productos descompuestos,
es decir, si se guardan en la factura 2 hamb. 2 papas 2 gaseosas se
deberá guardar en la factura 2 (DOS) COMBO1. Si 1 combo1 equivale
a: 1 hamb. 1 papa y 1 gaseosa.
Nota: Considerar que cada vez que se guardan los items, se mandan
todos los productos de ese item a la vez, y no de manera parcial. */
-- SQL
SELECT
    c.clie_codigo AS Cod_Cliente,
    (   SELECT TOP 1 i2.item_producto
        FROM Factura f2
        JOIN Item_Factura i2
            ON i2.item_tipo = f2.fact_tipo AND i2.item_sucursal = f2.fact_sucursal AND i2.item_numero = f2.fact_numero
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
        GROUP BY i2.item_producto
        ORDER BY SUM(i2.item_cantidad) DESC, i2.item_producto
    ) AS Cod_Producto_Mas_Comprado,

    (   SELECT TOP 1 p2.prod_detalle
        FROM Factura f2
        JOIN Item_Factura i2
            ON i2.item_tipo = f2.fact_tipo
           AND i2.item_sucursal = f2.fact_sucursal
           AND i2.item_numero = f2.fact_numero
        JOIN Producto p2
            ON p2.prod_codigo = i2.item_producto
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
        GROUP BY p2.prod_codigo, p2.prod_detalle
        ORDER BY SUM(i2.item_cantidad) DESC, p2.prod_codigo
    ) AS Nombre_Producto_Mas_Comprado,

    COUNT(DISTINCT i.item_producto) AS Cant_Productos_Distintos,

    COUNT(DISTINCT CASE 
            WHEN i.item_producto IN (
                SELECT comp_producto
                FROM Composicion
            ) 
            THEN i.item_producto
        END) AS Cant_Productos_Con_Composicion
FROM Cliente c
JOIN Factura f ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura i ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
JOIN Producto p ON p.prod_codigo = i.item_producto
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY c.clie_codigo, c.clie_razon_social
HAVING COUNT(DISTINCT p.prod_rubro) = (
    SELECT COUNT(*)
    FROM Rubro )
ORDER BY c.clie_razon_social ASC,
            CASE
                WHEN (
                    SELECT SUM(f3.fact_total)
                    FROM Factura f3
                    WHERE f3.fact_cliente = c.clie_codigo
                      AND YEAR(f3.fact_fecha) = 2012
                ) BETWEEN
                    0.20 * (
                        SELECT SUM(f4.fact_total)
                        FROM Factura f4
                        WHERE YEAR(f4.fact_fecha) = 2012
                    )
                    AND
                    0.30 * (
                        SELECT SUM(f5.fact_total)
                        FROM Factura f5
                        WHERE YEAR(f5.fact_fecha) = 2012
                    )
                THEN 0 ELSE 1
            END;
-- TSQL
CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_COMPONER
ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN TRANSACTION
    DECLARE @combos TABLE (
        item_tipo CHAR(1),
        item_sucursal CHAR(4),
        item_numero CHAR(8),
        comp_producto CHAR(8),
        cant_combo DECIMAL(12,2)
    )
    -- Detecto qué productos compuestos se pueden formar
    INSERT INTO @combos (item_tipo,item_sucursal,item_numero,comp_producto,cant_combo)
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        c.comp_producto,
        MIN(i.item_cantidad / c.comp_cantidad) AS cant_combo
    FROM inserted i
    JOIN Composicion c ON c.comp_componente = i.item_producto
    GROUP BY i.item_tipo,i.item_sucursal,i.item_numero,c.comp_producto
    HAVING COUNT(DISTINCT c.comp_componente) = (
        SELECT COUNT(DISTINCT c2.comp_componente)
        FROM Composicion c2
        WHERE c2.comp_producto = c.comp_producto )
    AND MIN(i.item_cantidad / c.comp_cantidad) = MAX(i.item_cantidad / c.comp_cantidad)
    -- Inserto los combos detectados
    INSERT INTO Item_Factura (item_tipo,item_sucursal,item_numero,item_producto,
        item_cantidad,item_precio)
    SELECT
        cb.item_tipo,
        cb.item_sucursal,
        cb.item_numero,
        cb.comp_producto,
        cb.cant_combo,
        p.prod_precio
    FROM @combos cb
    JOIN Producto p ON p.prod_codigo = cb.comp_producto
    -- Inserto normalmente los productos que no formaron parte de ningún combo
    INSERT INTO Item_Factura (item_tipo,item_sucursal,item_numero,item_producto,
        item_cantidad,item_precio)
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        i.item_cantidad,
        i.item_precio
    FROM inserted i
    WHERE NOT EXISTS (
            SELECT 1
            FROM @combos cb
            JOIN Composicion c ON c.comp_producto = cb.comp_producto
            WHERE cb.item_tipo = i.item_tipo
              AND cb.item_sucursal = i.item_sucursal
              AND cb.item_numero = i.item_numero
              AND c.comp_componente = i.item_producto
    )
COMMIT TRANSACTION

/* Parcial Practico de Gestión de Datos
12/11/2022
1. Realizar una consulta SQL que permita saber los clientes que
compraron por encima del promedio de compras (fact_total) de todos
los clientes del 2012.
De estos clientes mostrar para el 2012:
1. El código del cliente
7. La razón social del cliente
3. Código de producto que en cantidades más compro.
A. El nombre del producto del punto 3.
. Cantidad de productos distintos comprados por el
cliente.
.Cantidad de productos con composición comprados
por el cliente.
El resultado deberá ser ordenado poniendo primero aquellos clientes
que compraron más de entre 5 y 10 productos distintos en el 2012.
Nota: No se permiten select en el from, es decir, select ... from (select ...) as T,...
2. Implementar una regla de negocio de validación en línea que permita
validar el STOCK al realizarse una venta. Cada venta se debe
descontar sobre el depósito 00. En caso de que se venda un producto
compuesto, el descuento de stock se debe realizar por sus
componentes. Si no hay STOCK para ese artículo, no se deberá
guardar ese articulo, pero si los otros en los cuales hay stock positivo.
Es decir, solamente se deberán guardar aquellos para los cuales si hay
stock, sin guardarse los que no poseen cantidades suficientes.*/
-- SQL
SELECT
    c.clie_codigo AS Cod_Cliente,
    c.clie_razon_social AS Razon_Social,

    (
        SELECT TOP 1 i2.item_producto
        FROM Factura f2
        JOIN Item_Factura i2
            ON i2.item_tipo = f2.fact_tipo
           AND i2.item_sucursal = f2.fact_sucursal
           AND i2.item_numero = f2.fact_numero
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
        GROUP BY i2.item_producto
        ORDER BY SUM(i2.item_cantidad) DESC, i2.item_producto
    ) AS Cod_Producto_Mas_Comprado,

    (
        SELECT TOP 1 p2.prod_detalle
        FROM Factura f2
        JOIN Item_Factura i2
            ON i2.item_tipo = f2.fact_tipo
           AND i2.item_sucursal = f2.fact_sucursal
           AND i2.item_numero = f2.fact_numero
        JOIN Producto p2
            ON p2.prod_codigo = i2.item_producto
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
        GROUP BY p2.prod_codigo, p2.prod_detalle
        ORDER BY SUM(i2.item_cantidad) DESC, p2.prod_codigo
    ) AS Nombre_Producto_Mas_Comprado,

    COUNT(DISTINCT i.item_producto) AS Cant_Productos_Distintos,

    COUNT(DISTINCT CASE
        WHEN i.item_producto IN (
            SELECT comp_producto
            FROM Composicion
        )
        THEN i.item_producto
    END) AS Cant_Productos_Con_Composicion

FROM Cliente c
JOIN Factura f
    ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura i
    ON i.item_tipo = f.fact_tipo
   AND i.item_sucursal = f.fact_sucursal
   AND i.item_numero = f.fact_numero

WHERE YEAR(f.fact_fecha) = 2012

GROUP BY
    c.clie_codigo,
    c.clie_razon_social

HAVING (
    SELECT SUM(fx.fact_total)
    FROM Factura fx
    WHERE fx.fact_cliente = c.clie_codigo
      AND YEAR(fx.fact_fecha) = 2012
) > (
    SELECT SUM(fy.fact_total) * 1.0
    FROM Factura fy
    WHERE YEAR(fy.fact_fecha) = 2012
) / (
    SELECT COUNT(DISTINCT fz.fact_cliente)
    FROM Factura fz
    WHERE YEAR(fz.fact_fecha) = 2012
)

ORDER BY
    CASE
        WHEN COUNT(DISTINCT i.item_producto) BETWEEN 5 AND 10
        THEN 0
        ELSE 1
    END,
    c.clie_razon_social;

--TSQL
CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_VALIDAR_STOCK
ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN TRANSACTION
    /*1) Insertar productos simples con stock suficiente*/
    INSERT INTO Item_Factura (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        item_cantidad,
        item_precio
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        i.item_cantidad,
        i.item_precio
    FROM inserted i
    JOIN Stock s
        ON s.stoc_producto = i.item_producto
       AND s.stoc_deposito = '00'
    WHERE i.item_producto NOT IN (
        SELECT comp_producto
        FROM Composicion
    )
      AND s.stoc_cantidad >= i.item_cantidad
    /*2) Descontar stock de productos simples insertados*/
    UPDATE s
    SET s.stoc_cantidad = s.stoc_cantidad - i.item_cantidad
    FROM Stock s
    JOIN inserted i
        ON s.stoc_producto = i.item_producto
       AND s.stoc_deposito = '00'
    WHERE i.item_producto NOT IN (
        SELECT comp_producto
        FROM Composicion
    )
      AND s.stoc_cantidad >= i.item_cantidad
    /*3) Insertar productos compuestos solo si todos sus componentes
           tienen stock suficiente en depósito 00*/
    INSERT INTO Item_Factura (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        item_cantidad,
        item_precio
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        i.item_cantidad,
        i.item_precio
    FROM inserted i
    WHERE i.item_producto IN (
        SELECT comp_producto
        FROM Composicion
    )
      AND NOT EXISTS (
            SELECT 1
            FROM Composicion c
            LEFT JOIN Stock s
                ON s.stoc_producto = c.comp_componente
               AND s.stoc_deposito = '00'
            WHERE c.comp_producto = i.item_producto
              AND ISNULL(s.stoc_cantidad, 0) < i.item_cantidad * c.comp_cantidad
      )
    /*4) Descontar stock de los componentes de los productos compuestos
           que sí pudieron insertarse*/
    UPDATE s
    SET s.stoc_cantidad = s.stoc_cantidad - (i.item_cantidad * c.comp_cantidad)
    FROM Stock s
    JOIN Composicion c
        ON c.comp_componente = s.stoc_producto
    JOIN inserted i
        ON i.item_producto = c.comp_producto
    WHERE s.stoc_deposito = '00'
      AND NOT EXISTS (
            SELECT 1
            FROM Composicion c2
            LEFT JOIN Stock s2
                ON s2.stoc_producto = c2.comp_componente
               AND s2.stoc_deposito = '00'
            WHERE c2.comp_producto = i.item_producto
              AND ISNULL(s2.stoc_cantidad, 0) < i.item_cantidad * c2.comp_cantidad
      )
COMMIT TRANSACTION


/* Parcial Practico de Gestión de Datos
19/11/2022
1. Realizar una consulta SQL que permita saber los clientes que
compraron en el 2012 al menos 1 unidad de todos los productos
compuestos.
De estos clientes mostrar, siempre para el 2012:
1. El código del cliente
2. Código de producto que en cantidades más compro.
3. El número de fila según el orden establecido con nn
alias llamado ORDINAL.
4. Cantidad de productos distintos comprados por el
cliente.
5. Monto total comprado.
El resultado deberá ser ordenado por razón social del cliente
alfabéticamente primero y luego, los clientes que compraron entre un
20% у 30% del total facturado en el 2012 primero, luego, los restantes.
Nota: No se permiten select en el from, es decir, select ... from (select ...) as T,...
1. Implementar una regla de negocio en línea donde nunca una factura
nueva tenga un precio de producto distinto al que figura en la tabla
PRODUCTO. Registrar en una estructura adicional todos los casos
donde se intenta guardar un precio distinto.*/

SELECT
    c.clie_codigo AS Cod_Cliente,

    (
        SELECT TOP 1 i2.item_producto
        FROM Factura f2
        JOIN Item_Factura i2
            ON i2.item_tipo = f2.fact_tipo
           AND i2.item_sucursal = f2.fact_sucursal
           AND i2.item_numero = f2.fact_numero
        WHERE f2.fact_cliente = c.clie_codigo
          AND YEAR(f2.fact_fecha) = 2012
        GROUP BY i2.item_producto
        ORDER BY SUM(i2.item_cantidad) DESC, i2.item_producto
    ) AS Cod_Producto_Mas_Comprado,

    ROW_NUMBER() OVER (
        ORDER BY 
            c.clie_razon_social ASC,
            CASE
                WHEN (
                    SELECT SUM(f3.fact_total)
                    FROM Factura f3
                    WHERE f3.fact_cliente = c.clie_codigo
                      AND YEAR(f3.fact_fecha) = 2012
                ) BETWEEN 
                    0.20 * (
                        SELECT SUM(f4.fact_total)
                        FROM Factura f4
                        WHERE YEAR(f4.fact_fecha) = 2012
                    )
                    AND
                    0.30 * (
                        SELECT SUM(f5.fact_total)
                        FROM Factura f5
                        WHERE YEAR(f5.fact_fecha) = 2012
                    )
                THEN 0
                ELSE 1
            END
    ) AS ORDINAL,

    COUNT(DISTINCT i.item_producto) AS Cant_Productos_Distintos,

    (
        SELECT SUM(f6.fact_total)
        FROM Factura f6
        WHERE f6.fact_cliente = c.clie_codigo
          AND YEAR(f6.fact_fecha) = 2012
    ) AS Monto_Total_Comprado

FROM Cliente c
JOIN Factura f
    ON f.fact_cliente = c.clie_codigo
JOIN Item_Factura i
    ON i.item_tipo = f.fact_tipo
   AND i.item_sucursal = f.fact_sucursal
   AND i.item_numero = f.fact_numero

WHERE YEAR(f.fact_fecha) = 2012

GROUP BY
    c.clie_codigo,
    c.clie_razon_social

HAVING COUNT(DISTINCT CASE
            WHEN i.item_producto IN (
                SELECT comp_producto
                FROM Composicion
            )
            AND i.item_cantidad >= 1
            THEN i.item_producto
       END) = (
            SELECT COUNT(DISTINCT comp_producto)
            FROM Composicion
       )

ORDER BY
    c.clie_razon_social ASC,
    CASE
        WHEN (
            SELECT SUM(f7.fact_total)
            FROM Factura f7
            WHERE f7.fact_cliente = c.clie_codigo
              AND YEAR(f7.fact_fecha) = 2012
        ) BETWEEN
            0.20 * (
                SELECT SUM(f8.fact_total)
                FROM Factura f8
                WHERE YEAR(f8.fact_fecha) = 2012
            )
            AND
            0.30 * (
                SELECT SUM(f9.fact_total)
                FROM Factura f9
                WHERE YEAR(f9.fact_fecha) = 2012
            )
        THEN 0
        ELSE 1
    END;

--TSQL
CREATE TABLE Log_Precio_Item_Factura (
    item_tipo CHAR(1),
    item_sucursal CHAR(4),
    item_numero CHAR(8),
    item_producto CHAR(8),
    precio_intentado DECIMAL(12,2),
    precio_correcto DECIMAL(12,2),
    fecha SMALLDATETIME
);

CREATE OR ALTER TRIGGER TR_ITEM_FACTURA_PRECIO_PRODUCTO
ON Item_Factura
INSTEAD OF INSERT
AS
BEGIN TRANSACTION

    -- Registro intentos con precio distinto al precio del producto
    INSERT INTO Log_Precio_Item_Factura (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        precio_intentado,
        precio_correcto,
        fecha
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
    JOIN Producto p
        ON p.prod_codigo = i.item_producto
    WHERE i.item_precio <> p.prod_precio


    -- Inserto el ítem usando siempre el precio correcto de Producto
    INSERT INTO Item_Factura (
        item_tipo,
        item_sucursal,
        item_numero,
        item_producto,
        item_cantidad,
        item_precio
    )
    SELECT
        i.item_tipo,
        i.item_sucursal,
        i.item_numero,
        i.item_producto,
        i.item_cantidad,
        p.prod_precio
    FROM inserted i
    JOIN Producto p
        ON p.prod_codigo = i.item_producto

COMMIT TRANSACTION
GO

/* Parcial 01/07/2026 — SQL
Enunciado

Realizar una consulta SQL que devuelva los pares de productos vendidos juntos en una misma factura durante el año 2011, que sean del mismo rubro y mismo envase, y que hayan sido vendidos juntos más de 50 veces.

Mostrar:

Nro de fila
Nombre del producto 1
Nombre del producto 2
Código de rubro
Código de envase
Porcentaje de unidades vendidas en 2011 que representa ese par

Los productos del par deben mostrarse ordenados alfabéticamente.
*/

SELECT
    ROW_NUMBER() OVER(ORDER BY p1.prod_detalle ASC) AS Nro_Fila,

    p1.prod_detalle AS Nombre_Prod1,
    p2.prod_detalle AS Nombre_Prod2,

    r.rubr_id AS Cod_Rubro,
    e.enva_codigo AS Cod_Envase,

    ISNULL(CAST(
        SUM(i1.item_cantidad + i2.item_cantidad) * 100.0 /
        (
            SELECT SUM(i3.item_cantidad)
            FROM Factura f3
            JOIN Item_Factura i3
                ON i3.item_tipo = f3.fact_tipo
               AND i3.item_sucursal = f3.fact_sucursal
               AND i3.item_numero = f3.fact_numero
            WHERE YEAR(f3.fact_fecha) = 2011
        )
        AS DECIMAL(12,2)
    ), 0) AS Porcentaje_Unidades_2011

FROM Factura f
JOIN Item_Factura i1
    ON f.fact_tipo = i1.item_tipo
   AND f.fact_sucursal = i1.item_sucursal
   AND f.fact_numero = i1.item_numero

JOIN Producto p1
    ON i1.item_producto = p1.prod_codigo

JOIN Item_Factura i2
    ON f.fact_tipo = i2.item_tipo
   AND f.fact_sucursal = i2.item_sucursal
   AND f.fact_numero = i2.item_numero

JOIN Producto p2
    ON i2.item_producto = p2.prod_codigo

JOIN Rubro r
    ON p1.prod_rubro = r.rubr_id
   AND p2.prod_rubro = r.rubr_id

JOIN Envases e
    ON p1.prod_envase = e.enva_codigo
   AND p2.prod_envase = e.enva_codigo

WHERE YEAR(f.fact_fecha) = 2011
  AND p1.prod_detalle < p2.prod_detalle

GROUP BY
    p1.prod_codigo,
    p1.prod_detalle,
    p2.prod_codigo,
    p2.prod_detalle,
    r.rubr_id,
    e.enva_codigo

HAVING COUNT(DISTINCT f.fact_tipo + '-' + f.fact_sucursal + '-' + f.fact_numero) > 50

ORDER BY
    Nombre_Prod1 ASC;

/* Parcial 08/07/2026 — SQL
Enunciado

Realizar una consulta SQL que devuelva, para cada cliente:

a. Razón social
b. Período AAAAMM en que realizó mayor cantidad de compras
c. Cantidad de productos distintos adquiridos
d. Importe total facturado

Ordenar de forma descendente por la cantidad de facturas emitidas para cada cliente.
*/

SELECT
    c.clie_razon_social AS Razon_Social,

    ISNULL((
        SELECT TOP 1
            CAST(YEAR(fp.fact_fecha) AS CHAR(4)) +
            RIGHT('0' + CAST(MONTH(fp.fact_fecha) AS VARCHAR(2)), 2)
        FROM Factura fp
        WHERE fp.fact_cliente = c.clie_codigo
        GROUP BY 
            YEAR(fp.fact_fecha),
            MONTH(fp.fact_fecha)
        ORDER BY
            COUNT(DISTINCT fp.fact_tipo + '-' + fp.fact_sucursal + '-' + fp.fact_numero) DESC,
            YEAR(fp.fact_fecha),
            MONTH(fp.fact_fecha)
    ), '000000') AS Periodo,

    ISNULL((
        SELECT COUNT(DISTINCT i2.item_producto)
        FROM Factura f2
        JOIN Item_Factura i2
            ON i2.item_tipo = f2.fact_tipo
           AND i2.item_sucursal = f2.fact_sucursal
           AND i2.item_numero = f2.fact_numero
        WHERE f2.fact_cliente = c.clie_codigo
    ), 0) AS Cantidad_Productos_Distintos,

    SUM(f.fact_total) AS Importe_Total

FROM Cliente c
JOIN Factura f
    ON c.clie_codigo = f.fact_cliente

GROUP BY
    c.clie_codigo,
    c.clie_razon_social

ORDER BY
    COUNT(DISTINCT f.fact_tipo + '-' + f.fact_sucursal + '-' + f.fact_numero) DESC;

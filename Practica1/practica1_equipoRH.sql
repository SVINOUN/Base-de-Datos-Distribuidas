
;WITH Ventas2014 AS (
    SELECT
        sod.ProductID,
        soh.CustomerID,
        SUM(sod.OrderQty) AS CantidadVendida
    FROM Sales.SalesOrderHeader AS soh
    JOIN Sales.SalesOrderDetail AS sod
        ON soh.SalesOrderID = sod.SalesOrderID
    WHERE YEAR(soh.OrderDate) = 2014
    GROUP BY sod.ProductID, soh.CustomerID
),
Top10 AS (
    SELECT TOP 10
        ProductID,
        CustomerID,
        CantidadVendida
    FROM Ventas2014
    ORDER BY CantidadVendida DESC
)
SELECT
    p.Name AS Producto,
    t.CantidadVendida,
    COALESCE(pp.FirstName + ' ' + pp.LastName, s.Name) AS Cliente
FROM Top10 AS t
JOIN Production.Product AS p
    ON p.ProductID = t.ProductID
JOIN Sales.Customer AS c
    ON c.CustomerID = t.CustomerID
LEFT JOIN Person.Person AS pp
    ON pp.BusinessEntityID = c.PersonID
LEFT JOIN Sales.Store AS s
    ON s.BusinessEntityID = c.StoreID
ORDER BY t.CantidadVendida DESC;







/*Inciso b*/

;WITH Ventas2014 AS (
    SELECT
        sod.ProductID,
        soh.CustomerID,
        SUM(sod.OrderQty) AS CantidadVendida,
        AVG(CAST(sod.UnitPrice AS DECIMAL(18,2))) AS PrecioUnitarioPromedio
    FROM Sales.SalesOrderHeader AS soh
    JOIN Sales.SalesOrderDetail AS sod
        ON soh.SalesOrderID = sod.SalesOrderID
    WHERE YEAR(soh.OrderDate) = 2014
    GROUP BY sod.ProductID, soh.CustomerID
),
Top10 AS (
    SELECT TOP 10
        ProductID,
        CustomerID,
        CantidadVendida,
        PrecioUnitarioPromedio
    FROM Ventas2014
    ORDER BY CantidadVendida DESC
)
SELECT
    p.Name AS Producto,
    t.CantidadVendida,
    COALESCE(pp.FirstName + ' ' + pp.LastName, s.Name) AS Cliente,
    t.PrecioUnitarioPromedio,
    p.ListPrice
FROM Top10 AS t
JOIN Production.Product AS p
    ON p.ProductID = t.ProductID
JOIN Sales.Customer AS c
    ON c.CustomerID = t.CustomerID
LEFT JOIN Person.Person AS pp
    ON pp.BusinessEntityID = c.PersonID
LEFT JOIN Sales.Store AS s
    ON s.BusinessEntityID = c.StoreID
WHERE p.ListPrice > 1000
ORDER BY t.CantidadVendida DESC;






















USE AdventureWorks2022;
GO

SELECT
    p.BusinessEntityID AS SalesPersonID,
    p.FirstName + ' ' + p.LastName AS Empleado,
    SUM(soh.TotalDue) AS TotalVentas
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesTerritory AS st
    ON st.TerritoryID = soh.TerritoryID
JOIN HumanResources.Employee AS e
    ON e.BusinessEntityID = soh.SalesPersonID
JOIN Person.Person AS p
    ON p.BusinessEntityID = e.BusinessEntityID
WHERE st.Name = 'Northwest'
  AND soh.SalesPersonID IS NOT NULL
GROUP BY p.BusinessEntityID, p.FirstName, p.LastName
HAVING SUM(soh.TotalDue) >
(
    SELECT AVG(VentasPorEmpleado)
    FROM
    (
        SELECT SUM(soh2.TotalDue) AS VentasPorEmpleado
        FROM Sales.SalesOrderHeader AS soh2
        JOIN Sales.SalesTerritory AS st2
            ON st2.TerritoryID = soh2.TerritoryID
        WHERE st2.Name = 'Northwest'
          AND soh2.SalesPersonID IS NOT NULL
        GROUP BY soh2.SalesPersonID
    ) AS x
)
ORDER BY TotalVentas DESC;


/*Usando CTE */


WITH VentasNW AS
(
    SELECT
        soh.SalesPersonID,
        SUM(soh.TotalDue) AS TotalVentas
    FROM Sales.SalesOrderHeader AS soh
    JOIN Sales.SalesTerritory AS st
        ON st.TerritoryID = soh.TerritoryID
    WHERE st.Name = 'Northwest'
      AND soh.SalesPersonID IS NOT NULL
    GROUP BY soh.SalesPersonID
),
PromedioNW AS
(
    SELECT AVG(CAST(TotalVentas AS DECIMAL(18,2))) AS PromedioVentas
    FROM VentasNW
)
SELECT
    p.BusinessEntityID AS SalesPersonID,
    p.FirstName + ' ' + p.LastName AS Empleado,
    v.TotalVentas
FROM VentasNW AS v
CROSS JOIN PromedioNW AS pr
JOIN HumanResources.Employee AS e
    ON e.BusinessEntityID = v.SalesPersonID
JOIN Person.Person AS p
    ON p.BusinessEntityID = e.BusinessEntityID
WHERE v.TotalVentas > pr.PromedioVentas
ORDER BY v.TotalVentas DESC;




/*Ejercicio 3*/


SELECT
    st.Name AS Territorio,
    YEAR(soh.OrderDate) AS Año,
    COUNT(*) AS NumOrdenes,
    SUM(soh.TotalDue) AS VentasTotales
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesTerritory AS st
    ON st.TerritoryID = soh.TerritoryID
GROUP BY
    st.Name,
    YEAR(soh.OrderDate)
HAVING
    COUNT(*) > 5
    AND SUM(soh.TotalDue) > 1000000
ORDER BY
    VentasTotales DESC;




	/*Aplicando desviacion*/


SELECT
    st.Name AS Territorio,
    YEAR(soh.OrderDate) AS Año,
    COUNT(*) AS NumOrdenes,
    SUM(soh.TotalDue) AS VentasTotales,
    STDEV(CAST(soh.TotalDue AS DECIMAL(18,2))) AS DesvStdVentas
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesTerritory AS st
    ON st.TerritoryID = soh.TerritoryID
GROUP BY
    st.Name,
    YEAR(soh.OrderDate)
HAVING
    COUNT(*) > 5
    AND SUM(soh.TotalDue) > 1000000
ORDER BY
    VentasTotales DESC;




--Ejercicio 4: Encuentra vendedores que han vendido TODOS los productos de la categoría "Bikes".
-- Paso 1: Contar cuántos productos existen en la categoría 'Bikes'
WITH TotalBikes AS
(
    SELECT COUNT(P.ProductID) AS Total
    FROM Production.Product P
    JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    JOIN Production.ProductCategory PC ON PSC.ProductCategoryID = PC.ProductCategoryID
    WHERE PC.Name = 'Bikes'
 )
-- Paso 2: Evaluar a cada vendedor y mostrar su nombre
SELECT 
    PER.FirstName + ' ' + PER.LastName AS VendedorEstrella
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
JOIN Production.Product P ON SOD.ProductID = P.ProductID
JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
JOIN Production.ProductCategory PC ON PSC.ProductCategoryID = PC.ProductCategoryID
-- Tablas para sacar el nombre:
JOIN HumanResources.Employee EMP ON SOH.SalesPersonID = EMP.BusinessEntityID
JOIN Person.Person PER ON EMP.BusinessEntityID = PER.BusinessEntityID
WHERE PC.Name = 'Bikes'
GROUP BY SOH.SalesPersonID, PER.FirstName, PER.LastName
-- La división relacional:
HAVING COUNT(DISTINCT SOD.ProductID) = (SELECT Total FROM TotalBikes);



-- Ejercicio 4.1: Cambia a categoría "Clothing" (ID=4)

WITH TotalClothing AS 
    (
    -- Contamos cuántos IDs de producto únicos existen y bautizamos la columna como "Total".
    SELECT COUNT(P.ProductID) AS Total
    FROM Production.Product P
    -- La unimos con la tabla Subcategoría para poder saber a qué categoría padre pertenece cada producto.
    JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
    -- Filtramos estrictamente para que solo cuente los productos que pertenecen a la categoría 4 (Clothing).
    WHERE PSC.ProductCategoryID = 4
    )
-- Iniciamos la consulta principal para buscar al vendedor.
SELECT 
    -- Concatenamos el nombre y apellido del vendedor en una sola columna llamada "VendedorEstrella".
    PER.FirstName + ' ' + PER.LastName AS VendedorEstrella
FROM Sales.SalesOrderHeader SOH
-- Unimos con el detalle de la venta para saber qué productos específicos venían en esa orden.
JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
-- Unimos con el catálogo de productos para vincular el ID vendido con sus características.
JOIN Production.Product P ON SOD.ProductID = P.ProductID
-- Unimos con subcategoría para poder filtrar por el tipo de producto.
JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
-- Unimos con la tabla de empleados para validar el registro de la persona como trabajador.
JOIN HumanResources.Employee EMP ON SOH.SalesPersonID = EMP.BusinessEntityID
-- Unimos con la tabla Person para poder extraer el nombre real (texto) de la persona usando su ID.
JOIN Person.Person PER ON EMP.BusinessEntityID = PER.BusinessEntityID
-- Condicionamos para que todo este rastreo de ventas analice ÚNICAMENTE artículos de ropa (Categoría 4).
WHERE PSC.ProductCategoryID = 4
-- Agrupamos todos los registros por vendedor para poder totalizar el historial de cada uno individualmente.
GROUP BY SOH.SalesPersonID, PER.FirstName, PER.LastName
--Filtramos a los grupos y solo mostramos al vendedor si la cantidad de ropa diferente
--que vendió (COUNT DISTINCT) es exactamente igual al totaal que calculamos en nuestro CTE inicial.
HAVING COUNT(DISTINCT SOD.ProductID) = (SELECT Total FROM TotalClothing);

--validacion Demostración de conjunto vacío

-- Prueba 1: Averiguar matemáticamente cuántos artículos de ropa existen en la base de datos.
SELECT COUNT(P.ProductID) AS TotalRopaEnCatalogo
FROM Production.Product P
JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
WHERE PSC.ProductCategoryID = 4;

-- Prueba 2: Buscar al vendedor que mayor variedad de ropa ha vendido en toda la historia.

SELECT TOP 1
    -- Mostramos su número de empleado.
    SOH.SalesPersonID,
    -- Contamos cuántos artículos de ropa DIFERENTES facturó.
    COUNT(DISTINCT SOD.ProductID) AS RopaDiferenteVendida
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
JOIN Production.Product P ON SOD.ProductID = P.ProductID
JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
-- Filtramos por ropa (ID 4) y excluimos las ventas hechas por internet (donde SalesPersonID es nulo).
WHERE PSC.ProductCategoryID = 4 AND SOH.SalesPersonID IS NOT NULL
-- Agrupamos el conteo por cada vendedor.
GROUP BY SOH.SalesPersonID
-- Ordenamos los resultados de mayor a menor para que el que más vendió quede en la fila 1 (el TOP 1).
ORDER BY RopaDiferenteVendida DESC;




--4.2
SELECT 
    PER.FirstName + ' ' + PER.LastName AS NombreVendedor,
    PC.Name AS CategoriaProducto,
    COUNT(DISTINCT SOD.ProductID) AS VariedadProductosVendidos
FROM Sales.SalesOrderHeader SOH
JOIN Sales.SalesOrderDetail SOD ON SOH.SalesOrderID = SOD.SalesOrderID
JOIN Production.Product P ON SOD.ProductID = P.ProductID
JOIN Production.ProductSubcategory PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
JOIN Production.ProductCategory PC ON PSC.ProductCategoryID = PC.ProductCategoryID
JOIN HumanResources.Employee EMP ON SOH.SalesPersonID = EMP.BusinessEntityID
JOIN Person.Person PER ON EMP.BusinessEntityID = PER.BusinessEntityID
GROUP BY 
    SOH.SalesPersonID, 
    PER.FirstName, 
    PER.LastName, 
    PC.Name
ORDER BY 
    NombreVendedor, 
    CategoriaProducto;
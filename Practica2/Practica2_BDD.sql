SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO


SELECT YEAR(soh.OrderDate) AS Año, MONTH(soh.OrderDate) AS Mes,
       COUNT(*) AS TotalPedidos, SUM(sod.LineTotal) AS TotalVentas
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
GROUP BY YEAR(soh.OrderDate), MONTH(soh.OrderDate);


WITH DetallePorPedido AS
(
    SELECT
        SalesOrderID,
        SUM(LineTotal) AS TotalVentasPedido
    FROM Sales.SalesOrderDetail
    GROUP BY SalesOrderID
)
SELECT
    YEAR(soh.OrderDate) AS Año,
    MONTH(soh.OrderDate) AS Mes,
    COUNT(*) AS TotalPedidos,
    SUM(dpp.TotalVentasPedido) AS TotalVentas
FROM Sales.SalesOrderHeader AS soh
JOIN DetallePorPedido AS dpp
    ON soh.SalesOrderID = dpp.SalesOrderID
GROUP BY
    YEAR(soh.OrderDate),
    MONTH(soh.OrderDate)
ORDER BY Año, Mes;


SELECT 
    c.CustomerID,
    COALESCE(p.FirstName + ' ' + p.LastName, s.Name) AS Nombre,
    COUNT(*) AS TotalPedidos
FROM Sales.Customer c
JOIN Sales.SalesOrderHeader soh 
    ON c.CustomerID = soh.CustomerID
LEFT JOIN Person.Person p
    ON c.PersonID = p.BusinessEntityID
LEFT JOIN Sales.Store s
    ON c.StoreID = s.BusinessEntityID
WHERE COALESCE(p.FirstName + ' ' + p.LastName, s.Name) LIKE 'A%'
GROUP BY 
    c.CustomerID,
    COALESCE(p.FirstName + ' ' + p.LastName, s.Name);


	SELECT c.CustomerID, c.Name, COUNT(*) AS TotalPedidos
FROM Sales.Customer c
JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
WHERE UPPER(c.Name) LIKE 'A%'
GROUP BY c.CustomerID, c.Name;





SELECT TOP 100 sod.SalesOrderDetailID, sod.OrderQty, sod.UnitPrice, soh.OrderDate
FROM Sales.SalesOrderDetail sod
JOIN Sales.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
ORDER BY soh.ShipDate DESC, sod.OrderQty DESC, sod.UnitPrice DESC;


WITH TopPedidos AS
(
    SELECT TOP 100
        SalesOrderID,
        OrderDate,
        ShipDate
    FROM Sales.SalesOrderHeader
    WHERE ShipDate IS NOT NULL
    ORDER BY ShipDate DESC
)
SELECT TOP 100
    sod.SalesOrderDetailID,
    sod.OrderQty,
    sod.UnitPrice,
    tp.OrderDate
FROM TopPedidos tp
JOIN Sales.SalesOrderDetail sod
    ON tp.SalesOrderID = sod.SalesOrderID
ORDER BY 
    tp.ShipDate DESC,
    sod.OrderQty DESC,
    sod.UnitPrice DESC;


SELECT 
    p.ProductID, 
    p.Name, 
    SUM(sod.OrderQty) AS TotalVendido
FROM Production.Product p
JOIN Sales.SalesOrderDetail sod 
    ON p.ProductID = sod.ProductID
JOIN Sales.SalesOrderHeader soh 
    ON sod.SalesOrderID = soh.SalesOrderID
WHERE soh.OrderDate >= '2014-01-01'
GROUP BY 
    p.ProductID, 
    p.Name
HAVING SUM(sod.OrderQty) > 100;


WITH Pedidos2014 AS
(
    SELECT SalesOrderID
    FROM Sales.SalesOrderHeader
    WHERE OrderDate >= '2014-01-01'
      AND OrderDate < '2015-01-01'
)
SELECT
    p.ProductID,
    p.Name,
    SUM(sod.OrderQty) AS TotalVendido
FROM Pedidos2014 AS p2014
JOIN Sales.SalesOrderDetail AS sod
    ON p2014.SalesOrderID = sod.SalesOrderID
JOIN Production.Product AS p
    ON p.ProductID = sod.ProductID
GROUP BY
    p.ProductID,
    p.Name
HAVING SUM(sod.OrderQty) > 100;



SELECT p.ProductID, p.Name,
       (SELECT COUNT(*) FROM Sales.SalesOrderDetail sod WHERE sod.ProductID = p.ProductID) AS VecesVendido,
       (SELECT SUM(sod.OrderQty * sod.UnitPrice) FROM Sales.SalesOrderDetail sod WHERE sod.ProductID = p.ProductID) AS Ingresos
FROM Production.Product p
JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
WHERE psc.ProductCategoryID = 3;


WITH VentasPorProducto AS
(
    SELECT
        sod.ProductID,
        COUNT(*) AS VecesVendido,
        SUM(sod.OrderQty * sod.UnitPrice) AS Ingresos
    FROM Sales.SalesOrderDetail sod
    GROUP BY sod.ProductID
)
SELECT
    p.ProductID,
    p.Name,
    ISNULL(vpp.VecesVendido, 0) AS VecesVendido,
    ISNULL(vpp.Ingresos, 0) AS Ingresos
FROM Production.Product p
JOIN Production.ProductSubcategory pscs
    ON p.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN VentasPorProducto vpp
    ON p.ProductID = vpp.ProductID
WHERE psc.ProductCategoryID = 3;



SELECT c.Name AS Cliente, p.Name AS Producto, 
       SUM(sod.OrderQty) AS Cantidad, SUM(sod.LineTotal) AS Total,
       DATEDIFF(day, soh.OrderDate, soh.ShipDate) AS DiasEnvio
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p ON sod.ProductID = p.ProductID
WHERE DATEDIFF(day, soh.OrderDate, soh.ShipDate) > 5
  AND DATEPART(quarter, soh.OrderDate) = 2
  AND sod.LineTotal > 1000
GROUP BY c.Name, p.Name, soh.OrderDate, soh.ShipDate
ORDER BY Total DESC;}

SELECT 
    COALESCE(pp.FirstName + ' ' + pp.LastName, s.Name) AS Cliente,
    p.Name AS Producto,
    SUM(sod.OrderQty) AS Cantidad,
    SUM(sod.LineTotal) AS Total,
    DATEDIFF(day, soh.OrderDate, soh.ShipDate) AS DiasEnvio
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c 
    ON soh.CustomerID = c.CustomerID
LEFT JOIN Person.Person pp
    ON c.PersonID = pp.BusinessEntityID
LEFT JOIN Sales.Store s
    ON c.StoreID = s.BusinessEntityID
JOIN Sales.SalesOrderDetail sod 
    ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p 
    ON sod.ProductID = p.ProductID
WHERE DATEDIFF(day, soh.OrderDate, soh.ShipDate) > 5
  AND DATEPART(quarter, soh.OrderDate) = 2
  AND sod.LineTotal > 1000
GROUP BY 
    COALESCE(pp.FirstName + ' ' + pp.LastName, s.Name),
    p.Name,
    soh.OrderDate,
    soh.ShipDate
ORDER BY Total DESC;

SELECT
    COALESCE(pp.FirstName + ' ' + pp.LastName, s.Name) AS Cliente,
    p.Name AS Producto,
    SUM(sod.OrderQty) AS Cantidad,
    SUM(sod.LineTotal) AS Total,
    DATEDIFF(day, soh.OrderDate, soh.ShipDate) AS DiasEnvio
FROM Sales.SalesOrderHeader soh
JOIN Sales.Customer c
    ON soh.CustomerID = c.CustomerID
LEFT JOIN Person.Person pp
    ON c.PersonID = pp.BusinessEntityID
LEFT JOIN Sales.Store s
    ON c.StoreID = s.BusinessEntityID
JOIN Sales.SalesOrderDetail sod
    ON soh.SalesOrderID = sod.SalesOrderID
JOIN Production.Product p
    ON sod.ProductID = p.ProductID
WHERE soh.ShipDate > DATEADD(day, 5, soh.OrderDate)
  AND soh.OrderDate >= '2014-04-01'
  AND soh.OrderDate < '2014-07-01'
  AND sod.LineTotal > 1000
GROUP BY
    COALESCE(pp.FirstName + ' ' + pp.LastName, s.Name),
    p.Name,
    soh.OrderDate,
    soh.ShipDate
ORDER BY Total DESC;
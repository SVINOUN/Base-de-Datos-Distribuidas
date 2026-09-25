/*
  TOPOLOGÍA:
  - Servidor A (Nodo Local / Coordinador Global):
      Aloja fragmentos de ventas en línea (OnlineOrderFlag = 1): F1, F3, F5.
      Aloja tablas globales replicadas: SalesTerritory, Customer, Product.
      Ejecuta las vistas  globales y las consultas de la práctica.
  - Servidor B (Nodo Remoto - IP: 172.20.10.2):
      * Aloja fragmentos de ventas en mostrador (OnlineOrderFlag = 0): F2, F4, F6[cite: 1].
      * Aloja fragmento residual / nuevos territorios: F7[cite: 1].
      * Aloja tablas globales replicadas: SalesTerritory, Customer, Product[cite: 1].
*/

-- CONFIGURACIÓN DE LA CONECTIVIDAD DISTRIBUIDA (LINKED SERVER)
-- Nodo de ejecución: SERVIDOR A
-- Propósito: Establecer el canal de comunicación (MSOLEDBSQL) sobre TCP/IP (puerto 1433)


USE master;
GO

-- 1. Eliminar el linked server previo con el parámetro rechazado

IF EXISTS (SELECT * FROM sys.servers WHERE name = 'SERVIDOR_B')
BEGIN
    EXEC sp_dropserver @server = 'SERVIDOR_B', @droplogins = 'droplogins';
END
GO

-- 2. Crear el enlace 
EXEC sp_addlinkedserver 
   @server = N'SERVIDOR_B', 
   @srvproduct = N'',
   @provider = N'MSOLEDBSQL', 
   @datasrc = N'tcp:172.20.10.2,1433',
   @provstr = N'TrustServerCertificate=yes;';
GO

-- 3. Autenticación
EXEC sp_addlinkedsrvlogin 
   @rmtsrvname = N'SERVIDOR_B', 
   @useself = N'False', 
   @locallogin = NULL, 
   @rmtuser = N'sa', 
   @rmtpassword = N'UPIITABDD';
GO

-- 4. Habilitar RPC para ejecución de planes distribuidos
EXEC sp_serveroption @server = N'SERVIDOR_B', @optname = N'rpc', @optvalue = N'true';
EXEC sp_serveroption @server = N'SERVIDOR_B', @optname = N'rpc out', @optvalue = N'true';
GO



-- Nodo de ejecución: SERVIDOR A -> SERVIDOR B

-- Valida existencia de la BD 'PracticaDistribuidas' en Servidor B
SELECT name 
FROM [SERVIDOR_B].master.sys.databases;
GO

-- Lista de tablas y fragmentos materializados en Servidor B
SELECT TABLE_SCHEMA, TABLE_NAME 
FROM [SERVIDOR_B].[PracticaDistribuidas].INFORMATION_SCHEMA.TABLES;
GO

-- Prueba de aislamiento de lectura sobre fragmento primario remoto
SELECT TOP 5 * 
FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F2SOH];
GO



-- Nodo de ejecución: SERVIDOR A (BD: PracticaDistribuidas)

USE PracticaDistribuidas;
GO

-- 1. Vista Federada Global para SalesOrderHeader (Unión de los 7 fragmentos)
CREATE OR ALTER VIEW dbo.V_Global_SalesOrderHeader AS
    -- Fragmentos locales de ventas en línea (Servidor A)
    SELECT * FROM dbo.F1SOH
    UNION ALL
    SELECT * FROM dbo.F3SOH
    UNION ALL
    SELECT * FROM dbo.F5SOH
    UNION ALL
    -- Fragmentos remotos de mostrador y nuevos territorios (Servidor B)
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F2SOH]
    UNION ALL
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F4SOH]
    UNION ALL
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F6SOH]
    UNION ALL
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F7SOH];
GO

-- 2. Vista Federada Global para SalesOrderDetail (Unión de los fragmentos derivados)
CREATE OR ALTER VIEW dbo.V_Global_SalesOrderDetail AS
    -- Fragmentos locales (Servidor A)
    SELECT * FROM dbo.F1SOD
    UNION ALL
    SELECT * FROM dbo.F3SOD
    UNION ALL
    SELECT * FROM dbo.F5SOD
    UNION ALL
    -- Fragmentos remotos (Servidor B)
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F2SOD]
    UNION ALL
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F4SOD]
    UNION ALL
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F6SOD]
    UNION ALL
    SELECT * FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F7SOD];
GO


-- CONSULTAS DISTRIBUIDAS DE NEGOCIO
-- Nodo de ejecución: SERVIDOR A

-- CONSULTA 1: Reporte global de ventas totales en línea y promedio de compra
-- Requerimiento: Finanzas solicita total vendido en línea y promedio por cliente,
--               ordenado de mayor a menor[cite: 1].


-- Uso de la vista federada global
SELECT 
    c.CustomerID,
    SUM(soh.TotalDue) AS VentasTotalesEnLinea,
    AVG(soh.TotalDue) AS PromedioCompraCliente
FROM dbo.V_Global_SalesOrderHeader soh
INNER JOIN dbo.Customer c 
    ON soh.CustomerID = c.CustomerID
WHERE soh.OnlineOrderFlag = 1
GROUP BY c.CustomerID
ORDER BY VentasTotalesEnLinea DESC;

-- Optimización distribuida por reducción y localización
-- Dado que el predicado exige 'OnlineOrderFlag = 1', los fragmentos remotos 
-- de mostrador (F2, F4, F6) se descartan por contradicción (σ = Ø)
WITH VentasEnLineaLocales AS (
    SELECT CustomerID, TotalDue FROM dbo.F1SOH
    UNION ALL
    SELECT CustomerID, TotalDue FROM dbo.F3SOH
    UNION ALL
    SELECT CustomerID, TotalDue FROM dbo.F5SOH
)
SELECT 
    c.CustomerID,
    SUM(v.TotalDue) AS VentasTotalesEnLinea,
    AVG(v.TotalDue) AS PromedioCompraCliente
FROM VentasEnLineaLocales v
INNER JOIN dbo.Customer c 
    ON v.CustomerID = c.CustomerID
GROUP BY c.CustomerID
ORDER BY VentasTotalesEnLinea DESC;


-- Comparación de ventas 2014 entre North America y Pacific


WITH VentasNAPacific2014 AS (
    -- North America: En Línea (Local)
    SELECT TerritoryID, OnlineOrderFlag, SalesOrderID, TotalDue, OrderDate 
    FROM dbo.F1SOH
    UNION ALL
    -- North America: Mostrador (Remoto en B)
    SELECT TerritoryID, OnlineOrderFlag, SalesOrderID, TotalDue, OrderDate 
    FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F2SOH]
    UNION ALL
    -- Pacific: En Línea (Local)
    SELECT TerritoryID, OnlineOrderFlag, SalesOrderID, TotalDue, OrderDate 
    FROM dbo.F5SOH
    UNION ALL
    -- Pacific: Mostrador (Remoto en B)
    SELECT TerritoryID, OnlineOrderFlag, SalesOrderID, TotalDue, OrderDate 
    FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F6SOH]
)
SELECT a
    st.[Group] AS Region,
    st.CountryRegionCode AS CodigoPais,
    st.Name AS NombreTerritorio,
    CASE 
        WHEN v.OnlineOrderFlag = 1 THEN 'En Línea'
        ELSE 'Mostrador'
    END AS CanalVenta,
    COUNT(v.SalesOrderID) AS CantidadOrdenes,
    SUM(v.TotalDue) AS MontoTotalVentas
FROM VentasNAPacific2014 v
INNER JOIN dbo.SalesTerritory st 
    ON v.TerritoryID = st.TerritoryID
WHERE YEAR(v.OrderDate) = 2014
GROUP BY 
    st.[Group],
    st.CountryRegionCode,
    st.Name,
    v.OnlineOrderFlag
ORDER BY 
    st.[Group], 
    NombreTerritorio, 
    CanalVenta;


-- Top 5 de productos más vendidos en la región Europa
-- Requerimiento: Marketing Europa solicita los 5 productos con mayor volumen 
--               de ventas (nombre, número y cantidad total)

WITH VentasEuropaDetalle AS (
    -- Ventas en línea Europa (Local en Servidor A)
    SELECT ProductID, OrderQty FROM dbo.F3SOD
    UNION ALL
    -- Ventas en mostrador Europa (Remoto en Servidor B)
    SELECT ProductID, OrderQty FROM [SERVIDOR_B].[PracticaDistribuidas].[dbo].[F4SOD]
),
ConsolidadoProductos AS (
    SELECT 
        ProductID,
        SUM(OrderQty) AS TotalCantidadVendida
    FROM VentasEuropaDetalle
    GROUP BY ProductID
)
SELECT TOP 5
    p.ProductID,
    p.Name AS NombreProducto,
    p.ProductNumber AS NumeroProducto,
    cp.TotalCantidadVendida
FROM ConsolidadoProductos cp
INNER JOIN dbo.[Product] p 
    ON cp.ProductID = p.ProductID
ORDER BY cp.TotalCantidadVendida DESC;


-- Total de tuplas obtenidas a través de la unión distribuida en la Vista Global
SELECT COUNT(*) AS Conteo_VistaFederadaGlobal 
FROM dbo.V_Global_SalesOrderHeader;

-- Total de tuplas existentes en la tabla centralizada original
SELECT COUNT(*) AS Conteo_TablaCentralizadaOriginal 
FROM AdventureWorks2022.Sales.SalesOrderHeader;
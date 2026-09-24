USE covidHistorico2;
GO

ALTER DATABASE covidHistorico2 ADD FILEGROUP FG_P3_2020;
ALTER DATABASE covidHistorico2 ADD FILEGROUP FG_P3_2021;
ALTER DATABASE covidHistorico2 ADD FILEGROUP FG_P3_2022;
GO

ALTER DATABASE covidHistorico2
ADD FILE
(
    NAME = N'Covid_P3_2020',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\Covid_P3_2020.ndf',
    SIZE = 64MB,
    FILEGROWTH = 64MB
)
TO FILEGROUP FG_P3_2020;
GO

ALTER DATABASE covidHistorico2
ADD FILE
(
    NAME = N'Covid_P3_2021',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\Covid_P3_2021.ndf',
    SIZE = 64MB,
    FILEGROWTH = 64MB
)
TO FILEGROUP FG_P3_2021;
GO

ALTER DATABASE covidHistorico2
ADD FILE
(
    NAME = N'Covid_P3_2022',
    FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\Covid_P3_2022.ndf',
    SIZE = 64MB,
    FILEGROWTH = 64MB
)
TO FILEGROUP FG_P3_2022;
GO

CREATE PARTITION FUNCTION pf_p3_anio (DATE)
AS RANGE RIGHT
FOR VALUES ('20210101', '20220101');
GO

CREATE PARTITION SCHEME ps_p3_anio
AS PARTITION pf_p3_anio
TO (FG_P3_2020, FG_P3_2021, FG_P3_2022);
GO

CREATE TABLE dbo.covid_particionado_p3
(
    FECHA_INGRESO DATE NOT NULL,
    ENTIDAD_RES VARCHAR(50) NULL,
    EDAD INT NULL,

    CONSTRAINT CK_covid_p3_fechas
        CHECK
        (
            FECHA_INGRESO >= '20200101'
            AND FECHA_INGRESO < '20230101'
        )
)
ON ps_p3_anio(FECHA_INGRESO);
GO

CREATE CLUSTERED INDEX IX_covid_p3_fecha
ON dbo.covid_particionado_p3(FECHA_INGRESO)
ON ps_p3_anio(FECHA_INGRESO);
GO

/*5*/
IF EXISTS (SELECT 1 FROM dbo.covid_particionado_p3)
BEGIN
    THROW 50001,
          'La tabla ya contiene registros. No se repetira la carga.',
          1;
END;

INSERT INTO dbo.covid_particionado_p3
(
    FECHA_INGRESO,
    ENTIDAD_RES,
    EDAD
)
SELECT
    f.Fecha,
    REPLACE(d.ENTIDAD_RES, '"', ''),
    TRY_CONVERT(INT, REPLACE(d.EDAD, '"', ''))
FROM dbo.datoscovid AS d
CROSS APPLY
(
    VALUES
    (
        TRY_CONVERT(
            DATE,
            REPLACE(d.FECHA_INGRESO, '"', ''),
            23
        )
    )
) AS f(Fecha)
WHERE f.Fecha >= '20200101'
  AND f.Fecha < '20230101';
GO

/*6*/
SELECT
    $PARTITION.pf_p3_anio(FECHA_INGRESO) AS Particion,
    YEAR(FECHA_INGRESO) AS Anio,
    COUNT_BIG(*) AS Registros,
    MIN(FECHA_INGRESO) AS PrimeraFecha,
    MAX(FECHA_INGRESO) AS UltimaFecha
FROM dbo.covid_particionado_p3
GROUP BY
    $PARTITION.pf_p3_anio(FECHA_INGRESO),
    YEAR(FECHA_INGRESO)
ORDER BY Particion;
GO

/*7*/
SELECT
    p.partition_number AS Particion,
    fg.name AS GrupoArchivos,
    p.rows AS Registros
FROM sys.indexes AS i
JOIN sys.partitions AS p
    ON p.object_id = i.object_id
   AND p.index_id = i.index_id
JOIN sys.partition_schemes AS ps
    ON ps.data_space_id = i.data_space_id
JOIN sys.destination_data_spaces AS dds
    ON dds.partition_scheme_id = ps.data_space_id
   AND dds.destination_id = p.partition_number
JOIN sys.filegroups AS fg
    ON fg.data_space_id = dds.data_space_id
WHERE i.object_id = OBJECT_ID(N'dbo.covid_particionado_p3')
  AND i.index_id = 1
ORDER BY p.partition_number;
GO

/*8*/
SET STATISTICS IO ON;

SELECT COUNT_BIG(*) AS Registros2021
FROM dbo.covid_particionado_p3
WHERE FECHA_INGRESO >= '20210101'
  AND FECHA_INGRESO < '20220101';

SET STATISTICS IO OFF;
GO

/*..*/
USE covidHistorico2;
GO

SELECT COUNT_BIG(*) AS Registros2021
FROM dbo.covid_particionado_p3
WHERE FECHA_INGRESO >= '20210101'
  AND FECHA_INGRESO <  '20220101'
OPTION (RECOMPILE);
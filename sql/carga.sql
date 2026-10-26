/* =====================================================================
   PROYECTO INTEGRADOR · Comercio exterior de Argentina y Uruguay
   Archivo: carga.sql
   Contenido: carga de los CSV limpios (generados por el notebook
              01_carga_y_limpieza.ipynb) en las tablas creadas por ddl.sql.
   Orden de ejecución: 1) ddl.sql  2) carga.sql  3) analisis.sql

   ANTES DE EJECUTAR:
   1. Reemplazar la ruta 'D:/Bootcamp/Proyecto/' por la carpeta donde
      están los CSV. Usar barras normales (/), no invertidas (\).
   2. La conexión de Workbench tiene que permitir leer archivos locales
      (ver el instructivo: OPT_LOCAL_INFILE=1).
   ===================================================================== */

USE comercio_arg_uy;

-- Habilitar en el servidor la lectura de archivos locales
SET GLOBAL local_infile = 1;

-- Workbench trae activado el "modo seguro", que no permite DELETE sin WHERE.
-- Lo desactivamos solo durante la carga (se vuelve a activar al final).
SET SQL_SAFE_UPDATES = 0;

-- Vaciar las tablas para poder volver a ejecutar la carga sin duplicar datos.
-- Primero la tabla de hechos, porque depende de dim_socio (clave foránea).
DELETE FROM fact_comercio;
DELETE FROM dim_socio;


/* ---------------------------------------------------------------------
   1) Dimensión de socios
   --------------------------------------------------------------------- */
LOAD DATA LOCAL INFILE 'D:/Bootcamp/Proyecto/dim_socio.csv'
INTO TABLE dim_socio
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'      -- nombres con coma, ej.: "Bahamas, The"
LINES TERMINATED BY '\n'
IGNORE 1 LINES                         -- saltear la fila de encabezados
(id_socio, nombre_socio, tipo_socio);


/* ---------------------------------------------------------------------
   2) Tabla de hechos
   Las celdas vacías del CSV llegan como texto vacío ('').
   Se leen primero en variables (@usd, @pct) y NULLIF las convierte en NULL;
   si no, MySQL las guardaría como 0, que no es lo mismo que "sin dato".
   --------------------------------------------------------------------- */
LOAD DATA LOCAL INFILE 'D:/Bootcamp/Proyecto/fact_comercio.csv'
INTO TABLE fact_comercio
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
       OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(pais_reportante, id_socio, flujo, anio, @usd, @pct)
SET valor_miles_usd   = NULLIF(@usd, ''),
    participacion_pct = NULLIF(@pct, '');

-- Volver a activar el modo seguro de Workbench
SET SQL_SAFE_UPDATES = 1;


/* ---------------------------------------------------------------------
   3) Verificación de la carga
   --------------------------------------------------------------------- */
-- Cantidad de filas: deben coincidir con las que informa el notebook (Paso 6)
SELECT 'dim_socio'     AS tabla, COUNT(*) AS filas FROM dim_socio
UNION ALL
SELECT 'fact_comercio' AS tabla, COUNT(*) AS filas FROM fact_comercio;

-- Las celdas vacías tienen que haber quedado como NULL, no como 0
SELECT SUM(valor_miles_usd IS NULL)   AS usd_sin_dato,
       SUM(participacion_pct IS NULL) AS pct_sin_dato
FROM fact_comercio;

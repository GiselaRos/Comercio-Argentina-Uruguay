/* =====================================================================
   PROYECTO INTEGRADOR · Comercio exterior de Argentina y Uruguay
   Archivo: ddl.sql
   Contenido: estructura de la base de datos (solo CREATE, sin datos).
   Fuente de datos: World Bank – WITS, descarga "Partner-Timeseries".
   Orden de ejecución: 1) ddl.sql  2) carga_datos.sql  3) analisis.sql
   ===================================================================== */

-- Crear la base desde cero (borra la anterior si existe)
DROP DATABASE IF EXISTS comercio_arg_uy;
CREATE DATABASE comercio_arg_uy
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE comercio_arg_uy;


/* ---------------------------------------------------------------------
   DIMENSIÓN: dim_socio
   Un registro por socio comercial (país, región o total mundial).
   tipo_socio indica cómo se puede sumar:
     'Pais'   → país individual. Se puede sumar con otros países.
     'Otro'   → destino no identificado (Unspecified, Free Zones...).
     'Region' → agregado regional del Banco Mundial. NO sumar con países.
     'Total'  → World, el total del país con el mundo.
   --------------------------------------------------------------------- */
CREATE TABLE dim_socio (
  id_socio      INT          NOT NULL,
  nombre_socio  VARCHAR(100) NOT NULL,
  tipo_socio    ENUM('Pais', 'Region', 'Total', 'Otro') NOT NULL,
  CONSTRAINT pk_dim_socio PRIMARY KEY (id_socio),
  CONSTRAINT uq_nombre_socio UNIQUE (nombre_socio)
);


/* ---------------------------------------------------------------------
   HECHOS: fact_comercio
   Un registro por país informante + socio + flujo + año.
   valor_miles_usd   → monto comerciado, en MILES de US$ corrientes.
   participacion_pct → % que representa ese socio en el total del país.
   Cualquiera de las dos medidas puede ser NULL si WITS no informa el dato.
   --------------------------------------------------------------------- */
CREATE TABLE fact_comercio (
  pais_reportante    VARCHAR(20)   NOT NULL,   -- 'Argentina' o 'Uruguay'
  id_socio           INT           NOT NULL,
  flujo              ENUM('Export', 'Import') NOT NULL,
  anio               SMALLINT      NOT NULL,
  valor_miles_usd    DECIMAL(18,3) NULL,
  participacion_pct  DECIMAL(9,4)  NULL,
  CONSTRAINT pk_fact_comercio PRIMARY KEY (pais_reportante, id_socio, flujo, anio),
  CONSTRAINT fk_fact_socio FOREIGN KEY (id_socio) REFERENCES dim_socio (id_socio)
);

-- Índice para acelerar los filtros más comunes (por año y flujo)
CREATE INDEX idx_fact_anio_flujo ON fact_comercio (anio, flujo);

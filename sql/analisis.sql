/* =====================================================================
   PROYECTO INTEGRADOR · Comercio exterior de Argentina y Uruguay
   Archivo: analisis.sql
   Contenido: exploración, controles de calidad y consultas de análisis.
   Requisito: haber ejecutado ddl.sql y carga.sql.

   Convenciones usadas en todo el archivo:
   - Los montos están en MILES de US$. Para mostrarlos en MILLONES se
     dividen por 1000.
   - Para sumar o comparar socios se filtra tipo_socio = 'Pais'.
     El total de cada país con el mundo es tipo_socio = 'Total' (World).
   - Período comparable entre ambos países: 1994–2023.
   ===================================================================== */

USE comercio_arg_uy;


/* =====================================================================
   PARTE 1 · EXPLORACIÓN INICIAL Y CONTROLES DE CALIDAD
   ===================================================================== */

-- 1.1 Cantidad de socios según su tipo
SELECT tipo_socio, COUNT(*) AS cantidad
FROM dim_socio
GROUP BY tipo_socio
ORDER BY cantidad DESC;

-- 1.2 Rango de años y cantidad de registros por país y flujo
SELECT pais_reportante,
       flujo,
       MIN(anio)  AS primer_anio,
       MAX(anio)  AS ultimo_anio,
       COUNT(*)   AS registros
FROM fact_comercio
GROUP BY pais_reportante, flujo
ORDER BY pais_reportante, flujo;

-- 1.3 Registros sin monto en US$ (WITS informa el % pero no el monto).
--     Resultado: son todos casos en que el país figura como socio de sí mismo
--     (reimportaciones: mercadería exportada que vuelve a ingresar). Su peso es
--     menor al 0,5 % y no afecta el análisis.
SELECT f.pais_reportante, f.flujo, f.anio, s.nombre_socio, f.participacion_pct
FROM fact_comercio f
JOIN dim_socio s ON s.id_socio = f.id_socio
WHERE f.valor_miles_usd IS NULL
ORDER BY f.pais_reportante, f.anio;

-- 1.4 Control: la suma de los socios (países + otros) vs. el total World.
--     Una diferencia chica es esperable: WITS no detalla algunos socios menores.
WITH suma_socios AS (
    SELECT f.pais_reportante, f.flujo, f.anio,
           SUM(f.valor_miles_usd) AS suma
    FROM fact_comercio f
    JOIN dim_socio s ON s.id_socio = f.id_socio
    WHERE s.tipo_socio IN ('Pais', 'Otro')
    GROUP BY f.pais_reportante, f.flujo, f.anio
),
total_world AS (
    SELECT f.pais_reportante, f.flujo, f.anio,
           f.valor_miles_usd AS total
    FROM fact_comercio f
    JOIN dim_socio s ON s.id_socio = f.id_socio
    WHERE s.tipo_socio = 'Total'
)
SELECT t.pais_reportante, t.flujo,
       ROUND(MAX(ABS(s.suma / t.total - 1) * 100), 2) AS diferencia_maxima_pct
FROM total_world t
JOIN suma_socios s
  ON  s.pais_reportante = t.pais_reportante
  AND s.flujo = t.flujo
  AND s.anio  = t.anio
GROUP BY t.pais_reportante, t.flujo;


/* =====================================================================
   PARTE 2 · EVOLUCIÓN DEL COMERCIO Y BALANZA COMERCIAL
   ===================================================================== */

-- 2.1 Vista con exportaciones, importaciones y balanza por país y año,
--     en millones de US$. La usan las consultas siguientes y Power BI.
CREATE OR REPLACE VIEW vw_balanza_anual AS
SELECT f.pais_reportante,
       f.anio,
       ROUND(SUM(CASE WHEN f.flujo = 'Export' THEN f.valor_miles_usd END) / 1000, 1) AS exportaciones_musd,
       ROUND(SUM(CASE WHEN f.flujo = 'Import' THEN f.valor_miles_usd END) / 1000, 1) AS importaciones_musd,
       ROUND((SUM(CASE WHEN f.flujo = 'Export' THEN f.valor_miles_usd END)
            - SUM(CASE WHEN f.flujo = 'Import' THEN f.valor_miles_usd END)) / 1000, 1) AS balanza_musd
FROM fact_comercio f
JOIN dim_socio s ON s.id_socio = f.id_socio
WHERE s.tipo_socio = 'Total'
  AND f.anio BETWEEN 1994 AND 2023
GROUP BY f.pais_reportante, f.anio;

SELECT * FROM vw_balanza_anual ORDER BY pais_reportante, anio;

-- 2.2 Variación interanual (%) de exportaciones e importaciones.
--     LAG trae el valor del año anterior dentro de cada país.
SELECT pais_reportante,
       anio,
       exportaciones_musd,
       ROUND((exportaciones_musd / LAG(exportaciones_musd) OVER w - 1) * 100, 1) AS var_expo_pct,
       importaciones_musd,
       ROUND((importaciones_musd / LAG(importaciones_musd) OVER w - 1) * 100, 1) AS var_impo_pct
FROM vw_balanza_anual
WINDOW w AS (PARTITION BY pais_reportante ORDER BY anio)
ORDER BY pais_reportante, anio;

-- 2.3 Las 3 mayores caídas de importaciones de cada país
--     (las importaciones suelen reaccionar primero ante una crisis).
WITH variaciones AS (
    SELECT pais_reportante,
           anio,
           ROUND((importaciones_musd / LAG(importaciones_musd)
                  OVER (PARTITION BY pais_reportante ORDER BY anio) - 1) * 100, 1) AS var_impo_pct
    FROM vw_balanza_anual
),
ranking AS (
    SELECT *,
           RANK() OVER (PARTITION BY pais_reportante ORDER BY var_impo_pct) AS puesto
    FROM variaciones
    WHERE var_impo_pct IS NOT NULL
)
SELECT pais_reportante, anio, var_impo_pct, puesto
FROM ranking
WHERE puesto <= 3
ORDER BY pais_reportante, puesto;

-- 2.4 Años con superávit y con déficit comercial por país
SELECT pais_reportante,
       SUM(balanza_musd > 0) AS anios_superavit,
       SUM(balanza_musd < 0) AS anios_deficit
FROM vw_balanza_anual
GROUP BY pais_reportante;


/* =====================================================================
   PARTE 3 · PRINCIPALES SOCIOS COMERCIALES
   ===================================================================== */

-- 3.1 Top 5 socios de cada país y flujo en 2023
WITH ranking AS (
    SELECT f.pais_reportante,
           f.flujo,
           s.nombre_socio,
           ROUND(f.valor_miles_usd / 1000, 1) AS millones_usd,
           f.participacion_pct,
           RANK() OVER (PARTITION BY f.pais_reportante, f.flujo
                        ORDER BY f.valor_miles_usd DESC) AS puesto
    FROM fact_comercio f
    JOIN dim_socio s ON s.id_socio = f.id_socio
    WHERE s.tipo_socio = 'Pais'
      AND f.anio = 2023
)
SELECT *
FROM ranking
WHERE puesto <= 5
ORDER BY pais_reportante, flujo, puesto;

-- 3.2 Participación de Brasil, China y Estados Unidos cada 5 años.
--     Muestra el avance de China frente a los socios tradicionales.
SELECT f.pais_reportante,
       f.flujo,
       f.anio,
       MAX(CASE WHEN s.nombre_socio = 'Brazil'        THEN f.participacion_pct END) AS brasil_pct,
       MAX(CASE WHEN s.nombre_socio = 'China'         THEN f.participacion_pct END) AS china_pct,
       MAX(CASE WHEN s.nombre_socio = 'United States' THEN f.participacion_pct END) AS eeuu_pct
FROM fact_comercio f
JOIN dim_socio s ON s.id_socio = f.id_socio
WHERE f.anio IN (1994, 1998, 2003, 2008, 2013, 2018, 2023)
GROUP BY f.pais_reportante, f.flujo, f.anio
ORDER BY f.pais_reportante, f.flujo, f.anio;

-- 3.3 Primer socio de cada país y flujo, año por año
--     (permite ver en qué año China superó a Brasil, si ocurrió).
WITH ranking AS (
    SELECT f.pais_reportante, f.flujo, f.anio, s.nombre_socio, f.participacion_pct,
           ROW_NUMBER() OVER (PARTITION BY f.pais_reportante, f.flujo, f.anio
                              ORDER BY f.participacion_pct DESC) AS puesto
    FROM fact_comercio f
    JOIN dim_socio s ON s.id_socio = f.id_socio
    WHERE s.tipo_socio = 'Pais'
)
SELECT pais_reportante, flujo, anio, nombre_socio AS primer_socio, participacion_pct
FROM ranking
WHERE puesto = 1
ORDER BY pais_reportante, flujo, anio;


/* =====================================================================
   PARTE 4 · CONCENTRACIÓN DEL COMERCIO
   Índice Herfindahl-Hirschman (HHI): suma de los cuadrados de la
   participación (%) de cada socio. Va de 0 a 10.000.
     menos de 1.500   → comercio diversificado
     1.500 a 2.500    → concentración moderada
     más de 2.500     → comercio concentrado
   ===================================================================== */

-- 4.1 Vista con el HHI y la participación de los 3 primeros socios
CREATE OR REPLACE VIEW vw_concentracion AS
WITH ranking AS (
    SELECT f.pais_reportante, f.flujo, f.anio, f.participacion_pct,
           ROW_NUMBER() OVER (PARTITION BY f.pais_reportante, f.flujo, f.anio
                              ORDER BY f.participacion_pct DESC) AS puesto
    FROM fact_comercio f
    JOIN dim_socio s ON s.id_socio = f.id_socio
    WHERE s.tipo_socio = 'Pais'
      AND f.anio BETWEEN 1994 AND 2023
)
SELECT pais_reportante,
       flujo,
       anio,
       ROUND(SUM(POWER(participacion_pct, 2)), 0)                  AS hhi,
       ROUND(SUM(CASE WHEN puesto <= 3 THEN participacion_pct END), 1) AS top3_pct,
       COUNT(*)                                                     AS cantidad_socios
FROM ranking
GROUP BY pais_reportante, flujo, anio;

SELECT * FROM vw_concentracion ORDER BY pais_reportante, flujo, anio;

-- 4.2 Comparación de la concentración al inicio y al final del período
SELECT pais_reportante,
       flujo,
       MAX(CASE WHEN anio = 1994 THEN hhi END) AS hhi_1994,
       MAX(CASE WHEN anio = 2023 THEN hhi END) AS hhi_2023,
       MAX(CASE WHEN anio = 1994 THEN top3_pct END) AS top3_1994,
       MAX(CASE WHEN anio = 2023 THEN top3_pct END) AS top3_2023
FROM vw_concentracion
GROUP BY pais_reportante, flujo;


/* =====================================================================
   PARTE 5 · COMERCIO BILATERAL ARGENTINA – URUGUAY
   ===================================================================== */

-- 5.1 Peso de cada país en el comercio del otro (cada 5 años)
SELECT f.pais_reportante,
       s.nombre_socio AS socio,
       f.flujo,
       f.anio,
       ROUND(f.valor_miles_usd / 1000, 1) AS millones_usd,
       f.participacion_pct
FROM fact_comercio f
JOIN dim_socio s ON s.id_socio = f.id_socio
WHERE ((f.pais_reportante = 'Argentina' AND s.nombre_socio = 'Uruguay')
    OR (f.pais_reportante = 'Uruguay'   AND s.nombre_socio = 'Argentina'))
  AND f.anio IN (1994, 1998, 2003, 2008, 2013, 2018, 2023)
ORDER BY f.pais_reportante, f.flujo, f.anio;

-- 5.2 Estadísticas espejo: lo que un país declara exportar al otro
--     debería parecerse a lo que el otro declara importar.
--     Se espera que la importación sea algo MAYOR (entre 5 % y 10 %),
--     porque se valúa con flete y seguro (CIF) y la exportación sin ellos (FOB).
WITH bilateral AS (
    SELECT f.pais_reportante, s.nombre_socio AS socio, f.flujo, f.anio, f.valor_miles_usd
    FROM fact_comercio f
    JOIN dim_socio s ON s.id_socio = f.id_socio
    WHERE (f.pais_reportante = 'Argentina' AND s.nombre_socio = 'Uruguay')
       OR (f.pais_reportante = 'Uruguay'   AND s.nombre_socio = 'Argentina')
)
SELECT CONCAT(e.pais_reportante, ' → ', e.socio)        AS sentido,
       e.anio,
       ROUND(e.valor_miles_usd / 1000, 1)               AS expo_declarada_musd,
       ROUND(i.valor_miles_usd / 1000, 1)               AS impo_declarada_musd,
       ROUND((i.valor_miles_usd / e.valor_miles_usd - 1) * 100, 1) AS diferencia_pct
FROM bilateral e
JOIN bilateral i
  ON  i.pais_reportante = e.socio
  AND i.socio           = e.pais_reportante
  AND i.anio            = e.anio
  AND i.flujo           = 'Import'
WHERE e.flujo = 'Export'
ORDER BY sentido, e.anio;

-- 5.3 Resumen de la comparación espejo por década
WITH bilateral AS (
    SELECT f.pais_reportante, s.nombre_socio AS socio, f.flujo, f.anio, f.valor_miles_usd
    FROM fact_comercio f
    JOIN dim_socio s ON s.id_socio = f.id_socio
    WHERE (f.pais_reportante = 'Argentina' AND s.nombre_socio = 'Uruguay')
       OR (f.pais_reportante = 'Uruguay'   AND s.nombre_socio = 'Argentina')
)
SELECT CONCAT(e.pais_reportante, ' → ', e.socio) AS sentido,
       CONCAT(FLOOR(e.anio / 10) * 10, 's')      AS decada,
       ROUND(AVG((i.valor_miles_usd / e.valor_miles_usd - 1) * 100), 1) AS diferencia_promedio_pct
FROM bilateral e
JOIN bilateral i
  ON  i.pais_reportante = e.socio
  AND i.socio           = e.pais_reportante
  AND i.anio            = e.anio
  AND i.flujo           = 'Import'
WHERE e.flujo = 'Export'
GROUP BY sentido, decada
ORDER BY sentido, decada;


/* =====================================================================
   PARTE 6 · VISTA PARA POWER BI
   Comercio por país socio (sin regiones ni totales), con el nombre del
   socio ya incorporado. Junto con vw_balanza_anual y vw_concentracion
   son las vistas que se importan en Power BI.
   ===================================================================== */

CREATE OR REPLACE VIEW vw_comercio_socios AS
SELECT f.pais_reportante,
       f.flujo,
       f.anio,
       s.id_socio,
       s.nombre_socio,
       ROUND(f.valor_miles_usd / 1000, 3) AS millones_usd,
       f.participacion_pct
FROM fact_comercio f
JOIN dim_socio s ON s.id_socio = f.id_socio
WHERE s.tipo_socio = 'Pais'
  AND f.anio BETWEEN 1994 AND 2023;

SELECT COUNT(*) AS filas_vista FROM vw_comercio_socios;

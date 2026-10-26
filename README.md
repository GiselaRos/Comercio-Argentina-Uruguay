# Comercio exterior de Argentina y Uruguay (1994–2023)

**Proyecto Integrador · Bootcamp de Análisis de Datos**

Integrantes: [nombre 1] · [nombre 2] · [nombre 3]

## Problemática

Argentina y Uruguay son economías abiertas y expuestas a los vaivenes externos. Este proyecto analiza 30 años de comercio exterior para responder **qué tan vulnerables son ante las crisis y ante la dependencia de pocos socios comerciales**.

**Preguntas de análisis**

1. ¿Cómo evolucionaron las exportaciones y las importaciones, y cómo impactaron las crisis de 2002, 2009 y 2020?
2. ¿Qué país tiene superávit y cuál déficit comercial?
3. ¿Cómo cambió el peso de Brasil, China y Estados Unidos como socios?
4. ¿Qué tan concentrado está el comercio en pocos socios?
5. ¿Cuánto comercian Argentina y Uruguay entre sí, y coinciden las cifras que declara cada uno?

## Principales hallazgos

- **Las crisis golpean por las importaciones.** En 2002 las importaciones cayeron 56 % en Argentina y 36 % en Uruguay, mientras las exportaciones casi no se movieron.
- **Dos modelos opuestos.** Argentina tuvo superávit comercial en 22 de 30 años; Uruguay, déficit en 29 de 30.
- **China cambió el mapa.** Pasó de cerca del 1 % a cerca del 20 % de las importaciones de ambos países y llegó a superar a Brasil como primer socio.
- **El comercio está diversificado.** En 2023 ningún flujo supera un índice de concentración HHI de 1.200.
- **Relación asimétrica y cifras que no coinciden.** Argentina pasó de recibir el 20 % de las exportaciones uruguayas al 5 %. Además, lo que declara cada país sobre el comercio mutuo se aleja del rango esperable.

## Herramientas y flujo de trabajo

```
WITS (Banco Mundial)  →  Python (limpieza)  →  CSV  →  MySQL (modelo y análisis)  →  Power BI (dashboard)
   8 archivos Excel        pandas, Jupyter                  ddl.sql · carga.sql          modelo estrella
                                                           analisis.sql                 7 medidas DAX
```

| Herramienta | Rol |
|---|---|
| **Python** (pandas) | Lectura de los Excel, limpieza, paso a formato largo, clasificación de socios y controles de calidad |
| **MySQL** | Modelo estrella con reglas de integridad, carga de los datos y consultas de análisis |
| **Power BI** | Modelo de datos, medidas DAX y dashboard interactivo |

## Estructura del repositorio

```
comercio-argentina-uruguay/
├── data/
│   ├── raw/                 8 archivos Excel originales de WITS
│   └── processed/           dim_socio.csv y fact_comercio.csv (datos limpios)
├── notebooks/
│   └── 01_carga_y_limpieza.ipynb
├── sql/
│   ├── ddl.sql              estructura de la base (solo CREATE)
│   ├── carga.sql            carga de los CSV
│   └── analisis.sql         exploración, controles y consultas de análisis
├── powerbi/
│   └── dashboard.pbix
└── docs/
    ├── Memoria_tecnica.docx
    ├── Medidas_DAX.pdf
    ├── Guia_paso_a_paso.docx
    └── Presentacion_comercio_Argentina_Uruguay.pptx
```

## Modelo de datos

Modelo estrella en la base `comercio_arg_uy`:

- **`fact_comercio`** (19.551 filas): un registro por país + socio + flujo + año, con el monto en miles de US$ y la participación %.
- **`dim_socio`** (247 filas): socios comerciales, clasificados como `Pais`, `Region`, `Total` u `Otro`.
- En Power BI se agrega **`dim_anio`**, una tabla calculada de años.

## Cómo reproducir el proyecto

**Requisitos:** Python 3 con pandas y openpyxl (por ejemplo, Anaconda), MySQL 8 o superior con Workbench, Power BI Desktop con MySQL Connector/NET.

1. **Limpieza:** abrir `notebooks/01_carga_y_limpieza.ipynb` y ejecutar todas las celdas. Lee los Excel de `data/raw/` y genera los CSV en `data/processed/`.
2. **Base de datos:** en MySQL Workbench, ejecutar `sql/ddl.sql`.
3. **Carga:** en `sql/carga.sql`, reemplazar la ruta de ejemplo por la carpeta `data/processed/` del repositorio, usando barras `/`, y ejecutarlo. La conexión de Workbench necesita `OPT_LOCAL_INFILE=1` (en *Edit Connection → Advanced → Others*).
4. **Análisis:** ejecutar `sql/analisis.sql`.
5. **Dashboard:** abrir `powerbi/dashboard.pbix` y apretar **Actualizar**.

La guía completa, con los resultados esperados en cada paso y los errores frecuentes, está en `docs/Guia_paso_a_paso.docx`.

## Fuente de los datos

World Bank, **World Integrated Trade Solution (WITS)**, *Country Profile*: exportaciones e importaciones de mercancías por país socio (todos los productos), en miles de US$ corrientes y en % de participación. Descarga de octubre de 2026; último año disponible: 2023.

Patrón de las direcciones de descarga:

```
https://wits.worldbank.org/CountryProfile/en/Country/{ARG|URY}/StartYear/1993/EndYear/2023/TradeFlow/{Export|Import}/Indicator/{XPRT-TRD-VL|MPRT-TRD-VL}/Partner/ALL/Product/Total
https://wits.worldbank.org/CountryProfile/en/Country/{ARG|URY}/StartYear/1993/EndYear/2023/TradeFlow/{Export|Import}/Partner/ALL/Indicator/{XPRT-PRTNR-SHR|MPRT-PRTNR-SHR}
```

## Limitaciones

- Montos en dólares corrientes, sin ajustar por inflación.
- Comercio de mercancías registrado en aduana: no incluye servicios y puede no captar parte del comercio de zonas francas.
- Análisis por país socio, sin desagregar por producto.

# Guía de API's

## 1. OpenAQ


https://docs.openaq.org/  
**URL base:** `https://api.openaq.org/v3`

OpenAQ proporciona datos históricos de **calidad del aire**, recopilados mediante estaciones de monitoreo en diferentes ciudades del mundo.

### 1.1. Autenticación con API Key

OpenAQ requiere una API Key, que se obtiene creando una cuenta.

En Postman:

1. Crear una petición `GET`.
2. Abrir `Headers`.
3. Agregar:

| Key | Value |
|---|---|
| `X-API-Key` | Tu API Key |
| `Accept` | `application/json` |

4. Presionar **Send**.

### 1.2. Buscar estaciones por ubicación

**Por país:**

`GET https://api.openaq.org/v3/locations?iso=EC&limit=100`

**Por coordenadas:**

`GET https://api.openaq.org/v3/locations?coordinates=-0.1807,-78.4678&radius=25000&limit=100`

**Parámetros principales:**

| Parámetro | Significado | Ejemplo |
|---|---|---|
| `iso` | Código del país | `EC` (Ecuador) |
| `coordinates` | Latitud, longitud | `-0.1807,-78.4678` |
| `radius` | Radio de búsqueda en metros, máximo 25.000 | `25000` |
| `limit` | Resultados máximos por página | `100` |
| `page` | Número de página | `2` |
| `parameters_id` | Filtrar estaciones por contaminante | `2` (PM2.5) |

**Coordenadas de referencia:**

| Ciudad | Latitud | Longitud |
|---|---|---|
| Quito | -0.1807 | -78.4678 |
| Londres | 51.5074 | -0.1278 |
| Nueva York | 40.7128 | -74.0060 |
| París | 48.8566 | 2.3522 |
| Los Ángeles | 34.0522 | -118.2437 |

### 1.3. Interpretar las estaciones

La respuesta JSON contiene:

- `meta.found`: cantidad de resultados encontrados.
- `results`: lista de estaciones.
- `id`: identificador único de la estación.
- `name`: nombre de la estación.
- `coordinates`: latitud y longitud.
- `sensors`: sensores disponibles y sus identificadores.
- `datetimeFirst` / `datetimeLast`: primera y última actividad de la estación.

**Importante:** una estación puede tener varios sensores con diferentes períodos de actividad.

### 1.4. Consultar sensores

Una vez identificada una estación, buscamos en `sensors` el contaminante deseado y copiamos su `id`.

Ejemplo:

`GET https://api.openaq.org/v3/sensors/254`

El ID `254` corresponde al sensor PM2.5 de Bexley - Slade Green, Londres.

La respuesta incluye:

| Campo | Significado |
|---|---|
| `parameter` | Contaminante y unidad |
| `datetimeFirst` | Primera medición del sensor |
| `datetimeLast` | Última medición del sensor |
| `latest.value` | Última concentración reportada |
| `summary.avg` | Promedio reportado |

### 1.5. Consultar mediciones por fechas

**Mediciones diarias:**

`GET https://api.openaq.org/v3/sensors/254/days?date_from=2025-01-01&date_to=2025-01-31&limit=100`

**Mediciones horarias:**

`GET https://api.openaq.org/v3/sensors/254/hours?date_from=2025-01-01&date_to=2025-01-03&limit=100`

| Parámetro | Significado |
|---|---|
| `{id}` | ID del sensor que queremos consultar |
| `date_from` | Fecha inicial (`AAAA-MM-DD`) |
| `date_to` | Fecha final (`AAAA-MM-DD`) |
| `limit` | Máximo de registros por página |
| `page` | Página de resultados |

Si hay más registros que el límite, debemos consultar las siguientes páginas.

### 1.6. Interpretar las mediciones

| Campo JSON | Significado |
|---|---|
| `value` | Concentración del contaminante |
| `parameter.name` | Nombre del contaminante |
| `parameter.units` | Unidad de medida |
| `period.datetimeFrom` | Inicio de la medición |
| `period.datetimeTo` | Fin de la medición |
| `summary.min/max/avg` | Mínimo, máximo y promedio |
| `coverage.percentComplete` | Porcentaje de completitud reportado |
| `flagInfo.hasFlags` | Si existen banderas de calidad |

**Contaminantes comunes:**

| Código | Significado |
|---|---|
| `pm25` | Partículas finas de hasta 2.5 µm |
| `pm10` | Partículas de hasta 10 µm |
| `no2` | Dióxido de nitrógeno |
| `o3` | Ozono |
| `co` | Monóxido de carbono |
| `so2` | Dióxido de azufre |

**Ejemplo:** `PM2.5 = 12 µg/m³` significa una concentración de 12 microgramos de partículas finas por metro cúbico de aire.

### 1.7. Ejemplo práctico: PM2.5 de Quito entre 2016 y 2020

**Paso 1. Buscar estaciones de Quito que midan PM2.5.**

`GET https://api.openaq.org/v3/locations?coordinates=-0.1807,-78.4678&radius=25000&parameters_id=2&limit=100`

**Paso 2.** En `results`, identificar las estaciones y buscar un sensor cuyo `parameter.name` sea `pm25`. Copiar su ID.

**Paso 3.** Comprobar las fechas disponibles del sensor. (**Aquí ya no es necesario ubicar las coordenadas ni el país, puesto que cada sensor es único de aquella ubicación.**)

`GET https://api.openaq.org/v3/sensors/ID_SENSOR`

**Paso 4.** Consultar las mediciones históricas:

`GET https://api.openaq.org/v3/sensors/ID_SENSOR/days?date_from=2016-01-01&date_to=2020-12-31&limit=100`

Reemplazar `ID_SENSOR` por el identificador encontrado y recorrer las páginas de resultados.

**Nota:** esta consulta no garantiza que existan datos para todos los días de 2016 a 2020. Si hay varias estaciones, deben consultarse sus sensores por separado. Para obtener un promedio de Quito sería necesario definir cómo combinar sus mediciones.

---

**Secuencia para recordar:**

`Buscar ubicación → Identificar estación → Identificar sensor → Consultar fechas → Obtener mediciones`

El identificador de un sensor es único dentro de OpenAQ. Por eso, una vez que conocemos su ID, no necesitamos volver a especificar la ciudad.
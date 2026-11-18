# ==============================================================================
# PROYECTO: Interoperabilidad y Explotación de Datos en Ecosistemas Heterogéneos
# ENTREGABLE 2: Extracción, Limpieza e Integración de Datos (Tránsito + Clima)
# AUTORES: Carlos Sánchez, Leonardo Mendieta
# ==============================================================================

# 1. Carga de librerías necesarias
# Si falta alguna, ejecutar una vez: install.packages(c("dplyr", "httr", "jsonlite"))
library(dplyr)
library(httr)
library(jsonlite)

# ==============================================================================
# PARTE A: EXTRACCIÓN Y LIMPIEZA DE ACCIDENTES DE TRÁNSITO (DfT Reino Unido)
# ==============================================================================

# Cargar dataset original (asegúrate de que la ruta coincida con tu carpeta en RStudio)
accidentes_raw <- read.csv("C:/Users/V I C T U S/OneDrive/Desktop/Proyecto datos/Files/londres_accidentes_5years.csv", stringsAsFactors = FALSE)

# Seleccionar las 15 variables relevantes definidas en el Entregable 2
variables <- c(
  "collision_index",
  "collision_year",
  "date",
  "time",
  "latitude",
  "longitude",
  "collision_severity",
  "number_of_vehicles",
  "number_of_casualties",
  "speed_limit",
  "road_type",
  "light_conditions",
  "weather_conditions",
  "road_surface_conditions",
  "urban_or_rural_area"
)

accidentes <- accidentes_raw[, variables]

# Estandarizar formato de fecha de DD/MM/AAAA a YYYY-MM-DD (ISO 8601)
accidentes$date <- as.Date(accidentes$date, format = "%d/%m/%Y")

# Auditoría de calidad previa a la limpieza
cat("Total registros iniciales:", nrow(accidentes), "\n")
cat("Identificadores duplicados:", sum(duplicated(accidentes$collision_index)), "\n")
cat("Registros sin fecha:", sum(is.na(accidentes$date)), "\n")
cat("Registros sin coordenadas:", sum(is.na(accidentes$latitude) | is.na(accidentes$longitude)), "\n")

# Limpieza 1: Eliminar los 53 registros sin coordenadas y verificar fecha/hora válidas
accidentes_limpios <- subset(
  accidentes,
  !is.na(latitude) & !is.na(longitude) & !is.na(date) & !is.na(time) & time != ""
)

# Limpieza 2: Enriquecimiento semántico (decodificación y filtro espacial de Londres)
accidentes_limpios <- accidentes_limpios %>%
  mutate(
    severidad_desc = case_when(
      collision_severity == 1 ~ "Mortal",
      collision_severity == 2 ~ "Grave",
      collision_severity == 3 ~ "Leve",
      TRUE ~ "Desconocido"
    ),
    zona_desc = case_when(
      urban_or_rural_area == 1 ~ "Urbana",
      urban_or_rural_area == 2 ~ "Rural",
      TRUE ~ "Sin asignar"
    ),
    # Extraer la hora entera (0 a 23) para facilitar las preguntas de competencia
    hora_entera = as.integer(substr(time, 1, 2)),
    # Delimitar el área metropolitana del Gran Londres mediante Bounding Box
    # Las coordenadas que se presentan a continuación pertenecen a Londres
    en_londres = ifelse(
      latitude >= 51.28 & latitude <= 51.70 & longitude >= -0.52 & longitude <= 0.33,
      TRUE, FALSE
    )
  )

cat("Total registros limpios (Gran Bretaña):", nrow(accidentes_limpios), "\n")
cat("Total registros limpios en Área de Londres:", sum(accidentes_limpios$en_londres), "\n")

# ==============================================================================
# PARTE B: EXTRACCIÓN AUTOMATIZADA DE DATOS METEOROLÓGICOS (API Open-Meteo)
# ==============================================================================

# Coordenadas centrales de Londres (51.5074, -0.1278) | Período: 2021-01-01 a 2025-12-31
url_open_meteo <- "https://archive-api.open-meteo.com/v1/archive"

# La siguiente petición permite obtener la temperatura diaria durante los 5 años de rango
# Esto equivale a aproximadamente 1800 registros, que luego serán unidos por la fecha
# Mediante un Left Join con el dataset de los accidentes de tránsito
parametros_clima <- list(
  latitude = 51.5074,
  longitude = -0.1278,
  start_date = "2021-01-01",
  end_date = "2025-12-31",
  daily = "temperature_2m_mean,temperature_2m_max,temperature_2m_min,precipitation_sum,rain_sum,wind_speed_10m_max",
  timezone = "Europe/London"
)

cat("Consultando API histórica de Open-Meteo (2021-2025)...\n")
respuesta <- GET(url = url_open_meteo, query = parametros_clima)

if (status_code(respuesta) == 200) {
  contenido_json <- content(respuesta, as = "text", encoding = "UTF-8")
  datos_clima_lista <- fromJSON(contenido_json)
  
  clima_londres <- as.data.frame(datos_clima_lista$daily)
  clima_londres$time <- as.Date(clima_londres$time)
  
  clima_londres <- clima_londres %>%
    rename(
      date = time,
      temp_promedio_c = temperature_2m_mean,
      temp_max_c = temperature_2m_max,
      temp_min_c = temperature_2m_min,
      precipitacion_mm = precipitation_sum,
      lluvia_mm = rain_sum,
      viento_max_kmh = wind_speed_10m_max
    ) %>%
    mutate(
      clima_id = paste0("CLIMA_LON_", format(date, "%Y%m%d")),
      ciudad = "Londres",
      es_dia_lluvioso = ifelse(precipitacion_mm >= 1.0, TRUE, FALSE),
      lluvia_mayor_10mm = ifelse(precipitacion_mm > 10.0, TRUE, FALSE)
    )
  
  cat("Registros diarios de clima extraídos:", nrow(clima_londres), "\n")
  cat("Valores nulos en temperatura:", sum(is.na(clima_londres$temp_promedio_c)), "\n")
} else {
  stop("Error al conectar con Open-Meteo. Código HTTP: ", status_code(respuesta))
}

# ==============================================================================
# PARTE C: INTEGRACIÓN DE AMBAS FUENTES Y EXPORTACIÓN DE ARCHIVOS LIMPIOS
# ==============================================================================

# Unir accidentes de Londres con los datos climáticos diarios mediante 'date'
dataset_integrado_londres <- accidentes_limpios %>%
  filter(en_londres == TRUE) %>%
  left_join(clima_londres, by = "date")

# Vista previa de verificación (ejemplo 15 de mayo de 2025)
ejemplo_mayo <- subset(dataset_integrado_londres, date == as.Date("2025-05-15"))
print(head(ejemplo_mayo[, c("collision_index", "date", "time", "severidad_desc", "clima_id", "temp_promedio_c", "precipitacion_mm")], 5))


# Vista previa
str(dataset_integrado_londres)
View(dataset_integrado_londres)
# Guardar los tres archivos CSV resultantes para el modelado del Grafo

# MODIFICAR LA PATH SI SE USA DE FORMA LOCAL. 
path <- "C:/Users/V I C T U S/OneDrive/Desktop/Proyecto datos/Files"

write.csv(accidentes_limpios, file.path(path, "accidentes_inglaterra_limpio.csv"), row.names = FALSE)
write.csv(clima_londres, file.path(path, "clima_londres_2021_2025.csv"), row.names = FALSE)
write.csv(dataset_integrado_londres, file.path(path, "dataset_integrado_londres.csv"), row.names = FALSE)

cat("¡Proceso finalizado! Archivos exportados en el directorio de trabajo.\n")

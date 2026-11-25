# ==============================================================================
# PROYECTO: Interoperabilidad y Explotación de Datos en Ecosistemas Heterogéneos
# ENTREGABLE 2: Extracción, Limpieza e Integración de Datos (Tránsito + Clima)
# AUTORES: Carlos Sánchez, Leonardo Mendieta
# DESCRIPCIÓN: Script refactorizado con funciones modulares para la extracción,
#              limpieza, partición en 4 franjas horarias e integración relacional.
# ==============================================================================

# 1. Carga de librerías necesarias
suppressPackageStartupMessages({
  library(dplyr)
  library(httr)
  library(jsonlite)
})

# ==============================================================================
# SECCIÓN 1: DEFINICIÓN DE FUNCIONES MODULARES
# ==============================================================================

#' 1.1 Extraer y limpiar datos de accidentes de tránsito (DfT Reino Unido)
#'
#' @param ruta_csv Ruta al archivo CSV con los accidentes originales.
#' @param variables Vector de nombres de columnas a seleccionar.
#' @param bbox Lista con los límites geográficos (lat_min, lat_max, lon_min, lon_max).
#' @return Dataframe con los accidentes limpios y enriquecidos semánticamente.
extraer_limpiar_transito <- function(
  ruta_csv,
  variables = c(
    "collision_index", "collision_year", "date", "time", "latitude", "longitude",
    "collision_severity", "number_of_vehicles", "number_of_casualties",
    "speed_limit", "road_type", "light_conditions", "weather_conditions",
    "road_surface_conditions", "urban_or_rural_area"
  ),
  bbox = list(lat_min = 51.28, lat_max = 51.70, lon_min = -0.52, lon_max = 0.33)
) {
  if (!file.exists(ruta_csv)) {
    stop(paste("Error: El archivo de accidentes no existe en:", ruta_csv))
  }
  
  message("[Tránsito] Leyendo dataset original...")
  accidentes_raw <- read.csv(ruta_csv, stringsAsFactors = FALSE)
  
  # Seleccionar únicamente las 15 variables de interés
  columnas_validas <- intersect(variables, names(accidentes_raw))
  accidentes <- accidentes_raw[, columnas_validas]
  
  # Estandarización de fecha (ISO 8601: YYYY-MM-DD)
  accidentes$date <- as.Date(accidentes$date, format = "%d/%m/%Y")
  
  # Auditoría preliminar
  total_inicial <- nrow(accidentes)
  sin_coordenadas <- sum(is.na(accidentes$latitude) | is.na(accidentes$longitude))
  message(paste("[Tránsito] Registros iniciales:", total_inicial))
  message(paste("[Tránsito] Registros sin coordenadas descartados:", sin_coordenadas))
  
  # Limpieza: descartar nulos en geolocalización, fecha o registro de hora
  accidentes_limpios <- subset(
    accidentes,
    !is.na(latitude) & !is.na(longitude) & !is.na(date) & !is.na(time) & time != ""
  )
  
  # Enriquecimiento semántico y partición temporal en franjas horarias
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
      # Hora entera de 0 a 23
      hora_entera = as.integer(substr(time, 1, 2)),
      # Partición en 4 franjas del día (6 horas cada una)
      franja_horaria = case_when(
        hora_entera >= 0 & hora_entera < 6  ~ "Madrugada",
        hora_entera >= 6 & hora_entera < 12 ~ "Mañana",
        hora_entera >= 12 & hora_entera < 18 ~ "Tarde",
        hora_entera >= 18 & hora_entera <= 23 ~ "Noche",
        TRUE ~ "No determinada"
      ),
      # Delimitación geográfica del Gran Londres (Bounding Box)
      en_londres = (latitude >= bbox$lat_min & latitude <= bbox$lat_max &
                    longitude >= bbox$lon_min & longitude <= bbox$lon_max)
    )
  
  message(paste("[Tránsito] Registros limpios (Gran Bretaña):", nrow(accidentes_limpios)))
  message(paste("[Tránsito] Registros en Área Metropolitana de Londres:", sum(accidentes_limpios$en_londres)))
  
  return(accidentes_limpios)
}


#' 1.2 Extraer datos horarios de la API de Open-Meteo
#'
#' @param latitud Coordenada latitud.
#' @param longitud Coordenada longitud.
#' @param fecha_inicio Fecha en formato YYYY-MM-DD.
#' @param fecha_fin Fecha en formato YYYY-MM-DD.
#' @param variables_horarias Cadena con variables separadas por comas.
#' @param timezone Zona horaria (por defecto "Europe/London").
#' @return Dataframe con las observaciones horarias históricas.
extraer_clima_horario_open_meteo <- function(
  latitud = 51.5074,
  longitud = -0.1278,
  fecha_inicio = "2021-01-01",
  fecha_fin = "2025-12-31",
  variables_horarias = "temperature_2m,precipitation,rain,wind_speed_10m",
  timezone = "Europe/London"
) {
  url_base <- "https://archive-api.open-meteo.com/v1/archive"
  
  parametros <- list(
    latitude = latitud,
    longitude = longitud,
    start_date = fecha_inicio,
    end_date = fecha_fin,
    hourly = variables_horarias,
    timezone = timezone
  )
  
  message(paste("[Open-Meteo] Consultando API histórica para el período:", fecha_inicio, "al", fecha_fin))
  respuesta <- GET(url = url_base, query = parametros)
  
  if (status_code(respuesta) != 200) {
    stop(paste("Error en petición Open-Meteo. Código HTTP:", status_code(respuesta)))
  }
  
  contenido <- content(respuesta, as = "text", encoding = "UTF-8")
  datos_json <- fromJSON(contenido)
  
  clima_horario <- as.data.frame(datos_json$hourly)
  message(paste("[Open-Meteo] Horas extraídas exitosamente:", nrow(clima_horario)))
  
  return(clima_horario)
}


#' 1.3 Procesar y agregar datos climáticos en 4 franjas del día
#'
#' @param clima_horario Dataframe devuelto por extraer_clima_horario_open_meteo.
#' @return Dataframe agregado por fecha y franja horaria (4 registros por día).
procesar_clima_por_franjas <- function(clima_horario) {
  message("[Clima] Agregando observaciones horarias en 4 franjas del día (6 horas)...")
  
  # Descomponer timestamp ISO ("2021-01-01T00:00") en fecha y hora entera
  clima_horario$date <- as.Date(substr(clima_horario$time, 1, 10))
  clima_horario$hora <- as.integer(substr(clima_horario$time, 12, 13))
  
  clima_horario <- clima_horario %>%
    mutate(
      franja_horaria = case_when(
        hora >= 0 & hora < 6  ~ "Madrugada",
        hora >= 6 & hora < 12 ~ "Mañana",
        hora >= 12 & hora < 18 ~ "Tarde",
        hora >= 18 & hora <= 23 ~ "Noche",
        TRUE ~ "No determinada"
      ),
      codigo_franja = case_when(
        franja_horaria == "Madrugada" ~ "MAD",
        franja_horaria == "Mañana"    ~ "MAN",
        franja_horaria == "Tarde"     ~ "TAR",
        franja_horaria == "Noche"     ~ "NOC",
        TRUE ~ "ND"
      )
    )
  
  # Agregación estadística por intervalo de 6 horas
  clima_franjas <- clima_horario %>%
    group_by(date, franja_horaria, codigo_franja) %>%
    summarise(
      temp_promedio_c = round(mean(temperature_2m, na.rm = TRUE), 2),
      temp_max_c = round(max(temperature_2m, na.rm = TRUE), 2),
      temp_min_c = round(min(temperature_2m, na.rm = TRUE), 2),
      precipitacion_mm = round(sum(precipitation, na.rm = TRUE), 2),
      lluvia_mm = round(sum(rain, na.rm = TRUE), 2),
      viento_max_kmh = round(max(wind_speed_10m, na.rm = TRUE), 2),
      .groups = "drop"
    ) %>%
    mutate(
      # Identificador unívoco para el Grafo de Conocimiento (Entidad ClimaFranja)
      clima_franja_id = paste0("CLIMA_LON_", format(date, "%Y%m%d"), "_", codigo_franja),
      ciudad = "Londres",
      # Indicadores analíticos en la franja
      es_franja_lluviosa = ifelse(precipitacion_mm >= 0.5, TRUE, FALSE),
      lluvia_fuerte_franja = ifelse(precipitacion_mm >= 5.0, TRUE, FALSE)
    ) %>%
    select(-codigo_franja)
  
  message(paste("[Clima] Franjas procesadas:", nrow(clima_franjas), "(esperadas 1.826 días x 4 = 7.304)"))
  return(clima_franjas)
}


#' 1.4 Integrar datasets de Tránsito y Clima mediante llaves compuestas
#'
#' @param accidentes_df Dataframe de accidentes limpios.
#' @param clima_franjas_df Dataframe de clima agregado por franjas.
#' @param solo_londres Lógico. Si TRUE, filtra únicamente accidentes del Gran Londres.
#' @return Dataframe consolidado.
integrar_transito_clima <- function(accidentes_df, clima_franjas_df, solo_londres = TRUE) {
  message("[Integración] Uniendo accidentes y clima mediante 'date' y 'franja_horaria'...")
  
  base_accidentes <- if (solo_londres) {
    accidentes_df %>% filter(en_londres == TRUE)
  } else {
    accidentes_df
  }
  
  # Llave compuesta: date (Fecha) y franja_horaria (Madrugada, Mañana, Tarde, Noche)
  dataset_integrado <- base_accidentes %>%
    left_join(clima_franjas_df, by = c("date", "franja_horaria"))
  
  # Verificación de integridad relacional
  nulos_clima <- sum(is.na(dataset_integrado$clima_franja_id))
  message(paste("[Integración] Registros totales consolidados:", nrow(dataset_integrado)))
  message(paste("[Integración] Registros sin coincidencia climática:", nulos_clima))
  
  return(dataset_integrado)
}


#' 1.5 Exportar datasets procesados a archivos CSV
#'
#' @param df_accidentes Dataframe de accidentes limpios.
#' @param df_clima Dataframe de clima en franjas.
#' @param df_integrado Dataframe consolidado.
#' @param carpeta_salida Directorio donde se guardarán los archivos.
exportar_datasets <- function(df_accidentes, df_clima, df_integrado, carpeta_salida) {
  if (!dir.exists(carpeta_salida)) {
    dir.create(carpeta_salida, recursive = TRUE)
  }
  
  ruta_acc <- file.path(carpeta_salida, "accidentes_inglaterra_limpio.csv")
  ruta_cli <- file.path(carpeta_salida, "clima_londres_franjas_2021_2025.csv")
  ruta_int <- file.path(carpeta_salida, "dataset_integrado_londres.csv")
  
  message("[Exportación] Guardando archivos CSV en:", carpeta_salida)
  write.csv(df_accidentes, ruta_acc, row.names = FALSE)
  write.csv(df_clima, ruta_cli, row.names = FALSE)
  write.csv(df_integrado, ruta_int, row.names = FALSE)
  
  message("  -> ", ruta_acc)
  message("  -> ", ruta_cli)
  message("  -> ", ruta_int)
  message("[Exportación] ¡Exportación completada con éxito!")
}


# ==============================================================================
# SECCIÓN 2: PIPELINE PRINCIPAL DE EJECUCIÓN
# ==============================================================================

ejecutar_pipeline_completo <- function() {
  cat("\n==============================================================================\n")
  cat(" INICIANDO PIPELINE: INTEROPERABILIDAD TRÁNSITO + CLIMA (FRANJAS HORARIAS)\n")
  cat("==============================================================================\n\n")
  
  # Detección flexible de rutas de trabajo
  ruta_carpeta_files <- if (dir.exists("Files")) {
    "Files"
  } else if (dir.exists("C:/Users/V I C T U S/OneDrive/Desktop/Proyecto datos/Files")) {
    "C:/Users/V I C T U S/OneDrive/Desktop/Proyecto datos/Files"
  } else {
    "."
  }
  
  ruta_csv_accidentes <- file.path(ruta_carpeta_files, "londres_accidentes_5years.csv")
  
  # Paso 1: Extracción y limpieza de accidentes
  accidentes_limpios <- extraer_limpiar_transito(
    ruta_csv = ruta_csv_accidentes
  )
  
  # Paso 2: Extracción horaria de Open-Meteo (2021-2025)
  clima_horario_raw <- extraer_clima_horario_open_meteo(
    latitud = 51.5074,
    longitud = -0.1278,
    fecha_inicio = "2021-01-01",
    fecha_fin = "2025-12-31"
  )
  
  # Paso 3: Agregación en 4 franjas horarias
  clima_franjas <- procesar_clima_por_franjas(clima_horario_raw)
  
  # Paso 4: Integración relacional compuesta (date + franja_horaria)
  dataset_integrado <- integrar_transito_clima(
    accidentes_df = accidentes_limpios,
    clima_franjas_df = clima_franjas,
    solo_londres = TRUE
  )
  
  # Paso 5: Exportación de resultados limpios
  exportar_datasets(
    df_accidentes = accidentes_limpios,
    df_clima = clima_franjas,
    df_integrado = dataset_integrado,
    carpeta_salida = ruta_carpeta_files
  )
  
  # Vista previa de control
  cat("\n=== VISTA PREVIA DEL DATASET INTEGRADO (5 PRIMEROS REGISTROS) ===\n")
  columnas_preview <- c("collision_index", "date", "time", "franja_horaria", 
                        "severidad_desc", "clima_franja_id", "temp_promedio_c", 
                        "precipitacion_mm", "es_franja_lluviosa")
  print(head(dataset_integrado[, columnas_preview], 5))
  
  cat("\n==============================================================================\n")
  cat(" PROCESO FINALIZADO CON ÉXITO\n")
  cat("==============================================================================\n")
}

# Ejecutar automáticamente si el script se llama directamente
if (!interactive()) {
  ejecutar_pipeline_completo()
}

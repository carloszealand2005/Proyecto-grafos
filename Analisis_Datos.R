# ==============================================================================
# PROYECTO: Interoperabilidad y Explotación de Datos en Ecosistemas Heterogéneos
# ANÁLISIS DESCRIPTIVO: Tránsito y Condiciones Meteorológicas en Londres (2021-2025)
# ==============================================================================

library(dplyr)

# 1. Definir ruta de archivos y carga de datos
path <- "C:/Users/V I C T U S/OneDrive/Desktop/Proyecto datos/Files"

# Dataset unificado (cada fila es un accidente con el clima de ese día)
dataset_unificado <- read.csv(file.path(path, "dataset_integrado_londres.csv"), stringsAsFactors = FALSE)
dataset_unificado$date <- as.Date(dataset_unificado$date)

# Dataset climático puro (1 fila por día, 1.826 días en total)
# NOTA: Cargar también este archivo es vital para no duplicar la lluvia al calcular totales anuales
clima_londres <- read.csv(file.path(path, "clima_londres_2021_2025.csv"), stringsAsFactors = FALSE)
clima_londres$date <- as.Date(clima_londres$date)
clima_londres$anio <- as.integer(format(clima_londres$date, "%Y"))

cat("Total accidentes en Londres (2021-2025):", nrow(dataset_unificado), "\n")
cat("Total días climáticos registrados:", nrow(clima_londres), "\n\n")


# ==============================================================================
# 2. ANÁLISIS CLIMÁTICO ANUAL (Fuente: Clima diario sin duplicación)
# ==============================================================================

cat("=== 1. PRECIPITACIÓN Y DÍAS LLUVIOSOS POR AÑO EN LONDRES ===\n")
resumen_lluvia_anual <- clima_londres %>%
  group_by(anio) %>%
  summarise(
    lluvia_total_mm = round(sum(precipitacion_mm, na.rm = TRUE), 1),
    promedio_diario_mm = round(mean(precipitacion_mm, na.rm = TRUE), 2),
    dias_con_lluvia = sum(es_dia_lluvioso, na.rm = TRUE),
    dias_lluvia_fuerte_10mm = sum(lluvia_mayor_10mm, na.rm = TRUE),
    porcentaje_dias_lluviosos = round((sum(es_dia_lluvioso, na.rm = TRUE) / n()) * 100, 1)
  )
print(resumen_lluvia_anual)

cat("\n=== 2. RESUMEN TÉRMICO ANUAL EN LONDRES (°C) ===\n")
resumen_temperatura_anual <- clima_londres %>%
  group_by(anio) %>%
  summarise(
    temp_media_anual = round(mean(temp_promedio_c, na.rm = TRUE), 1),
    temp_maxima_extrema = max(temp_max_c, na.rm = TRUE),
    temp_minima_extrema = min(temp_min_c, na.rm = TRUE)
  )
print(resumen_temperatura_anual)


# ==============================================================================
# 3. ANÁLISIS INTEGRADO: ACCIDENTES Y METEOROLOGÍA
# ==============================================================================

cat("\n=== 3. TASA PROMEDIO DE ACCIDENTES: DÍAS LLUVIOSOS VS. DÍAS SECOS ===\n")
# Calculamos cuántos accidentes ocurrieron por día en cada fecha
accidentes_por_dia <- dataset_unificado %>%
  group_by(date, es_dia_lluvioso) %>%
  summarise(total_accidentes = n(), .groups = "drop")

tasa_accidentes_lluvia <- accidentes_por_dia %>%
  group_by(es_dia_lluvioso) %>%
  summarise(
    total_dias = n(),
    promedio_accidentes_diarios = round(mean(total_accidentes), 2),
    desviacion_estandar = round(sd(total_accidentes), 2),
    total_accidentes_periodo = sum(total_accidentes)
  )
print(tasa_accidentes_lluvia)


cat("\n=== 4. SEVERIDAD DE ACCIDENTES SEGÚN CATEGORÍA DE PRECIPITACIÓN ===\n")
dataset_unificado <- dataset_unificado %>%
  mutate(
    categoria_lluvia = case_when(
      precipitacion_mm == 0 ~ "Seco (0 mm)",
      precipitacion_mm > 0 & precipitacion_mm < 5 ~ "Lluvia Ligera (< 5 mm)",
      precipitacion_mm >= 5 & precipitacion_mm < 10 ~ "Lluvia Moderada (5-10 mm)",
      precipitacion_mm >= 10 ~ "Lluvia Fuerte (>= 10 mm)"
    )
  )

tabla_severidad_lluvia <- table(dataset_unificado$categoria_lluvia, dataset_unificado$severidad_desc)
print(tabla_severidad_lluvia)

cat("\nPorcentajes relativos de severidad por nivel de lluvia (%):\n")
print(round(prop.table(tabla_severidad_lluvia, margin = 1) * 100, 2))


cat("\n=== 5. CONDICIÓN DE LA CALZADA (POLICÍA) VS. LLUVIA (OPEN-METEO) ===\n")
# road_surface_conditions: 1=Seca, 2=Mojada/Húmeda, 3=Nieve, 4=Hielo/Escarcha, 5=Inundación, -1/9=Desconocido
dataset_unificado <- dataset_unificado %>%
  mutate(
    calzada_desc = case_when(
      road_surface_conditions == 1 ~ "Seca",
      road_surface_conditions == 2 ~ "Mojada/Húmeda",
      road_surface_conditions %in% c(3, 4) ~ "Nieve/Hielo",
      road_surface_conditions == 5 ~ "Inundada (>3cm)",
      TRUE ~ "Otra / Desconocida"
    )
  )

cruce_calzada_lluvia <- dataset_unificado %>%
  group_by(calzada_desc) %>%
  summarise(
    total_accidentes = n(),
    lluvia_promedio_mm = round(mean(precipitacion_mm, na.rm = TRUE), 2),
    porcentaje_en_dia_lluvioso = round(mean(es_dia_lluvioso, na.rm = TRUE) * 100, 1)
  ) %>%
  arrange(desc(total_accidentes))
print(cruce_calzada_lluvia)


cat("\n=== 6. ACCIDENTES SEGÚN RANGOS DE TEMPERATURA (°C) ===\n")
dataset_unificado <- dataset_unificado %>%
  mutate(
    rango_temperatura = case_when(
      temp_promedio_c < 0 ~ "Helada (< 0°C)",
      temp_promedio_c >= 0 & temp_promedio_c < 10 ~ "Frío (0°C - 10°C)",
      temp_promedio_c >= 10 & temp_promedio_c < 20 ~ "Templado (10°C - 20°C)",
      temp_promedio_c >= 20 ~ "Cálido (>= 20°C)"
    )
  )

resumen_temperatura <- dataset_unificado %>%
  group_by(rango_temperatura) %>%
  summarise(
    total_accidentes = n(),
    victimas_totales = sum(number_of_casualties, na.rm = TRUE),
    promedio_vehiculos = round(mean(number_of_vehicles, na.rm = TRUE), 2)
  ) %>%
  arrange(desc(total_accidentes))
print(resumen_temperatura)


cat("\n=== 7. IMPACTO DEL VIENTO EN LA ACCIDENTALIDAD ===\n")
dataset_unificado <- dataset_unificado %>%
  mutate(
    viento_categoria = case_when(
      viento_max_kmh < 20 ~ "Calma/Bajo (< 20 km/h)",
      viento_max_kmh >= 20 & viento_max_kmh < 40 ~ "Moderado (20-40 km/h)",
      viento_max_kmh >= 40 ~ "Fuerte (>= 40 km/h)"
    )
  )

resumen_viento <- dataset_unificado %>%
  group_by(viento_categoria) %>%
  summarise(
    total_accidentes = n(),
    accidentes_mortales_o_graves = sum(severidad_desc %in% c("Mortal", "Grave")),
    porcentaje_graves_o_mortales = round((sum(severidad_desc %in% c("Mortal", "Grave")) / n()) * 100, 2)
  )
print(resumen_viento)


cat("\n=== 8. TOP 10 DÍAS CON MÁS ACCIDENTES EN LONDRES Y SU CLIMA ===\n")
top_dias_accidentes <- dataset_unificado %>%
  group_by(date, temp_promedio_c, precipitacion_mm, viento_max_kmh, es_dia_lluvioso) %>%
  summarise(
    total_accidentes = n(),
    total_victimas = sum(number_of_casualties, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_accidentes)) %>%
  head(10)
print(top_dias_accidentes)


# ==============================================================================
# 9. GRÁFICO DE DISPERSIÓN Y CORRELACIÓN (LLUVIA VS. ACCIDENTES DIARIOS)
# ==============================================================================

cat("\n=== 9. CORRELACIÓN Y DISPERSIÓN: PRECIPITACIÓN VS. ACCIDENTES ===\n")

# Agrupar accidentes por fecha y cruzar con la lluvia de ese día
accidentes_diarios <- dataset_unificado %>%
  group_by(date) %>%
  summarise(total_accidentes = n(), .groups = "drop")

datos_dispersion <- clima_londres %>%
  select(date, precipitacion_mm) %>%
  left_join(accidentes_diarios, by = "date") %>%
  mutate(total_accidentes = ifelse(is.na(total_accidentes), 0, total_accidentes))

# 1. Cálculo estadístico de correlación de Pearson y prueba de significancia
test_correlacion <- cor.test(datos_dispersion$precipitacion_mm, datos_dispersion$total_accidentes)
r_correlacion <- round(test_correlacion$estimate, 4)
p_valor <- test_correlacion$p.value

cat("Coeficiente de correlación de Pearson (r):", r_correlacion, "\n")
cat("P-valor de la prueba:", format.pval(p_valor, digits = 4), "\n")
if (abs(r_correlacion) < 0.1) {
  cat("Interpretación: Correlación prácticamente nula / inexistente entre la lluvia diaria y la cantidad de accidentes.\n")
} else if (abs(r_correlacion) < 0.3) {
  cat("Interpretación: Correlación débil.\n")
}

# 2. Generar el gráfico de dispersión en el visor de RStudio (plot)
plot(
  x = datos_dispersion$precipitacion_mm,
  y = datos_dispersion$total_accidentes,
  main = "Precipitación Diaria vs. Accidentes de Tránsito (Londres 2021-2025)",
  xlab = "Precipitación acumulada diaria (mm)",
  ylab = "Cantidad de accidentes diarios",
  pch = 19,
  col = rgb(0.1, 0.4, 0.8, 0.4), # Azul semitransparente para apreciar la densidad de puntos
  cex = 0.9
)
grid(col = "gray85", lty = "dotted")

# Línea de regresión lineal (tendencia)
modelo_lineal <- lm(total_accidentes ~ precipitacion_mm, data = datos_dispersion)
abline(modelo_lineal, col = "red", lwd = 2.5)

# Cuadro de leyenda con métricas
legend(
  "topright",
  legend = c(
    paste0("Correlación de Pearson (r) = ", r_correlacion),
    paste0("P-valor = ", format.pval(p_valor, digits = 3)),
    "Línea de tendencia (Regresión)"
  ),
  col = c(NA, NA, "red"),
  lty = c(NA, NA, 1),
  lwd = c(NA, NA, 2.5),
  bg = "white",
  box.col = "gray70"
)

# 3. Guardar copia en imagen PNG en la carpeta Files (ideal para incluir en el informe)
archivo_png <- file.path(path, "dispersion_lluvia_vs_accidentes.png")
png(archivo_png, width = 900, height = 650, res = 120)
plot(
  x = datos_dispersion$precipitacion_mm,
  y = datos_dispersion$total_accidentes,
  main = "Precipitación Diaria vs. Accidentes de Tránsito (Londres 2021-2025)",
  xlab = "Precipitación acumulada diaria (mm)",
  ylab = "Cantidad de accidentes diarios",
  pch = 19,
  col = rgb(0.1, 0.4, 0.8, 0.4),
  cex = 0.9
)
grid(col = "gray85", lty = "dotted")
abline(modelo_lineal, col = "red", lwd = 2.5)
legend(
  "topright",
  legend = c(
    paste0("Correlación de Pearson (r) = ", r_correlacion),
    paste0("P-valor = ", format.pval(p_valor, digits = 3)),
    "Línea de tendencia (Regresión)"
  ),
  col = c(NA, NA, "red"),
  lty = c(NA, NA, 1),
  lwd = c(NA, NA, 2.5),
  bg = "white",
  box.col = "gray70"
)
dev.off()
cat("Gráfico guardado en:", archivo_png, "\n")

cat("\n¡Análisis descriptivo completado exitosamente!\n")

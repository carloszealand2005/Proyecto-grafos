# Script para modificar los accidentes de tránsito de londres

library(dplyr)
accidentes = read.csv("Files/londres_accidentes_5years.csv")

str(accidentes)

# Variables necesarias para el proyecto
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

# Seleccionar las variables
accidentes <- accidentes[, variables]

# Comprobar resultado
str(accidentes)
dim(accidentes)


#Aquí voy a transformar la fecha porque open meteo trabaja con otro formato
# Convertir fecha a tipo Date
accidentes$date <- as.Date(
  accidentes$date,
  format = "%d/%m/%Y"
)

# Comprobar
head(accidentes$date)

# Revisar rango temporal
# Sneak peek: es [1] "2021-01-01" "2025-12-31"
range(accidentes$date, na.rm = TRUE)



# Rango de coordenadas
summary(accidentes[, c("latitude", "longitude")])

# Accidentes por año
table(accidentes$collision_year)

# Fechas faltantes
sum(is.na(accidentes$date))

# Coordenadas faltantes
sum(is.na(accidentes$latitude) |
      is.na(accidentes$longitude))


#   2021   2022   2023   2024   2025 
#  101087 106004 104258 100927 101525 
table(accidentes$collision_year)


# Fechas faltantes: 0

# Faltan 53 de latitud y longitud: 
sum(is.na(accidentes$latitude) |
      is.na(accidentes$longitude))



# Buscar accidentes en Londres el 15 de mayo de 2025
coincidencias <- subset(
  accidentes,
  date == as.Date("2025-05-15") &
    latitude >= 51.28 & latitude <= 51.70 &
    longitude >= -0.52 & longitude <= 0.33 &
    !is.na(time)
)

# Mostrar los primeros 5
head(coincidencias[, c(
  "collision_index",
  "date",
  "time",
  "latitude",
  "longitude",
  "collision_severity",
  "weather_conditions"
)], 5)

accidente <- coincidencias[1, ]

accidente[, c(
  "collision_index",
  "date",
  "time",
  "latitude",
  "longitude"
)]


nrow(accidentes)
str(accidentes)
summary(accidentes)


# Buscar el accidente víal con el mayor número de víctimas
accidentes[
  accidentes$number_of_casualties == max(accidentes$number_of_casualties, na.rm = TRUE),
]

table(accidentes$collision_severity, useNA = "ifany")
table(accidentes$road_type, useNA = "ifany")
table(accidentes$light_conditions, useNA = "ifany")
table(accidentes$weather_conditions, useNA = "ifany")
table(accidentes$road_surface_conditions, useNA = "ifany")
table(accidentes$urban_or_rural_area, useNA = "ifany")


# Eliminar registros que no tienen ubicación ni fecha
accidentes_limpios <- subset(
  accidentes,
  !is.na(latitude) & !is.na(longitude) & !is.na(date) 
)

 
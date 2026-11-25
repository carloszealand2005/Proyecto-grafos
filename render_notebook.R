Sys.setenv(RSTUDIO_PANDOC = "D:/RStudio/resources/app/bin/quarto/bin/tools")
setwd("c:/Users/V I C T U S/OneDrive/Desktop/Proyecto datos")
cat("Compilando Entregable_2_Notebook.Rmd a HTML...\n")
rmarkdown::render(
  input = "Entregable_2_Notebook.Rmd",
  output_file = "Entregable_2_Notebook.html",
  quiet = FALSE
)
cat("¡Compilación finalizada exitosamente!\n")

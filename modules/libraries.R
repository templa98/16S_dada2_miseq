# this file is used to import all the libraries that are used in the main file
# this is done to keep the main file clean and easy to read
# this file is sourced in the main file


.cran_packages <- c("jsonlite", "ggplot2", "dplyr", "gridExtra", "purrr", "tibble", "tidyr", "parallel")
.bioc_packages <- c("BiocStyle", "dada2", "phyloseq", "ShortRead", "Biostrings")


libraries <- c(.cran_packages, .bioc_packages)
for (lib in libraries) {
  suppressPackageStartupMessages(library(lib, character.only = TRUE))
  cat(paste0("Loaded: ", lib, " (Version ", packageVersion(lib), ")\n"))
}

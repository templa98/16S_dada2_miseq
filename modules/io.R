d2w_io <- new.env()


d2w_io$mkdirs <- function(relative_path) {
  # Check if the directory was successfully created
  if (!file.exists(relative_path)) {
    dir.create(relative_path, recursive = TRUE)
  }
}
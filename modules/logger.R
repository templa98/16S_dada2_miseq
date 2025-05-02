d2w_logger <- new.env()

GLOBAL.STEP <- 0
GLOBAL.TIME <- Sys.time()

d2w_logger$logs <- function(...) {
  GLOBAL.STEP <<- GLOBAL.STEP + 1
  current_time <- Sys.time()
  time_difference <- as.numeric(difftime(current_time, GLOBAL.TIME, units = "secs"))

  time_difference_mm_ss <- d2w_timer$time_diff_to_str(time_difference)

  cat("\n:s:******************************* time elapsed: ", time_difference_mm_ss, " ************************************:s:\n")
  cat("\n\n:s:>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> STEP ", GLOBAL.STEP, ": ", paste0(...), " <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<:s:\n", sep = "")

  GLOBAL.TIME <<- current_time
}

d2w_logger$logi <- function(...) {
  cat(":i:>> ", paste0(...), "\n", sep = "")
}

d2w_logger$logv <- function(..., verbose = FALSE) {
  if (!verbose) {
    return()
  }
  cat(":v:>> ", paste0(...), "\n", sep = "")
}

d2w_logger$print <- function(...) {
  cat(paste0(...), "\n", sep = "")
}

# reset the global step counter
d2w_logger$reset_step_counter <- function() {
  GLOBAL.STEP <<- 0
}

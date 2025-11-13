d2w_logger <- new.env()

GLOBAL.STEP <- 0
GLOBAL.TIME <- Sys.time()
GLOBAL.LOG.TIME <- Sys.time()  # Shared clock for info/warning/error logs

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

# Format time difference with hours:minutes or minutes:seconds
d2w_logger$format_delta_time <- function(seconds) {
  if (seconds >= 3600) {
    # Show hours:minutes
    hours <- floor(seconds / 3600)
    minutes <- floor((seconds %% 3600) / 60)
    return(sprintf("+%d:%02d Hr", hours, minutes))
  } else if (seconds >= 60) {
    # Show minutes:seconds
    minutes <- floor(seconds / 60)
    secs <- seconds %% 60
    return(sprintf("+%d:%04.1f Min", minutes, secs))
  } else {
    # Show seconds with one decimal
    return(sprintf("+%.1f Sec", seconds))
  }
}

# info log with timestamp
d2w_logger$info <- function(...) {
  current_time <- Sys.time()
  time_difference <- as.numeric(difftime(current_time, GLOBAL.LOG.TIME, units = "secs"))
  GLOBAL.LOG.TIME <<- current_time
  
  timestamp <- format(current_time, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  delta_str <- d2w_logger$format_delta_time(time_difference)
  cat(sprintf("[%s - INFO - %s] - %s\n", timestamp, delta_str, paste0(...)))
}

# warning log with timestamp
d2w_logger$warn <- function(...) {
  current_time <- Sys.time()
  time_difference <- as.numeric(difftime(current_time, GLOBAL.LOG.TIME, units = "secs"))
  GLOBAL.LOG.TIME <<- current_time
  
  timestamp <- format(current_time, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  delta_str <- d2w_logger$format_delta_time(time_difference)
  cat(sprintf("[%s - WARNING - %s] - %s\n", timestamp, delta_str, paste0(...)))
}

# error log with timestamp
d2w_logger$error <- function(...) {
  current_time <- Sys.time()
  time_difference <- as.numeric(difftime(current_time, GLOBAL.LOG.TIME, units = "secs"))
  GLOBAL.LOG.TIME <<- current_time
  
  timestamp <- format(current_time, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  delta_str <- d2w_logger$format_delta_time(time_difference)
  cat(sprintf("[%s - ERROR - %s] - %s\n", timestamp, delta_str, paste0(...)))
}

# verbose log with timestamp
d2w_logger$verbose <- function(..., verbose = FALSE) {
  if (!verbose) {
    return()
  }
  current_time <- Sys.time()
  time_difference <- as.numeric(difftime(current_time, GLOBAL.LOG.TIME, units = "secs"))
  GLOBAL.LOG.TIME <<- current_time
  
  timestamp <- format(current_time, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  delta_str <- d2w_logger$format_delta_time(time_difference)
  cat(sprintf("[%s - VERBOSE - %s] - %s\n", timestamp, delta_str, paste0(...)))
}

# reset the global step counter
d2w_logger$reset_step_counter <- function() {
  GLOBAL.STEP <<- 0
  GLOBAL.LOG.TIME <<- Sys.time()
}

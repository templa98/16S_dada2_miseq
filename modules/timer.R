# create a new environment to store the timer related variables and functions
d2w_timer <- new.env()

# this timer
d2w_timer$start_time <- NULL


d2w_timer$secondsToTimeFormat <- function(elapsed_seconds) {
  tf <- list()
  tf$hour <- floor(elapsed_seconds / 3600)
  tf$minute <- floor((elapsed_seconds %% 3600) / 60)
  tf$second <- floor((elapsed_seconds %% 3600) %% 60)
  return(paste0(tf$hour, ":", tf$minute, ":", tf$second))
}

# initialize the timer
initialize_timer <- function() {
  d2w_timer$start_time <<- Sys.time()
}

# get the current runtime of the code in milliseconds
d2w_timer$current_runtime_ms <- function() {
  return(as.numeric(difftime(Sys.time(), d2w_timer$start_time, units = "secs")) * 1000)
}

# get the current system time in milliseconds
d2w_timer$current_systime_ms <- function() {
  return(as.numeric(Sys.time(), units = "secs") * 1000)
}

# convert the time difference to a string
d2w_timer$time_diff_to_str <- function(time_difference) {
  time_difference.S <- floor(time_difference %% 60)
  time_difference.M <- floor(time_difference / 60)
  time_difference_mm_ss <- paste0(time_difference.M, ":", time_difference.S)

  if (time_difference.M > 60) {
    time_difference.H <- floor(time_difference.M / 60)
    time_difference.M <- floor(time_difference.M %% 60)
    time_difference_mm_ss <- paste0(time_difference.H, ":", time_difference.M, ":", time_difference.S)
  }
  return(time_difference_mm_ss)
}

# reset the timer
d2w_timer$reset_timer <- function() {
  d2w_timer$start_time <<- Sys.time()
}

# get the elapsed time since the timer was started
d2w_timer$elapsed_time <- function(currentTimeSec = NULL) {
  if (is.null(currentTimeSec)) {
    current_time <- Sys.time()
  } else {
    current_time <- currentTimeSec
  }
  time_difference <- as.numeric(difftime(current_time, d2w_timer$start_time, units = "secs"))
  return(time_difference)
}

# get the elapsed time since the timer was started in a string format
d2w_timer$elapsed_time_str <- function(currentTimeSec = NULL) {
  time_difference <- d2w_timer$elapsed_time(currentTimeSec)
  time_format <- d2w_timer$secondsToTimeFormat(time_difference)
  return(time_format)
}

# initialize the timer when the module is sourced
initialize_timer()

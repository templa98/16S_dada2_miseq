d2w_configs <- new.env()

args <- commandArgs(trailingOnly = TRUE)
d2w_configs$default_experiment_path <- args[1]
d2w_configs$slurm_log_directory <- if (length(args) >= 2) args[2] else NULL


# read and parse the json file
d2w_configs$load_experiments <- function() {
    # Read the entire JSON file into a single string
    json_content <- readLines(d2w_configs$default_experiment_path, warn = FALSE)
    json_string <- paste(json_content, collapse = "")

    # Parse the JSON string into an R list with simplify = FALSE to maintain structure
    parsed_data <- rjson::fromJSON(json_string, simplify = FALSE)

    return(parsed_data)
}




# set up the directory structure for the experiment and return the path
# TODO: require this function to output a JSON file with the experiment details along with computecanada configurations
d2w_configs$setup_experiment <- function(experiment) {
    # create an experiment id and create the directory structure
    if (!endsWith(experiment$settings$output_directory, "/")) {
        experiment$settings$output_directory <- paste0(experiment$settings$output_directory, "/")
    }
    experiment_id <- paste0(format(Sys.time(), "%d%h%y %H:%M"), " ", experiment$settings$name)
    experiment$runtime$directory <- paste0(experiment$settings$output_directory, experiment_id, "/")

    d2w_io$mkdirs(paste0(experiment$runtime$directory, "quality_control/"))
    d2w_io$mkdirs(paste0(experiment$runtime$directory, "plots/"))
    d2w_io$mkdirs(paste0(experiment$runtime$directory, "output/"))
    d2w_io$mkdirs(paste0(experiment$runtime$directory, "logs/"))


    # this needs to be converted to a List, otherwise when we try to output to json,
    # jsonlite package does not handle Dlist classes used internally by R!!! how weird!
    envs <- as.list(Sys.getenv())
    experiment$runtime$is_compute_canada <- FALSE
    if (!is.null(envs[["SLURM_JOB_ID"]])) {
        experiment$runtime$is_compute_canada <- TRUE
        experiment$runtime$environment$name <- "Compute Canada"
        experiment$runtime$environment$job_id <- as.character(envs[["SLURM_JOB_ID"]])
        experiment$runtime$environment$cluster_name <- as.character(envs[["SLURM_CLUSTER_NAME"]])
        cc_mempernode <- as.numeric(envs[["SLURM_MEM_PER_NODE"]])
        experiment$runtime$environment$memory_per_task <- paste0((cc_mempernode / 1024), "GB")
        experiment$runtime$environment$cpu_per_task <- as.numeric(envs[["SLURM_CPUS_PER_TASK"]])
        experiment$runtime$environment$duration <- d2w_timer$secondsToTimeFormat(as.numeric(envs[["SLURM_JOB_END_TIME"]]) - as.numeric(envs[["SLURM_JOB_START_TIME"]]))
        experiment$runtime$output_slurm_log_dir <- d2w_configs$slurm_log_directory
    }

    configs <- file(paste0(experiment$runtime$directory, "experiment.json"), open = "w")
    runtime_data <- experiment$runtime
    experiment$runtime <- NULL
    writeLines(jsonlite::toJSON(experiment, simplifyVector = TRUE, pretty = 4, auto_unbox = TRUE), configs)
    experiment$runtime <- runtime_data

    close(configs)


    return(experiment)
}

d2w_configs$copy_slurm_logs <- function(experiment) {
    # Only copy if running on Compute Canada
    if (!experiment$runtime$is_compute_canada) {
        return()
    }

    # Check if output_slurm_log_dir is available
    if (is.null(experiment$runtime$output_slurm_log_dir)) {
        d2w_logger$warn("SLURM log directory not provided. Skipping log copy.")
        return()
    }

    job_id <- experiment$runtime$environment$job_id
    slurm_log_dir <- experiment$runtime$output_slurm_log_dir

    # Source files
    output_log <- file.path(slurm_log_dir, paste0(job_id, "-slurm-output.txt"))
    error_log <- file.path(slurm_log_dir, paste0(job_id, "-slurm-error.txt"))

    # Destination directory
    dest_dir <- paste0(experiment$runtime$directory, "logs/")

    # Flush SLURM logs before copying (force sync to disk)
    # Note: R's flush.console() only affects R output, not SLURM's file buffers
    # SLURM automatically manages its log buffering, but we can try to ensure R output is flushed
    flush.console()
    
    # Small delay to allow file system sync (optional, helps with networked file systems)
    Sys.sleep(10)

    # Copy logs if they exist
    logs_copied <- FALSE
    if (file.exists(output_log)) {
        success <- file.copy(output_log, file.path(dest_dir, paste0(job_id, "-slurm-output.txt")), overwrite = TRUE)
        if (success) {
            d2w_logger$info(paste("Copied SLURM output log to experiment folder:", basename(output_log)))
            logs_copied <- TRUE
        } else {
            d2w_logger$warn(paste("Failed to copy SLURM output log:", output_log))
        }
    } else {
        d2w_logger$warn(paste("SLURM output log not found:", output_log))
    }

    if (file.exists(error_log)) {
        success <- file.copy(error_log, file.path(dest_dir, paste0(job_id, "-slurm-error.txt")), overwrite = TRUE)
        if (success) {
            d2w_logger$info(paste("Copied SLURM error log to experiment folder:", basename(error_log)))
            logs_copied <- TRUE
        } else {
            d2w_logger$warn(paste("Failed to copy SLURM error log:", error_log))
        }
    } else {
        d2w_logger$warn(paste("SLURM error log not found:", error_log))
    }

    if (!logs_copied) {
        d2w_logger$warn("No SLURM logs were copied to the experiment folder.")
    }
}

d2w_configs$close_experiment <- function(experiment) {
    # Copy SLURM logs before closing
    d2w_configs$copy_slurm_logs(experiment)

    # Close the experiment
    total_runtime <- d2w_timer$elapsed_time_str()
    configs <- file(paste0(experiment$runtime$directory, "runtime.json"), open = "w")
    runtime_data <- experiment$runtime
    runtime_data$runtime_duration <- total_runtime
    writeLines(jsonlite::toJSON(runtime_data, simplifyVector = TRUE, pretty = 4, auto_unbox = TRUE), configs)
    close(configs)
}

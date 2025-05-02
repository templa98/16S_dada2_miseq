d2w_configs <- new.env()

d2w_configs$default_experiment_path <- "./experiments.json"


# read and parse the json file
d2w_configs$load_experiments <- function() {
    # Read the entire JSON file into a single string
    json_content <- readLines(d2w_configs$default_experiment_path, warn = FALSE)
    json_string <- paste(json_content, collapse = "")

    # Parse the JSON string into an R list with simplify = FALSE to maintain structure
    parsed_data <- rjson::fromJSON(json_string, simplify = FALSE)

    return(parsed_data)
}

# validate the configurations of the experiments
d2w_configs$validate_configurations <- function(experiments) {
    # TODO: implement the function
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
    }

    configs <- file(paste0(experiment$runtime$directory, "experiment.json"), open = "w")
    runtime_data <- experiment$runtime
    experiment$runtime <- NULL
    writeLines(jsonlite::toJSON(experiment, simplifyVector = TRUE, pretty = 4, auto_unbox = TRUE), configs)
    experiment$runtime <- runtime_data

    close(configs)


    return(experiment)
}

d2w_configs$close_experiment <- function(experiment) {
    # Close the experiment
    total_runtime <- d2w_timer$elapsed_time_str()
    configs <- file(paste0(experiment$runtime$directory, "runtime.json"), open = "w")
    runtime_data <- experiment$runtime
    runtime_data$runtime_duration <- total_runtime
    writeLines(jsonlite::toJSON(runtime_data, simplifyVector = TRUE, pretty = 4, auto_unbox = TRUE), configs)
    close(configs)
}

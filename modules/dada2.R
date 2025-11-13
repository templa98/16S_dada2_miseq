d2w_dada <- new.env()


d2w_dada$count_fastq_reads <- function(file_path) {
    # Count the number of reads in a FASTQ file
    # Returns 0 if file doesn't exist or has errors
    if (!file.exists(file_path)) {
        return(0)
    }
    
    tryCatch({
        geom <- fastq.geometry(file_path)
        return(geom[1])  # First element is the number of reads
    }, error = function(e) {
        return(0)
    })
}

d2w_dada$validate_input_samples <- function(experiment) {
    # Validate that all input FASTQ files have at least one read
    # Remove samples with zero reads in either forward or reverse
    
    d2w_logger$info("Validating input FASTQ files for zero-read samples")
    
    valid_indices <- c()
    excluded_samples <- list()
    
    for (i in seq_along(experiment$runtime$samples$forward)) {
        fw_file <- experiment$runtime$samples$forward[i]
        rv_file <- experiment$runtime$samples$reverse[i]
        sample_name <- experiment$runtime$samples$names[i]
        
        fw_reads <- d2w_dada$count_fastq_reads(fw_file)
        rv_reads <- d2w_dada$count_fastq_reads(rv_file)
        
        if (fw_reads > 0 && rv_reads > 0) {
            valid_indices <- c(valid_indices, i)
        } else {
            excluded_info <- list(
                sample = sample_name,
                forward_reads = fw_reads,
                reverse_reads = rv_reads,
                forward_file = basename(fw_file),
                reverse_file = basename(rv_file)
            )
            excluded_samples <- c(excluded_samples, list(excluded_info))
        }
    }
    
    # Log excluded samples
    if (length(excluded_samples) > 0) {
        d2w_logger$error(paste0("Excluded ", length(excluded_samples), " sample(s) with zero reads:"))
        for (excl in excluded_samples) {
            d2w_logger$error(paste0("  - Sample: ", excl$sample, 
                                   " | Forward reads: ", excl$forward_reads,
                                   " | Reverse reads: ", excl$reverse_reads))
        }
    }
    
    # Update experiment with only valid samples
    if (length(valid_indices) == 0) {
        d2w_logger$error("No valid samples with reads found. Cannot proceed.")
        stop("No valid samples with reads found.")
    }
    
    original_count <- experiment$runtime$samples$num_samples
    experiment$runtime$samples$forward <- experiment$runtime$samples$forward[valid_indices]
    experiment$runtime$samples$reverse <- experiment$runtime$samples$reverse[valid_indices]
    experiment$runtime$samples$names <- experiment$runtime$samples$names[valid_indices]
    experiment$runtime$samples$num_samples <- length(valid_indices)
    
    if (length(valid_indices) < original_count) {
        d2w_logger$warn(paste0("Removed ", original_count - length(valid_indices), 
                              " sample(s). Remaining valid samples: ", length(valid_indices)))
    } else {
        d2w_logger$info(paste0("All ", original_count, " input samples have valid reads"))
    }
    
    return(experiment)
}

d2w_dada$validate_filtered_samples <- function(experiment, filtFs, filtRs) {
    # Validate that filtered files exist and have reads
    # Returns updated lists and a list of excluded samples
    
    d2w_logger$info("Validating filtered FASTQ files for zero-read samples")
    
    valid_indices <- c()
    excluded_samples <- list()
    
    for (i in seq_along(filtFs)) {
        fw_file <- filtFs[i]
        rv_file <- filtRs[i]
        sample_name <- experiment$runtime$samples$names[i]
        
        # Check if filtered files were created (dada2 doesn't create files with zero reads)
        fw_exists <- file.exists(fw_file)
        rv_exists <- file.exists(rv_file)
        
        fw_reads <- 0
        rv_reads <- 0
        
        if (fw_exists) {
            fw_reads <- d2w_dada$count_fastq_reads(fw_file)
        }
        if (rv_exists) {
            rv_reads <- d2w_dada$count_fastq_reads(rv_file)
        }
        
        if (fw_reads > 0 && rv_reads > 0) {
            valid_indices <- c(valid_indices, i)
        } else {
            excluded_info <- list(
                sample = sample_name,
                forward_reads = fw_reads,
                reverse_reads = rv_reads,
                forward_exists = fw_exists,
                reverse_exists = rv_exists
            )
            excluded_samples <- c(excluded_samples, list(excluded_info))
        }
    }
    
    # Log excluded samples
    if (length(excluded_samples) > 0) {
        d2w_logger$error(paste0("Excluded ", length(excluded_samples), 
                               " sample(s) after filtering (zero reads or missing files):"))
        for (excl in excluded_samples) {
            status_fw <- if (excl$forward_exists) paste0(excl$forward_reads, " reads") else "missing"
            status_rv <- if (excl$reverse_exists) paste0(excl$reverse_reads, " reads") else "missing"
            d2w_logger$error(paste0("  - Sample: ", excl$sample, 
                                   " | Forward: ", status_fw,
                                   " | Reverse: ", status_rv))
        }
    }
    
    # Check if we have any valid samples remaining
    if (length(valid_indices) == 0) {
        d2w_logger$error("No valid samples remaining after filtering. Cannot proceed.")
        stop("No valid samples remaining after filtering.")
    }
    
    original_count <- length(filtFs)
    if (length(valid_indices) < original_count) {
        d2w_logger$warn(paste0("Removed ", original_count - length(valid_indices), 
                              " sample(s) after filtering. Remaining valid samples: ", 
                              length(valid_indices)))
    } else {
        d2w_logger$info(paste0("All ", original_count, " filtered samples have valid reads"))
    }
    
    # Return updated lists
    return(list(
        valid_indices = valid_indices,
        excluded_samples = excluded_samples,
        filtFs = filtFs[valid_indices],
        filtRs = filtRs[valid_indices]
    ))
}

d2w_dada$normalize_pids <- function(pid_list, sub_space = TRUE, sub_dash = TRUE) {
    # Remove the spaces, and dashes
    if (sub_space) {
        pid_list <- gsub(" ", "", pid_list)
    }
    if (sub_dash) {
        pid_list <- gsub("-", "", pid_list)
    }
    return(pid_list)
}

d2w_dada$generate_quality_profile_plots <- function(experiment) {
    # Check if the experiment quality control section has the quality profile step
    if (is.null(experiment$quality_control$quality_profile_plot)) {
        # if the quality profile step is missing, return and do nothing
        d2w_logger$info("Skipping quality profile plot generation")
        return()
    }

    if (!experiment$quality_control$quality_profile_plot) {
        d2w_logger$info("Skipping quality profile plot generation")
        return()
    }
    
    # Check if we have any samples to plot
    if (experiment$runtime$samples$num_samples == 0) {
        d2w_logger$error("No samples available for quality profile plots")
        return()
    }
    
    d2w_logger$info("Generating quality profile plots")

    # Visualize quality profiles of random samples
    if (experiment$settings$random_seed > 0) {
        set.seed(experiment$settings$random_seed)
    }
    
    num_samples_to_plot <- min(experiment$runtime$samples$num_samples, 6)
    ii <- sample(length(experiment$runtime$samples$forward), num_samples_to_plot)
    
    # Wrap in tryCatch to handle any plotting errors gracefully
    tryCatch({
        qualityProf.fnFs <- plotQualityProfile(experiment$runtime$samples$forward[ii]) +
            ggtitle(paste0("Quality Scores of Forward Reads in ", experiment$settings$name)) 

        qualityProf.fnRs <- plotQualityProfile(experiment$runtime$samples$reverse[ii]) +
            ggtitle(paste0("Quality Scores of Reverse Reads in ", experiment$settings$name)) 

        if(experiment$settings$pipeline$dada){
            qualityProf.fnFs <- qualityProf.fnFs +
                scale_x_continuous(breaks = seq(0, 350, 25)) +
                geom_vline(xintercept = experiment$dada$filter_and_trim$truncate$forward, linetype = "solid", color = "blue", linewidth = 0.6)

            qualityProf.fnRs <- qualityProf.fnRs +
                scale_x_continuous(breaks = seq(0, 350, 25)) +
                geom_vline(xintercept = experiment$dada$filter_and_trim$truncate$reverse, linetype = "solid", color = "blue", linewidth = 0.6)
        }


        qpFS <- paste0(experiment$runtime$directory, "quality_control/", "quality_profile_forward_reads", "_", experiment$settings$name, ".pdf")
        qpRS <- paste0(experiment$runtime$directory, "quality_control/", "quality_profile_reverse_reads", "_", experiment$settings$name, ".pdf")

        ggsave(qpFS, qualityProf.fnFs, width = 18, height = 8, units = "in")
        ggsave(qpRS, qualityProf.fnRs, width = 18, height = 8, units = "in")
        
        d2w_logger$info("Successfully generated quality profile plots")
        
    }, error = function(e) {
        d2w_logger$error(paste0("Failed to generate quality profile plots: ", e$message))
        d2w_logger$warn("Continuing without quality profile plots")
    })
}
d2w_dada$run_multiqc <- function(experiment) {
    # Check if the experiment quality control section has the multiqc step
    if (is.null(experiment$quality_control$multiqc)) {
        # if the multiqc step is missing, return and do nothing
        d2w_logger$info("Skipping MultiQC report generation")
        return()
    }


    interactive <- TRUE
    if (!is.null(experiment$quality_control$multiqc$interactive_plots)) {
        interactive <- experiment$quality_control$multiqc$interactive_plots
    }
    no_intermediate_reports <- TRUE
    if (!is.null(experiment$quality_control$multiqc$delete_intermediate_files)) {
        no_intermediate_reports <- experiment$quality_control$multiqc$delete_intermediate_files
    }



    execute_fastqc <- function(pid, fastq_file, output_dir) {
        fastqc_path <- shQuote("./3rd party/FastQC/fastqc")
        output_dir <- shQuote(output_dir)
        fastq_file <- shQuote(fastq_file)
        command <- paste(fastqc_path, "-o", output_dir, fastq_file, ">/dev/null 2>&1")
        result <- system(command, intern = TRUE, ignore.stderr = FALSE, ignore.stdout = TRUE)
        message <- paste0("Finished FastQC for ", fastq_file)
        d2w_logger$verbose(message, verbose = experiment$settings$verbose)
        return(message)
    }

    execute_multiqc <- function(fastqc_dir, file_name) {
        multiqc_path <- shQuote("multiqc")
        input_dir <- shQuote(fastqc_dir)
        output_dir <- shQuote(paste0(experiment$runtime$directory, "quality_control/multiqc/"))

        interactive_mqc <- ifelse(interactive, "--interactive", "")
        intermediate_reports_mqc <- ifelse(no_intermediate_reports, "--no-data-dir", "")

        command <- paste(multiqc_path, input_dir, "-o", output_dir, "--filename", file_name, interactive_mqc, intermediate_reports_mqc, ">/dev/null 2>&1")
        d2w_logger$info(paste0("Running MultiQC on ", fastqc_dir))
        result <- system(command, intern = TRUE, ignore.stderr = FALSE, ignore.stdout = TRUE)
    }

    # Run FastQC on the forward and reverse reads separately
    if (experiment$quality_control$multiqc$separate_direction_reports) {
        d2w_logger$info("Running FastQC on the forward and reverse reads separately")
        output_dir_fw <- paste0(experiment$runtime$directory, "quality_control/multiqc/intermediate/fasqc/forward/")
        output_dir_re <- paste0(experiment$runtime$directory, "quality_control/multiqc/intermediate/fasqc/reverse/")
        d2w_io$mkdirs(output_dir_fw)
        d2w_io$mkdirs(output_dir_re)


        fastq_files <- c(experiment$runtime$samples$forward)
        num_jobs <- length(fastq_files)
        pids <- 1:num_jobs
        num_cpus <- ifelse(experiment$settings$multi_thread, parallel::detectCores(), 1)
        results <- mclapply(pids, function(i) execute_fastqc(pids[i], fastq_files[i], output_dir_fw), mc.cores = num_cpus)
        d2w_logger$info("Finished FastQC on the forward reads")

        fastq_files <- c(experiment$runtime$samples$reverse)
        num_jobs <- length(fastq_files)
        pids <- 1:num_jobs
        num_cpus <- ifelse(experiment$settings$multi_thread, parallel::detectCores(), 1)
        results <- mclapply(pids, function(i) execute_fastqc(pids[i], fastq_files[i], output_dir_re), mc.cores = num_cpus)
        d2w_logger$info("Finished FastQC on the reverse reads")

        # Run MultiQC on the forward and reverse reads separately
        execute_multiqc(output_dir_fw, "multiqc_forward_reads")
        execute_multiqc(output_dir_re, "multiqc_reverse_reads")
    } else { # Run FastQC on the combined forward and reverse reads
        d2w_logger$info("Running FastQC on the forward and reverse reads in combined mode")
        output_dir <- paste0(experiment$runtime$directory, "quality_control/multiqc/intermediate/fasqc/")
        d2w_io$mkdirs(output_dir)

        fastq_files <- c(experiment$runtime$samples$forward, experiment$runtime$samples$reverse)
        num_jobs <- length(fastq_files)
        pids <- 1:num_jobs
        num_cpus <- ifelse(experiment$settings$multi_thread, parallel::detectCores(), 1)
        results <- mclapply(pids, function(i) execute_fastqc(pids[i], fastq_files[i], output_dir), mc.cores = num_cpus)
        execute_multiqc(output_dir, "multiqc_combined_reads")
    }


    if (no_intermediate_reports == TRUE) {
        # delete the intermediate reports directory
        d2w_logger$info("Deleting the intermediate reports directory")
        unlink(paste0(experiment$runtime$directory, "quality_control/multiqc/intermediate"), recursive = TRUE)
    }
}


d2w_dada$has_custom_pids <- function(experiment) {
    return(length(experiment$input_data$custom_samples_pid) > 0)
}


d2w_dada$import_fastq_files <- function(experiment) {
    # Sort out the forward and reverse reads and organize them in order
    fnFs <- sort(list.files(experiment$input_data$input_miseq_directory, pattern = "_R1_001.fastq", full.names = TRUE))
    fnRs <- sort(list.files(experiment$input_data$input_miseq_directory, pattern = "_R2_001.fastq", full.names = TRUE))
    assertthat::are_equal(length(fnFs), length(fnRs))

    # Extract sample names, assuming filenames have format: SAMPLENAME_SXXX.fastq
    sample.names <- sapply(strsplit(basename(fnFs), "_S"), `[`, 1)
    d2w_logger$verbose("Raw sample names:\n", paste0(sample.names, collapse = ", "), "\n", verbose = experiment$settings$verbose_output)


    experiment$runtime$samples$forward <- fnFs
    experiment$runtime$samples$reverse <- fnRs
    experiment$runtime$samples$names <- sample.names
    experiment$runtime$samples$num_samples <- length(fnFs)

    return(experiment)
}

d2w_dada$read_custom_pid_samples <- function(experiment) {
    custom_files <- experiment$input_data$custom_samples_pid
    if (experiment$input_data$normalize_pids) {
        custom_files <- d2w_dada$normalize_pids(custom_files)
    }
    experiment$runtime$samples$forward <- experiment$runtime$samples$forward[experiment$runtime$samples$names %in% custom_files]
    experiment$runtime$samples$reverse <- experiment$runtime$samples$reverse[experiment$runtime$samples$names %in% custom_files]
    experiment$runtime$samples$names <- experiment$runtime$samples$names[experiment$runtime$samples$names %in% custom_files]
    experiment$runtime$samples$num_samples <- length(experiment$runtime$samples$forward)

    assertthat::are_equal(length(experiment$runtime$samples$forward), length(experiment$runtime$samples$reverse))
    return(experiment)
}

d2w_dada$sub_sample_input_files <- function(experiment) {
    assertthat::are_equal(length(experiment$runtime$samples$forward), length(experiment$runtime$samples$reverse))
    num.input.files <- length(experiment$runtime$samples$forward)

    s_count <- Inf
    s_count <- floor(experiment$input_data$sample_frequency * num.input.files)
    s_count <- max(1, s_count)
    if (experiment$settings$random_seed > 0) {
        set.seed(experiment$settings$random_seed)
    }
    s_mask <- sample(num.input.files, s_count)


    experiment$runtime$samples$forward <- experiment$runtime$samples$forward[s_mask]
    experiment$runtime$samples$reverse <- experiment$runtime$samples$reverse[s_mask]
    experiment$runtime$samples$names <- experiment$runtime$samples$names[s_mask]
    experiment$runtime$samples$num_samples <- length(experiment$runtime$samples$forward)

    return(experiment)
}


d2w_dada$export_to_fasta <- function(asv_dict, asv_as_key = TRUE) {
    fasta <- c()
    if (asv_as_key) {
        fasta <- unlist(lapply(names(asv_dict), function(asv_id) {
            c(paste0(">", asv_dict[[asv_id]], "\n"), asv_dict[[asv_id]])
        }))
    } else {
        fasta <- unlist(lapply(names(asv_dict), function(asv_id) {
            c(paste0(">", asv_id, "\n"), asv_dict[[asv_id]])
        }))
    }

    return(fasta)
}

d2w_dada$generate_asv_dict <- function(seq_table) {
    asv_list <- colnames(seq_table)
    asv_dict <- setNames(as.list(asv_list), paste0("ASV", seq_along(asv_list)))
    return(asv_dict)
}

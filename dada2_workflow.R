#--------------------- importing libraries
cat("importing libraries\n")
source("./modules/libraries.R")

#--------------------- importing modules
cat("importing modules\n")
source("./modules/io.R") # for reading and writing files
source("./modules/timer.R") # for keeping track of time
source("./modules/logger.R") # for logging the progress of the program
source("./modules/configs.R") # for loading configurations of the experiments
source("./modules/dada2.R") # for running the dada2 pipeline


# load the experiment.json file
experiment_configs <- d2w_configs$load_experiments()
# TODO: for each experiment, delete object to release memory

for (experiment in experiment_configs) {
    if (experiment$settings$run_experiment == FALSE) {
        # skip this experiment
        d2w_logger$print("skipping experiment: ", experiment$settings$name)
        next
    }

    # start the timer and the step counter for the experiment
    d2w_logger$print("Running experiment: ", experiment$settings$name)
    d2w_timer$reset_timer()
    d2w_logger$reset_step_counter()

    experiment <- d2w_configs$setup_experiment(experiment)
    plotName <- function(name) {
        return(paste0(experiment$runtime$directory, "plots/", name, "_", experiment$settings$name, ".pdf"))
    }
    saveObj <- function(obj, file_name) {
        file_path <- paste0(experiment$runtime$directory, "output/", file_name, "_", experiment$settings$name, ".RDS")
        saveRDS(obj, file = file_path)
    }
    writeToFile <- function(obj, file_name, file_extention = ".txt") {
        file_path <- paste0(experiment$runtime$directory, "output/", file_name, "_", experiment$settings$name, file_extention)
        writeLines(obj, file_path)
    }

    # --------------------- importing data
    d2w_logger$logs("Importing Data")
    experiment <- d2w_dada$import_fastq_files(experiment)

    # check if the experiment requires normalizing the PIDs
    if (experiment$input_data$normalize_pids) {
        d2w_logger$logi("Normalizing PIDs")
        experiment$runtime$samples$names <- d2w_dada$normalize_pids(experiment$runtime$samples$names)
        d2w_logger$logv("Normalized sample names:\n", paste0(experiment$runtime$samples$names, collapse = ", "), "\n", verbose = experiment$settings$verbose_output)
    }

    # check if the custom PID list is not empty
    if (d2w_dada$has_custom_pids(experiment)) {
        d2w_logger$logi("Selecting custom samples (PIDs) from the list of all samples")
        experiment <- d2w_dada$read_custom_pid_samples(experiment)
        count <- paste0("(Number of PIDs read = ", length(experiment$runtime$samples$names), " )")
        d2w_logger$logv("Custom sample names ", count, ": \n", paste0(experiment$runtime$samples$names, collapse = ", "), "\n", verbose = experiment$settings$verbose_output)
    }


    if (experiment$input_data$sample_input) {
        d2w_logger$logi("Sampling input FastQ files with a sample frequency of ", experiment$input_data$sample_frequency)
        experiment <- d2w_dada$sub_sample_input_files(experiment)
        d2w_logger$logi("Number of sampled PIDs: ", experiment$runtime$samples$num_samples)
        d2w_logger$print("Sampled PID names:\n", paste0(experiment$runtime$samples$names, collapse = ", "), "\n")
    }

    if (experiment$settings$verbose_output) {
        count <- paste0("(Number of Samples = ", length(experiment$runtime$samples$forward), " )")
        d2w_logger$logv("Forward Reads Files ", count, ":\n", verbose = experiment$settings$verbose_output)
        d2w_logger$print(paste0(experiment$runtime$samples$forward, collapse = "\n"))

        count <- paste0("(Number of Samples = ", length(experiment$runtime$samples$reverse), " )")
        d2w_logger$logv("\n\nReverse Reads Files ", count, ":\n", verbose = experiment$settings$verbose_output)
        d2w_logger$print(paste0(experiment$runtime$samples$reverse, collapse = "\n"))
    }


    # --------------------- quality plots
    if (experiment$settings$pipeline$quality_control) {
        d2w_logger$logs("Quality Control")
        d2w_dada$generate_quality_profile_plots(experiment)
        d2w_dada$run_multiqc(experiment)
    } else {
        d2w_logger$logs("Skipping Quality Control Step")
    }



    if (! experiment$settings$pipeline$dada) {
        d2w_logger$logs("Skipping DADA2 pipeline for experiment: ", experiment$settings$name)
        # close the experiment and write out the final results
        d2w_configs$close_experiment(experiment)
        next
    }




    # --------------------- filtering and trimming
    d2w_logger$logs("Filtering and Trimming Reads")

    filtFs <- file.path(experiment$input_data$output_filtered_fastq_directory, paste0(experiment$runtime$samples$names, "_F_filt.fastq.gz"))
    filtRs <- file.path(experiment$input_data$output_filtered_fastq_directory, paste0(experiment$runtime$samples$names, "_R_filt.fastq.gz"))
    names(filtFs) <- experiment$runtime$samples$names
    names(filtRs) <- experiment$runtime$samples$names

    # running some assertion before commiting to DADA2 pipeline
    d2w_logger$logi("Running sanity check assertions on input data")
    assertthat::are_equal(length(filtFs), length(filtRs))
    assertthat::are_equal(length(experiment$runtime$samples$forward), length(filtFs))
    assertthat::are_equal(length(experiment$runtime$samples$reverse), length(filtRs))

    # Filter and trim reads
    out_filter_and_trim <- filterAndTrim(experiment$runtime$samples$forward, filtFs, experiment$runtime$samples$reverse, filtRs,
        truncLen = c(experiment$filter_and_trim$truncate$forward, experiment$filter_and_trim$truncate$reverse),
        trimLeft = c(experiment$filter_and_trim$trim_lef$forward, experiment$filter_and_trim$trim_lef$reverse),
        maxN = 0, maxEE = c(2, 2), truncQ = 2, # TODO: investigate maxEE and truncQ
        rm.phix = experiment$filter_and_trim$remove_phix_genome,
        minLen = experiment$filter_and_trim$min_read_length, compress = TRUE, multithread = experiment$settings$multi_thread,
        verbose = experiment$settings$verbose_output
    )

    df.filter.trim <- out_filter_and_trim %>% as.data.frame()
    rownames(df.filter.trim) <- rownames(out_filter_and_trim)
    df.filter.trim <- df.filter.trim %>% mutate(sample_id = sapply(strsplit(basename(experiment$runtime$samples$forward), "_S"), `[`, 1))
    write.csv(df.filter.trim, paste0(experiment$runtime$directory, "output/filter_and_trim_", experiment$settings$name, ".csv"))

    # plot filter and trim results
    df.temp <- df.filter.trim %>% arrange(reads.in)
    p <- ggplot(df.temp) +
        geom_line(aes(x = reorder(sample_id, reads.in), y = reads.in, group = 1, colour = "reads.in")) +
        geom_line(aes(x = reorder(sample_id, reads.in), y = reads.out, group = 1, colour = "reads.out")) +
        labs(x = "Sample ID", y = "Read Counts (log10)", title = paste0("Input raw reads VS filtered reads in ", experiment$settings$fancy_name)) +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 6)) +
        scale_color_manual(values = c("reads.in" = "red", "reads.out" = "blue")) +
        scale_y_log10(labels = scales::comma)

    ggsave(plotName("filter_and_trim"), p, width = 12, height = 6, units = "in")


    # -------------------- Dereplication
    d2w_logger$logs("Dereplicating Reads")

    # Check for the existence of filtered sequence files
    exists <- file.exists(filtFs) # Check for forward reads

    # Perform dereplication on existing files
    # Dereplicate forward reads
    derepFs <- derepFastq(filtFs[exists], verbose = experiment$settings$verbose_output)
    names(derepFs) <- experiment$runtime$samples$names[exists]

    # Check for the existence of filtered sequence files
    exists <- file.exists(filtRs) # Check for reverse reads
    # Dereplicate reverse reads
    derepRs <- derepFastq(filtRs[exists], verbose = experiment$settings$verbose_output)
    names(derepRs) <- experiment$runtime$samples$names[exists]


    # -------------------- Error Estimation
    d2w_logger$logs("Learning Errors")

    errFs <- learnErrors(derepFs, multithread = experiment$settings$multi_thread, randomize = experiment$asv_inference$error_model$randomize, MAX_CONSIST = experiment$asv_inference$error_model$iterations)
    saveObj(errFs, "errFs")
    errRs <- learnErrors(derepRs, multithread = experiment$settings$multi_thread, randomize = experiment$asv_inference$error_model$randomize, MAX_CONSIST = experiment$asv_inference$error_model$iterations)
    saveObj(errRs, "errRs")

    p <- plotErrors(errFs, nominalQ = TRUE) + ggtitle(paste0("Forward reads errors in ", experiment$settings$fancy_name))
    ggsave(plotName("error_forward"), p, width = 12, height = 6, units = "in")

    p <- plotErrors(errRs, nominalQ = TRUE) + ggtitle(paste0("Reverse reads errors in ", experiment$settings$fancy_name))
    ggsave(plotName("error_reverse"), p, width = 12, height = 6, units = "in")

    # -------------------- DADA2
    d2w_logger$logs("DADA 2")

    # Apply DADA2 Algorithm
    dadaFs <- dada(derepFs, err = errFs, multithread = experiment$settings$multi_thread, pool = experiment$asv_inference$dada_pool_samples)
    d2w_logger$logi("Finished DADA2 for derepFs")

    dadaRs <- dada(derepRs, err = errRs, multithread = experiment$settings$multi_thread, pool = experiment$asv_inference$dada_pool_samples)
    d2w_logger$logi("Finished DADA2 for derepRs")

    # -------------------- Merging paired-end results
    d2w_logger$logs("Merging paired-end results")
    # Merge Paired-End Reads
    mergers <- mergePairs(dadaFs, derepFs, dadaRs, derepRs, verbose = experiment$settings$verbose_output)
    d2w_logger$logi("Finished merging paired-end reads")
    saveObj(mergers, "mergers")

    # free memory
    rm(derepFs)
    rm(derepRs)

    rm(errFs)
    rm(errRs)

    d2w_logger$logv("Calling Garbage Collector to free memory", verbose = experiment$settings$verbose_output)
    gc(verbose = experiment$settings$verbose_output)

    # -------------------- Remove Chimeras
    d2w_logger$logs("Removing Chimeras")

    # Remove Chimeras (Default Method)
    # TODO: see if we need this at all!
    # no_chimera_denovo_merger <- removeBimeraDenovo(mergers, multithread = experiment$settings$multi_thread, verbose = experiment$settings$verbose_output)
    # saveObj(no_chimera_denovo_merger, "no_chimera_denovo_merger")

    # Create Sequence Table
    seq_table_from_mergers <- makeSequenceTable(mergers)
    saveObj(seq_table_from_mergers, "seq_table_from_mergers")

    observed_seq_table <- table(nchar(getSequences(seq_table_from_mergers)))
    saveObj(observed_seq_table, "observed_seq_table")


    # Remove Chimeras (Default Method) from Sequence Table
    seq_tab_no_chimera <- removeBimeraDenovo(seq_table_from_mergers, method = "consensus", multithread = experiment$settings$multi_thread, verbose = experiment$settings$verbose_output)
    saveObj(seq_tab_no_chimera, "seq_tab_no_chimera")

    # export ASVs to a .fasta file
    asv_dict <- d2w_dada$generate_asv_dict(seq_tab_no_chimera) # keep a mapping between ASV keys and their sequences (e.g. ASV254 -> ACTGGCTA...)
    asv_fasta <- d2w_dada$export_to_fasta(asv_dict)
    writeToFile(asv_fasta, "asv_no_chimera", ".fasta")

    # -------------------- Generating tracking matrix
    d2w_logger$logs("Generating tracking matrix")
    getN <- function(x) sum(getUniques(x))
    track <- cbind(experiment$runtime$samples$names, out_filter_and_trim, sapply(dadaFs, getN), sapply(dadaRs, getN), sapply(mergers, getN), rowSums(seq_tab_no_chimera))
    colnames(track) <- c("PID", "input", "filtered", "denoisedF", "denoisedR", "merged", "non_chimeric")
    rownames(track) <- experiment$runtime$samples$names
    write.csv(track, paste0(experiment$runtime$directory, "output/track_reads_", experiment$settings$name, ".csv"), row.names = FALSE)

    track <- as.data.frame(track)
    stage_order <- c("input", "filtered", "denoisedF", "denoisedR", "merged", "non_chimeric")
    track.mat <- track %>% select(-PID)
    track_long <- gather(track.mat, key = "category", value = "value")
    track_long$category <- factor(track_long$category, levels = stage_order)
    track_long$value <- as.numeric(track_long$value)

    track.plot <- ggplot(track_long, aes(x = category, y = value)) +
        geom_boxplot() +
        labs(title = paste0("Number of reads after each stage in ", experiment$settings$fancy_name), x = "Stage", y = "Number of Reads") +
        theme_minimal() +
        scale_y_continuous(labels = scales::comma)
    ggsave(plotName("track_reads_boxplot"), track.plot, width = 16, height = 6, units = "in")

    track_long <- gather(track, key = "category", value = "value", -PID)
    track_long$category <- factor(track_long$category, levels = stage_order)
    track_long$value <- as.numeric(track_long$value)

    track.plot <- ggplot(track_long, aes(x = category, y = value, group = PID, color = PID)) +
        labs(color = "Sample PIDs", x = " Stage", y = "Number of Reads (log10)", title = paste0("Number of reads after each stage in ", experiment$settings$fancy_name)) +
        geom_line() +
        scale_y_log10(label = scales::comma) +
        theme_minimal()
    ggsave(plotName("track_reads_log10"), track.plot, width = 16, height = 6, units = "in")


    track.plot <- ggplot(track_long, aes(x = category, y = value, group = PID, color = PID)) +
        labs(color = "Sample PIDs", x = " Stage", y = "Number of Reads", title = paste0("Number of reads after each stage in ", experiment$settings$fancy_name)) +
        geom_line() +
        scale_y_continuous(label = scales::comma) +
        theme_minimal()
    ggsave(plotName("track_reads"), track.plot, width = 16, height = 6, units = "in")

    # -------------------- Assign Taxonomy
    d2w_logger$logs("Assigning Taxonomy to ASVs")

    for (fastaConfig in experiment$taxonomy_assignment) {
        fasta_train_file <- fastaConfig$reference_name
        if (fastaConfig$active == FALSE) {
            # skip this fasta file
            d2w_logger$print("skipping fasta file: ", fastaConfig$reference_name)
            next
        }
        d2w_logger$logi("Assigning Taxonomy (Kingdom:Genus) to ASVs using ", fasta_train_file)
        taxonomy_table <- assignTaxonomy(seq_tab_no_chimera, refFasta = fastaConfig$train_set_path, tryRC = fastaConfig$reverse_match_taxa, multithread = experiment$settings$multi_thread)
        saveObj(taxonomy_table, paste0("taxonomy_table_", tolower(fasta_train_file)))


        # check if the experiment requires assigning species to the ASVs
        if (fastaConfig$assign_species) {
            d2w_logger$logi(paste0("Assigning species to ASVs using ", fasta_train_file))
            taxonomy_table <- addSpecies(taxonomy_table, refFasta = fastaConfig$species_train_set_path, tryRC = fastaConfig$reverse_match_taxa, allowMultiple = fastaConfig$allow_multiple_species, verbose = experiment$settings$verbose_output)
            saveObj(taxonomy_table, paste0("taxonomy_table_species_", tolower(fasta_train_file)))
        }

        d2w_logger$logi("Generating ASV Statistics for ", fasta_train_file)
        asv_stat_cols <- c("ASV", colnames(taxonomy_table))
        otu.stat <- as.data.frame(taxonomy_table)
        otu.stat[, "ASV"] <- rownames(otu.stat)
        otu.stat.num.asv <- nrow(otu.stat)
        otu.stat.clean <- otu.stat %>% select(all_of(asv_stat_cols))
        otu.stat.na <- otu.stat.clean %>%
            select(-ASV) %>%
            summarise(across(everything(), ~ sum(is.na(.))))
        percent <- (otu.stat.na / otu.stat.num.asv) * 100
        otu.stat.na <- rbind(otu.stat.na, percent)
        rownames(otu.stat.na) <- c("NA count (ASVs)", "NA % (ASVs)")
        write.csv(otu.stat.na, paste0(experiment$runtime$directory, "output/asv_stat_", tolower(fasta_train_file), "_", experiment$settings$name, ".csv"))

        d2w_logger$logi("Generating Phyloseq Object for ", fasta_train_file)
        PID <- experiment$runtime$samples$names
        sample.data <- as.data.frame(PID)
        rownames(sample.data) <- PID
        ps <- phyloseq(
            otu_table(seq_tab_no_chimera, taxa_are_rows = FALSE),
            sample_data(sample.data),
            tax_table(taxonomy_table)
        )
        saveObj(ps, paste0("ps_", tolower(fasta_train_file)))
    }


    # close the experiment and write out the final results
    d2w_configs$close_experiment(experiment)

    # clear the memory and free allocated resources
    rm(dadaFs)
    rm(dadaRs)
    rm(out_filter_and_trim)
    rm(mergers)
    rm(seq_table_from_mergers)
    rm(seq_tab_no_chimera)
    rm(taxonomy_table)
    d2w_logger$logv("Calling Garbage Collector to free memory", verbose = experiment$settings$verbose_output)
    gc(verbose = experiment$settings$verbose_output)
}



print("program finished")

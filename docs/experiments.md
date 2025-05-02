# Experiment Configuration File Documentation

---

## Introduction

The **Experiment Configuration File** is a [JSON-formatted](https://www.digitalocean.com/community/tutorials/an-introduction-to-json) file that specifies all necessary settings and parameters required to run the DADA2 pipeline for sequence data analysis. It allows users to configure their experiments in a structured and organized manner, facilitating reproducibility and ease of use.

---

## Pipeline Stages

The configuration file is divided into several sequential stages:

1. [**settings**](#1-settings)
2. [**input_data**](#2-input_data)
3. [**quality_control**](#3-quality_control)
4. [**filter_and_trim**](#4-filter_and_trim)
5. [**asv_inference**](#5-asv_inference)
6. [**taxonomy_assignment**](#6-taxonomy_assignment)

Each section contains related parameters and settings pertinent to different stages of the DADA2 pipeline. Bellow is a not-so-accurate description of an experiment.

```
[
    {
      "settings": {a collection of instructions that describe this experiment and control the pipeline stages},
      "input_data": {a collection of instruction for the pipeline on how to find input MiSeq data},
      "quality_control": { a collection of instruction on how to perform quality control on our input sequences},
      "filter_and_trim": { a collection of instruction on how to filter and trim our sequences},
      "asv_inference": { a collection of instruction on how to converge on an error model and infer ASVs},
      "taxonomy_assignment": [ A list of reference databses]
    }
]
```
Notice the opening `[` and closing `]` brackets! these indicate that we are defining an array (a collection or a list) of experiments. That means you can chain multiple experiments together in one configuration file. Here is a simple example: 

```
[
    {
      "settings": {a collection of instructions that describe this experiment and control the pipeline stages},
      "input_data": {a collection of instruction for the pipeline on how to find input MiSeq data},
      "quality_control": { a collection of instruction on how to perform quality control on our input sequences},
      "filter_and_trim": { a collection of instruction on how to filter and trim our sequences},
      "asv_inference": { a collection of instruction on how to converge on an error model and infer ASVs},
      "taxonomy_assignment": [ A list of reference databses]
    },

    {
      "settings": {a collection of instructions that describe this experiment and control the pipeline stages},
      "input_data": {a collection of instruction for the pipeline on how to find input MiSeq data},
      "quality_control": { a collection of instruction on how to perform quality control on our input sequences},
      "filter_and_trim": { a collection of instruction on how to filter and trim our sequences},
      "asv_inference": { a collection of instruction on how to converge on an error model and infer ASVs},
      "taxonomy_assignment": [ A list of reference databses]
    }
]
```
In the above example, we can see two distince experiments defined in the JSON format in the configuration file. Now that we understand the purpose of the experiment configuration file, lets discuss what instructions can bed defined inside each pipeline stage.

---

## Sections and Fields Detailed Documentation

### **1. settings**

This section contains general settings for the experiment.
```json
"settings": {
    "run_experiment": true,
    "name": "experiment_01",
    "fancy_name": "Microbiome Analysis of Soil Samples",
    "output_directory": "./output",
    "random_seed": 42,
    "multi_thread": true,
    "verbose_output": false,
    "notes": "Initial test run",
    "pipeline": {
      "quality_control": true,
      "dada": true
    }
  }
```

#### Fields:

- **run_experiment**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Indicates whether to execute the experiment.

- **name**  
  *Type:* `string`  
  *Required:* **Yes**  
  *Description:* A unique identifier for the experiment.

- **fancy_name**  
  *Type:* `string`  
  *Required:* **Yes**  
  *Description:* A descriptive name for the experiment.

- **output_directory**  
  *Type:* `string` (Unix directory path)  
  *Required:* **Yes**  
  *Description:* The path where output files will be saved.

- **random_seed**  
  *Type:* `integer`  
  *Required:* **Yes**  
  *Description:* Seed for random number generation to ensure reproducibility.

- **multi_thread**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Enables multi-threading if set to `true`.

- **verbose_output**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Enables detailed logging output.

- **notes**  
  *Type:* `string`  
  *Required:* **Yes**  
  *Description:* Any additional notes or comments about the experiment.

- **pipeline**  
  *Type:* `object`  
  *Required:* **Yes**  
  *Description:* Specifies which parts of the pipeline to run.

  - **quality_control**  
    *Type:* `boolean`  
    *Required:* **Yes**  
    *Description:* Whether to perform quality control.

  - **dada**  
    *Type:* `boolean`  
    *Required:* **Yes**  
    *Description:* Whether to perform DADA2 analysis.

#### Field Dependencies:

- If `pipeline.quality_control` is set to `false`, the `quality_control` section can be omitted from the configuration file.

- If `pipeline.dada` is set to `false`, the following sections can be omitted:

  - `filter_and_trim`
  - `asv_inference`
  - `taxonomy_assignment`

---

### **2. input_data**

This section specifies the input data and sampling options.

```json
"input_data": {
    "input_miseq_directory": "~/data/miseq_runs/run_01",
    "output_filtered_fastq_directory": "~/data/miseq_runs/run_01/filtered_fastq",
    "normalize_pids": false,
    "custom_samples_pid": [ "sample_001", "sample_002",  "sample_003",  "sample_004",  "sample_005",
                            "sample_006",  "sample_007",  "sample_008", "sample_009",  "sample_010" ],
    "sample_input": true,
    "sample_frequency": 0.5
  }
```

#### Fields:

- **input_miseq_directory**  
  *Type:* `string` (Unix directory path)  
  *Required:* **Yes**  
  *Must Exist:* **Yes**  
  *Description:* Path to the directory containing MiSeq data.

- **output_filtered_fastq_directory**  
  *Type:* `string` (Unix directory path)  
  *Required:* **Yes**  
  *Description:* Path where filtered FASTQ files will be saved.

- **normalize_pids**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Whether to normalize participant IDs.

- **custom_samples_pid**  
  *Type:* `array` of `string`  
  *Required:* **Yes**  
  *Description:* List of custom sample participant IDs. Can be empty.

- **sample_input**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Whether to sample the input data.

- **sample_frequency**  
  *Type:* `float`  
  *Required:* **Yes**  
  *Range:* `0.0` to `1.0` (inclusive)  
  *Description:* The fraction of data to sample.

---

### **3. quality_control**

Settings related to the quality control process.

**Note:** This section is required **only** if `settings.pipeline.quality_control` is set to `true`.

```json
"quality_control": {
    "quality_profile_plot": true,
    "rarefaction_curve": false,
    "multiqc": {
      "separate_direction_reports": true,
      "delete_intermediate_files": true,
      "interactive_plots": false,
      "configs": "./multiqc_config.yaml"
    }
  }
```

#### Fields:

- **quality_profile_plot**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Generate quality profile plots.

- **rarefaction_curve**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Generate rarefaction curves.

- **multiqc**  
  *Type:* `object`  
  *Required:* **Yes**  
  *Description:* Settings for MultiQC reports.

  - **separate_direction_reports**  
    *Type:* `boolean`  
    *Required:* **Yes**  
    *Description:* Generate separate reports for each read direction.

  - **delete_intermediate_files**  
    *Type:* `boolean`  
    *Required:* **Yes**  
    *Description:* Delete intermediate files after processing.

  - **interactive_plots**  
    *Type:* `boolean`  
    *Required:* **Yes**  
    *Description:* Include interactive plots in reports.

  - **configs**  
    *Type:* `string`  
    *Required:* **No**  
    *Description:* Path to custom MultiQC configuration file.

---

### **4. filter_and_trim**

Parameters for filtering and trimming sequences.

**Note:** This section is required **only** if `settings.pipeline.dada` is set to `true`.

```json
"filter_and_trim": {
    "remove_phix_genome": true,
    "min_read_length": 50,
    "truncate": {
      "forward": 240,
      "reverse": 200
    },
    "trim_left": {
      "forward": 20,
      "reverse": 20
    }
  }
```

#### Fields:

- **remove_phix_genome**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Remove PhiX control sequences.

- **min_read_length**  
  *Type:* `integer`  
  *Required:* **Yes**  
  *Description:* Minimum read length to retain.

- **truncate**  
  *Type:* `object`  
  *Required:* **Yes**  
  *Description:* Positions to truncate reads.

  - **forward**  
    *Type:* `integer`  
    *Required:* **Yes**  
    *Description:* Truncate forward reads at this position.

  - **reverse**  
    *Type:* `integer`  
    *Required:* **Yes**  
    *Description:* Truncate reverse reads at this position.

- **trim_left**  
  *Type:* `object`  
  *Required:* **Yes**  
  *Description:* Positions to trim from the start of reads.

  - **forward**  
    *Type:* `integer`  
    *Required:* **Yes**  
    *Description:* Trim this many bases from the start of forward reads.

  - **reverse**  
    *Type:* `integer`  
    *Required:* **Yes**  
    *Description:* Trim this many bases from the start of reverse reads.

---

### **5. asv_inference**

Settings for Amplicon Sequence Variant inference.

**Note:** This section is required **only** if `settings.pipeline.dada` is set to `true`.

```json
"asv_inference": {
    "error_model": {
      "randomize": false,
      "iterations": 10
    },
    "dada_pool_samples": true
  }
```

#### Fields:

- **error_model**  
  *Type:* `object`  
  *Required:* **Yes**  
  *Description:* Settings for error modeling.

  - **randomize**  
    *Type:* `boolean`  
    *Required:* **Yes**  
    *Description:* Randomize error models.

  - **iterations**  
    *Type:* `integer`  
    *Required:* **Yes**  
    *Range:* `5` to `30` (inclusive)  
    *Description:* Number of iterations for error model training.

- **dada_pool_samples**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Pool samples during DADA2 processing.

---

### **6. taxonomy_assignment**

An array of taxonomy assignment configurations. You can use multiple reference databases for taxonomy assignment on the generated ASVs. 

**Note:** This section is required **only** if `settings.pipeline.dada` is set to `true`.

```json
"taxonomy_assignment": [
    {
      "active": true,
      "reference_name": "SILVA_138",
      "train_set_path": "~/databases/silva_train_set.fa",
      "assign_species": true,
      "allow_multiple_species": false,
      "species_train_set_path": "~/databases/silva_species_train_set.fa",
      "reverse_match_taxa": true
    },
    {
      "active": true,
      "reference_name": "RDP",
      "train_set_path": "~/databases/rdp_train_set.fa",
      "assign_species": true,
      "allow_multiple_species": true,
      "species_train_set_path": "~/databases/rdp_species_train_set.fa",
      "reverse_match_taxa": true
    }
  ]
```

#### Fields for Each Entry in the Array:

- **active**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Whether to perform this taxonomy assignment.

- **reference_name**  
  *Type:* `string`  
  *Required:* **Yes**  
  *Description:* Name of the reference database.

- **train_set_path**  
  *Type:* `string` (Unix file path)  
  *Required:* **Yes**  
  *Must Exist:* **Yes**  
  *Description:* Path to the training set file.

- **assign_species**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Whether to assign species-level taxonomy.

- **allow_multiple_species**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Allow multiple species assignments.

- **species_train_set_path**  
  *Type:* `string` (Unix file path)  
  *Required:* **Yes**  
  *Must Exist:* **Yes**  
  *Description:* Path to the species training set.

- **reverse_match_taxa**  
  *Type:* `boolean`  
  *Required:* **Yes**  
  *Description:* Match taxonomy in reverse complement.

---

## Field Dependencies and Conditional Requirements

- **pipeline.quality_control**:

  - If set to `false`, the `quality_control` section can be omitted from the configuration file.

- **pipeline.dada**:

  - If set to `false`, the following sections can be omitted:

    - `filter_and_trim`
    - `asv_inference`
    - `taxonomy_assignment`

- **quality_control.multiqc.configs**:

  - This field is **optional**. If provided, it must be a string representing the path to a custom MultiQC configuration file.

---

## Notes on Required and Optional Fields

- **Required Fields**:

  - All fields marked as *Required: Yes* must be provided in the configuration file unless their containing section can be omitted due to the above dependencies.

- **Optional Fields**:

  - Fields marked as *Required: No* are optional. They can be omitted or set to `null` if not needed.

---

## General Guidelines

- **Data Types**:

  - Ensure that all values match the specified data types. For example, `boolean` values must be `true` or `false` (without quotes), integers must not contain decimals, and strings must be enclosed in quotes.

- **Path Fields**:

  - Paths specified for files and directories should be valid Unix paths. They can be absolute or relative and may include the home directory shorthand (`~/`).

  - Fields marked with *Must Exist: Yes* require that the path exists on the filesystem at the time of validation.

- **Numeric Ranges**:

  - For fields with specified ranges, ensure that the values are within the inclusive range.

    - Example: `sample_frequency` must be between `0.0` and `1.0`, including `0.0` and `1.0`.

- **Arrays**:

  - For fields that are arrays (e.g., `custom_samples_pid`), the array can be empty, but all elements must be of the specified type.

- **Type Enforcement**:

  - The configuration validator enforces strict type checking. Types must match exactly; no type coercion is performed.

---

## Putting It All Together
Here is one experiment defined in the JSON format:
```json
[
  {
    "settings": {
      "run_experiment": true,
      "name": "experiment_01",
      "fancy_name": "Microbiome Analysis of Soil Samples",
      "output_directory": "./output",
      "random_seed": 42,
      "multi_thread": true,
      "verbose_output": false,
      "notes": "Initial test run",
      "pipeline": {
        "quality_control": true,
        "dada": true
      }
    },
    "input_data": {
      "input_miseq_directory": "~/data/miseq_runs/run_01",
      "output_filtered_fastq_directory": "./filtered_fastq",
      "normalize_pids": false,
      "custom_samples_pid": [ "sample_001", "sample_002",  "sample_003",  "sample_004",  "sample_005",
                              "sample_006",  "sample_007",  "sample_008", "sample_009",  "sample_010" ],
      "sample_input": true,
      "sample_frequency": 0.5
    },
    "quality_control": {
      "quality_profile_plot": true,
      "rarefaction_curve": false,
      "multiqc": {
        "separate_direction_reports": true,
        "delete_intermediate_files": true,
        "interactive_plots": false,
        "configs": "./multiqc_config.yaml"
      }
    },
    "filter_and_trim": {
      "remove_phix_genome": true,
      "min_read_length": 50,
      "truncate": {
        "forward": 240,
        "reverse": 200
      },
      "trim_left": {
        "forward": 20,
        "reverse": 20
      }
    },
    "asv_inference": {
      "error_model": {
        "randomize": false,
        "iterations": 10
      },
      "dada_pool_samples": true
    },
    "taxonomy_assignment": [
      {
        "active": true,
        "reference_name": "SILVA_138",
        "train_set_path": "~/databases/silva_train_set.fa",
        "assign_species": true,
        "allow_multiple_species": false,
        "species_train_set_path": "~/databases/silva_species_train_set.fa",
        "reverse_match_taxa": true
      },
      {
        "active": true,
        "reference_name": "RDP",
        "train_set_path": "~/databases/rdp_train_set.fa",
        "assign_species": true,
        "allow_multiple_species": true,
        "species_train_set_path": "~/databases/rdp_species_train_set.fa",
        "reverse_match_taxa": true
      }
    ]
  }
]
```

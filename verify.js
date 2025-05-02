#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');

// Utility functions for validation
function isBoolean(value) {
  return typeof value === 'boolean';
}

function isString(value) {
  return typeof value === 'string';
}

function isInt(value) {
  return Number.isInteger(value);
}

function isFloat(value) {
  return typeof value === 'number' && !Number.isNaN(value);
}

function checkRange(value, min, max) {
  return value >= min && value <= max;
}

function pathExists(p) {
  if (p.startsWith('~/')) {
    // Replace '~/' with the user's home directory
    p = path.join(os.homedir(), p.slice(2));
  }
  return fs.existsSync(p);
}

function isUnixPath(p) {
  // Simple check for Unix-like paths
  return typeof p === 'string' && (p.startsWith('/') || p.startsWith('./') || p.startsWith('../') || p.startsWith('~/'));
}

function validateConfig(config) {
  let errors = [];
  const pipeline_stages = {
    qc: true,
    dada: true
  }

  // Validate "settings" section
  if (!config.settings) {
    errors.push('Missing "settings" section.');
  } else {
    const settings = config.settings;

    // Check for required keys in "settings"
    const requiredSettingsKeys = [
      'run_experiment',
      'name',
      'fancy_name',
      'output_directory',
      'random_seed',
      'multi_thread',
      'verbose_output',
      'notes',
      'pipeline',
    ];
    requiredSettingsKeys.forEach((key) => {
      if (!(key in settings)) {
        errors.push(`Missing "settings.${key}" field.`);
      }
    });

    if ('run_experiment' in settings && !isBoolean(settings.run_experiment)) {
      errors.push('"settings.run_experiment" must be a boolean.');
    }
    if ('name' in settings && !isString(settings.name)) {
      errors.push('"settings.name" must be a string.');
    }
    if ('fancy_name' in settings && !isString(settings.fancy_name)) {
      errors.push('"settings.fancy_name" must be a string.');
    }
    if ('output_directory' in settings) {
      if (!isString(settings.output_directory) || !isUnixPath(settings.output_directory)) {
        errors.push('"settings.output_directory" must be a valid Unix directory path.');
      }
    }
    if ('random_seed' in settings && !isInt(settings.random_seed)) {
      errors.push('"settings.random_seed" must be an integer.');
    }
    if ('multi_thread' in settings && !isBoolean(settings.multi_thread)) {
      errors.push('"settings.multi_thread" must be a boolean.');
    }
    if ('verbose_output' in settings && !isBoolean(settings.verbose_output)) {
      errors.push('"settings.verbose_output" must be a boolean.');
    }
    if ('notes' in settings && !isString(settings.notes)) {
      errors.push('"settings.notes" must be a string.');
    }

    if (!('pipeline' in settings)) {
      errors.push('Missing "settings.pipeline" section.');
    } else {
      const pipeline = settings.pipeline;
      // Check for required keys in "pipeline"
      const requiredPipelineKeys = ['quality_control', 'dada'];
      requiredPipelineKeys.forEach((key) => {
        if (!(key in pipeline)) {
          errors.push(`Missing "settings.pipeline.${key}" field.`);
        }
      });

      if (!isBoolean(pipeline.quality_control)) {
        errors.push('"settings.pipeline.quality_control" must be a boolean.');
      } else {
        pipeline_stages.qc = pipeline.quality_control;
      }
      if ('dada' in pipeline && !isBoolean(pipeline.dada)) {
        errors.push('"settings.pipeline.dada" must be a boolean.');
      } else {
        pipeline_stages.dada = pipeline.dada;
      }
    }
  }

  // Validate "input_data" section

  if (!config.input_data) {
    errors.push('Missing "input_data" section.');
  } else {
    const inputData = config.input_data;

    // Check for required keys in "input_data"
    const requiredInputDataKeys = [
      'input_miseq_directory',
      'output_filtered_fastq_directory',
      'normalize_pids',
      'custom_samples_pid',
      'sample_input',
      'sample_frequency',
    ];
    requiredInputDataKeys.forEach((key) => {
      if (!(key in inputData)) {
        errors.push(`Missing "input_data.${key}" field.`);
      }
    });

    if ('input_miseq_directory' in inputData) {
      if (
        !isString(inputData.input_miseq_directory) ||
        !isUnixPath(inputData.input_miseq_directory)
      ) {
        errors.push('"input_data.input_miseq_directory" must be a valid Unix directory path.');
      } else if (!pathExists(inputData.input_miseq_directory)) {
        errors.push(
          `"input_data.input_miseq_directory" path does not exist: ${inputData.input_miseq_directory}`
        );
      }
    }
    if ('output_filtered_fastq_directory' in inputData) {
      if (
        !isString(inputData.output_filtered_fastq_directory) ||
        !isUnixPath(inputData.output_filtered_fastq_directory)
      ) {
        errors.push('"input_data.output_filtered_fastq_directory" must be a valid Unix directory path.');
      }
    }
    if ('normalize_pids' in inputData && !isBoolean(inputData.normalize_pids)) {
      errors.push('"input_data.normalize_pids" must be a boolean.');
    }
    if ('custom_samples_pid' in inputData) {
      if (!Array.isArray(inputData.custom_samples_pid)) {
        errors.push('"input_data.custom_samples_pid" must be an array of strings.');
      } else {
        inputData.custom_samples_pid.forEach((pid, index) => {
          if (!isString(pid)) {
            errors.push(`"input_data.custom_samples_pid[${index}]" must be a string.`);
          }
        });
      }
    }
    if ('sample_input' in inputData && !isBoolean(inputData.sample_input)) {
      errors.push('"input_data.sample_input" must be a boolean.');
    }
    if ('sample_frequency' in inputData) {
      if (!isFloat(inputData.sample_frequency)) {
        errors.push('"input_data.sample_frequency" must be a float.');
      } else if (!checkRange(inputData.sample_frequency, 0.0, 1.0)) {
        errors.push('"input_data.sample_frequency" must be between 0.0 and 1.0 inclusive.');
      }
    }
  }

  // Validate "quality_control" section
  if (pipeline_stages.qc) {
    if (!config.quality_control) {
      errors.push('Missing "quality_control" section.');
    } else {
      const qc = config.quality_control;

      // Check for required keys in "quality_control"
      const requiredQcKeys = ['quality_profile_plot', 'rarefaction_curve', 'multiqc'];
      requiredQcKeys.forEach((key) => {
        if (!(key in qc)) {
          errors.push(`Missing "quality_control.${key}" field.`);
        }
      });

      if ('quality_profile_plot' in qc && !isBoolean(qc.quality_profile_plot)) {
        errors.push('"quality_control.quality_profile_plot" must be a boolean.');
      }
      if ('rarefaction_curve' in qc && !isBoolean(qc.rarefaction_curve)) {
        errors.push('"quality_control.rarefaction_curve" must be a boolean.');
      }

      if ('multiqc' in qc) {
        const multiqc = qc.multiqc;

        // Check for required keys in "multiqc"
        const requiredMultiqcKeys = [
          'separate_direction_reports',
          'delete_intermediate_files',
          'interactive_plots',
          // 'configs' is optional
        ];
        requiredMultiqcKeys.forEach((key) => {
          if (!(key in multiqc)) {
            errors.push(`Missing "quality_control.multiqc.${key}" field.`);
          }
        });

        if (
          'separate_direction_reports' in multiqc &&
          !isBoolean(multiqc.separate_direction_reports)
        ) {
          errors.push('"quality_control.multiqc.separate_direction_reports" must be a boolean.');
        }
        if ('delete_intermediate_files' in multiqc && !isBoolean(multiqc.delete_intermediate_files)) {
          errors.push('"quality_control.multiqc.delete_intermediate_files" must be a boolean.');
        }
        if ('interactive_plots' in multiqc && !isBoolean(multiqc.interactive_plots)) {
          errors.push('"quality_control.multiqc.interactive_plots" must be a boolean.');
        }
        if ('configs' in multiqc && multiqc.configs !== undefined && !isString(multiqc.configs)) {
          errors.push('"quality_control.multiqc.configs" must be a string if provided.');
        }
      }
    }
  }


  if (pipeline_stages.dada){// Validate "filter_and_trim" section
  if (!config.filter_and_trim) {
    errors.push('Missing "filter_and_trim" section.');
  } else {
    const ft = config.filter_and_trim;

    // Check for required keys in "filter_and_trim"
    const requiredFtKeys = ['remove_phix_genome', 'min_read_length', 'truncate', 'trim_left'];
    requiredFtKeys.forEach((key) => {
      if (!(key in ft)) {
        errors.push(`Missing "filter_and_trim.${key}" field.`);
      }
    });

    if ('remove_phix_genome' in ft && !isBoolean(ft.remove_phix_genome)) {
      errors.push('"filter_and_trim.remove_phix_genome" must be a boolean.');
    }
    if ('min_read_length' in ft && !isInt(ft.min_read_length)) {
      errors.push('"filter_and_trim.min_read_length" must be an integer.');
    }

    if (!('truncate' in ft)) {
      errors.push('Missing "filter_and_trim.truncate" section.');
    } else {
      const truncate = ft.truncate;

      // Check for required keys in "truncate"
      const requiredTruncateKeys = ['forward', 'reverse'];
      requiredTruncateKeys.forEach((key) => {
        if (!(key in truncate)) {
          errors.push(`Missing "filter_and_trim.truncate.${key}" field.`);
        }
      });

      if ('forward' in truncate && !isInt(truncate.forward)) {
        errors.push('"filter_and_trim.truncate.forward" must be an integer.');
      }
      if ('reverse' in truncate && !isInt(truncate.reverse)) {
        errors.push('"filter_and_trim.truncate.reverse" must be an integer.');
      }
    }

    if (!('trim_left' in ft)) {
      errors.push('Missing "filter_and_trim.trim_left" section.');
    } else {
      const trimLeft = ft.trim_left;

      // Check for required keys in "trim_left"
      const requiredTrimLeftKeys = ['forward', 'reverse'];
      requiredTrimLeftKeys.forEach((key) => {
        if (!(key in trimLeft)) {
          errors.push(`Missing "filter_and_trim.trim_left.${key}" field.`);
        }
      });

      if ('forward' in trimLeft && !isInt(trimLeft.forward)) {
        errors.push('"filter_and_trim.trim_left.forward" must be an integer.');
      }
      if ('reverse' in trimLeft && !isInt(trimLeft.reverse)) {
        errors.push('"filter_and_trim.trim_left.reverse" must be an integer.');
      }
    }
  }

  // Validate "asv_inference" section
  if (!config.asv_inference) {
    errors.push('Missing "asv_inference" section.');
  } else {
    const asv = config.asv_inference;

    // Check for required keys in "asv_inference"
    const requiredAsvKeys = ['error_model', 'dada_pool_samples'];
    requiredAsvKeys.forEach((key) => {
      if (!(key in asv)) {
        errors.push(`Missing "asv_inference.${key}" field.`);
      }
    });

    if (!('error_model' in asv)) {
      errors.push('Missing "asv_inference.error_model" section.');
    } else {
      const errorModel = asv.error_model;

      // Check for required keys in "error_model"
      const requiredErrorModelKeys = ['randomize', 'iterations'];
      requiredErrorModelKeys.forEach((key) => {
        if (!(key in errorModel)) {
          errors.push(`Missing "asv_inference.error_model.${key}" field.`);
        }
      });

      if ('randomize' in errorModel && !isBoolean(errorModel.randomize)) {
        errors.push('"asv_inference.error_model.randomize" must be a boolean.');
      }
      if ('iterations' in errorModel) {
        if (!isInt(errorModel.iterations)) {
          errors.push('"asv_inference.error_model.iterations" must be an integer.');
        } else if (!checkRange(errorModel.iterations, 1, 30)) {
          errors.push('"asv_inference.error_model.iterations" must be between 1 and 30 inclusive.');
        }
      }
    }

    if ('dada_pool_samples' in asv && !isBoolean(asv.dada_pool_samples)) {
      errors.push('"asv_inference.dada_pool_samples" must be a boolean.');
    }
  }

  // Validate "taxonomy_assignment" section
  if (!('taxonomy_assignment' in config)) {
    errors.push('Missing "taxonomy_assignment" section.');
  } else if (!Array.isArray(config.taxonomy_assignment)) {
    errors.push('"taxonomy_assignment" must be an array.');
  } else {
    config.taxonomy_assignment.forEach((ta, index) => {
      // Check for required keys in each taxonomy assignment
      const requiredTaKeys = [
        'active',
        'reference_name',
        'train_set_path',
        'assign_species',
        'allow_multiple_species',
        'species_train_set_path',
        'reverse_match_taxa',
      ];
      requiredTaKeys.forEach((key) => {
        if (!(key in ta)) {
          errors.push(`Missing "taxonomy_assignment[${index}].${key}" field.`);
        }
      });

      if ('active' in ta && !isBoolean(ta.active)) {
        errors.push(`"taxonomy_assignment[${index}].active" must be a boolean.`);
      }
      if ('reference_name' in ta && !isString(ta.reference_name)) {
        errors.push(`"taxonomy_assignment[${index}].reference_name" must be a string.`);
      }
      if ('train_set_path' in ta) {
        if (!isString(ta.train_set_path) || !isUnixPath(ta.train_set_path)) {
          errors.push(
            `"taxonomy_assignment[${index}].train_set_path" must be a valid Unix file path.`
          );
        } else if (!pathExists(ta.train_set_path)) {
          errors.push(
            `"taxonomy_assignment[${index}].train_set_path" path does not exist: ${ta.train_set_path}`
          );
        }
      }
      if ('assign_species' in ta && !isBoolean(ta.assign_species)) {
        errors.push(`"taxonomy_assignment[${index}].assign_species" must be a boolean.`);
      }
      if ('allow_multiple_species' in ta && !isBoolean(ta.allow_multiple_species)) {
        errors.push(`"taxonomy_assignment[${index}].allow_multiple_species" must be a boolean.`);
      }
      if ('species_train_set_path' in ta) {
        if (!isString(ta.species_train_set_path) || !isUnixPath(ta.species_train_set_path)) {
          errors.push(
            `"taxonomy_assignment[${index}].species_train_set_path" must be a valid Unix file path.`
          );
        } else if (!pathExists(ta.species_train_set_path)) {
          errors.push(
            `"taxonomy_assignment[${index}].species_train_set_path" path does not exist: ${ta.species_train_set_path}`
          );
        }
      }
      if ('reverse_match_taxa' in ta && !isBoolean(ta.reverse_match_taxa)) {
        errors.push(`"taxonomy_assignment[${index}].reverse_match_taxa" must be a boolean.`);
      }
    });
  }}

  return errors;
}

// Main script execution
(function main() {
  const configFilePath = process.argv[2];

  if (!configFilePath) {
    console.error('Usage: node verifier.js <path_to_config.json>');
    process.exit(1);
  }

  if (!fs.existsSync(configFilePath)) {
    console.error(`Configuration file does not exist: ${configFilePath}`);
    process.exit(1);
  }

  let configContent;
  try {
    configContent = fs.readFileSync(configFilePath, 'utf-8');
  } catch (err) {
    console.error(`Error reading the configuration file: ${err.message}`);
    process.exit(1);
  }

  let bubuJsonConfig;
  try {
    bubuJsonConfig = JSON.parse(configContent);
  } catch (err) {
    console.error(`Error parsing the configuration file: ${err.message}`);
    process.exit(1);
  }

  if (!Array.isArray(bubuJsonConfig)) {
    console.error('Experiments must appear inside an JSON Array (i.e [ ... ])');
    process.exit(1);
  }

  let current_exp_num = 1;
  let num_exp = bubuJsonConfig.length;
  let has_errors = false;
  console.log(`Found ${bubuJsonConfig.length} experiments. Running verifier...`);

  for (config of bubuJsonConfig) {
    const errors = validateConfig(config);
    console.log(`Verifying experiment ${current_exp_num}/${num_exp}`);


    if (errors.length > 0) {
      has_errors = true;
      console.error('Experiment configuration validation failed with the following errors:');
      errors.forEach((error) => {
        console.error(`- ${error}`);
      });

    } else {
      console.log('Experiment configuration validation passed successfully.');
    }

    console.log("\n");
    current_exp_num++;


  }

  if (has_errors) {
    process.exit(1);
  }

})();

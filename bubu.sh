#!/bin/bash

# Check if exactly one argument (the JSON file) is provided
if [ $# -ne 1 ]; then
  printf "Error: \nThe experiment's JSON configuration file is missing \nUsage: ./bubu.sh experiment001.json\n"
  exit 1
fi

CONFIG_FILE="$1"

# Check if the configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file '$CONFIG_FILE' does not exist."
  exit 1
fi

# Run the verifier.js script with the provided configuration file
echo "Validating configuration file..."
# loading the modules 
module load StdEnv/2023
module load nodejs/20.16.0
node verify.js "$CONFIG_FILE"
EXIT_CODE=$?
module unload nodejs/20.16.0

if [ $EXIT_CODE -ne 0 ]; then
  echo ""
  echo "Validation failed. Please fix the problems in the configuration file and re-run the script."
  exit $EXIT_CODE
else
  echo ""
  echo "Configuration file is valid."
  echo ""

  # Prompt the user for additional information
  echo "Please provide the following information:"

  # 1. Total time in H:M (hours and minutes)
  while true; do
    read -p "1. Total time (HH:MM): " TOTAL_TIME
    if [[ $TOTAL_TIME =~ ^([0-9]{1,2}):([0-5][0-9])$ ]]; then
      break
    else
      echo "Invalid time format. Please enter in HH:MM format."
    fi
  done

  # 2. Number of CPUs
  while true; do
    read -p "2. Number of CPUs: " NUM_CPUS
    if [[ $NUM_CPUS =~ ^[1-9][0-9]*$ ]]; then
      break
    else
      echo "Please enter a valid positive integer for the number of CPUs."
    fi
  done

  # 3. RAM memory size in GB
  while true; do
    read -p "3. RAM memory size in GB (e.g., 16): " RAM_SIZE
    if [[ $RAM_SIZE =~ ^[1-9][0-9]*$ ]]; then
      break
    else
      echo "Please enter a valid positive integer for the RAM size in GB."
    fi
  done


  # 4. Job output directory
  DEFAULT_OUTPUT_DIR="$(cd "$(dirname "$0")/.."; pwd)/slurm_logs"
  echo "4. Job output directory"
  read -p "   press Enter for default: $DEFAULT_OUTPUT_DIR: " OUTPUT_DIR
  if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
  fi
  
  if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
      echo "Failed to create directory '$OUTPUT_DIR'. Please check the path and try again."
      exit 1
    fi
  fi


  # 5. Email address for notifications (optional)
  read -p "5. Email address for notifications (press Enter to skip): " EMAIL
  if [[ -n "$EMAIL" ]]; then
    # Validate the email format
    if [[ ! $EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$ ]]; then
      echo "Invalid email address format. Please try again."
      exit 1
    fi
  fi

  # Display the collected information
  echo ""
  echo "The following information has been provided:"
  echo "-------------------------------------------"
  echo "Total time:              $TOTAL_TIME"
  echo "Number of CPUs:          $NUM_CPUS"
  echo "RAM memory size:         ${RAM_SIZE}G"
  echo "Job output directory:    $OUTPUT_DIR"
  if [[ -n "$EMAIL" ]]; then
    echo "Email for notifications: $EMAIL"
  else
    echo "Email for notifications: Not provided"
  fi
  echo "-------------------------------------------"

  # Generate the SLURM job script in memory and submit it
  echo ""
  echo "Submitting job to SLURM..."


CONFIG_PATH="$(realpath "$CONFIG_FILE")"

(
  cat <<EOF
#!/bin/bash

#SBATCH --time=${TOTAL_TIME}:00
#SBATCH --nodes=1
#SBATCH --mem=${RAM_SIZE}G
#SBATCH --cpus-per-task=${NUM_CPUS}
#SBATCH --output=${OUTPUT_DIR}/%j-slurm-output.txt
#SBATCH --error=${OUTPUT_DIR}/%j-slurm-error.txt
EOF

if [[ -n "${EMAIL}" ]]; then
  echo "#SBATCH --mail-type=ALL"
  echo "#SBATCH --mail-user=${EMAIL}"
fi

cat <<EOF

module load StdEnv/2023
module load gcc/12.3
module load r-bundle-bioconductor/3.20
module load r/4.4.0

echo "Running with config: ${CONFIG_PATH}"
Rscript dada2_workflow.R "${CONFIG_PATH}"
EOF

) | sbatch



  echo "Job submitted successfully."
fi

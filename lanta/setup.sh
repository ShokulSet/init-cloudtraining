#!/bin/bash

# ------------------------------- Script Info -------------------------------- #

# LANTA Setup Script
# Version: 1.0.2

# ------------------------------ Jupyter Script ------------------------------ #

jupyter='''
port=$(shuf -i 6000-9999 -n 1)
USER=$(whoami)
node=$(hostname -s)

#jupyter notebookng instructions to the output file
echo -e "Jupyter server is running on: $(hostname)
Job starts at: $(date)

Copy/Paste the following command into your local terminal
--------------------------------------------------------------------
ssh -L $port:$node:$port $USER@lanta.nstda.or.th
--------------------------------------------------------------------
"

## start a cluster instance and launch jupyter server

unset XDG_RUNTIME_DIR
if [ "$SLURM_JOBTMP" != "" ]; then
    export XDG_RUNTIME_DIR=$SLURM_JOBTMP
fi
'''

# -------------------------- Select Option Function -------------------------- #

function select_option() {
    local options=("$@")
    local selection

    select opt in "${options[@]}" "Quit"; do
        case $opt in
        "Quit")
            echo "Exiting..."
            kill $$
            exit 1
            ;;
        *)
            if [[ " ${options[*]} " =~ " ${opt} " ]]; then
                selection="$opt"
                break
            fi
            ;;
        esac
    done

    echo "$selection"
}

tput clear

# ------------------------------- Node Type ---------------------------------- #

node_type=("compute" "gpu")
echo "Please select one of the following options:"
NODE_TYPE=$(select_option "${node_type[@]}")

if [ "$NODE_TYPE" == "${node_type[0]}" ]; then
    processors=("1 (128c)" "1/2 (64c)" "1/4 (32c)" "1/8 (16c)")
elif [ "$NODE_TYPE" == "${node_type[1]}" ]; then
    processors=("1/2 (64c)" "1/4 (32c)" "1/8 (16c)")
fi

# ------------------------------- Processors Type ---------------------------- #

echo "Please select one of the following options:"
PROCESSORS_TYPE=$(select_option "${processors[@]}")

if [ "$NODE_TYPE" == "${node_type[0]}" ]; then
    if [ "$PROCESSORS_TYPE" == "${processors[0]}" ]; then
        PROCESSORS_TYPE=128
    elif [ "$PROCESSORS_TYPE" == "${processors[1]}" ]; then
        PROCESSORS_TYPE=64
    elif [ "$PROCESSORS_TYPE" == "${processors[2]}" ]; then
        PROCESSORS_TYPE=32
    elif [ "$PROCESSORS_TYPE" == "${processors[3]}" ]; then
        PROCESSORS_TYPE=16
    fi
elif [ "$NODE_TYPE" == "${node_type[1]}" ]; then
    if [ "$PROCESSORS_TYPE" == "${processors[0]}" ]; then
        PROCESSORS_TYPE=64
    elif [ "$PROCESSORS_TYPE" == "${processors[1]}" ]; then
        PROCESSORS_TYPE=32
    elif [ "$PROCESSORS_TYPE" == "${processors[2]}" ]; then
        PROCESSORS_TYPE=16
    fi
fi

tput clear
echo "Processors Type: $PROCESSORS_TYPE"
echo ""

# ------------------------------- GPU Count ---------------------------------- #

if [ "$NODE_TYPE" == "gpu" ]; then
    gpu_options=("1" "2" "3" "4")
    echo "Please select the number of GPUs:"
    GPUs=$(select_option "${gpu_options[@]}")

    SPACES_NODE_TYPE="                    "

    tput clear
    echo "Processors Type: $PROCESSORS_TYPE"
    echo "Number of GPUs: $GPUs"
    echo ""
else
    GPUs="N/A"
    SPACES_NODE_TYPE="                "
fi

# ------------------------------- Time Limit --------------------------------- #

echo "Please enter the maximum time limit (hour: minute: second):"
read -p "Time limit: " TIME_LIMIT

IFS=':' read -r hours minutes seconds <<<"$TIME_LIMIT"
total_seconds=$((hours * 3600 + minutes * 60 + seconds))

threshold_hours=120
threshold_seconds=$((threshold_hours * 3600))

tput clear

if [ $total_seconds -gt $threshold_seconds ]; then
    echo "The input time exceeds $threshold_hours hours, setting to default time limit. (2:00:00)"
    echo ""
    TIME_LIMIT="2:00:00"
elif [ -z "$TIME_LIMIT" ]; then
    echo "Time limit not specified, setting to default time limit. (2:00:00)"
    echo ""
    TIME_LIMIT="2:00:00"
elif [[ ! $TIME_LIMIT =~ ^[0-9]{1,2}:[0-9]{2}:[0-9]{2}$ ]]; then
    echo "Invalid time format, setting to default time limit. (2:00:00)"
    echo ""
    TIME_LIMIT="2:00:00"
fi

echo "Processors Type: $PROCESSORS_TYPE"
echo "Number of GPUs: $GPUs"
echo "Time limit: $TIME_LIMIT"

# ------------------------------- Project Name ------------------------------- #

myquota

read -p "Project Name (check myquota for project names place ltxxxxxx-aixxxx): " project_name

if [ -z "$project_name" ]; then
    echo "Project name cannot be empty. Exiting..."
    exit 1
fi

if [ ${#PROCESSORS_TYPE} -eq 3 ]; then
    SPACES_PROCESSORS="               "
else
    SPACES_PROCESSORS="                "
fi

PROJECT_NAME_BATCH=$(echo $project_name | cut -d- -f1)

GPU_OPTION=""

if [ "$NODE_TYPE" == "gpu" ]; then
    GPU_OPTION="""
#SBATCH --gpus-per-task=$GPUs           # Specify the number of GPUs"""
fi

params="""#!/bin/bash
#SBATCH -p $NODE_TYPE $SPACES_NODE_TYPE # Specify partition [Compute/Memory/GPU]
#SBATCH -N 1 -c $PROCESSORS_TYPE $SPACES_PROCESSORS # Specify number of nodes and processors per task$GPU_OPTION
#SBATCH --ntasks-per-node=1         # Specify tasks per node
#SBATCH -t $TIME_LIMIT                  # Specify maximum time limit (hour: minute: second)
#SBATCH -A $PROJECT_NAME_BATCH                 # Specify project name
#SBATCH -J jupyter_notebook         # Specify job name
"""

cat <<EOF
$params 
EOF

read -p "Press enter to confirm the parameters... "

tput clear

module load Mamba/23.11.0-0 # Load the module that you want to use

conda env list

read -p "Please enter the name of the conda environment: " conda_env

if [ -z "$conda_env" ]; then
    echo "Conda environment is empty, using pytorch-2.2.2"
    exit 1
fi

read -p "Press enter to copy the following parameters to submit-$NODE_TYPE.sh... "

cat <<EOF >./submit-$NODE_TYPE.sh
$params 
EOF

cat <<EOF >>./submit-$NODE_TYPE.sh
ml Mamba
conda activate $conda_env
export HF_DATASETS_CACHE="/project/$project_name/.cache"
export HF_HOME="/project/$project_name/.cache"
export HF_HUB_CACHE="/project/$project_name/.cache"
export HF_HUB_OFFLINE=1
HF_DATASETS_OFFLINE=1
TRANSFORMERS_OFFLINE=1
EOF

read -p "Starting Directory (leave blank if pwd): " notebookdir

if [ -z "$notebookdir" ]; then
    notebookdir=$(pwd)
fi

jupyter_type=("notebook" "lab")
echo "Jupyter options (make sure to have it installed):"
jupyter_option=$(select_option "${jupyter_type[@]}")

port='''--port $port'''
ip='''--ip=$node'''

cat <<EOF >>./submit-$NODE_TYPE.sh
$jupyter
jupyter $jupyter_option --no-browser $port --notebook-dir=$notebookdir $ip
EOF

tput clear

echo "Parameters copied to submit-$NODE_TYPE.sh"

cat ./submit-$NODE_TYPE.sh

read -p "Confirm the file, and type (Y/n)?" submit_script
case "$submit_script" in
y | Y) sbatch ./submit-$NODE_TYPE.sh ;;
esac

# Guides and Scripts for LANTA

## Scripts for initalizing Jupyter Server

This script will help you to install Jupyter Server on your server.

```bash
ssh <name>@lanta.nstda.or.th

# for high-bandwidth and downloading files
ssh <name>@transfer.lanta.nstda.or.th
```

## Check if you have Jupyter in conda
```bash
ml Mamba

# check your available enviroments
conda env list 
conda activate <envname>

#this should show Jupyter if you have it installed
conda list | grep jupyter 
```

If you don't have conda installed please refer to guide below.

## Initializing the submit script

***Note: SSH into the server as the user created in the previous step first.***

```bash
mkdir scripts
cd scripts

wget https://github.com/ShokulSet/init-cloudtraining/releases/download/v1.0.3/setup.sh

bash setup.sh
```

Then follow the interactive prompt to setup the Jupyter Server.

## Inspecting the Jupyter Server when script finishes

After the script finishes, check your queue to see if the script has been submitted.

```bash
myqueue
```

If the script has been submitted, check your current directory with `ls` to see the slurm file.

```bash
ls

cat slurm-xxxxxx.out
```

The slurm file will contain the URL to access the Jupyter Server.

## Accessing the Jupyter Server

To access the Jupyter Server, copy the URL from the slurm file and paste it into your browser.

```bash
ssh -L <PORT>:<HOST>:<PORT> <username>@lanta.nstda.or.th -i <path-to-private-key>
```

Then open your browser and go to `localhost:<PORT>`  
or copy the URL with the token from the slurm file and paste it into your browser.

## Stopping the Jupyter Server

To stop the Jupyter Server, go to the terminal where you ran the batch script.

Run the following command to see the job ID.

```bash
myqueue
```

Then run the following command to stop the Jupyter Server.

```bash
scancel <job-id>
```

## To Install Packages or create Environments, use the compute node to install

```bash
ssh <username>@transfer.lanta.nstda.or.th
```

Then run the following command to SSH into the compute node.

```bash
bash setup.sh

myqueue

ssh lanta-c-xxx
```

### To clone existing environment

**NOTE: Your disk quota is limited to 100GB, if you need more space, use your house projects storage.**

```bash
conda create --name <env-name> --clone <source-env>
```

### To install packages

```bash
conda activate <env-name>

# To install a package
conda install <package-name>

# To install a package from a requirements file
pip install --file requirements.txt
```

### To remove an environment

```bash
conda env remove -n <env-name>
```

## Basic Slurm Commands

### s* commands

`sbatch` - Submit a batch script to the queue.

`scancel` - Cancel a job.

`sbalance` - Check the balance of the queue (GPU hours).

`sinfo` - Check nodes that are both idle and running.

### my* commands

`myqueue` - Check the queue.

`myquota` - Check your quota (Disk usage, projects).

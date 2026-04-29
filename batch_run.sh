#!/bin/tcsh
#BSUB -J dsa595_sim[1-200]
#BSUB -n 1
#BSUB -R span[hosts=1]
#BSUB -W 00:30
#BSUB -o output/logs/sim_%J_%I.out
#BSUB -e output/logs/sim_%J_%I.err

module load R

Rscript run_file.r $LSB_JOBINDEX output/traces/

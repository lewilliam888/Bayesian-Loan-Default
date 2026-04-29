#!/bin/bash
# Workflow to reproduce the results of the DSA 595 project by William Le

set -e

mkdir -p output/traces output/figures

for seed in {1..200}
do
  Rscript run_file.r $seed output/traces/
done

Rscript out_file.r output/traces/ output/figures/

Rscript real_data_fit.r data/lending_club_clean.csv output/

echo "workflow complete."

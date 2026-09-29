MRMhub INTEGRATOR - input files
===============================

The MRMhub executable reads these files from its own folder. They are set up
for the MRMhub demo dataset and serve as templates for your own data. Their
format matches this version of INTEGRATOR.

  param.txt         Processing parameters: location of the mzML files,
                    m/z and RT tolerances, integration settings, threads.
  run_order.csv     One row per mzML file in acquisition order: file name,
                    batch, sample type, and reference samples for RT
                    alignment.
  feature_list.csv  Transitions to integrate: feature ID, ISTD, precursor
                    and product m/z, expected RT, integration options.
  MRMhub_plot.r     R script used by step 4 to write chromatogram PDFs
                    (requires R).

Run the steps from a terminal in this folder with ./MRMhub 1 to 4
(Windows: MRMhub.exe 1 to 4), or start MRMhub and choose a step.

Manual: https://slinghub.github.io/MRMhub/integrator/

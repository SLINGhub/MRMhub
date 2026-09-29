# mrmhub 1.0.0

First stable release of the MRMhub software framework.

## Changes

- New function `set_lipid_class()` derives lipid classes from lipid feature names using the `rgoslin` package.
- Calibration curves support `1/sqrt(x)` weighting.
- External calibration works with only one or two calibrator levels too.
- QC metrics report the number of replicates per QC type (new columns `n_bqc`, `n_tqc`, `n_spl`).
- New [release v1.0.0](https://github.com/SLINGhub/MRMhub/releases/tag/v1.0.0) with INTEGRATOR binaries and the QUANT R package, with and without a complete demo project.
- Various bug fixes and improvements in robustness, performance and usability.

# mrmhub 0.9.9

Peer-reviewed version of Burla, Teo *et al.*, *Nature Metabolism* (2026), [doi:10.1038/s42255-026-01629-2](https://doi.org/10.1038/s42255-026-01629-2). The version initially submitted for review was 0.9.2.

## Changes

- New isotope interference correction for precursor (MS1) and transition-level (MRM) interferences, based on the LICAR method ([Gao *et al.*, *Anal. Chem.* 2021](https://doi.org/10.1021/acs.analchem.0c04565)).
- New batch-correction methods (experimental): empirical Bayes ComBat (`correct_batch_combat()`; [Johnson *et al.*, *Biostatistics* 2007](https://doi.org/10.1093/biostatistics/kxj037)) and SERRF random-forest normalization (`correct_batch_serrf()`; [Fan *et al.*, *Anal. Chem.* 2019](https://doi.org/10.1021/acs.analchem.8b05592)), complementing `correct_batch_centering()`.
- New import from and export to the community format mzTab-M (`import_data_mztab()`, `save_dataset_mztab()`; [Hoffmann *et al.*, *Anal. Chem.* 2019](https://doi.org/10.1021/acs.analchem.8b04310)).
- New export to Bioconductor `SummarizedExperiment` ([Morgan *et al.*](https://doi.org/10.18129/B9.bioc.SummarizedExperiment)) and `lipidr` `LipidomicsExperiment` objects ([Mohamed *et al.*, *J. Proteome Res.* 2020](https://doi.org/10.1021/acs.jproteome.0c00082)) via `save_dataset_summarizedexperiment()`.
- More consistent plotting, with plot settings such as point size, colours, legend placement and dimensions definable globally via `mrmhub_set_plot_defaults()`.
- New `save_plot()` writes any `plot_*()` figure to a file at a defined physical size and format, including multi-page PDFs.
- New `save_dataset_rds()` and `read_dataset_rds()` save and load a complete `MRMhubExperiment`, making it easy to share and archive datasets with all data, metadata and processing status.
- Improved console output, processing summaries and more actionable error messages.
- Enhanced up-front validation of function arguments.
- Improved data and metadata import, with more robust sample and feature ID matching, deduplication and stronger schema validation.
- Various bug fixes and improvements in performance, robustness and usability, partly based on user feedback.

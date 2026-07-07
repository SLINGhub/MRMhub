# Data Identifiers in MRMhub

## Key Data Identifiers

The following fields are essential for organizing data in MRMhub. They
link the data tables within the `MRMhubExperiment` object and are used
by processing functions throughout the package.

| Table | Field | Description |
|----|----|----|
| Analyses | **`analysis_id`** | Unique identifier for each injection/analysis. |
|  | `qc_type` | Sample type label (e.g., SPL, BQC, CAL). See below. |
|  | `batch_id` | Identifies the analytical batch. |
|  | `sample_id` | Identifies the physical sample that was tested. |
| Features | **`feature_id`** | Unique identifier for each MRM transition/feature. |
|  | `istd_feature_id` | The `feature_id` of the internal standard used for normalization. |
|  | `analyte_id` | Identifies the analyte (compound). |

**Why `analysis_id` instead of `sample_id`?** A sample may be measured
multiple times (replicates, different methods). Each injection needs a
unique identifier. Similarly, one analyte can be measured through
multiple transitions, so `feature_id` (not `analyte_id`) is the primary
key.

## QC Types (Sample Types)

QC types categorize samples by their analytical purpose. This
classification combines nomenclature from Broadhurst et al. (2018) (SPL,
BQC, TQC, LTR, RQC) with traditional terms from analytical and clinical
chemistry (LQC, MQC, HQC, CAL, NIST, SST, blanks).

QC types are shown with consistent colors and point shapes in all MRMhub
plots, allowing quick visual identification across different figures.

## See Also

- [Sample Types & QC
  Roles](https://slinghub.github.io/MRMhub/quant/articles/manual-00-sample-types.md)
  — detailed definitions and usage rules
- [Data
  Structures](https://slinghub.github.io/MRMhub/quant/articles/manual-01-data-structure.md)
  — overview of all tables
- [Feature
  Variables](https://slinghub.github.io/MRMhub/quant/articles/manual-03-feature-variables.md)
  — measurement variable columns

## References

Broadhurst, David, Royston Goodacre, Stacey N. Reinke, et al. 2018.
“Guidelines and Considerations for the Use of System Suitability and
Quality Control Samples in Mass Spectrometry Assays Applied in
Untargeted Clinical Metabolomic Studies.” *Metabolomics* 14 (6): 72.
<https://doi.org/10.1007/s11306-018-1367-3>.

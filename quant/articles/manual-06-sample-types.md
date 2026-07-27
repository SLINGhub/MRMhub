# Sample types & QC roles

Manual

MRMhub uses the `qc_type` column in the analysis annotation to
categorize samples by their analytical purpose. This label determines
which samples are used for drift correction, batch correction, QC-metric
calculation and calibration, and which are excluded from the reported
study results. Assigning the wrong label therefore causes MRMhub to use
the wrong samples for corrections, so the `qc_type` column should be
checked before processing.

## QC types (sample types)

The classification combines nomenclature from several sources: the
standardized terms SPL, BQC, TQC, LTR and RQC were introduced by
Broadhurst et al. (2018) for the use of system-suitability and
quality-control samples in mass spectrometry assays, while the others
(LQC, MQC, HQC, CAL, NIST, SST and the blank types) derive from
traditional terminology in analytical and clinical chemistry.

| QC type | Group | Description |
|----|----|----|
| `SPL` | Unknowns | Study sample (“unknowns”) |
| `BQC` | QC | Batch / Process QC |
| `PQC` | QC | Process QC (or Pooled QC); see `BQC` |
| `TQC` | QC | Technical QC |
| `EQC` | QC | Equilibration QC; injected to equilibrate the system and check that it is stable and performing as expected |
| `LQC` | QC | Low QC |
| `MQC` | QC | Mid QC |
| `HQC` | QC | High QC |
| `QC` | QC | General QC sample (not strictly defined) |
| `CAL` | Calibration | Calibration sample |
| `RQC` | QC | Response QC (dilution series) |
| `LTR` | Reference material | Long-Term Reference |
| `NIST` | Reference material | NIST Standard Reference Material |
| `EQA` | QC | External Quality Assessment sample, e.g. from proficiency-testing (PT) schemes |
| `SST` | QA | System Suitability Test sample |
| `PBLK` | Process blank | No matrix, processed with ISTD as all other samples |
| `UBLK` | Blank | Unextracted Blank: no matrix, with ISTD, without undergoing sample processing |
| `SBLK` | Blank | Solvent / double blank: no matrix, no ISTD, just solvents |
| `TBLK` | Blank | Technical blank (instrument blank) |
| `MBLK` | Blank | Matrix Blank: matrix processed as samples but without ISTDs |
| `BLK` | Blank | Generic blank, when the specific blank type is unknown or unspecified |

## Which samples are used where

The reference QC types for drift and batch correction are user-selected
(`ref_qc_types`), typically the QC pool (`BQC`). The table below
summarises the usual roles.

| Processing step | Uses | Typical sample types |
|----|----|----|
| Drift correction (QC-based models) | Signal anchors | `BQC` (or the selected `ref_qc_types`) |
| Batch correction (centering) | Cross-batch alignment | `BQC` (or the selected `ref_qc_types`) |
| QC metrics (CV, bias) | Precision monitoring | `BQC`, `TQC`, `PBLK` |
| Calibration curves | Quantification | `CAL` |
| Excluded from study results | Not reported | all blanks, `CAL`, `RQC`, `SST` |

## Setting the sample type in the annotation

The analysis annotation must have a column called `sample_type` or
`qc_type`. Labels are matched case-insensitively against the types
listed above (so `CAL`, `Cal`, and `cal` are equivalent), and a small
set of vendor labels is recognised as aliases: `Sample` → `SPL`, `Blank`
→ `BLK`, `DoubleBlank` → `SBLK`, `MatrixBlank` → `MBLK`, and
`ResponseCheck` → `RQC`. Unrecognised labels are retained but dropped
from QC metrics and plots that expect a standard type. Every analysis
must carry a label, and QC samples used as drift/batch anchors should be
evenly distributed across the run (at least five per batch for reliable
drift correction).

    analysis_id,sample_type,batch_id,analysis_order
    Inj_001,SBLK,Batch_1,1
    Inj_002,BQC,Batch_1,2
    Inj_003,SPL,Batch_1,3
    Inj_004,SPL,Batch_1,4
    ...
    Inj_010,BQC,Batch_1,10
    Inj_080,BQC,Batch_1,80
    Inj_081,SBLK,Batch_1,81

## Typical batch layout

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA3MDAgOTAiIHN0eWxlPSJtYXgtd2lkdGg6IDcwMHB4OyB3aWR0aDogMTAwJTsgaGVpZ2h0OiBhdXRvOyBmb250LWZhbWlseTogLWFwcGxlLXN5c3RlbSwgQmxpbmtNYWNTeXN0ZW1Gb250LCAmIzM5O1NlZ29lIFVJJiMzOTssIHNhbnMtc2VyaWY7Ij48c3R5bGU+CiAgICAuYmwtYm94IHsgcng6IDQ7IHJ5OiA0OyBzdHJva2Utd2lkdGg6IDEuMjsgfQogICAgLmJsLXR4dCB7IGZvbnQtc2l6ZTogMTBweDsgZm9udC13ZWlnaHQ6IDYwMDsgZmlsbDogI2ZmZjsgdGV4dC1hbmNob3I6IG1pZGRsZTsgfQogICAgLmJsLWFubiB7IGZvbnQtc2l6ZTogOXB4OyBmaWxsOiAjNTU1OyB0ZXh0LWFuY2hvcjogbWlkZGxlOyB9CiAgPC9zdHlsZT4KPCEtLSBTQkxLIC0tPjxyZWN0IGNsYXNzPSJibC1ib3giIHg9IjUiIHk9IjIwIiB3aWR0aD0iNTAiIGhlaWdodD0iMzUiIGZpbGw9IiMxODU0ZjkiIHN0cm9rZT0iIzBmM2FiNSIgLz48dGV4dCBjbGFzcz0iYmwtdHh0IiB4PSIzMCIgeT0iNDIiPlNCTEs8L3RleHQ+PHRleHQgY2xhc3M9ImJsLWFubiIgeD0iMzAiIHk9IjcyIj5ibGFuazwvdGV4dD48IS0tIFRRQyAtLT48cmVjdCBjbGFzcz0iYmwtYm94IiB4PSI2NSIgeT0iMjAiIHdpZHRoPSI1MCIgaGVpZ2h0PSIzNSIgZmlsbD0iIzE4NTRmOSIgc3Ryb2tlPSIjMGYzYWI1IiAvPjx0ZXh0IGNsYXNzPSJibC10eHQiIHg9IjkwIiB5PSI0MiI+VFFDPC90ZXh0Pjx0ZXh0IGNsYXNzPSJibC1hbm4iIHg9IjkwIiB5PSI3MiI+dGVjaDwvdGV4dD48IS0tIEJRQyAtLT48cmVjdCBjbGFzcz0iYmwtYm94IiB4PSIxMjUiIHk9IjIwIiB3aWR0aD0iNDUiIGhlaWdodD0iMzUiIGZpbGw9IiNmMjc1MDciIHN0cm9rZT0iI2IzNTcwMCIgLz48dGV4dCBjbGFzcz0iYmwtdHh0IiB4PSIxNDciIHk9IjQyIj5CUUM8L3RleHQ+PHRleHQgY2xhc3M9ImJsLWFubiIgeD0iMTQ3IiB5PSI3MiI+YW5jaG9yPC90ZXh0PjwhLS0gU1BMIGJsb2NrIC0tPjxyZWN0IGNsYXNzPSJibC1ib3giIHg9IjE4MCIgeT0iMjAiIHdpZHRoPSIxODAiIGhlaWdodD0iMzUiIGZpbGw9IiM4ZTliOWUiIHN0cm9rZT0iIzZmN2M3ZiIgLz48dGV4dCBjbGFzcz0iYmwtdHh0IiB4PSIyNzAiIHk9IjQyIj5TUEwgU1BMIFNQTCBTUEwgU1BMIFNQTDwvdGV4dD48dGV4dCBjbGFzcz0iYmwtYW5uIiB4PSIyNzAiIHk9IjcyIj5zdHVkeSBzYW1wbGVzPC90ZXh0PjwhLS0gQlFDIG1pZCAtLT48cmVjdCBjbGFzcz0iYmwtYm94IiB4PSIzNzAiIHk9IjIwIiB3aWR0aD0iNDUiIGhlaWdodD0iMzUiIGZpbGw9IiNmMjc1MDciIHN0cm9rZT0iI2IzNTcwMCIgLz48dGV4dCBjbGFzcz0iYmwtdHh0IiB4PSIzOTIiIHk9IjQyIj5CUUM8L3RleHQ+PHRleHQgY2xhc3M9ImJsLWFubiIgeD0iMzkyIiB5PSI3MiI+YW5jaG9yPC90ZXh0PjwhLS0gU1BMIGJsb2NrIDIgLS0+PHJlY3QgY2xhc3M9ImJsLWJveCIgeD0iNDI1IiB5PSIyMCIgd2lkdGg9IjEyMCIgaGVpZ2h0PSIzNSIgZmlsbD0iIzhlOWI5ZSIgc3Ryb2tlPSIjNmY3YzdmIiAvPjx0ZXh0IGNsYXNzPSJibC10eHQiIHg9IjQ4NSIgeT0iNDIiPlNQTCBTUEwgU1BMIFNQTDwvdGV4dD48IS0tIEJRQyBlbmQgLS0+PHJlY3QgY2xhc3M9ImJsLWJveCIgeD0iNTU1IiB5PSIyMCIgd2lkdGg9IjQ1IiBoZWlnaHQ9IjM1IiBmaWxsPSIjZjI3NTA3IiBzdHJva2U9IiNiMzU3MDAiIC8+PHRleHQgY2xhc3M9ImJsLXR4dCIgeD0iNTc3IiB5PSI0MiI+QlFDPC90ZXh0Pjx0ZXh0IGNsYXNzPSJibC1hbm4iIHg9IjU3NyIgeT0iNzIiPmFuY2hvcjwvdGV4dD48IS0tIFNCTEsgZW5kIC0tPjxyZWN0IGNsYXNzPSJibC1ib3giIHg9IjYxMCIgeT0iMjAiIHdpZHRoPSI1MCIgaGVpZ2h0PSIzNSIgZmlsbD0iIzE4NTRmOSIgc3Ryb2tlPSIjMGYzYWI1IiAvPjx0ZXh0IGNsYXNzPSJibC10eHQiIHg9IjYzNSIgeT0iNDIiPlNCTEs8L3RleHQ+PHRleHQgY2xhc3M9ImJsLWFubiIgeD0iNjM1IiB5PSI3MiI+Ymxhbms8L3RleHQ+PCEtLSBBcnJvd3MgLS0+PGxpbmUgeDE9IjU1IiB5MT0iMzciIHgyPSI2NSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSIxMTUiIHkxPSIzNyIgeDI9IjEyNSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSIxNzAiIHkxPSIzNyIgeDI9IjE4MCIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSIzNjAiIHkxPSIzNyIgeDI9IjM3MCIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSI0MTUiIHkxPSIzNyIgeDI9IjQyNSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSI1NDUiIHkxPSIzNyIgeDI9IjU1NSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSI2MDAiIHkxPSIzNyIgeDI9IjYxMCIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjwvc3ZnPg==)

## Colour coding

Each `qc_type` is drawn with a consistent line colour and point shape in
every plot MRMhub produces. The swatches below are the exact line
colours defined in the package (`qc_type_col`).

| Type                         | Colour       |     |
|------------------------------|--------------|-----|
| `SPL`                        | grey         |     |
| `SST`                        | yellow-green |     |
| `BQC`                        | red          |     |
| `TQC`                        | blue         |     |
| `PQC`                        | orange       |     |
| `QC` / `HQC` / `MQC` / `LQC` | dark orange  |     |
| `RQC`                        | periwinkle   |     |
| `CAL`                        | blue         |     |
| `NIST`                       | navy         |     |
| `LTR` / `EQA`                | purple       |     |
| `EQC`                        | brown        |     |
| `SBLK`                       | blue         |     |
| `TBLK`                       | red          |     |
| `UBLK`                       | magenta      |     |
| `PBLK`                       | green        |     |
| `MBLK`                       | black        |     |
| `BLK`                        | grey         |     |

## Next steps

- [Key concepts &
  glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-01-key-concepts.md):
  broader terminology
- [Importing
  metadata](https://slinghub.github.io/MRMhub/quant/articles/manual-05-metadata.md):
  preparing the annotation files
- [Drift and batch
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md):
  where the QC types are used

## References

Broadhurst, David, Royston Goodacre, Stacey N. Reinke, et al. 2018.
“Guidelines and Considerations for the Use of System Suitability and
Quality Control Samples in Mass Spectrometry Assays Applied in
Untargeted Clinical Metabolomic Studies.” *Metabolomics* 14 (6): 72.
<https://doi.org/10.1007/s11306-018-1367-3>.

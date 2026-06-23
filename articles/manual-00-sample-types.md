# Definitions: Sample Types and QC Roles

## Why Sample Types Matter

MRMhub uses the `sample_type` (or `qc_type`) column in your analysis
annotation to determine which samples are used for:

- **Drift correction** — uses QC samples to model signal drift
- **Batch correction** — uses QC samples to align batches
- **QC metrics** — calculates CV, bias from QC replicates
- **Calibration** — uses CAL samples for quantification curves
- **Filtering** — excludes blanks and system suitability from final
  results

**⚠ Critical:** Assigning the wrong label means MRMhub will use the
wrong samples for corrections. Double-check your `sample_type` column
before processing.

## Sample Type Reference

### Study Samples

| Label | Full Name | Role |
|----|----|----|
| `SST` | Study Sample (Test) | Your actual biological/clinical samples. These are the samples you want to quantify. |
| `SPL` | Sample | Generic sample label (same as SST in most workflows) |

### Quality Control Samples

| Label | Full Name | Role |
|----|----|----|
| `QC` | Pooled Quality Control | Generic QC pool — mix of all study samples. Injected regularly to monitor precision. |
| `BQC` | Batch Quality Control | QC pool used for batch-level monitoring. Same meaning as QC in most setups. |
| `TQC` | Technical Quality Control | QC for evaluating technical precision (injected at start/end of batch). |
| `PQC` | Process Quality Control | Undergoes the full sample preparation. Monitors extraction variability. |
| `HQC` | High-concentration QC | QC at high concentration level (for calibration range validation). |
| `MQC` | Mid-concentration QC | QC at mid concentration level. |
| `LQC` | Low-concentration QC | QC at low concentration level (near LOQ). |
| `RQC` | Response QC (dilution series) | Serial dilution of QC pool. Assesses linearity/response curves. |
| `EQC` | External QC | QC material from external provider (e.g., NIST, ring trial). |
| `EQA` | External Quality Assessment | Samples from proficiency testing / ring trials. |
| `NIST` | NIST Reference Material | Standard reference material (e.g., NIST SRM 1950). |
| `LTR` | Long-Term Reference | Aliquots stored long-term; track instrument drift over weeks/months. |

### Blanks

| Label | Full Name | Role |
|----|----|----|
| `SBLK` | Solvent Blank | Pure solvent injection. Detects carry-over and contamination. |
| `TBLK` | Technical Blank | Blank processed through the instrument only (no extraction). |
| `PBLK` | Process Blank | Blank that goes through full sample preparation. Detects extraction contamination. |
| `MBLK` | Method Blank | Similar to PBLK; method-level blank control. |
| `UBLK` | Unknown Blank | Unspecified blank type. |

### Calibration

| Label | Full Name | Role |
|----|----|----|
| `CAL` | Calibration Standard | Known concentration for building calibration curves. Multiple levels (CAL1, CAL2, …) are distinguished by concentration in metadata. |

## Which Samples Are Used Where?

| Processing Step | Uses | Sample Types |
|----|----|----|
| Drift correction (QC-based models) | Signal anchors | QC, BQC |
| Batch correction (centering) | Cross-batch alignment | QC, BQC |
| QC metrics (CV, bias) | Precision monitoring | QC, BQC, TQC, PQC, HQC, MQC, LQC |
| Calibration curves | Quantification | CAL |
| Excluded from study results | Not reported | All blanks, CAL, RQC |

## Setting Sample Types in Your Annotation

Your analysis annotation CSV must have a column called `sample_type` or
`qc_type`:

    analysis_id,sample_type,batch_id,analysis_order
    Inj_001,SBLK,Batch_1,1
    Inj_002,QC,Batch_1,2
    Inj_003,SST,Batch_1,3
    Inj_004,SST,Batch_1,4
    ...
    Inj_010,QC,Batch_1,10
    Inj_080,QC,Batch_1,80
    Inj_081,SBLK,Batch_1,81

**Rules:**

- Labels are **case-sensitive** — use uppercase exactly as shown
- Every analysis must have a `sample_type` assigned
- At least 5 QC injections per batch for reliable drift correction
- QC samples should be evenly distributed across the run

## Typical Batch Layout

![](data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdib3g9IjAgMCA3MDAgOTAiIHN0eWxlPSJtYXgtd2lkdGg6IDcwMHB4OyB3aWR0aDogMTAwJTsgaGVpZ2h0OiBhdXRvOyBmb250LWZhbWlseTogLWFwcGxlLXN5c3RlbSwgQmxpbmtNYWNTeXN0ZW1Gb250LCAmIzM5O1NlZ29lIFVJJiMzOTssIHNhbnMtc2VyaWY7Ij48c3R5bGU+CiAgICAuYmwtYm94IHsgcng6IDQ7IHJ5OiA0OyBzdHJva2Utd2lkdGg6IDEuMjsgfQogICAgLmJsLXR4dCB7IGZvbnQtc2l6ZTogMTBweDsgZm9udC13ZWlnaHQ6IDYwMDsgZmlsbDogI2ZmZjsgdGV4dC1hbmNob3I6IG1pZGRsZTsgfQogICAgLmJsLWFubiB7IGZvbnQtc2l6ZTogOXB4OyBmaWxsOiAjNTU1OyB0ZXh0LWFuY2hvcjogbWlkZGxlOyB9CiAgPC9zdHlsZT4KPCEtLSBTQkxLIC0tPjxyZWN0IGNsYXNzPSJibC1ib3giIHg9IjUiIHk9IjIwIiB3aWR0aD0iNTAiIGhlaWdodD0iMzUiIGZpbGw9IiM0YTkwZDkiIHN0cm9rZT0iIzJjNWY5OSIgLz48dGV4dCBjbGFzcz0iYmwtdHh0IiB4PSIzMCIgeT0iNDIiPlNCTEs8L3RleHQ+PHRleHQgY2xhc3M9ImJsLWFubiIgeD0iMzAiIHk9IjcyIj5ibGFuazwvdGV4dD48IS0tIFRRQyAtLT48cmVjdCBjbGFzcz0iYmwtYm94IiB4PSI2NSIgeT0iMjAiIHdpZHRoPSI1MCIgaGVpZ2h0PSIzNSIgZmlsbD0iIzVhOGFhYSIgc3Ryb2tlPSIjM2E2YThhIiAvPjx0ZXh0IGNsYXNzPSJibC10eHQiIHg9IjkwIiB5PSI0MiI+VFFDPC90ZXh0Pjx0ZXh0IGNsYXNzPSJibC1hbm4iIHg9IjkwIiB5PSI3MiI+dGVjaDwvdGV4dD48IS0tIFFDIC0tPjxyZWN0IGNsYXNzPSJibC1ib3giIHg9IjEyNSIgeT0iMjAiIHdpZHRoPSI0NSIgaGVpZ2h0PSIzNSIgZmlsbD0iI2NjMzMzMyIgc3Ryb2tlPSIjOTkyMjIyIiAvPjx0ZXh0IGNsYXNzPSJibC10eHQiIHg9IjE0NyIgeT0iNDIiPlFDPC90ZXh0Pjx0ZXh0IGNsYXNzPSJibC1hbm4iIHg9IjE0NyIgeT0iNzIiPmFuY2hvcjwvdGV4dD48IS0tIFNTVCBibG9jayAtLT48cmVjdCBjbGFzcz0iYmwtYm94IiB4PSIxODAiIHk9IjIwIiB3aWR0aD0iMTgwIiBoZWlnaHQ9IjM1IiBmaWxsPSIjNjY2IiBzdHJva2U9IiM0NDQiIC8+PHRleHQgY2xhc3M9ImJsLXR4dCIgeD0iMjcwIiB5PSI0MiI+U1NUIFNTVCBTU1QgU1NUIFNTVCBTU1Q8L3RleHQ+PHRleHQgY2xhc3M9ImJsLWFubiIgeD0iMjcwIiB5PSI3MiI+c3R1ZHkgc2FtcGxlczwvdGV4dD48IS0tIFFDIG1pZCAtLT48cmVjdCBjbGFzcz0iYmwtYm94IiB4PSIzNzAiIHk9IjIwIiB3aWR0aD0iNDUiIGhlaWdodD0iMzUiIGZpbGw9IiNjYzMzMzMiIHN0cm9rZT0iIzk5MjIyMiIgLz48dGV4dCBjbGFzcz0iYmwtdHh0IiB4PSIzOTIiIHk9IjQyIj5RQzwvdGV4dD48dGV4dCBjbGFzcz0iYmwtYW5uIiB4PSIzOTIiIHk9IjcyIj5hbmNob3I8L3RleHQ+PCEtLSBTU1QgYmxvY2sgMiAtLT48cmVjdCBjbGFzcz0iYmwtYm94IiB4PSI0MjUiIHk9IjIwIiB3aWR0aD0iMTIwIiBoZWlnaHQ9IjM1IiBmaWxsPSIjNjY2IiBzdHJva2U9IiM0NDQiIC8+PHRleHQgY2xhc3M9ImJsLXR4dCIgeD0iNDg1IiB5PSI0MiI+U1NUIFNTVCBTU1QgU1NUPC90ZXh0PjwhLS0gUUMgZW5kIC0tPjxyZWN0IGNsYXNzPSJibC1ib3giIHg9IjU1NSIgeT0iMjAiIHdpZHRoPSI0NSIgaGVpZ2h0PSIzNSIgZmlsbD0iI2NjMzMzMyIgc3Ryb2tlPSIjOTkyMjIyIiAvPjx0ZXh0IGNsYXNzPSJibC10eHQiIHg9IjU3NyIgeT0iNDIiPlFDPC90ZXh0Pjx0ZXh0IGNsYXNzPSJibC1hbm4iIHg9IjU3NyIgeT0iNzIiPmFuY2hvcjwvdGV4dD48IS0tIFNCTEsgZW5kIC0tPjxyZWN0IGNsYXNzPSJibC1ib3giIHg9IjYxMCIgeT0iMjAiIHdpZHRoPSI1MCIgaGVpZ2h0PSIzNSIgZmlsbD0iIzRhOTBkOSIgc3Ryb2tlPSIjMmM1Zjk5IiAvPjx0ZXh0IGNsYXNzPSJibC10eHQiIHg9IjYzNSIgeT0iNDIiPlNCTEs8L3RleHQ+PHRleHQgY2xhc3M9ImJsLWFubiIgeD0iNjM1IiB5PSI3MiI+Ymxhbms8L3RleHQ+PCEtLSBBcnJvd3MgLS0+PGxpbmUgeDE9IjU1IiB5MT0iMzciIHgyPSI2NSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSIxMTUiIHkxPSIzNyIgeDI9IjEyNSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSIxNzAiIHkxPSIzNyIgeDI9IjE4MCIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSIzNjAiIHkxPSIzNyIgeDI9IjM3MCIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSI0MTUiIHkxPSIzNyIgeDI9IjQyNSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSI1NDUiIHkxPSIzNyIgeDI9IjU1NSIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjxsaW5lIHgxPSI2MDAiIHkxPSIzNyIgeDI9IjYxMCIgeTI9IjM3IiBzdHJva2U9IiM5OTkiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjwvc3ZnPg==)

## Colour Coding

MRMhub uses consistent colours for sample types in all plots:

| Type    | Colour      |     |
|---------|-------------|-----|
| BQC/QC  | Red         |     |
| TQC     | Blue        |     |
| PQC     | Orange      |     |
| LQC/MQC | Dark orange |     |
| HQC     | Green       |     |
| SBLK    | Blue        |     |
| TBLK    | Red         |     |
| SST/SPL | Grey        |     |
| CAL     | Purple      |     |

## Next Steps

- [Key Concepts and
  Glossary](https://slinghub.github.io/MRMhub/quant/articles/manual-00-key-concepts.md)
  — broader terminology
- [Data
  Import](https://slinghub.github.io/MRMhub/quant/articles/manual-05-data-import.md)
  — preparing your annotation files
- [Multi-Batch
  Tutorial](https://slinghub.github.io/MRMhub/quant/articles/tutorial-08-multi-batch.md)
  — see sample types in action

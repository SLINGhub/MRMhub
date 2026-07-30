# Isotopic interference correction

Manual

In class-based targeted assays, the natural M+2 isotopologue of a
lighter species can fall in the transition window of a species two mass
units heavier and inflate its measured area. MRMhub corrects this with
the LICAR method (Gao et al. 2021): for each affected (target) feature
it subtracts a fixed fraction *K* of the interference source’s area,
where *K* is the source’s theoretical M+2 abundance. This is a Type II
correction (overlap between different species); Type I natural-abundance
(MID) correction of a compound’s own isotopes is not performed.

For MRM data the factor is computed at the fragment, not the whole
molecule. Whether the heavy isotope ends up on the product ion or on the
neutral loss changes *K*, so a whole-molecule (MS1) factor does not give
the right value for a fragment transition. Class-based LC-MRM therefore
uses `level = "MRM"`; `level = "MS1"` is reserved for genuine full-scan
data and is not a fallback when a product *m/z* is missing.

The [Isotopic interference correction
tutorial](https://slinghub.github.io/MRMhub/quant/articles/tutorial-11-interference-correction.md)
gives the step-by-step workflow; this page is the concept and label
reference.

## The `mrm_pattern` annotation

Automatic derivation needs one hand-added column, `mrm_pattern`, in the
**Features** sheet of the metadata workbook. It names the lipid class
and the product-ion type, from which
[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
builds the fragment formula; the precursor and product *m/z* and the
polarity come from the imported data or the metadata. Feature names are
parsed with rgoslin, so the usual lipid shorthand is accepted;
fatty-acyl (FA) and sphingoid-base (LCB) patterns additionally need a
chain-resolved name (`PC 16:0_18:1`, `Cer 18:1;O2/16:0`), while a
sum-composition name (`PC 34:1`) suffices for head-group patterns.

| feature_id | feature_class | precursor_mz | product_mz | polarity | mrm_pattern |
|:---|:---|---:|---:|:---|:---|
| PC 34:1 | PC | 760.6 | 184.1 | Pos | PC (Pos) Pro=184.1 |
| SM 34:1;O2 | SM | 703.6 | 184.1 | Pos | SM (Pos) Pro=184.1 |
| Cer 18:1;O2/16:0 | Cer | 538.5 | 264.3 | Pos | Cer (Pos) SphB-2H2O |

The `mrm_pattern` column in the Features metadata sheet (other feature
columns omitted; values illustrative). {.table}

On import the label is validated: an unknown label is an error, and a
label whose class disagrees with the feature name, or a sum-composition
name under an FA/LCB pattern, is a warning. The
[`save_metadata_templates()`](https://slinghub.github.io/MRMhub/quant/reference/save_metadata_templates.md)
workbook offers the labels as a filtered dropdown.

Most lipidomics assays use a handful of classes: the head-group patterns
(`PC (Pos) Pro=184.1`, `SM (Pos) Pro=184.1`, `LPC (Pos) Pro=184.1`,
`PE (Pos) Pre-Pro=141`), the sphingoid-base patterns for ceramides
(`Cer (Pos) SphB-2H2O`, `Hex1Cer (Pos) SphB-2H2O`), and, in negative
mode, the fatty-acyl patterns (`PC (Neg, FA) FA`, `PE (Neg) FA`). Not
every valid label is auto-derived (see the note below the list). The
complete list is at the [end of this page](#mrm-pattern-labels).

## Derivation levels

[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
discovers the overlaps and stores them in `annot_interferences`; the
`level` argument selects how *K* is computed.

|  | `level = "MRM"` | `level = "MS1"` |
|----|----|----|
| Intended data | Class-based LC-MRM (precursor **and** product *m/z*) | Genuine MS1 / full-scan (precursor *m/z* only) |
| Correction basis | Fragment formula (product ion or neutral loss) | Whole-molecule precursor formula |
| Pairing scope | Within an `mrm_pattern` | Within a `feature_class` |
| Applies to | Lipids (needs the class fragment chemistry) | Any compound with a formula |

At the MRM level a head-group transition carries a single overlap. A
fatty-acyl or sphingoid-base transition can carry two at once: one
source whose extra mass sits on the retained product ion, and one on the
neutral loss. The correction subtracts both. Each overlap is one row of
`annot_interferences`, with `overlap_type` `m2_head`, `m2_front`,
`m2_back`, or `ms1_m2`, and `source` `auto` (derived) or `manual`
(declared in the metadata).
[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
warns when MS1 derivation is run on data whose product *m/z* differs
from the precursor, i.e. real MRM transitions.

## Co-elution

The correction subtracts the source’s full area, so it applies only
where the interference source and target peaks co-elute and/or are
co-integrated. The experimental `check_coelution = TRUE` enforces this,
dropping *m/z*-matched pairs that are chromatographically resolved. It
is off by default while the gate is validated.

## Provenance

The factors are theoretical isotope abundances, computed with `enviPat`
2.8 (Loos et al. 2015). The version is pinned to reproduce the published
LICAR values, and
[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
warns when a different version is installed. Derivation is
deterministic, and the derived `annot_interferences` table travels with
the saved object and the report workbook, so the correction is
reproducible from the metadata alone.

## `mrm_pattern` labels

The valid labels follow the original LICAR class list (Gao et al. 2021),
grouped by the product-ion type the transition monitors: head group,
fatty acyl (FA), and sphingoid base (LCB), which MRMhub extends with
neutral-loss and reversed-phase (RPLC) patterns.
[`licar_pattern_choices()`](https://slinghub.github.io/MRMhub/quant/reference/licar_pattern_choices.md)
returns the same list from R.

Automatic derivation covers the head-group, fatty-acyl (FA), and
sphingoid-base (LCB) patterns. Neutral-loss classes (`CE`, `DG`, `TG`)
and cardiolipin FA (`CL`) can be annotated but are not auto-derived at
the MRM level:
[`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
skips them with a warning, and a correction for them must be declared
manually with
[`correct_custom_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_custom_interferences.md).
The RPLC labels and a few placeholder entries (`PC d9`, `MG`) are valid
labels but are not offered in the template dropdown.

## Next steps

- [Isotopic interference correction
  tutorial](https://slinghub.github.io/MRMhub/quant/articles/tutorial-11-interference-correction.md):
  the step-by-step workflow
- [Drift and batch
  correction](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md):
  applied after interference correction
- [The MRMhubExperiment data
  object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.html#feature-variables):
  how `_orig` preserves the raw intensities
- [`calc_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/calc_isotopic_interferences.md)
  ·
  [`correct_isotopic_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_isotopic_interferences.md):
  function reference

## References

Gao, Liang, Shanshan Ji, Bo Burla, Markus R. Wenk, Federico Torta, and
Amaury Cazenave-Gassiot. 2021. “LICAR: An Application for Isotopic
Correction of Targeted Lipidomic Data Acquired with Class-Based
Chromatographic Separations Using Multiple Reaction Monitoring.”
*Analytical Chemistry* 93 (6): 3163–71.
<https://doi.org/10.1021/acs.analchem.0c04565>.

Loos, Martin, Christian Gerber, Frederic Corona, Juliane Hollender, and
Heinz Singer. 2015. “Nontarget Screening with High-Resolution Mass
Spectrometry in the Environment: Ready to Go?” *Environmental Science &
Technology* 49 (3): 1857–65. <https://doi.org/10.1021/es5040179>.

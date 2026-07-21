# Isotopic Interference Correction

Manual

In targeted assays that measure many species of one lipid class under a
shared precursor or product scan, the natural-abundance heavy
isotopologues (chiefly M+2 from two `¹³C`) of a lighter species can fall
into the transition window of a species two mass units heavier. The
heavier species’ measured area is then inflated by a fixed fraction of
the lighter species’ area. MRMhub removes this bias with a
contribution-based subtraction ported from the LICAR method (Gao et al.
2021): for each affected (*victim*) feature it subtracts a proportion
`K` of each *interfering* feature’s area, where `K` is the interferer’s
theoretical M+2 relative abundance.

This page is the conceptual reference for the correction. The
step-by-step workflow — annotating `mrm_pattern`, deriving
relationships, inspecting them, and applying the subtraction — is
covered in the [Interference correction
tutorial](https://slinghub.github.io/MRMhub/quant/articles/tutorial-11-interference-correction.md).

## Two derivation levels, one subtraction engine

Interference relationships are discovered by
[`derive_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/derive_interferences.md)
and stored in the `annot_interferences` slot as a long table of edges
`(feature_id, interference_feature_id, interference_contribution, overlap_type, source)`.
A single engine,
[`correct_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interferences.md),
then applies every edge — auto-derived or manually annotated — in one
pass. Two derivation *levels* feed that engine:

|  | **MRM** (`level = "MRM"`) | **MS1** (`level = "MS1"`) |
|----|----|----|
| Intended data | Class-based LC-MRM (precursor **and** product m/z) | Genuine MS1 / full-scan (precursor m/z only) |
| Correction basis | Fragment-level (front + back) | Whole-molecule precursor formula |
| Overlaps per feature | Up to two (front and back) | One |
| Factor source | Ported LICAR per-class fragment offsets → [`enviPat::isowrap`](https://rdrr.io/pkg/enviPat/man/isowrap.html) M+2 | `mrmhub` native `isopattern` M+2 of the molecular formula |
| Pairing scope | Within an `mrm_pattern` | Within a `feature_class` |
| Chain chemistry | rgoslin-parsed per-chain C / double bonds | Not required (formula only) |

The MRM level is lipid-scoped because it needs the class fragmentation
chemistry; the MS1 level is purely formula-based and therefore extends
to non-lipids. Interferences beyond the reach of either level are
handled through the manual annotation path (see the tutorial).

## Why MRM needs front *and* back

Under class-based separation a victim transition `(m, p)` can be
perturbed by **two different** interferers, each one M+2 lighter at the
precursor. Their M+2 isotopologue reaches the victim’s precursor window,
but they differ in where that +2 sits relative to the product ion:

- a **front** interferer shares the product ion (`ΔQ3 = 0`) — the +2 is
  on the neutral loss;
- a **back** interferer carries the +2 on the product ion itself
  (`ΔQ3 = +2`).

Each contributes its own M+2 factor, so a victim can carry a front edge
and a back edge simultaneously. The engine composes them as
`X − front − back`.

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgNDYwIDI1MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9Im0veiBzY2F0dGVyIG9mIGZyb250IGFuZCBiYWNrIGludGVyZmVyZXJzIG92ZXJsYXBwaW5nIHRoZSB2aWN0aW0gdHJhbnNpdGlvbiI+PGRlZnM+PG1hcmtlciBpZD0iYWgiIG1hcmtlcndpZHRoPSI4IiBtYXJrZXJoZWlnaHQ9IjgiIHJlZng9IjYiIHJlZnk9IjMiIG9yaWVudD0iYXV0byI+PHBhdGggZD0iTTAsMCBMNiwzIEwwLDYgWiIgZmlsbD0iIzJDM0U1MCIgLz48L21hcmtlcj48L2RlZnM+PGxpbmUgeDE9IjU1IiB5MT0iMjA1IiB4Mj0iNDI1IiB5Mj0iMjA1IiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMS4yIj48L2xpbmU+PGxpbmUgeDE9IjU1IiB5MT0iMjA1IiB4Mj0iNTUiIHkyPSIzMCIgc3Ryb2tlPSIjMkMzRTUwIiBzdHJva2Utd2lkdGg9IjEuMiI+PC9saW5lPjx0ZXh0IHg9IjI0MCIgeT0iMjM1IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzJDM0U1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+UTEKcHJlY3Vyc29yIG0veiDihpI8L3RleHQ+PHRleHQgeD0iMjAiIHk9IjEyMCIgZm9udC1mYW1pbHk9InNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTEiIGZpbGw9IiMyQzNFNTAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIHRyYW5zZm9ybT0icm90YXRlKC05MCAyMCAxMjApIj5RMwpwcm9kdWN0IG0veiDihpI8L3RleHQ+PGxpbmUgeDE9IjI1MCIgeTE9IjExMCIgeDI9IjMzMiIgeTI9IjExMCIgc3Ryb2tlPSIjMkMzRTUwIiBzdHJva2Utd2lkdGg9IjEiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgbWFya2VyLWVuZD0idXJsKCNhaCkiPjwvbGluZT48bGluZSB4MT0iMjUyIiB5MT0iMTc4IiB4Mj0iMzMzIiB5Mj0iMTE4IiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiBtYXJrZXItZW5kPSJ1cmwoI2FoKSI+PC9saW5lPjxjaXJjbGUgY3g9IjM0MCIgY3k9IjExMCIgcj0iOCIgZmlsbD0iIzVCOEZBOCIgc3Ryb2tlPSIjMkMzRTUwIiBzdHJva2Utd2lkdGg9IjEuNSI+PC9jaXJjbGU+PGNpcmNsZSBjeD0iMjUwIiBjeT0iMTEwIiByPSI2IiBmaWxsPSIjQzI3MTcxIiBzdHJva2U9IiM5YzRhNGEiIHN0cm9rZS13aWR0aD0iMSI+PC9jaXJjbGU+PGNpcmNsZSBjeD0iMjUwIiBjeT0iMTc4IiByPSI2IiBmaWxsPSIjRDQ5MTRFIiBzdHJva2U9IiM5YTY0MjciIHN0cm9rZS13aWR0aD0iMSI+PC9jaXJjbGU+PHRleHQgeD0iMzUyIiB5PSIxMDciIGZvbnQtZmFtaWx5PSJzYW5zLXNlcmlmIiBmb250LXNpemU9IjExIiBmaWxsPSIjMkMzRTUwIj52aWN0aW0KQiAobSwgcCk8L3RleHQ+PHRleHQgeD0iMTUwIiB5PSIxMDciIGZvbnQtZmFtaWx5PSJzYW5zLXNlcmlmIiBmb250LXNpemU9IjEwIiBmaWxsPSIjOWM0YTRhIj5mcm9udAoobeKIkjIsIHApPC90ZXh0Pjx0ZXh0IHg9IjE1MCIgeT0iMTgyIiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzlhNjQyNyI+YmFjawoobeKIkjIsIHDiiJIyKTwvdGV4dD48dGV4dCB4PSIyOTIiIHk9IjEwMiIgZm9udC1mYW1pbHk9InNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzJDM0U1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+TSsyCsK3IM6UUTM9MDwvdGV4dD48dGV4dCB4PSIzMDAiIHk9IjE1MiIgZm9udC1mYW1pbHk9InNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iOSIgZmlsbD0iIzJDM0U1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+TSsyCsK3IM6UUTM9KzI8L3RleHQ+PC9zdmc+)

## MRM correction is fragment-based — MS1 is not a fallback

**MS1 is never a substitute for MRM correction.** For MRM data the
isotopic correction must be *fragment-based*: the contribution of a
heavy isotope to a transition depends on whether that isotope ends up on
the retained product ion or on the neutral loss (Gao et al. 2021). The
whole-molecule (`level = "MS1"`) factor ignores that split and is valid
**only** for genuine MS1 / full-scan measurements. It must **not** be
used for MRM data that merely happens to lack a recorded product m/z —
use `level = "MRM"` (and supply the product m/z) there.
[`derive_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/derive_interferences.md)
warns when MS1 derivation is run on data that carry product m/z.

Because the front and back fragments carry different numbers of carbons,
their M+2 abundances differ, and a single precursor-level factor would
be wrong for at least one of the two overlaps. This is the core reason
the MRM level reproduces the class fragment chemistry rather than
falling back to the molecular formula.

## Co-elution decides validity

An M+2 isotopologue elutes at the monoisotopic apex of its own species.
An m/z match between a lighter interferer and a heavier victim is
therefore a real interference **only if the two co-elute**: the
correction subtracts `K ×` the interferer’s *full* area, so it is
justified only when the victim’s integration window captures essentially
all of that interferer’s M+2 peak.

![](data:image/svg+xml;base64,PHN2ZyB2aWV3Ym94PSIwIDAgNzIwIDIxMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiByb2xlPSJpbWciIGFyaWEtbGFiZWw9InRocmVlIGNocm9tYXRvZ3JhbSBwYW5lbHM6IGNvLWVsdXRpbmcgdmFsaWQsIHBhcnRpYWwgb3ZlcmxhcCBvdmVyLXN1YnRyYWN0cywgcmVzb2x2ZWQgZG8gbm90IGNvcnJlY3QiPjxyZWN0IHg9Ijc1IiB5PSI1NSIgd2lkdGg9IjgwIiBoZWlnaHQ9IjExMCIgZmlsbD0iIzJDM0U1MCIgb3BhY2l0eT0iMC4wNSIgLz48bGluZSB4MT0iNzUiIHkxPSI1NSIgeDI9Ijc1IiB5Mj0iMTY1IiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiBvcGFjaXR5PSIwLjYiPjwvbGluZT48bGluZSB4MT0iMTU1IiB5MT0iNTUiIHgyPSIxNTUiIHkyPSIxNjUiIHN0cm9rZT0iIzJDM0U1MCIgc3Ryb2tlLXdpZHRoPSIxIiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIG9wYWNpdHk9IjAuNiI+PC9saW5lPjxwYXRoIGQ9Ik03MCAxNjUgQzk0Ljc1IDE2NSA5Mi41IDY1IDExNSA2NSBDMTM3LjUgNjUgMTM1LjI1IDE2NSAxNjAgMTY1IFoiIGZpbGw9IiM1QjhGQTgiIGZpbGwtb3BhY2l0eT0iMC4zIiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMS41IiAvPjxwYXRoIGQ9Ik03MCAxNjUgQzk0Ljc1IDE2NSA5Mi41IDEyMyAxMTUgMTIzIEMxMzcuNSAxMjMgMTM1LjI1IDE2NSAxNjAgMTY1IFoiIGZpbGw9IiNDMjcxNzEiIGZpbGwtb3BhY2l0eT0iMC41NSIgc3Ryb2tlPSIjOWM0YTRhIiBzdHJva2Utd2lkdGg9IjEiIC8+PGxpbmUgeDE9IjE1IiB5MT0iMTY1IiB4Mj0iMjI1IiB5Mj0iMTY1IiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMSI+PC9saW5lPjx0ZXh0IHg9IjEyMCIgeT0iMzAiIGZvbnQtZmFtaWx5PSJzYW5zLXNlcmlmIiBmb250LXNpemU9IjEyIiBmaWxsPSIjMkMzRTUwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmb250LXdlaWdodD0iYm9sZCI+Q28tZWx1dGluZzwvdGV4dD48dGV4dCB4PSIxMjAiIHk9IjQ2IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzJDM0U1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+YXBleGVzCmNvaW5jaWRlPC90ZXh0Pjx0ZXh0IHg9IjEyMCIgeT0iMTg4IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMSIgZmlsbD0iIzZCOUU1RSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9ImJvbGQiPuKckwpjb3JyZWN0IChmdWxsIEvCt0EpPC90ZXh0PjxyZWN0IHg9IjMyMCIgeT0iNTUiIHdpZHRoPSI4MCIgaGVpZ2h0PSIxMTAiIGZpbGw9IiMyQzNFNTAiIG9wYWNpdHk9IjAuMDUiIC8+PGxpbmUgeDE9IjMyMCIgeTE9IjU1IiB4Mj0iMzIwIiB5Mj0iMTY1IiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiBvcGFjaXR5PSIwLjYiPjwvbGluZT48bGluZSB4MT0iNDAwIiB5MT0iNTUiIHgyPSI0MDAiIHkyPSIxNjUiIHN0cm9rZT0iIzJDM0U1MCIgc3Ryb2tlLXdpZHRoPSIxIiBzdHJva2UtZGFzaGFycmF5PSI0IDMiIG9wYWNpdHk9IjAuNiI+PC9saW5lPjxwYXRoIGQ9Ik0zMTUgMTY1IEMzMzkuNzUgMTY1IDMzNy41IDY1IDM2MCA2NSBDMzgyLjUgNjUgMzgwLjI1IDE2NSA0MDUgMTY1IFoiIGZpbGw9IiM1QjhGQTgiIGZpbGwtb3BhY2l0eT0iMC4zIiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMS41IiAvPjxwYXRoIGQ9Ik0yNzMgMTY1IEMyOTcuNzUgMTY1IDI5NS41IDExMyAzMTggMTEzIEMzNDAuNSAxMTMgMzM4LjI1IDE2NSAzNjMgMTY1IFoiIGZpbGw9IiNDMjcxNzEiIGZpbGwtb3BhY2l0eT0iMC41NSIgc3Ryb2tlPSIjOWM0YTRhIiBzdHJva2Utd2lkdGg9IjEiIC8+PGxpbmUgeDE9IjI1NSIgeTE9IjE2NSIgeDI9IjQ2NSIgeTI9IjE2NSIgc3Ryb2tlPSIjMkMzRTUwIiBzdHJva2Utd2lkdGg9IjEiPjwvbGluZT48dGV4dCB4PSIzNjAiIHk9IjMwIiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMiIgZmlsbD0iIzJDM0U1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9ImJvbGQiPlBhcnRpYWwKLyBhcGV4IG9mZnNldDwvdGV4dD48dGV4dCB4PSIzNjAiIHk9IjQ2IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzJDM0U1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+d2luZG93CmNhdGNoZXMgb25seSBB4oCZcyB0YWlsPC90ZXh0Pjx0ZXh0IHg9IjM2MCIgeT0iMTg4IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMSIgZmlsbD0iI0MyNzE3MSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9ImJvbGQiPuKaoApvdmVyLXN1YnRyYWN0cyDihpIgZHJvcDwvdGV4dD48cmVjdCB4PSI1NzUiIHk9IjU1IiB3aWR0aD0iODAiIGhlaWdodD0iMTEwIiBmaWxsPSIjMkMzRTUwIiBvcGFjaXR5PSIwLjA1IiAvPjxsaW5lIHgxPSI1NzUiIHkxPSI1NSIgeDI9IjU3NSIgeTI9IjE2NSIgc3Ryb2tlPSIjMkMzRTUwIiBzdHJva2Utd2lkdGg9IjEiIHN0cm9rZS1kYXNoYXJyYXk9IjQgMyIgb3BhY2l0eT0iMC42Ij48L2xpbmU+PGxpbmUgeDE9IjY1NSIgeTE9IjU1IiB4Mj0iNjU1IiB5Mj0iMTY1IiBzdHJva2U9IiMyQzNFNTAiIHN0cm9rZS13aWR0aD0iMSIgc3Ryb2tlLWRhc2hhcnJheT0iNCAzIiBvcGFjaXR5PSIwLjYiPjwvbGluZT48cGF0aCBkPSJNNTczIDE2NSBDNTk2LjEgMTY1IDU5NCA2NSA2MTUgNjUgQzYzNiA2NSA2MzMuOSAxNjUgNjU3IDE2NSBaIiBmaWxsPSIjNUI4RkE4IiBmaWxsLW9wYWNpdHk9IjAuMyIgc3Ryb2tlPSIjMkMzRTUwIiBzdHJva2Utd2lkdGg9IjEuNSIgLz48cGF0aCBkPSJNNDk3IDE2NSBDNTE5LjkgMTY1IDUxNyAxMTMgNTM1IDExMyBDNTUzIDExMyA1NTAuMSAxNjUgNTczIDE2NSBaIiBmaWxsPSIjQzI3MTcxIiBmaWxsLW9wYWNpdHk9IjAuNTUiIHN0cm9rZT0iIzljNGE0YSIgc3Ryb2tlLXdpZHRoPSIxIiAvPjxsaW5lIHgxPSI0OTUiIHkxPSIxNjUiIHgyPSI3MDUiIHkyPSIxNjUiIHN0cm9rZT0iIzJDM0U1MCIgc3Ryb2tlLXdpZHRoPSIxIj48L2xpbmU+PHRleHQgeD0iNjAwIiB5PSIzMCIgZm9udC1mYW1pbHk9InNhbnMtc2VyaWYiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiMyQzNFNTAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZvbnQtd2VpZ2h0PSJib2xkIj5SZXNvbHZlZDwvdGV4dD48dGV4dCB4PSI2MDAiIHk9IjQ2IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMCIgZmlsbD0iIzJDM0U1MCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+QeKAmXMKTSsyIG91dHNpZGUgd2luZG93PC90ZXh0Pjx0ZXh0IHg9IjYwMCIgeT0iMTg4IiBmb250LWZhbWlseT0ic2Fucy1zZXJpZiIgZm9udC1zaXplPSIxMSIgZmlsbD0iI0MyNzE3MSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZm9udC13ZWlnaHQ9ImJvbGQiPuKclwpkb27igJl0IGNvcnJlY3Q8L3RleHQ+PC9zdmc+)

*Blue = victim peak; rose = the interferer’s M+2 contribution; dashed =
the victim integration window.*

The co-elution gate (`check_coelution = TRUE`, the default when
retention data are present) keeps an edge only when the interferer’s
apex falls inside the victim’s integration window
(`feature_int_start`..`feature_int_end`, from the imported integration
borders, or `feature_rt ± FWHM` where borders are absent).
Chromatographically resolved pairs are dropped and reported, because
subtracting a full `K·A` there would delete real victim signal. Border
overlap alone is necessary but not sufficient — apex coincidence is the
test. When no retention data are available the gate cannot be evaluated,
a warning is emitted, and all m/z-matched edges are kept. This gate is a
deliberate enhancement over LICAR, which assumes class co-elution with
no per-pair retention check.

## Provenance and reproducibility

The derived factors are theoretical isotope abundances and depend on the
abundance engine:

- **MRM** uses LICAR’s
  [`enviPat::isowrap`](https://rdrr.io/pkg/enviPat/man/isowrap.html)
  centroided M+2 (`resolution_list[[7]]`, `charge = 1`), which
  reproduces the published LICAR factors; the native `isopattern`
  differs by ~0.4 % and is not used at this level.
- **MS1** uses `mrmhub`’s native `isopattern` M+2 of the molecular
  formula, appropriate for a full-scan measurement.

Both engines are pinned to **`enviPat` version 2.8** (Loos et al. 2015),
the reference used for the golden parity tests;
[`derive_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/derive_interferences.md)
warns when a different version is installed. Because derivation is
deterministic under that pin, re-importing the `mrm_pattern` annotation
and re-running
[`derive_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/derive_interferences.md)
regenerates identical edges — the metadata alone reproduces the
correction. The exact factors additionally survive an `enviPat` upgrade
because the derived `annot_interferences` table travels with the saved
object and is written to the report workbook as a human-readable factor
archive.

Only the LICAR *data* — the per-class fragment offsets and the pattern
labels — is vendored; the abundance calculation, name parsing (rgoslin),
and subtraction are `mrmhub`’s own. This correction is distinct from
`¹³C`/`¹⁵N` natural-abundance metabolic-flux (MID) correction, which
MRMhub does not perform.

## Next steps

- [Interference
  correction](https://slinghub.github.io/MRMhub/quant/articles/tutorial-11-interference-correction.md)
  — the step-by-step workflow
- [Drift and Batch
  Correction](https://slinghub.github.io/MRMhub/quant/articles/manual-07-corrections.md)
  — apply after interference correction
- [The MRMhubExperiment Data
  Object](https://slinghub.github.io/MRMhub/quant/articles/manual-02-data-object.html#feature-variables)
  — how `_orig` postfixes preserve raw values
- [`derive_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/derive_interferences.md)
  ·
  [`correct_interferences()`](https://slinghub.github.io/MRMhub/quant/reference/correct_interferences.md)
  — function reference

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

# Plot highly correlated feature pairs

Creates scatter plots for pairs of features that have correlations
outside specified thresholds. Each pair is displayed in a separate facet
with its correlation coefficient.

This plot can be used to visually inspect highly correlated features,
that may represent duplicate identifications or represent isomers.

## Usage

``` r
plot_feature_correlations(
  data,
  variable,
  qc_types = NA,
  cor_min,
  cor_min_neg = -0.99,
  log_scale = FALSE,
  sort_by_corr = TRUE,
  filter_data = FALSE,
  include_qualifier = FALSE,
  include_istd = FALSE,
  include_feature_filter = NA,
  exclude_feature_filter = NA,
  min_median_value = NA,
  output_pdf = FALSE,
  path = NA,
  create_dir = TRUE,
  return_plots = FALSE,
  rows_page = 4,
  cols_page = 5,
  specific_page = NA,
  page_orientation = "LANDSCAPE",
  page_width = NULL,
  page_height = NULL,
  page_units = "mm",
  point_size = NULL,
  point_alpha = 0.8,
  point_stroke = 0.3,
  line_width = 0.5,
  line_color = "orange",
  line_alpha = 0.5,
  font_base_size = NULL,
  show_progress = TRUE
)
```

## Arguments

- data:

  A `MRMhubExperiment` object.

- variable:

  A character string indicating the signal variable to plot. Must be one
  of: "area", "height", "intensity", "norm_intensity", "response",
  "conc", "conc_raw", "rt", "fwhm".

- qc_types:

  A character vector specifying the QC types to plot. It must contain at
  least one element. The default `NA` plots any of the non-blank QC
  types ("SPL", "TQC", "BQC", "HQC", "MQC", "LQC", "NIST", "LTR")
  present in the dataset.

- cor_min:

  Numeric. Minimum correlation threshold. Only feature pairs with
  positive correlations above this value will be shown. Set to Inf to
  exclude positive correlations.

- cor_min_neg:

  Numeric. Minimum negative correlation threshold. Only feature pairs
  with negative correlations above this value will be shown. Set to -Inf
  to exclude negative correlations.

- log_scale:

  A logical value indicating whether to use a log10 scale for both axes.
  Default is `FALSE`.

- sort_by_corr:

  A logical value indicating whether to sort the features in the plot by
  correlation or alphabetically by feature ID. Default is `TRUE`.

- filter_data:

  A logical value indicating whether to use all data (default) or only
  QC-filtered data (filtered via
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md)).

- include_qualifier:

  A logical value indicating whether to include qualifier features.
  Default is `TRUE`.

- include_istd:

  A logical value indicating whether to include internal standard (ISTD)
  features. Default is `TRUE`.

- include_feature_filter:

  Feature(s) to include by `feature_id`, as a character vector. Each
  element is matched exactly when it names an existing feature,
  otherwise treated as a regex; elements combine with OR. A full ID
  (e.g. `"S1P d18:0 [M>60]"`) needs no escaping, while patterns like
  `"PC|PE"` still work. `NA` or `""` ignores the filter.

- exclude_feature_filter:

  Feature(s) to exclude by `feature_id`, matched the same way as
  `include_feature_filter`. `NA` or `""` ignores the filter.

- min_median_value:

  Minimum median feature value across the selected QC-type samples
  required for a feature to be included. `NA` (default) applies no
  filtering. This is a fast way to exclude noisy features; for
  principled QC-based filtering use
  [`filter_features_qc()`](https://slinghub.github.io/MRMhub/quant/reference/filter_features_qc.md).

- output_pdf:

  If `TRUE`, saves the generated plots as a PDF file. When `FALSE`,
  plots are directly plotted.

- path:

  The file path for saving the PDF. Must be defined if `output_pdf` is
  `TRUE`.

- create_dir:

  A logical value. If `TRUE` (the default) and `output_pdf` is `TRUE`,
  the parent directory of `path` is created if it does not yet exist.

- return_plots:

  Logical. If `TRUE`, returns the plots as a list of `ggplot` objects.

- rows_page:

  Number of rows of plots per page.

- cols_page:

  Number of columns of plots per page.

- specific_page:

  An integer specifying a specific page to plot. If `NA` (default), all
  pages are plotted.

- page_orientation:

  Orientation of the PDF paper: `"LANDSCAPE"` or `"PORTRAIT"`. Ignored
  when `page_width` and `page_height` are given.

- page_width, page_height:

  Size of a PDF page, in `page_units`. Both must be given together.
  `NULL` (default) uses an A4 page of 280 x 200 mm, oriented by
  `page_orientation`. When an explicit size is given, `page_orientation`
  has no effect.

- page_units:

  Unit of `page_width` and `page_height`: `"mm"` (default), `"cm"`,
  `"in"` or `"pt"`.

- point_size:

  A numeric value indicating the size of points in millimeters. Default
  is 1.

- point_alpha:

  A numeric value indicating the transparency of points (0-1). Default
  is 0.8.

- point_stroke:

  A numeric value indicating the stroke width of the points. Default is
  0.3.

- line_width:

  A numeric value indicating the size of the correlation line. Default
  is 0.5.

- line_color:

  A character string indicating the color of the correlation line.
  Default is orange.

- line_alpha:

  A numeric value indicating the transparency of the correlation line
  (0-1). Default is 0.5.

- font_base_size:

  Numeric. Base font size (in points) for plot text; all plot text
  scales proportionally with this value. `NULL` (default) uses the
  global default set by
  [`mrmhub_set_plot_defaults()`](https://slinghub.github.io/MRMhub/quant/reference/mrmhub_set_plot_defaults.md)
  if one is in effect, otherwise an automatic size (derived from the
  facet-column count on paged plots, or the per-plot default shown in
  the Usage section above).

- show_progress:

  Logical. If `TRUE`, displays a progress bar during plot creation.

## Value

A `ggplot` object showing scatter plots of highly correlated feature
pairs. Returns `NULL` if no correlations meet the threshold criteria.

## Preferred formats and devices

|  |  |  |  |
|----|----|----|----|
| Purpose | Format | Device used | Typical `dpi` |
| Journal figure, vector (default choice) | `"pdf"` | [`grDevices::cairo_pdf`](https://rdrr.io/r/grDevices/cairo.html), else [`grDevices::pdf`](https://rdrr.io/r/grDevices/pdf.html) | n/a |
| Figure for further editing (Illustrator, Inkscape) | `"svg"` | [`svglite::svglite`](https://svglite.r-lib.org/reference/svglite.html), else [`grDevices::svg`](https://rdrr.io/r/grDevices/cairo.html) | n/a |
| Slides, Quarto HTML, GitHub | `"png"` | [`ragg::agg_png`](https://ragg.r-lib.org/reference/agg_png.html), else [`grDevices::png`](https://rdrr.io/r/grDevices/png.html) | 150-300 |
| Journal requiring raster submission | `"tiff"` | [`ragg::agg_tiff`](https://ragg.r-lib.org/reference/agg_tiff.html), else [`grDevices::tiff`](https://rdrr.io/r/grDevices/png.html) | 300-600 |

Prefer a **vector** format (`pdf`, `svg`) for publication: text stays
selectable and searchable, and lines stay sharp at any magnification.

Prefer a **raster** format (`png`, `tiff`) when a plot draws very many
marks – a
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md)
page covering several thousand analyses, or a dense
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md)
score plot. Every point becomes a separate object in a PDF, so such
figures produce very large files that are slow to open and to typeset.
Saving them at 300-600 dpi instead keeps the file small with no visible
loss.

The optional packages `ragg` and `svglite` are used automatically when
installed, giving better text rendering, system-font support and smaller
SVG files. When they are absent the equivalent `grDevices` device is
used and the output is still correct. Installing both is recommended:
`install.packages(c("ragg", "svglite"))`.

PDF output uses the cairo device wherever R was built with cairo support
(`capabilities("cairo")`), because plain
[`grDevices::pdf()`](https://rdrr.io/r/grDevices/pdf.html) writes text
in a single-byte encoding and silently transliterates anything outside
it – an en dash becomes `-`, `>=` replaces the proper symbol. Unit
labels such as `umol/L` and statistical annotations routinely depend on
those glyphs.

Multi-page output from the paged plot functions
([`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_calibrationcurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_calibrationcurves.md),
[`plot_responsecurves()`](https://slinghub.github.io/MRMhub/quant/reference/plot_responsecurves.md),
`plot_feature_correlations()`) is PDF only, which is the only format
that holds many pages in one file. Use
[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
for single figures in any of the other formats.

## See also

[`save_plot()`](https://slinghub.github.io/MRMhub/quant/reference/save_plot.md)
to save a single figure in any format.

Other QC plots:
[`plot_interference_correction()`](https://slinghub.github.io/MRMhub/quant/reference/plot_interference_correction.md),
[`plot_matrixeffects()`](https://slinghub.github.io/MRMhub/quant/reference/plot_matrixeffects.md),
[`plot_normalization_qc()`](https://slinghub.github.io/MRMhub/quant/reference/plot_normalization_qc.md),
[`plot_pca()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca.md),
[`plot_pca_loading()`](https://slinghub.github.io/MRMhub/quant/reference/plot_pca_loading.md),
[`plot_qc_interference_impact()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_interference_impact.md),
[`plot_qc_summary_byclass()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_byclass.md),
[`plot_qc_summary_overall()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qc_summary_overall.md),
[`plot_qcmetrics_comparison()`](https://slinghub.github.io/MRMhub/quant/reference/plot_qcmetrics_comparison.md),
[`plot_rla_boxplot()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rla_boxplot.md),
[`plot_rt_vs_chain()`](https://slinghub.github.io/MRMhub/quant/reference/plot_rt_vs_chain.md),
[`plot_runscatter()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runscatter.md),
[`plot_runsequence()`](https://slinghub.github.io/MRMhub/quant/reference/plot_runsequence.md)

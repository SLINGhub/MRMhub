# RunSequence Plot

The RunSequence plot provides an overview of the analysis design and
timelines, which can be useful for subsequent processing steps. The plot
illustrates the batch structure, the quality control (QC) samples
included with their respective positions, and additional information
regarding the date, duration, and run time of the analysis.

Setting `show_timestamp = TRUE` allows you to check for any
interruptions in the analysis timeline.

## Usage

``` r
plot_runsequence(
  data = NULL,
  qc_types = NA,
  show_batches = TRUE,
  show_timestamp = FALSE,
  add_info_title = TRUE,
  single_row = FALSE,
  segment_linewidth = 0.5,
  batch_zebra_stripe = FALSE,
  batch_line_color = "#b6f0c5",
  batch_fill_color = "grey90",
  base_font_size = 8
)
```

## Arguments

- data:

  MRMhubExperiment object

- qc_types:

  QC types to be plotted. Can be a vector of QC types or a regular
  expression pattern. `NA` (default) displays all available QC/Sample
  types.

- show_batches:

  Logical, whether to show batch separators in the plot.

- show_timestamp:

  Logical, whether to use the acquisition timestamp as the x-axis
  instead of the run sequence number.

- add_info_title:

  Logical, whether to add a title with the experiment title, analysis
  date, and analysis times.

- single_row:

  Logical, whether to show all QC types in a single row.

- segment_linewidth:

  Width of the segment lines, default is 0.5.

- batch_zebra_stripe:

  Logical, whether to show batches as shaded areas instead of line
  separators.

- batch_line_color:

  Color of the batch separator lines.

- batch_fill_color:

  Color of the batch shaded areas.

- base_font_size:

  Numeric, base font size for the plot.

## Value

A ggplot object representing the run sequence plot.

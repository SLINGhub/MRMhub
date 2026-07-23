# Set default variable to be used as feature raw signal value

Sets the raw signal variable used for calculations starting from raw
signal values (i.e., normalization) Note that this set variable must be
part of the orginally imported data. Processed data variables (e.g.,
normalized intensities and concentrations) can not be set as default
feature intensity variable.

## Usage

``` r
set_intensity_var(
  data = NULL,
  variable_name,
  auto_select = FALSE,
  warnings = TRUE,
  ...
)
```

## Arguments

- data:

  [`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
  object

- variable_name:

  Feature variable to be used as default feature intensity for
  downstream processing.

- auto_select:

  If `TRUE` then the first available of these will be used as default:
  "intensity", "response", "area", "height".

- warnings:

  Suppress warnings

- ...:

  Feature variables to search for one-by-one when `auto_select = TRUE`

## Value

[`MRMhubExperiment`](https://slinghub.github.io/MRMhub/quant/reference/MRMhubExperiment-class.md)
object

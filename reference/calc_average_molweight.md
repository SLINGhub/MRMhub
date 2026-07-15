# Calculate Average Molecular Weight from Chemical Formulas

Calculates the average molecular weight of one or more chemical
formulas, based on the natural isotopic distribution of elements. The
calculation uses the enviPat package to retrieve isotopic masses and
abundances, and computes the weighted mean of the isotopic distribution.

## Usage

``` r
calc_average_molweight(formula)
```

## Arguments

- formula:

  A character vector of one or more chemical formulas to process.

## Value

A numeric vector of average molecular weights, one for each formula.

## Details

This function calculates the *average molecular weight* (not
monoisotopic mass), which reflects the average of the isotopic
distribution found in nature.

Isotopes can be specified explicitly in the formula. Atomic mass numbers
for isotopes must be enclosed in square brackets (e.g., `[13]C` for
carbon-13). Deuterium must be written as `D` instead of `[3]H`.

The function uses the enviPat package to validate and parse chemical
formulas, calculate isotopic patterns, and determine the average
molecular weight based on weighted means of isotopic abundances.

## References

Loos, M., Gerber, C., Corona, F., Hollender, J., & Singer, H. (2015).
Accelerated Isotope Fine Structure Calculation Using Pruned Transition
Trees. *Analytical Chemistry*, 87(11), 5738–5744.
[doi:10.1021/acs.analchem.5b00941](https://doi.org/10.1021/acs.analchem.5b00941)

## Examples

``` r
calc_average_molweight(c("C6H12O6", "[13]C6H12O6", "C8H10N4O2", "D2O"))
#> NOTE: You are sure that is the mass of an electrone?
#> [1] 180.15613 186.11184 194.19090  20.02761
```

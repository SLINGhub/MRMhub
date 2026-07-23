# Reorder a data frame based on a chain of linked values in two columns

This function orders rows of a data frame based on chained relationships
defined by two columns. It can also handle fully disconnected rows
(i.e., rows where both `From` and `To` values are not present in other
rows). The behavior for disconnected rows is controlled via the
`disconnected_action` parameter.

## Usage

``` r
order_chained_columns_tbl(
  df,
  from_col,
  to_col,
  include_chain_id,
  disconnected_action = "keep"
)
```

## Arguments

- df:

  A data frame containing the chain relationships.

- from_col:

  A string specifying the column name representing the starting point of
  the chain.

- to_col:

  A string specifying the column name representing the endpoint of the
  chain.

- include_chain_id:

  A logical indicating whether to include a `chain_id` column in the
  output.

- disconnected_action:

  A string indicating how to handle fully disconnected rows. Options
  are:

  "exclude"

  :   Exclude disconnected rows from the output.

  "keep"

  :   Keep disconnected rows in the result.

## Value

A data frame containing ordered chains. If `include_chain_id = TRUE`, a
`chain_id` column is added to distinguish between different chains; when
disconnected rows are included, they will have their own `chain_id`.

## Examples

``` r
df_unordered <- data.frame(
  From = c("INSPECT", "VERIFY", "START", "NULL", "NEW", "CREATE", "MID", "DIFFERENT", "OUTLIER"),
  To = c("VERIFY", "PUBLISH", "MID", "NEW", "CREATE", "INSPECT", "END", "NOTSAME", "INSIDER"),
stringsAsFactors = FALSE
)

# Order keeping disconnected rows
order_chained_columns_tbl(df_unordered, "From", "To", FALSE, "keep")
#>        From      To
#> 8     START     MID
#> 4       MID     END
#> 6      NULL     NEW
#> 5       NEW  CREATE
#> 1    CREATE INSPECT
#> 3   INSPECT  VERIFY
#> 9    VERIFY PUBLISH
#> 2 DIFFERENT NOTSAME
#> 7   OUTLIER INSIDER

# Order excluding disconnected rows
order_chained_columns_tbl(df_unordered, "From", "To", FALSE, "exclude")
#>      From      To
#> 6   START     MID
#> 3     MID     END
#> 5    NULL     NEW
#> 4     NEW  CREATE
#> 1  CREATE INSPECT
#> 2 INSPECT  VERIFY
#> 7  VERIFY PUBLISH

```

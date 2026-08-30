# check_pkg_installed() never prompts, also in interactive sessions

    Code
      check_pkg_installed(c("mrmhubnotapackage", "mrmhubalsonotapackage"), reason = "to run this example.")
    Condition
      Error:
      ! The packages mrmhubnotapackage and mrmhubalsonotapackage are required to run this example.
      i Install with `install.packages(c("mrmhubnotapackage", "mrmhubalsonotapackage"))`


# parse_masshunter_csv() output is stable across all valid fixtures

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 1_Testdata_MHQuant_DefaultSampleInfo_AreaOnly.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 10 x 5
         column                 class           n_na n_distinct  num_sum
         <chr>                  <chr>          <int>      <int>    <dbl>
       1 analysis_id            character          0         65       NA
       2 file_analysis_order    integer            0         65    34320
       3 raw_data_filename      character          0         65       NA
       4 sample_name            character          0         65       NA
       5 sample_type            character          0          1       NA
       6 sample_level           character          0          1       NA
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA
       8 feature_id             character          0         16       NA
       9 integration_qualifier  logical            0          1       NA
      10 feature_area           numeric           19        978 17599226

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 3_Testdata_MHQuant_DefaultSampleInfo_DetailedResults.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 19 x 5
         column                     class           n_na n_distinct    num_sum
         <chr>                      <chr>          <int>      <int>      <dbl>
       1 analysis_id                character          0         65       NA  
       2 file_analysis_order        integer            0         65    34320  
       3 raw_data_filename          character          0         65       NA  
       4 sample_name                character          0         65       NA  
       5 sample_type                character          0          1       NA  
       6 sample_level               character          0          1       NA  
       7 acquisition_time_stamp     POSIXct/POSIXt     0         65       NA  
       8 feature_id                 character          0         16       NA  
       9 integration_qualifier      logical            0          1       NA  
      10 feature_rt                 numeric           19         79     3473. 
      11 feature_area               numeric           19        978 17599226  
      12 feature_fwhm               numeric           19         97       62.9
      13 feature_height             numeric           19        873  5016036  
      14 feature_int_start          numeric           19        125     3392. 
      15 feature_int_end            numeric           19        134     3584. 
      16 feature_sn_ratio           numeric           19        903    44657. 
      17 feature_symmetry           numeric           19        169     1178. 
      18 feature_width              numeric           19         41      192. 
      19 feature_manual_integration logical            0          2       NA  

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 4_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM_DetailedMethods.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 31 x 5
         column                               class           n_na n_distinct
         <chr>                                <chr>          <int>      <int>
       1 analysis_id                          character          0         65
       2 file_analysis_order                  integer            0         65
       3 raw_data_filename                    character          0         65
       4 sample_name                          character          0         65
       5 sample_type                          character          0          1
       6 sample_level                         character          0          1
       7 acquisition_time_stamp               POSIXct/POSIXt     0         65
       8 feature_id                           character          0         16
       9 integration_qualifier                logical            0          1
      10 method_compound_group                character          0          1
      11 method_collision_energy              numeric            0          1
      12 method_fragmentor                    numeric            0          1
      13 method_compound_id                   character          0          1
      14 method_integration_method            character          0          1
      15 method_integration_parameters        character          0          1
      16 method_polarity                      factor             0          1
      17 method_ion_source                    character          0          1
      18 method_multiplier                    numeric            0          1
      19 method_noise_algorithm               character          0          1
      20 method_noise_raw_signal              numeric            0       1010
      21 method_precursor_mz                  numeric            0          8
      22 method_product_mz                    numeric            0          2
      23 method_peak_smoothing                character          0          1
      24 method_peak_smoothing_gauss_width    character          0          1
      25 method_peak_smoothing_function_width character          0          1
      26 method_transition                    character          0         16
      27 method_time_segment                  integer            0          1
      28 method_type                          character          0          1
      29 feature_rt                           numeric           19         79
      30 feature_area                         numeric           19        978
      31 feature_fwhm                         numeric           19         97
            num_sum
              <dbl>
       1       NA  
       2    34320  
       3       NA  
       4       NA  
       5       NA  
       6       NA  
       7       NA  
       8       NA  
       9       NA  
      10       NA  
      11    30160  
      12   395200  
      13       NA  
      14       NA  
      15       NA  
      16       NA  
      17       NA  
      18     1040  
      19       NA  
      20   110532. 
      21   454298  
      22    90012  
      23       NA  
      24       NA  
      25       NA  
      26       NA  
      27     1040  
      28       NA  
      29     3473. 
      30 17599226  
      31       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 5_Testdata_MHQuant_DetailedSampleInfo-RT-Areas-FWHM.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 22 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_group           character          0          9       NA  
       6 sample_type            character          0          1       NA  
       7 sample_level           character          0          1       NA  
       8 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       9 inj_volume             numeric            0          1     1040  
      10 comment                character          0          1       NA  
      11 completed              character          0          1       NA  
      12 dilution_factor        character          0          1       NA  
      13 instrument_name        character          0          1       NA  
      14 instrument_type        character          0          1       NA  
      15 acq_method_file        character          0          1       NA  
      16 acq_method_path        character          0          1       NA  
      17 data_file_path         character          0          1       NA  
      18 feature_id             character          0         16       NA  
      19 integration_qualifier  logical            0          1       NA  
      20 feature_rt             numeric           19         79     3473. 
      21 feature_area           numeric           19        978 17599226  
      22 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 6_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM-NoOutlierSum.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 7_Testdata_MHQuant_NoOutlierSum-noQuantMsgSum.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 8_Testdata_MHQuant_Corrupt_OutlierQuantMsgSumDeleted.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 9_Testdata_MHQuant_withQuantMethods_withQualifierMethResults.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 18 x 5
         column                  class           n_na n_distinct    num_sum
         <chr>                   <chr>          <int>      <int>      <dbl>
       1 analysis_id             character          0         65       NA  
       2 file_analysis_order     integer            0         65    34320  
       3 raw_data_filename       character          0         65       NA  
       4 sample_name             character          0         65       NA  
       5 sample_type             character          0          1       NA  
       6 sample_level            character          0          1       NA  
       7 acquisition_time_stamp  POSIXct/POSIXt     0         65       NA  
       8 feature_id              character          0         16       NA  
       9 integration_qualifier   logical            0          2       NA  
      10 method_polarity         factor             0          2       NA  
      11 method_product_mz       numeric            0          2    90012  
      12 method_precursor_mz     numeric            0          8   454298  
      13 method_collision_energy numeric          520          2    15080  
      14 method_fragmentor       numeric          520          2   197600  
      15 method_time_segment     integer          520          2      520  
      16 feature_rt              numeric           27         83     3444. 
      17 feature_area            numeric           27        965 17586013  
      18 feature_fwhm            numeric           27         92       61.4

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 10_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM-NoQuantMsgSum.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 11_Testdata_MHQuant_DefaultSampleInfo-noAcqDataTime_RT-Areas-FWHM.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 11 x 5
         column                class      n_na n_distinct    num_sum
         <chr>                 <chr>     <int>      <int>      <dbl>
       1 analysis_id           character     0         65       NA  
       2 file_analysis_order   integer       0         65    34320  
       3 raw_data_filename     character     0         65       NA  
       4 sample_name           character     0         65       NA  
       5 sample_type           character     0          1       NA  
       6 sample_level          character     0          1       NA  
       7 feature_id            character     0         16       NA  
       8 integration_qualifier logical       0          1       NA  
       9 feature_rt            numeric      19         79     3473. 
      10 feature_area          numeric      19        978 17599226  
      11 feature_fwhm          numeric      19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 15_Testdata_MHQuant_Corrupt_ExtraTopLine.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 18 x 5
         column                  class           n_na n_distinct    num_sum
         <chr>                   <chr>          <int>      <int>      <dbl>
       1 analysis_id             character          0         65       NA  
       2 file_analysis_order     integer            0         65    34320  
       3 raw_data_filename       character          0         65       NA  
       4 sample_name             character          0         65       NA  
       5 sample_type             character          0          1       NA  
       6 sample_level            character          0          1       NA  
       7 acquisition_time_stamp  POSIXct/POSIXt     0         65       NA  
       8 feature_id              character          0         16       NA  
       9 integration_qualifier   logical            0          2       NA  
      10 method_polarity         factor             0          2       NA  
      11 method_product_mz       numeric            0          2    90012  
      12 method_precursor_mz     numeric            0          8   454298  
      13 method_collision_energy numeric          520          2    15080  
      14 method_fragmentor       numeric          520          2   197600  
      15 method_time_segment     integer          520          2      520  
      16 feature_rt              numeric           27         83     3444. 
      17 feature_area            numeric           27        965 17586013  
      18 feature_fwhm            numeric           27         92       61.4

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 19_Testdata_MHQuant_MultipleQUAL_with_expectedRT.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 21 x 5
         column                  class           n_na n_distinct   num_sum
         <chr>                   <chr>          <int>      <int>     <dbl>
       1 analysis_id             character          0          8      NA  
       2 file_analysis_order     integer            0          8     576  
       3 raw_data_filename       character          0          8      NA  
       4 sample_name             character          0          8      NA  
       5 sample_type             character          0          1      NA  
       6 sample_level            character          0          1      NA  
       7 acquisition_time_stamp  POSIXct/POSIXt     0          8      NA  
       8 vial_position           character          0          6      NA  
       9 Vial                    character          0          1      NA  
      10 inj_volume              numeric            0          1    1280  
      11 feature_id              character          0         16      NA  
      12 integration_qualifier   logical            0          2      NA  
      13 method_collision_energy numeric           80          5     320  
      14 method_precursor_mz     numeric           80          7   14629. 
      15 method_product_mz       numeric            0         14   34975. 
      16 method_target_rt        numeric           80          7     515. 
      17 feature_area            numeric           26         99 2075019  
      18 feature_fwhm            numeric           26         73      13.2
      19 feature_height          numeric           26         98  294552  
      20 feature_rt              numeric           26         60    1118. 
      21 feature_sn_ratio        numeric           26         91     959. 

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 20_Testdata_MHQuant_withSpecialCharsInFeatures.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 21 x 5
         column                  class           n_na n_distinct   num_sum
         <chr>                   <chr>          <int>      <int>     <dbl>
       1 analysis_id             character          0          8      NA  
       2 file_analysis_order     integer            0          8     576  
       3 raw_data_filename       character          0          8      NA  
       4 sample_name             character          0          8      NA  
       5 sample_type             character          0          1      NA  
       6 sample_level            character          0          1      NA  
       7 acquisition_time_stamp  POSIXct/POSIXt     0          8      NA  
       8 vial_position           character          0          6      NA  
       9 Vial                    character          0          1      NA  
      10 inj_volume              numeric            0          1    1280  
      11 feature_id              character          0         16      NA  
      12 integration_qualifier   logical            0          2      NA  
      13 method_collision_energy numeric           80          5     320  
      14 method_precursor_mz     numeric           80          7   14629. 
      15 method_product_mz       numeric            0         14   34975. 
      16 method_target_rt        numeric           80          7     515. 
      17 feature_area            numeric           26         99 2075019  
      18 feature_fwhm            numeric           26         73      13.2
      19 feature_height          numeric           26         98  294552  
      20 feature_rt              numeric           26         60    1118. 
      21 feature_sn_ratio        numeric           26         91     959. 

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 21_Testdata_MHQuant_with_dots_InFeatures.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 22_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM_notInSeq.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 22_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM_notInSeq-noalphafeat.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 23_Testdata_MHQuant_DefaultSampleInfo_RT-Areas-FWHM_notInSeq_notimestamp.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 11 x 5
         column                class      n_na n_distinct    num_sum
         <chr>                 <chr>     <int>      <int>      <dbl>
       1 analysis_id           character     0         65       NA  
       2 file_analysis_order   integer       0         65    34320  
       3 raw_data_filename     character     0         65       NA  
       4 sample_name           character     0         65       NA  
       5 sample_type           character     0          1       NA  
       6 sample_level          character     0          1       NA  
       7 feature_id            character     0         16       NA  
       8 integration_qualifier logical       0          1       NA  
       9 feature_rt            numeric      19         79     3473. 
      10 feature_area          numeric      19        978 17599226  
      11 feature_fwhm          numeric      19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == MHQuant_demo.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 18 x 5
         column                     class           n_na n_distinct     num_sum
         <chr>                      <chr>          <int>      <int>       <dbl>
       1 analysis_id                character          0         38         NA 
       2 file_analysis_order        integer            0         38      22971 
       3 raw_data_filename          character          0         38         NA 
       4 sample_name                character          0         38         NA 
       5 sample_type                character          0          1         NA 
       6 sample_level               character          0          1         NA 
       7 acquisition_time_stamp     POSIXct/POSIXt     0         38         NA 
       8 vial_position              character          0         32         NA 
       9 feature_id                 character          0         31         NA 
      10 integration_qualifier      logical            0          1         NA 
      11 method_polarity            factor             0          1         NA 
      12 method_precursor_mz        numeric            0         25     826348 
      13 method_product_mz          numeric            0         15     467757.
      14 method_collision_energy    numeric            0          9      23446 
      15 feature_rt                 numeric            0         86       6039.
      16 feature_area               numeric            0       1177 3600834969 
      17 feature_fwhm               numeric            0        115        113.
      18 feature_manual_integration logical            0          2         NA 

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == MRMhub_TestData_MHQuant_S1P_DefaultSampleInfo_RT-Areas-FWHM.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         65       NA  
       2 file_analysis_order    integer            0         65    34320  
       3 raw_data_filename      character          0         65       NA  
       4 sample_name            character          0         65       NA  
       5 sample_type            character          0          1       NA  
       6 sample_level           character          0          1       NA  
       7 acquisition_time_stamp POSIXct/POSIXt     0         65       NA  
       8 feature_id             character          0         16       NA  
       9 integration_qualifier  logical            0          1       NA  
      10 feature_rt             numeric           19         79     3473. 
      11 feature_area           numeric           19        978 17599226  
      12 feature_fwhm           numeric           19         97       62.9

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == QuantLCMS_Example_MassHunter.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 25 x 5
         column                     class           n_na n_distinct     num_sum
         <chr>                      <chr>          <int>      <int>       <dbl>
       1 analysis_id                character          0         25        NA  
       2 file_analysis_order        integer            0         25      5200  
       3 raw_data_filename          character          0         25        NA  
       4 sample_name                character          0         25        NA  
       5 sample_type                character          0          3        NA  
       6 sample_level               character          0          9        NA  
       7 acquisition_time_stamp     POSIXct/POSIXt     0         25        NA  
       8 inj_volume                 numeric            0          1      4000  
       9 vial_position              character          0         25        NA  
      10 feature_id                 character          0         16        NA  
      11 integration_qualifier      logical            0          2        NA  
      12 method_conc_expected       numeric          272         36      2430. 
      13 method_polarity            factor           200          2        NA  
      14 method_precursor_mz        numeric            0          7    143980  
      15 method_product_mz          numeric            0         13     80078. 
      16 method_collision_energy    numeric          100         10      9150  
      17 feature_rt                 numeric           29         50      1121. 
      18 feature_conc_calc          numeric           29        372 200968942  
      19 feature_fwhm               numeric           29         59        34.2
      20 feature_conc_final         numeric           29        361  33348915  
      21 feature_symmetry           numeric           29        134       443. 
      22 feature_width              numeric          207         77        63.7
      23 feature_sn_ratio           numeric          303         98    407401. 
      24 feature_manual_integration logical          200          3        NA  
      25 feature_conc               numeric           29        361  33348915  

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == QuantLCMS_Example_MassHunter_CalcConc.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 25 x 5
         column                     class           n_na n_distinct     num_sum
         <chr>                      <chr>          <int>      <int>       <dbl>
       1 analysis_id                character          0         25        NA  
       2 file_analysis_order        integer            0         25      5200  
       3 raw_data_filename          character          0         25        NA  
       4 sample_name                character          0         25        NA  
       5 sample_type                character          0          3        NA  
       6 sample_level               character          0          9        NA  
       7 acquisition_time_stamp     POSIXct/POSIXt     0         25        NA  
       8 inj_volume                 numeric            0          1      4000  
       9 vial_position              character          0         25        NA  
      10 feature_id                 character          0         16        NA  
      11 integration_qualifier      logical            0          2        NA  
      12 method_conc_expected       numeric          272         36      2430. 
      13 method_polarity            factor           200          2        NA  
      14 method_precursor_mz        numeric            0          7    143980  
      15 method_product_mz          numeric            0         13     80078. 
      16 method_collision_energy    numeric          100         10      9150  
      17 feature_rt                 numeric           29         50      1121. 
      18 feature_conc_calc          numeric           29        372 200968942  
      19 feature_fwhm               numeric           29         59        34.2
      20 feature_height             numeric           29        361  33348915  
      21 feature_symmetry           numeric           29        134       443. 
      22 feature_width              numeric          207         77        63.7
      23 feature_sn_ratio           numeric          303         98    407401. 
      24 feature_manual_integration logical          200          3        NA  
      25 feature_conc               numeric           29        372 200968942  

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == QuantLCMS_Example_MassHunter_FinalConc.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 25 x 5
         column                     class           n_na n_distinct     num_sum
         <chr>                      <chr>          <int>      <int>       <dbl>
       1 analysis_id                character          0         25        NA  
       2 file_analysis_order        integer            0         25      5200  
       3 raw_data_filename          character          0         25        NA  
       4 sample_name                character          0         25        NA  
       5 sample_type                character          0          3        NA  
       6 sample_level               character          0          9        NA  
       7 acquisition_time_stamp     POSIXct/POSIXt     0         25        NA  
       8 inj_volume                 numeric            0          1      4000  
       9 vial_position              character          0         25        NA  
      10 feature_id                 character          0         16        NA  
      11 integration_qualifier      logical            0          2        NA  
      12 method_conc_expected       numeric          272         36      2430. 
      13 method_polarity            factor           200          2        NA  
      14 method_precursor_mz        numeric            0          7    143980  
      15 method_product_mz          numeric            0         13     80078. 
      16 method_collision_energy    numeric          100         10      9150  
      17 feature_rt                 numeric           29         50      1121. 
      18 feature_height             numeric           29        372 200968942  
      19 feature_fwhm               numeric           29         59        34.2
      20 feature_conc_final         numeric           29        361  33348915  
      21 feature_symmetry           numeric           29        134       443. 
      22 feature_width              numeric          207         77        63.7
      23 feature_sn_ratio           numeric          303         98    407401. 
      24 feature_manual_integration logical          200          3        NA  
      25 feature_conc               numeric           29        361  33348915  

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == QuantLCMS_Example_MassHunter-NoHdrSampleName.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 23 x 5
         column                     class           n_na n_distinct     num_sum
         <chr>                      <chr>          <int>      <int>       <dbl>
       1 analysis_id                character          0         25        NA  
       2 file_analysis_order        integer            0         25      5200  
       3 acquisition_time_stamp     POSIXct/POSIXt     0         25        NA  
       4 raw_data_filename          character          0         25        NA  
       5 sample_type                character          0          3        NA  
       6 sample_level               character          0          9        NA  
       7 inj_volume                 numeric            0          1      4000  
       8 vial_position              character          0         25        NA  
       9 feature_id                 character          0         16        NA  
      10 integration_qualifier      logical            0          2        NA  
      11 method_conc_expected       numeric          272         36      2430. 
      12 method_polarity            factor           200          2        NA  
      13 method_precursor_mz        numeric            0          7    143980  
      14 method_product_mz          numeric            0         13     80078. 
      15 method_collision_energy    numeric          100         10      9150  
      16 feature_rt                 numeric           29         50      1121. 
      17 feature_area               numeric           29        372 200968942  
      18 feature_fwhm               numeric           29         59        34.2
      19 feature_height             numeric           29        361  33348915  
      20 feature_symmetry           numeric           29        134       443. 
      21 feature_width              numeric          207         77        63.7
      22 feature_sn_ratio           numeric          303         98    407401. 
      23 feature_manual_integration logical          200          3        NA  

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 17_Testdata_Lipidomics_GermanSystem.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         10        NA 
       2 file_analysis_order    integer            0         10     16060 
       3 raw_data_filename      character          0         10        NA 
       4 sample_name            character          0          9        NA 
       5 sample_type            character          0          1        NA 
       6 sample_level           character          0          1        NA 
       7 acquisition_time_stamp POSIXct/POSIXt     0         10        NA 
       8 feature_id             character          0        292        NA 
       9 integration_qualifier  logical            0          1        NA 
      10 feature_rt             numeric            6       1865     40472.
      11 feature_area           numeric            6       1400 183311592 
      12 feature_fwhm           numeric            6        232       217.

---

    Code
      cat("== ", basename(f), " ==\n", sep = "")
    Output
      == 18_Testdata_Lipidomics_MultiLanguageCharactersSamplenamesFeatures.csv ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 12 x 5
         column                 class           n_na n_distinct    num_sum
         <chr>                  <chr>          <int>      <int>      <dbl>
       1 analysis_id            character          0         10        NA 
       2 file_analysis_order    integer            0         10     16060 
       3 raw_data_filename      character          0         10        NA 
       4 sample_name            character          0          9        NA 
       5 sample_type            character          0          1        NA 
       6 sample_level           character          0          1        NA 
       7 acquisition_time_stamp POSIXct/POSIXt     0         10        NA 
       8 feature_id             character          0        292        NA 
       9 integration_qualifier  logical            0          1        NA 
      10 feature_rt             numeric            6       1865     40472.
      11 feature_area           numeric            6       1400 183311592 
      12 feature_fwhm           numeric            6        232       217.

# parse_masshunter_csv(expand_qualifier_names = FALSE) output is stable

    Code
      cat("== ", basename(f), " (expand_qualifier_names = FALSE) ==\n", sep = "")
    Output
      == 9_Testdata_MHQuant_withQuantMethods_withQualifierMethResults.csv (expand_qualifier_names = FALSE) ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 18 x 5
         column                  class           n_na n_distinct    num_sum
         <chr>                   <chr>          <int>      <int>      <dbl>
       1 analysis_id             character          0         65       NA  
       2 file_analysis_order     integer            0         65    34320  
       3 raw_data_filename       character          0         65       NA  
       4 sample_name             character          0         65       NA  
       5 sample_type             character          0          1       NA  
       6 sample_level            character          0          1       NA  
       7 acquisition_time_stamp  POSIXct/POSIXt     0         65       NA  
       8 feature_id              character          0         16       NA  
       9 integration_qualifier   logical            0          2       NA  
      10 method_polarity         factor             0          2       NA  
      11 method_product_mz       numeric            0          2    90012  
      12 method_precursor_mz     numeric            0          8   454298  
      13 method_collision_energy numeric          520          2    15080  
      14 method_fragmentor       numeric          520          2   197600  
      15 method_time_segment     integer          520          2      520  
      16 feature_rt              numeric           27         83     3444. 
      17 feature_area            numeric           27        965 17586013  
      18 feature_fwhm            numeric           27         92       61.4

---

    Code
      cat("== ", basename(f), " (expand_qualifier_names = FALSE) ==\n", sep = "")
    Output
      == 19_Testdata_MHQuant_MultipleQUAL_with_expectedRT.csv (expand_qualifier_names = FALSE) ==
    Code
      print(mh_fingerprint(d), n = Inf, width = Inf)
    Output
      # A tibble: 21 x 5
         column                  class           n_na n_distinct   num_sum
         <chr>                   <chr>          <int>      <int>     <dbl>
       1 analysis_id             character          0          8      NA  
       2 file_analysis_order     integer            0          8     576  
       3 raw_data_filename       character          0          8      NA  
       4 sample_name             character          0          8      NA  
       5 sample_type             character          0          1      NA  
       6 sample_level            character          0          1      NA  
       7 acquisition_time_stamp  POSIXct/POSIXt     0          8      NA  
       8 vial_position           character          0          6      NA  
       9 Vial                    character          0          1      NA  
      10 inj_volume              numeric            0          1    1280  
      11 feature_id              character          0         16      NA  
      12 integration_qualifier   logical            0          2      NA  
      13 method_collision_energy numeric           80          5     320  
      14 method_precursor_mz     numeric           80          7   14629. 
      15 method_product_mz       numeric            0         14   34975. 
      16 method_target_rt        numeric           80          7     515. 
      17 feature_area            numeric           26         99 2075019  
      18 feature_fwhm            numeric           26         73      13.2
      19 feature_height          numeric           26         98  294552  
      20 feature_rt              numeric           26         60    1118. 
      21 feature_sn_ratio        numeric           26         91     959. 


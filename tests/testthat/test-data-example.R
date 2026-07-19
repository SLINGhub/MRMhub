test_that("data_load_example works", {
  mexp <- data_load_example()
  expect_true(is.data.frame(mexp@dataset))
  expect_equal(class(mexp) |> as.character(), "MRMhubExperiment")
  expect_equal(dim(mexp@dataset), c(14471, 20))

  expect_error(
    mexp <- data_load_example(dataset = 2),
    "only dataset 1 is currently available"
  )
})

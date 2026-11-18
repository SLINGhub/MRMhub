test_that("mh_quiet_info mutes info/success alerts but keeps warnings", {
  expect_no_message(mh_quiet_info({
    mh_info("info")
    mh_success("done")
  }))
  expect_message(mh_quiet_info(mh_warn("careful")), "careful")
  expect_equal(mh_quiet_info(42), 42)
})

context("Compare standalone occupancy probability to other occupancy functions")

test_that("standalone matches poccupy_species", {
  fit <- artificial_runjags(nspecies = 5, nsites = 100, nvisitspersite = 1, nlv = 0)
  a <- poccupy_species(fit, type = 1, conditionalLV = FALSE)
  XoccOrig <- unstandardise.designmatprocess(fit$XoccProcess, fit$data$Xocc)
  theta <- get_theta(fit, type = 1)
  u.b <- bugsvar2matrix(theta, "u.b", 1:fit$data$n, 1:ncol(fit$data$Xocc))
  b <- poccupancy_standalone_nolv(XoccOrig, fit$XoccProcess, u.b)
  expect_equivalent(a, b)
})


test_that("Multisite richness function matches others for single sites", {
  fit <- artificial_runjags(nspecies = 60, nsites = 100, nvisitspersite = 1, nlv = 0)
  Erichnesspersite <- predsumspecies(fit, UseFittedLV = FALSE, type = "marginal")
  
  XoccOrig <- unstandardise.designmatprocess(fit$XoccProcess, fit$data$Xocc)
  theta <- get_theta(fit, type = 1)
  u.b <- bugsvar2matrix(theta, "u.b", 1:fit$data$n, 1:ncol(fit$data$Xocc))
  b <- lapply(1:nrow(XoccOrig), function(i) {
    multisiterichness_nolv(XoccOrig[i, , drop = FALSE], fit$XoccProcess, u.b)})
  b <- simplify2array(b)
  expect_equivalent( b["Erichness", ], Erichnesspersite["Esum_occ", ])
  expect_equivalent( b["Vrichness", ], Erichnesspersite["Vsum_occ", ])
})

test_that("Multisite richness goes to max for many sites", {
  fit <- artificial_runjags(nspecies = 60, nsites = 100, nvisitspersite = 1, nlv = 0)
  XoccOrig <- unstandardise.designmatprocess(fit$XoccProcess, fit$data$Xocc)
  theta <- get_theta(fit, type = 1)
  u.b <- bugsvar2matrix(theta, "u.b", 1:fit$data$n, 1:ncol(fit$data$Xocc))
  Erichness <- multisiterichness_nolv(XoccOrig, fit$XoccProcess, u.b)
  expect_equal(Erichness[["Erichness"]], fit$data$n)
  expect_equal(Erichness[["Vrichness"]], 0)
})

test_that("Occupancy of any site is larger than occupancy of any single individual site", {
  fit <- artificial_runjags(nspecies = 60, nsites = 100, nvisitspersite = 1, nlv = 0)
  XoccOrig <- unstandardise.designmatprocess(fit$XoccProcess, fit$data$Xocc)
  theta <- get_theta(fit, type = 1)
  u.b <- bugsvar2matrix(theta, "u.b", 1:fit$data$n, 1:ncol(fit$data$Xocc))
  poccupy <- poccupancy_standalone_nolv(XoccOrig[1:5, ], fit$XoccProcess, u.b)
  panyoccupy <- panyoccupancy_indsites_nolv(poccupy)
  expect_true(all(Rfast::eachrow(poccupy, panyoccupy, oper = "-") <= 0))
})

#' @title Computing Likelihoods for Occupancy Detection Models


#' @details Any predictinve accuracy measure requires a choice of 
#' 1. the part of the model that is considered the 'likelihood' and 
#' 2. factorisation of the likelihood into 'data points' [Vehtari 2017]
#' 
#' On 1: New data will look like a new location or visit for a new season in our exisitng region, and observing only the species included in the model.
#' This means we have zero knowledge of the latent variable value at the new ModelSite. This means likelihood:
#'         *  conditional on the covariates u.b and v.b (not using the fitted values of mu.u.b, tau.u.b etc)
#'         *  is conditional on the lv.coef values of each species
#'         *  is conditional on the latent variable value for (each) new ModelSite being drawn from a standard Gaussian distribution.
#'         
#' On 2: Factoring the likelihood using the inbuilt independence properties of the model means 
#' a single 'data point' is all the data for all visits of a single ModelSite.
#' The likelihood could also be partitioned by each visit, but then data points are dependent (they have the same occupancy value).
#'         
#' The output of [likelihoods.fit()] can be easily passed to [loo::waic()] and [loo::loo()].

# For WAIC:
## function(data_i = data[i, , drop = FALSE], draws = draws)  --> returns a vector, each entry given by draw in draws.
# data: dataframe or matrix containing predictor and observed outcome data. For each observation, i, the ith row of data will be passed to the data_i argument
#       This is like the combination of Xocc joined to Xobs and y via ModelSite?
#       Except the multiple visits to the same ModelSite are *dependent*. Perhaps it is best to combine all visits to a model site!?
# draws: a posterior draws object, passed unaltered to the function
# ...  May be used too, it is passed to each call of the function (all i).
# This function can also be used to perform the PSIS-LOO estimate of PSIS. So long as the rows satisfy conditional independence in the data model.


#' @references A. Vehtari, A. Gelman, and J. Gabry, "Practical Bayesian model evaluation using leave-one-out cross-validation and WAIC," Stat Comput, vol. 27, pp. 1413-1432, Sep. 2017, doi: 10.1007/s11222-016-9696-4.

#' @examples
#' # simulate data
#' covars <- simulate_covar_data(nsites = 50, nvisitspersite = 2)
#' y <- simulate_iid_detections(3, nrow(covars$Xocc))
#' 
#' fittedmodel <- run.detectionoccupancy(
#'   Xocc = covars$Xocc,
#'   yXobs = cbind(covars$Xobs, y),
#'   species = colnames(y),
#'   ModelSite = "ModelSite",
#'   OccFmla = "~ UpSite + Sine1",
#'   ObsFmla = "~ UpVisit + Step",
#'   nlv = 2,
#'   MCMCparams = list(n.chains = 1, adapt = 0, burnin = 0, sample = 3, thin = 1)
#' )
#' 
#' # run likelihood computations, waic, and psis-loo
#' insamplell <- likelihoods.fit(fittedmodel)
#' waic <- loo::waic(log(insamplell))
#' looest <- loo::loo(log(insamplell), cores = 2)
#' 
#' 
#' 
#' outofsample_covars <- simulate_covar_data(nsites = 10, nvisitspersite = 2)
#' outofsample_y <- simulate_iid_detections(3, nrow(outofsample_covars$Xocc))
#' outofsample_lppd <- lppd.newdata(fittedmodel,
#'              Xocc = outofsample_covars$Xocc,
#'              yXobs = cbind(outofsample_covars$Xobs, outofsample_y),
#'              ModelSite = "ModelSite")
#' 
#' # Recommend using multiple cores:
#' cl <- parallel::makeCluster(2)
#' insamplell <- likelihoods.fit(fittedmodel, cl = cl)
#' 
#' outofsample_lppd <- lppd.newdata(fittedmodel,
#'                                  Xocc = outofsample_covars$Xocc,
#'                                  yXobs = cbind(outofsample_covars$Xobs, outofsample_y),
#'                                  ModelSite = "ModelSite",
#'                                  cl = cl)
#' parallel::stopCluster(cl)

#' @describeIn likelihoods.fit Compute the log pointwise posterior density of new (out-of-sample) data
#' @return `lppd.newdata` returns a list with components
#' lpds: a list of the log likelihood of the observations for each ModelSite in the supplied data
#' lppd: the computed log pointwise predictive density (sum of the lpds). This is equation (5) in Gelman et al 2014
#' @export
lppd.newdata <- function(fit, Xocc, yXobs, ModelSite, chains = 1, numlvsims = 1000, cl = NULL){
  likel.mat <- likelihoods.fit(fit, Xocc = Xocc, yXobs = yXobs, ModelSite = ModelSite,
                               chains = chains, numlvsims = numlvsims, cl = cl)
  likel.marg <- Rfast::colmeans(likel.mat) # the loglikelihood marginalised over theta (poseterior distribution)
  return(
    list(
      lppd = sum(log(likel.marg)),
      lpds = log(likel.marg) # a list of the log likelihood of the observations for each ModelSite in the supplied data
    )
  )
}

#' @describeIn likelihoods.fit Compute the likelihood of observations at each ModelSites. At data in the fitted model, or on new data supplied.
#' @param chains is a vector indicator which mcmc chains to extract draws from. If NULL then all chains used.
#' @param numlvsims the number of simulated latent variable values to use for computing likelihoods
#' @param cl a cluster created by parallel::makeCluster()
#' @return `likelihoods.fit` returns a matrix. Each row corresponds to a draw of the parameters from the posterior. Each column to a ModelSite
#' Compute the likelihoods of each ModelSite's observations given each draw of parameters in the posterior.
#' @export
likelihoods.fit <- function(fit, Xocc = NULL, yXobs = NULL, ModelSite = NULL, chains = NULL, numlvsims = 1000, cl = NULL){
  fit$data <- as_list_format(fit$data)
  if (is.null(chains)){chains <- 1:length(fit$mcmc)}
  draws <- do.call(rbind, fit$mcmc[chains])
  
  if ( (is.null(fit$data$nlv)) || (fit$data$nlv == 0)){ #make dummy lvsim and and 0 loadings to draws
    lvsim <- matrix(rnorm(2 * 1), ncol = 2, nrow = 2) #dummy lvsim vars
    lv.coef.bugs <- matrix2bugsvar(matrix(0, nrow = fit$data$n, ncol = 2), "lv.coef")
    lv.coef.draws <- Rfast::rep_row(lv.coef.bugs, nrow(draws))
    colnames(lv.coef.draws) <- names(lv.coef.bugs)
    draws <- cbind(draws, lv.coef.draws)
  } else {
    lvsim <- matrix(rnorm(fit$data$nlv * numlvsims), ncol = fit$data$nlv, nrow = numlvsims) #simulated lv values, should average over thousands
  }
  
  
  if (is.null(Xocc)){ #Extract the Xocc, yXobs etc from the fitted object, no preprocessing required
    sitedata <- fit$data
  } else {
    sitedata <- prep_new_data(fit, Xocc, yXobs, ModelSite)
  }
  
  u.b_arr <- bugsvar2array(draws, "u.b", 1:fit$data$n, 1:ncol(fit$data$Xocc))  # rows are species, columns are occupancy covariates
  v.b_arr <- bugsvar2array(draws, "v.b", 1:fit$data$n, 1:ncol(fit$data$Xobs))  # rows are species, columns are observation covariates
  lv.coef_arr <- bugsvar2array(draws, "lv.coef", 1:fit$data$n, 1:ncol(lvsim)) # rows are species, columns are lv
  
  if (is.null(cl)) {
    likel.l <- lapply(1:nrow(sitedata$Xocc), function(modelsiteid) {
      Xocc <- sitedata$Xocc[modelsiteid, , drop = FALSE]
      Xobs <- sitedata$Xobs[sitedata$ModelSite == modelsiteid, , drop = FALSE]
      y <- sitedata$y[sitedata$ModelSite == modelsiteid, , drop = FALSE]
      lkl <- likelihood_joint_marginal.ModelSite(
                      Xocc,Xobs, y,
                      u.b_arr, v.b_arr, lv.coef_arr, lvsim = lvsim)
      return(lkl)
    })
  }
  else {
    likel.l <- parallel::parLapply(cl = cl, 1:nrow(sitedata$Xocc), function(modelsiteid) {
      Xocc <- sitedata$Xocc[modelsiteid, , drop = FALSE]
      Xobs <- sitedata$Xobs[sitedata$ModelSite == modelsiteid, , drop = FALSE]
      y <- sitedata$y[sitedata$ModelSite == modelsiteid, , drop = FALSE]
      lkl <- likelihood_joint_marginal.ModelSite(
                      Xocc,Xobs, y,
                      u.b_arr, v.b_arr, lv.coef_arr, lvsim = lvsim)
      return(lkl)
    })
  }
  likel.mat <- do.call(cbind, likel.l) # each row is a draw, each column is a modelsite (which are independent data points)
  return(likel.mat)
}

#' @describeIn likelihoods.fit Compute the joint-species LV-marginal likelihood for a ModelSite
#' @param u.b_arr Occupancy covariate loadings. Each row is a species, each column an occupancy covariate, each layer (dim = 3) is a draw
#' @param v.b_arr Detection covariate loadings. Each row is a species, each column an detection covariate, each layer (dim = 3) is a draw
#' @param lv.coef_arr LV loadings. Each row is a species, each column a LV, each layer (dim = 3) is a draw
#' @param data_i A row of a data frame created by \code{prep_data_by_modelsite}. Each row contains data for a single ModelSite. 
#' @param lvsim A matrix of simulated LV values. Columns correspond to latent variables, each row is a simulation
#' @param Xocc A matrix of processed occupancy covariate values for the model site. Must have 1 row.
#' @param Xobs A matrix of processed detection covariate values for each visit to the model site. 
#' @param y Matrix of species detections for each visit to the model site.
#' @export
likelihood_joint_marginal.ModelSite <- function(Xocc, Xobs, y, u.b_arr, v.b_arr, lv.coef_arr, lvsim){
  stopifnot(length(dim(u.b_arr)) == 3)
  drawid <- 1:dim(u.b_arr)[[3]]

  Likl_margLV <- vapply(drawid, 
                        function(thetaid) likelihood_joint_marginal.ModelSite.theta(
        Xocc, Xobs, y,
        u.b = drop_to_matrix(u.b_arr[,, thetaid, drop = FALSE], dimdrop = 3),
        v.b = drop_to_matrix(v.b_arr[,, thetaid, drop = FALSE], dimdrop = 3),
        lv.coef = drop_to_matrix(lv.coef_arr[,, thetaid, drop = FALSE], dimdrop = 3),
        lvsim),
        FUN.VALUE = -0.001
    )
  return(Likl_margLV)
}

#' @describeIn likelihoods.fit Compute the joint-species LV-marginal likelihood for a ModelSite
#' @param Xocc A matrix of occupancy covariates. Must have a single row. Columns correspond to covariates.
#' @param Xobs A matrix of detection covariates, each row is a visit.
#' @param y A matrix of detection data for a given model site. 1 corresponds to detected. Each row is visit, each column is a species.
#' @param v.b Covariate loadings. Each row is a species, each column a detection covariate
#' @param u.b A vector of model parameters, labelled according to the BUGS labelling convention seen in runjags
#' @param lv.coef Loadings for the latent variables. Each row is a species, each column corresponds to a LV.
#' @param lvsim A matrix of simulated LV values. Columns correspond to latent variables, each row is a simulation
#' @export
likelihood_joint_marginal.ModelSite.theta <- function(Xocc, Xobs, y, u.b, v.b, lv.coef, lvsim){
stopifnot(nrow(Xocc) == 1)
stopifnot(nrow(Xobs) == nrow(y))
y <- as.matrix(y)
Xocc <- as.matrix(Xocc)
Xobs <- as.matrix(Xobs)
sd_u_condlv <- sqrt(1 - rowSums(lv.coef^2)) #for each species the standard deviation of the indicator random variable 'u', conditional on values of LV

## Probability of Detection, CONDITIONAL on occupied
Detection.Pred.Cond <- pdetection_occupied.ModelSite.theta(Xobs, v.b)

## Likelihood (probability) of single visit given occupied
Likl_condoccupied <- Detection.Pred.Cond * y + (1 - Detection.Pred.Cond) * (1 - y) # non-detection is complement of detection probability
# Likl_condoccupied[y == 0] <- (1 - Detection.Pred.Cond)[y == 0]   # non-detection is complement of detection probability

## Joint likelihood (probability) of detections of all visits CONDITIONAL on occupied
Likl_condoccupied.JointVisit <- apply(Likl_condoccupied, 2, prod)

## Likelihood (probability) of y given unoccupied is either 1 or 0 for detections. Won't include that here yet.
NoneDetected <- as.numeric(colSums(y) == 0)

## Probability of Site Occupancy
ModelSite.Occ.eta_external <- as.matrix(Xocc) %*% t(u.b) #columns are species

# probability of occupancy given LV
ModelSite.Occ.Pred.CondLV <- poccupy.ModelSite.theta(Xocc, u.b, lv.coef, LVvals = lvsim)

# likelihood given LV
Likl.JointVisit.condLV <- Rfast::eachrow(ModelSite.Occ.Pred.CondLV, Likl_condoccupied.JointVisit, oper = "*") #per species likelihood, occupied component. Works because species conditionally independent given LV
Likl.JointVisit.condLV <- Likl.JointVisit.condLV + 
  Rfast::eachrow((1 - ModelSite.Occ.Pred.CondLV), NoneDetected, oper = "*") #add probability of unoccupied for zero detections

# combine with likelihoods of detections
Likl.JointVisitSp.condLV <- Rfast::rowprods(Likl.JointVisit.condLV)  # multiply probabilities of each species together because species are conditionally independent

# take mean of all LV sims to get likelihood marginalised across LV values
Likl_margLV <- mean(Likl.JointVisitSp.condLV)

return(Likl_margLV)
}

# #### TIMING WORK ####
# library(loo)
# waic <- loo::waic(pdetect_joint_marginal.data_i,
#                   data = data[1:10, ],
#                   draws = draws[1:10, ],
#                   lvsim = lvsim)
# Above took 10 000 milliseconds on first go.
# After bugsvar2array faster, took 8000ms. Could pool bugsvar2array work to be even faster (this has been done as of Oct 6).
# After avoiding all dataframe use, dropped to 3000ms
# Can do all of JointSpVst_Liklhood.LV()'s work as matrix manipulations, dropped to 1800ms
# Down to 860ms: replaced use of "rep" with Rfast's functions eachrow, and also replaced row product with Rfast::rowprod. 

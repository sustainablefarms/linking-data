% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/avoid_multicollinearity.R
\name{remove_bycorrvif}
\alias{remove_bycorrvif}
\title{Removing variables using ViF and correlation}
\usage{
remove_bycorrvif(fmla, data, corrthresh, vifthresh, centrescalemains = FALSE)
}
\arguments{
\item{fmla}{A model formula, specifies a possible set of main effects}

\item{data}{A data frame to extract a the main effects from}

\item{corrthresh}{A threshold.
The variable with the highest correlation, and appearing later in the model matrix,
is removed until there are no pairwise correlations above \code{corrthresh}.}

\item{vifthresh}{A threshold. The variable with the highest ViF is removed until no variables have ViF above \code{vifthresh}.}

\item{centrescalemains}{If TRUE then \code{\link[=prep.designmatprocess]{prep.designmatprocess()}} and \code{\link[=apply.designmatprocess]{apply.designmatprocess()}} are used to centre and scale main effects (after any logarithms).}
}
\description{
Removing variables using ViF and correlation
}
\details{
The function first removes variables based on pairwise correlation, and then based on ViF.
Variables are removed one at a time.
First a variable is removed due to having high correlation, then pairwise correlation is recomputed.
This is repeated until no pairwise correlations are above the threshold \code{corrthresh}.
Then generalised Variance Inflation Factors (ViF) are computed using \code{\link[car:vif]{car::vif()}}.
The variable with the highest ViF is removed and ViFs are recomputed.
This is repeated until there are no ViFs higher than \code{vifthresh}.
}
\examples{
indata <- readRDS("./private/data/clean/7_2_10_input_data.rds")
remove_bycorrvif("~ AnnMeanTemp + AnnPrec + MaxTWarmMonth + PrecWarmQ + 
                   MinTColdMonth + PrecColdQ + PrecSeasonality + longitude * latitude",
                 data = indata$insampledata$Xocc,
                 corrthresh = 0.9,
                 vifthresh = 30)
}

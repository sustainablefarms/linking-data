% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/extract_brick_files.R
\name{extract_brick_files}
\alias{extract_brick_files}
\title{Extract RasterBrick from List of Filenames}
\usage{
extract_brick_files(
  files,
  varname,
  roi,
  dims = 1:3,
  timeconvertfun = function(t) lubridate::as_date(as.POSIXlt(t, origin =
    lubridate::origin))
)
}
\arguments{
\item{files}{A character list of filenames}

\item{varname}{Character. Variable name to extract from each file.}

\item{roi}{The region to extract. A \pkg{raster} 'extent' object.}

\item{dims}{The order of dimensions that the variable is saved in. dims = c(1, 2, 3) is \link{longitude, latitude, time}. dims = c(2, 1, 3) is \link{latitude, longitude, time}.}

\item{timeconvertfun}{A function that converts from time values, as given in the netCDF file, to time objects}
}
\value{
A rasterBrick object. The extents of the brick object are snapped to the smallest region containing all cells that intersect roi.
}
\description{
Extract RasterBrick from List of Filenames
}
\examples{
roi <- extent(148.0779, 148.2011, -35.26581, -35.13167)
files <- build_filename_list("http://dapds00.nci.org.au/thredds/dodsC/ub8/au/OzWALD",
      "8day/GPP",
      "OzWALD",
      "GPP",
      2000:2018,
      "nc")
b <- extract_brick_files(files, "GPP", roi, dims = c(2, 1, 3))
}

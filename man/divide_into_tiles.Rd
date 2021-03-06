% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/divide_into_tiles.R
\name{divide_into_tiles}
\alias{divide_into_tiles}
\alias{make_grid_buffer}
\alias{tilearoundobj}
\title{Divide points into tiles}
\usage{
divide_into_tiles(points, cellsize = 1, buffer = 0.01)

make_grid_buffer(points, cellsize = 0.1, overlap = 0.01)

tilearoundobj(sfobj, buffer)
}
\arguments{
\item{points}{An sf object to cover with a grid. Could also be a bbox object.}

\item{cellsize}{is the size of a single cell}

\item{buffer}{A numerical distance of a buffer to include around sfobj in the output tile}

\item{overlap}{is the amount of overlap of each cell}

\item{sfobj}{An sf object}
}
\value{
A list. Each element contains a slot 'tile' which is an sfc_POLYGON object,
and a slot 'pts', which is a an sf object of points covered by the tile with sufficient buffer

An sf multipolygon object made of squares that overlap by buffer, and cover the region bbox expanded by buffer.

an sf polygon object that is rectangular
}
\description{
Divide points into tiles
}
\section{Functions}{
\itemize{
\item \code{make_grid_buffer}: Creates a full grid of overlapping polygons that covers sfobj.

\item \code{tilearoundobj}: Creates a single rectangle around an sf object
}}


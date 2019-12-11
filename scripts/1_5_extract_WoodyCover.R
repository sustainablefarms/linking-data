# Extract Woody Cover
# it is in Albers Tile format with CRS = CRS("+init=epsg:3577").
# (see analysis 1_2_checking_albers_tiles.Rmd for why)
# Tiles are in folders xmin_ymin in Easting and Northings, where xmin and ymin are in '000 000s of meters.

invisible(lapply(c("raster", "maptools", "rgdal", "ncdf4", "lubridate"),
       library, character.only = TRUE))
invisible(lapply(paste0("../linking-private/data/functions/", list.files("../linking-private/data/functions/")), source))


# Construct Region Desired
sws_sites <- readRDS("../linking-private/data/private/data/clean/sws_sites.rds")
ptsraw <- sws_sites_2_spdf(sws_sites)
points <- spTransform(sws_sites_2_spdf(sws_sites),
                      CRS("+init=epsg:3577"))
spobj <- buffer(points, 1000) #the buffer here to make sure extracted brick includes extra around the points

#load / read raster values
b <- brick_woodycover(spobj, 2000:2018)
writeRaster(b, "woodycover_brick.tif")

#compute average of buffer for every pixel
wf <- focalWeight(b, 500, type = "circle") 
bs <- focal_bylayer(b, wf, fun = sum)
woodycover_500mradius <- t(extract(bs, points))
colnames(woodycover_500mradius) <- points$SiteCode
years <- year(as_date(rownames(woodycover_500mradius), format =  "X%Y", tz = "Australia/Sydney"))
woodycover_500mradius <- cbind(year = years, data.frame(woodycover_500mradius))
session <- sessionInfo()
save(woodycover_500mradius, session, file = "./private/data/remote_sensed/woodycover_500mradius.Rdata")
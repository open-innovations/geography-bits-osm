# Building a list of city/other OSM relations

The aim is to have an easy way to get polygons for cities across the whole planet much as the Open Innovations [geography bits](https://github.com/open-innovations/geography-bits) repository does for various ONS geographies in the UK i.e. we need a way to get from a reliable ID to a polygon.

One option is to download [ISO3166-2 polygons](https://www.volkerkrause.eu/2021/02/13/osm-country-subdivision-boundary-polygons.html) created by Volker Krause in February 2021. The downloaded GeoJSON had a wrong quotation mark on line 1855 which needed to be fixed. Aside: for checking in QGIS it is useful to convert the GeoJSON to sqlite first e.g.:

```
ogr2ogr -f sqlite -dsco spatialite=yes iso3166-2.sqlite iso3166-2-boundaries.geojson
```

Unfortunately, what counts as ISO3166-2 varies from country to country. In the UK these can be local authorities (e.g. Bradford, Leeds, Calderdale) but also the nations (e.g. England). In the US these are States. ISO3166-2 isn't the most consistent unit. So let's try extracting political boundaries from OpenStreetMap ourselves. First we need to get a `o5m` version of the [planet file](https://planet.osm.org/):

```
osmconvert planet-latest.osm.pbf -o=planet-latest.o5m
```

As of October 2022 this creates a 125GB file in under an hour on a laptop. Next we filter this for `boundary=administrative` and `boundary=political`:

```
osmfilter planet-latest.o5m --drop-author --keep='boundary=administrative boundary=political' -o=planet-boundary.osm
```

This creates a 17GB file. Next we extract the `MultiPolygons` from this that have `admin_level=` 3,4,5,6,7,8,9,10 (see [admin_level](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative)), saves them to a GeoJSON file, and creates a TSV file listing the names and OSM relation IDs:

```
perl boundaries.pl temp/planet-boundary.osm planet-boundary.tsv
```

This took 2953.83s on a laptop.

An OSM relation ID can be used to extract GeoJSON from OSM e.g. [Leeds - 118362](http://polygons.openstreetmap.fr/get_geojson.py?id=118362&params=0).


http://download.geonames.org/export/dump/

[Cities15000](http://download.geonames.org/export/dump/cities15000.zip) or [Cities1000](http://download.geonames.org/export/dump/cities1000.zip)


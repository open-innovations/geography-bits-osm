# Building a list of city/other OSM relations

October 2022

The Open Innovations [geography bits](https://github.com/open-innovations/geography-bits) repository has separate GeoJSON files for various ONS geographies in the UK. The aim of this repository is to create GeoJSON files for cities/towns/areas across the whole planet. Like the other repo, each area needs a unique ID to address it. Here are two ideas for getting polygons of areas:

## Idea 1 - ISO3166-2

One option is to download [ISO3166-2 polygons](https://www.volkerkrause.eu/2021/02/13/osm-country-subdivision-boundary-polygons.html) created by Volker Krause in February 2021. The downloaded GeoJSON had a wrong quotation mark on line 1855 which needed to be fixed. Aside: for checking in QGIS it is useful to convert the GeoJSON to sqlite first e.g.:

```
ogr2ogr -f sqlite -dsco spatialite=yes iso3166-2.sqlite iso3166-2-boundaries.geojson
```

Unfortunately, what counts as ISO3166-2 varies from country to country. In the UK these can be local authorities (e.g. Bradford, Leeds, Calderdale) but also the nations (e.g. England). In the US these are the 50 States. ISO3166-2 isn't the most consistent unit so we decided to try something different.

## Idea 2 - OSM administrative areas

OpenStreetMap includes administrative boundaries around the world so this seemed like a good option. If you know the relation ID for a particular area you can extract the polygon(s) for it using e.g. [Leeds = 118327](http://polygons.openstreetmap.fr/get_geojson.py?id=118327&params=0). However, the French OpenStreetMap API doesn't have CORS enabled so it wouldn't help with our likely use cases - maps in a web page. Also, we don't have a big list of OpenStreetMap relation IDs. This repository aims to create a one-off snapshot.

First we need to download the [planet file](https://planet.osm.org/) as a PBF and then convert that to a `.o5m` version:

```
osmconvert planet-latest.osm.pbf -o=planet-latest.o5m
```

This creates a 125GB file in under an hour on a modern laptop. Next we filter this for `boundary=administrative` and `boundary=political`:

```
osmfilter planet-latest.o5m --drop-author --keep='boundary=administrative boundary=political' -o=planet-boundary.osm
```

This creates a 17GB file. Next we extract the `MultiPolygons` from this that have `admin_level=` 3,4,5,6,7,8,9,10 (see [admin_level](https://wiki.openstreetmap.org/wiki/Tag:boundary%3Dadministrative)), save them to a GeoJSON file, and create a TSV file listing the names and OSM relation IDs. We created a perl script to do all that.

```
perl boundaries.pl temp/planet-boundary.osm planet-boundary.tsv
```

This took 2953.83s and gave 596,907 relations. Each of these has a name but doesn't have the region or country that that area is in. That means that if we searched for "Lisbon" we'd get a list of Lisbons and not know which one we needed. So, we needed a way to make a set of search results more useful. To do that we took the [Cities1000](http://download.geonames.org/export/dump/cities1000.zip) file from [Geonames.org](http://geonames.org). We run:

```
perl matchCities.pl
```

which attempts to match places in `planet-boundary.tsv` with those in `data/cities1000.txt` by checking the OSM name against the name and alternate names from Geonames and then double checking that the location was roughly correct (within 30 km). This outputs a file `good.tsv` which contains 82,664 places with the ASCII name from Geonames. We can run:

```
perl makeSearch.pl
```

to build a simple search index as a bunch of TSV files in `search/` based on the first two characters (ignoring `'`, backtick, `-`, `.`, and space characters). We then run:

```
perl makeGeoJSONExtracts.pl
```

which gets the OSM IDs from `good.tsv`, extracts the appropriate GeoJSON from `temp/planet-boundary.geojson` (generated above but not committed to the repo because it is huge!), and saves the output into `data/OSM/XXXXXX/YYYYY.geojson` where `YYYYYY` is the OSM ID, and `XXXXXX` is the ID rounded down to the nearest 100,000. Spreading the 86,000 files across multiple directories removed some commit issues.
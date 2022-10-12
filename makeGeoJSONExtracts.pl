#!/usr/bin/perl

open(FILE,"good.tsv");
@lines = <FILE>;
close(FILE);
%good;
for($i = 0; $i < @lines; $i++){
	# Sadabad	Hathras, Uttar Pradesh	10001782	6	36093	27.43818	78.03758
	($name,$region,$id,@cols) = split(/\t/,$lines[$i]);
	$good{$id} = 1;
}

$counter = 0;
open(FILE,"temp/planet-boundary.geojson");
# To deal with massive files we'll have to rely on each feature being on its own line so that we can deal with a line at a time
while(<FILE>){
	$line = $_;
	if($line =~ /"osm_id":"([^\"]+)"/){
		$id = $1;
		if($good{$id}){
			$dir = int($id/1e5)*100000;
			if(!-d "data/OSM/$dir"){
				`mkdir data/OSM/$dir`;
			}
			print "$counter: $id ($dir)\n";
			$line =~ s/\,[\n\r]*$//g;
			open(GEO,">","data/OSM/$dir/$id.geojson");
			print GEO $line;
			close(GEO);
			$counter++;
		}
	}
}
close(FILE);
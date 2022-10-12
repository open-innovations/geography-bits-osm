#!/usr/bin/perl
#####################################################################
# Extract GeoJSON of all the multipolygons in a .osm file and create
# a TSV file with all the area names, IDs and rough coordinates.
# Created 2022-10-11
# Last updated 2022-10-12
#####################################################################
# Make sure to have first converted the planet file and extracted boundaries from it:
# 	osmconvert planet-latest.osm.pbf -o=planet-latest.o5m
# 	osmfilter planet-latest.o5m --drop-author --keep='boundary=administrative boundary=political' -o=planet-boundary.osm
#
# Then run this script to only keep admin_level=6, admin_level=7, or admin_level=8 using:
# 	perl boundaries.pl temp/planet-boundary.osm planet-boundary.tsv

use utf8;
use JSON::XS;
use Data::Dumper;
use open qw( :std :encoding(UTF-8) );


$ifile = $ARGV[0];
$cfile = $ARGV[1];

if(!-e $ifile){
	print "ERROR: Input .osm file ($ifile) doesn't exist.\n";
	exit;
}
$ofile = $ifile;
$ofile =~ s/\.([^\.]+)$/\.geojson/;

if(!$cfile){
	$cfile = $ifile;
	$cfile =~ s/\.([^\.]+)$/\.tsv/;
}

saveGeoJSONFeatures($ifile,$ofile);



##############
# Subroutines

sub saveGeoJSONFeatures {

	my (@types,@features,$t,@lines,$perl_scalar,$n,$i,$geojson,$txt,$osm2);
	
	my $osm = $_[0];
	my $ofile = $_[1];

	if($osm =~ /\.o5m$/){
		# Need to convert the file
		$osm2 = $osm;
		$osm2 =~ s/\.o5m$/\.osm/;
		`osmconvert $osm -o=$osm2`;
		$osm = $osm2;		
	}

	
	# Extract each feature type as GeoJSON
	#	@types = ('points','lines','multilinestrings','multipolygons','other_relations');
	@types = ('multipolygons');

	open(GEO,">",$ofile);
	print GEO "{\n\"type\": \"FeatureCollection\",\n\"features\": [\n";

	open(CSV,">",$cfile);
	print CSV "Name\tOSM Relation ID\tLevel\tPopulation\tLon\tLat\n";

	$n = 0;
	for($i = 0; $i < @types; $i++){
		$t = $types[$i];
		print "Processing $t\n";

		# Construct file name for this feature type
		$gfile = $ofile;
		$gfile =~ s/(\.geojson)/_$t$1/;

		if(!-e $gfile || -s $gfile == 0){
			if(-e $gfile){
				`rm $gfile`;
			}
			`ogr2ogr -overwrite --config OSM_CONFIG_FILE osmconf.ini -skipfailures -f GeoJSON $gfile $osm $t`;
			print "Created GeoJSON at $gfile.\n";
		}

		open(FILE,$gfile);
		# To deal with massive files we'll have to rely on each feature being on its own line so that we can deal with a line at a time
		while(<FILE>){
			$line = $_;
			if($line =~ /"type": ?"Feature"/ && $line =~ /"admin_level" ?: ?"(3|4|5|6|7|8|9|10)"/){
				$str = $line;
				$str =~ s/\,[\n\r]*$//;
				$str =~ s/([0-9]\.[0-9]{4})[0-9]+/$1/g;
				$feature = JSON::XS->new->decode($str);
				if($feature{'properties'}{'other_tags'}){
					$feature{'properties'}{'other_tags'} =~ s/\=\>/\:/g;
					$feature{'properties'}{'other_tags'} = JSON::XS->new->decode("{".$feature{'properties'}{'other_tags'}."}");
				}
				if($n > 0){ print GEO ",\n"; }
				print GEO JSON::XS->new->canonical(1)->encode($feature);
				print CSV $feature->{'properties'}{'name'}."\t".$feature->{'properties'}{'osm_id'}."\t".$feature->{'properties'}{'admin_level'}."\t".$feature->{'properties'}{'population'}."\t".$feature->{'geometry'}{'coordinates'}[0][0][0][0]."\t".$feature->{'geometry'}{'coordinates'}[0][0][0][1]."\n";
				$n++;
			}
		}
		close(FILE);

		# Safer method reads whole file and parses it as JSON
		#		open(FILE,$gfile);
		#		@lines = <FILE>;
		#		close(FILE);
		#		$str = (join("\n",@lines));
		#		$str =~ s/\\+[nr]/==NL==/g;
		#		$str =~ s/\\+t/==TB==/g;
		#		print "Loaded $gfile. Decoding...\n";
		#		if(!$str){ $str = "{}"; }
		#		$perl_scalar = JSON::XS->new->decode($str);
		#		print "\t...done.\n";
		#		$total = @{$perl_scalar->{'features'}};
		#		for($f = 0; $f < $total; $f++){
		#			if($perl_scalar->{'features'}[$f]){
		#				# Process properties->other_tags into a structure
		#				if($perl_scalar->{'features'}[$f]{'properties'}{'other_tags'}){
		#					$perl_scalar->{'features'}[$f]{'properties'}{'other_tags'} =~ s/\=\>/\:/g;
		#					$perl_scalar->{'features'}[$f]{'properties'}{'other_tags'} = JSON::XS->new->decode("{".$perl_scalar->{'features'}[$f]{'properties'}{'other_tags'}."}");
		#				}
		#				if($n > 0){ print GEO ",\n"; }
		#				print GEO JSON::XS->new->canonical(1)->encode($perl_scalar->{'features'}[$f]);
		#				$n++;
		#			}
		#		}

		`rm $gfile`;

		print "Got $n features so far.\n";
	}
	print GEO "]\n}\n";

	close(CSV);
	close(GEO);
	print "$n features in $ofile\n";

	return;
}
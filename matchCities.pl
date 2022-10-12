#!/usr/bin/perl

use utf8;
use Math::Trig qw(great_circle_distance deg2rad);
use Data::Dumper;
use open qw( :std :encoding(UTF-8) );


open(FILE,"data/admin1CodesASCII.txt");
@lines = <FILE>;
close(FILE);
%admin;
for($i = 1; $i < @lines; $i++){
	$lines[$i] =~ s/[\n\r]//g;
	#code, name, name ascii, geonameid
	($code,$name,$ascii,$id) = split(/\t/,$lines[$i]);
	$admin{$code} = $ascii;
}

open(FILE,"data/admin2Codes.txt");
@lines = <FILE>;
close(FILE);
%admin;
for($i = 1; $i < @lines; $i++){
	$lines[$i] =~ s/[\n\r]//g;
	#code, name, name ascii, geonameid
	($code,$name,$ascii,$id) = split(/\t/,$lines[$i]);
	$admin{$code} = $ascii;
}



%osm;
open(FILE,"planet-boundary.tsv");
@lines = <FILE>;
close(FILE);
for($i = 1; $i < @lines; $i++){
	$lines[$i] =~ s/[\n\r]//g;
	($name,$osmid,$level,$pop,$lon,$lat) = split(/\t/,$lines[$i]);
	if($osmid){
		if(!$osm{$osmid}){
			$osm{$osmid} = {'name'=>$name,'level'=>$level,'pop'=>$pop,'lat'=>$lat,'lon'=>$lon};
		}else{
			print "WARNING: $osmid already exists in OSM.\n";
		}
	}
}

#geonameid         : integer id of record in geonames database
#name              : name of geographical point (utf8) varchar(200)
#asciiname         : name of geographical point in plain ascii characters, varchar(200)
#alternatenames    : alternatenames, comma separated, ascii names automatically transliterated, convenience attribute from alternatename table, varchar(10000)
#latitude          : latitude in decimal degrees (wgs84)
#longitude         : longitude in decimal degrees (wgs84)
#feature class     : see http://www.geonames.org/export/codes.html, char(1)
#feature code      : see http://www.geonames.org/export/codes.html, varchar(10)
#country code      : ISO-3166 2-letter country code, 2 characters
#cc2               : alternate country codes, comma separated, ISO-3166 2-letter country code, 200 characters
#admin1 code       : fipscode (subject to change to iso code), see exceptions below, see file admin1Codes.txt for display names of this code; varchar(20)
#admin2 code       : code for the second administrative division, a county in the US, see file admin2Codes.txt; varchar(80) 
#admin3 code       : code for third level administrative division, varchar(20)
#admin4 code       : code for fourth level administrative division, varchar(20)
#population        : bigint (8 byte int) 
#elevation         : in meters, integer
#dem               : digital elevation model, srtm3 or gtopo30, average elevation of 3''x3'' (ca 90mx90m) or 30''x30'' (ca 900mx900m) area in meters, integer. srtm processed by cgiar/ciat.
#timezone          : the iana timezone id (see file timeZone.txt) varchar(40)
#modification date : date of last modification in yyyy-MM-dd format
%geo;
%geonames;
open(FILE,"data/cities1000.txt");
@lines = <FILE>;
close(FILE);
for($i = 1; $i < @lines; $i++){
	$lines[$i] =~ s/[\n\r]//g;
	($geonameid,$name,$asciiname,$alternatenames,$lat,$lon,$fclass,$fcode,$cc,$cc2,$a1,$a2,$a3,$a4,$pop,$el,$dem,$tz,$date) = split(/\t/,$lines[$i]);
	if($geonameid){
		if(!$geo{$geonameid}){
			if($name && !$geonames{$name}){
				$geonames{$name} = {};
			}
			$geonames{$name}{$geonameid} = 1;
			$admin1 = $cc.".".$a1;
			$admin2 = $cc.".".$a1.".".$a2.".".$a3.".".$a4;
			$admin2 =~ s/\.+$//g;
			$admin2 =~ s/^([^\.]+\.[^\.]+\.[^\.]+)\..*$/$1/g;
			$geo{$geonameid} = {'name'=>$name,'ascii'=>$asciiname,'alternatenames'=>{},'lat'=>$lat,'lon'=>$lon,'pop'=>$pop,'tz'=>$tz,'fclass'=>$fclass,'fcode'=>$fcode,'admin1'=>$admin1,'admin2'=>$admin2};
			@alts = split(/,/,$alternatenames);
			for($a = 0; $a < @alts; $a++){
				$aname = $alts[$a];
				$geo{$geonameid}{'alternatenames'}{$aname} = 1;
				if($aname && !$geonames{$aname}){
					$geonames{$aname} = {};
				}
				$geonames{$aname}{$geonameid} = 1;
			}
		}else{
			print "WARNING: $geonameid already exists in geonames.\n";
		}
	}
}

print "Loaded Geonames\n";


#$geoid = findMatchInGeoNames(5153322);	# Londonderry
#$geoid = findMatchInGeoNames(118362);	# Leeds
#$geoid = findMatchInGeoNames(4818767);	# Horsforth
#$geoid = findMatchInGeoNames(299231);	# Tilburg


open($fh,">","good.tsv");
print $fh "Name\tRegion\tOSM ID\tLevel\tPopulation\tLatitude\tLongitude\n";
$counter = 0;
foreach $osmid (sort(keys(%osm))){
	print "$counter: ";
	$geoid = findMatchInGeoNames($osmid);
	if($geoid ne ""){
		$region = ($admin{$geo{$geoid}{'admin2'}} ? $admin{$geo{$geoid}{'admin2'}} : "");
		$region .= ($admin{$geo{$geoid}{'admin1'}} && $admin{$geo{$geoid}{'admin1'}} ne $admin{$geo{$geoid}{'admin2'}} ? ($region ? ", " : "").$admin{$geo{$geoid}{'admin1'}} : "");
		print $fh "$geo{$geoid}{'ascii'}"."\t$region\t$osmid\t$osm{$osmid}{'level'}\t$geo{$geoid}{'pop'}\t$geo{$geoid}{'lat'}\t$geo{$geoid}{'lon'}\n";
	}
	$counter++;
}
close($fh);

##############################
# 
sub NESW { deg2rad($_[0]), deg2rad(90 - $_[1]) }

sub findMatchInGeoNames {

	my $osmid = $_[0];
	my (@matches,$match,$id,$a,$n,$good,@L,@T,@keep);
	
	$good = "";

	print "Looking for $osm{$osmid}{'name'} ($osmid)... ";

	foreach $id (sort(keys(%{$geonames{$osm{$osmid}{'name'}}}))){
		push(@matches,$id);
	}
	$n = @matches;

	if($n == 1){

		# Check if it is close enough
		@L = NESW($osm{$osmid}{'lon'},$osm{$osmid}{'lat'});
		$id = $matches[0];
		@T = NESW($geo{$id}{'lon'},$geo{$id}{'lat'});
		$km = great_circle_distance(@L, @T, 6378);
		if($km < 30){
			$good = $id;
		}else{
			print "match is $km km away ";
		}

	}elsif($n > 1){

		print "found $n matches ";
		@keep = ();
		@L = NESW($osm{$osmid}{'lon'},$osm{$osmid}{'lat'});
		for($i = 0; $i < @matches; $i++){
			$id = $matches[$i];
			@T = NESW($geo{$id}{'lon'},$geo{$id}{'lat'});
			$km = great_circle_distance(@L, @T, 6378);
			if($km < 30){
				push(@keep,$id);
			}
			print "\n\tDistance for $id: ".sprintf("%0d",$km)."km";
		}
		print "\n";
		$n = @keep;
		if($n == 1){
			$good = $keep[0];
		}elsif($n >1){
			print "Multiple matches for $id:\n";
			print Dumper @keep;
		}
	}

	if($good){
		print $geo{$good}{'ascii'}." ($good) is $geo{$good}{'fclass'}";
	}
	print "\n";
	return $good;
}


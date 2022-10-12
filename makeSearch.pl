#!/usr/bin/perl

use utf8;
use Data::Dumper;
use open qw( :std :encoding(UTF-8) );


%az;

open(FILE,"good.tsv");
@lines = <FILE>;
close(FILE);

for($i = 1; $i < @lines; $i++){
	$lines[$i] =~ s/[\n\r]//g;
	#"Name\tRegion\tOSM ID\tLevel\tPopulation\tLatitude\tLongitude\
	($name,$region,$id,$level,$pop,$lat,$lon) = split(/\t/,$lines[$i]);
	$tname = lc($name);
	$tname =~ s/[\'\`\-\. ]//g;
	$first = substr($tname,0,2);
	if(!$az{$first}){
		$az{$first} = [];
	}
	push(@{$az{$first}},$lines[$i]);
}

foreach $first (sort(keys(%az))){
	$file = "search/$first.tsv";
	print $file."\n";
	open(FILE,">",$file);
	@lines = @{$az{$first}};
	@lines = sort(@lines);
	for($i = 0; $i < @lines; $i++){
		print FILE $lines[$i]."\n";
	}
	close(FILE);
}



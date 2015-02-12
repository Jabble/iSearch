#!/usr/bin/perl 
use strict;
use warnings;

## This script creates a semicolon (;) delimited CSV file with cited document isearch and arxiv ids, and regular expressions for search. 
## The regular expressions include one compiled from the arxiv id and 5 compiled from metadata in $cited_doc_data_file: 
## including authors, venue and year of publication. 

# Define global variables, such as directories and files
my $work_space = "";
my $meta_data = "";
my $cited_doc_data_file = "cited-doc-metadata.csv";
my $cited_doc_regex_file = "cited-doc-regex-values.csv";


# Open input and output files
open (INPUT, '<', $work_space.$meta_data.$cited_doc_data_file) or die "Unable to open $work_space$meta_data$cited_doc_data_file\n";
open (OUTPUT, '>>', $work_space.$meta_data.$cited_doc_regex_file) or warn "Unable to open $work_space$meta_data$cited_doc_regex_file\n"; 
print OUTPUT "cited_isearch_id;cited_arxiv_id;arxiv_regex;key_one;key_two;key_three;key_four;key_five\n";

# Gather field values from each line and create regex
while (<INPUT>) {
	my $line = $_;
	# Omit header
	if ($line =~ /cited_isearch_id/) {
		next;
	}
	
	my ($cited_isearch_id,$cited_arxiv_id,$cited_title,$cited_authors,$cited_venue,$cited_year,$raw_xml_file) = Extract_Csv_Field_Values($line);
	my ($arxiv_regex) = Create_Arxiv_Id_Regex($cited_arxiv_id);
	my ($key_one, $key_two, $key_three, $key_four, $key_five) = Return_Clusterkeys($cited_authors,$cited_venue,$cited_year);
	
	print "Writing: $cited_isearch_id\n";
	print OUTPUT "$cited_isearch_id;$cited_arxiv_id;$arxiv_regex;$key_one;$key_two;$key_three;$key_four;$key_five\n";
}


close INPUT;
close OUTPUT;


###SUBROUTINES###

# Subroutine to extract values for 7 comma delimited fields
sub Extract_Csv_Field_Values{
	my ($line) = @_;
	my ($isearch_id, $arxiv_id, $title, $authors, $venue, $year, $xml_file) = "";
	if ($line =~ /(.*)\,(.*)\,(.*)\,(.*)\,(.*)\,(.*)\,(.*)$/) {
		$isearch_id = $1;
		$arxiv_id = $2;
		$title = $3;
		$authors = $4;
		$venue = $5;
		$year = $6;
		$xml_file = $7;
	}
	return ($isearch_id,$arxiv_id,$title,$authors,$venue,$year,$xml_file);
}

# Subroutine to create a regular expression from an arxiv id
sub Create_Arxiv_Id_Regex{
	my ($arxiv_id) = @_;
	my $arxiv_regex = "null";
	# ([a-z]+)(\.|\-|\/)([a-z]+|[0-9]+)(\.|\-|\/)*([a-z]+|[0-9]+)*/
	if ($arxiv_id =~ /^([0-9]+)(\.|\-|\/)([0-9]+)$/) {
		$arxiv_regex = "$1.{0,1}$3";
	} elsif ( $arxiv_id =~ /^([a-z]+)(\.|\-|\/)([a-z]+|[0-9]+)(\.|\-|\/)([0-9]+)$/) {
		$arxiv_regex = "$1.{0,1}$3.{0,1}$5";
	} elsif ( $arxiv_id =~ /^([a-z]+)(\.|\-|\/)([0-9]+)$/) {
		$arxiv_regex = "$1.{0,1}$3"; 
	}
	return ($arxiv_regex);
}

# Subroutine to compile regex clusterkeys
sub Return_Clusterkeys{
	my ($authors,$venue,$year) = @_;
	my ($author_one, $author_two, $author_three) = Split_Authors($authors);
	my ($venue_one_short, $venue_one_long) = Extract_Venue($venue);
	my ($year_lax, $year_strict) = Extend_Year($year);
	my (@cluster_keys) = Define_Cluster_Keys($author_one, $author_two, $author_three, $venue_one_short, $venue_one_long, $year_lax, $year_strict);
	return (@cluster_keys);
}

# Subrountine to extract first three author last names seperated by '||'
sub Split_Authors{
	my ($sub_authors) = @_;
	my $author_one = "null";
	my $author_two = "null";
	my $author_three = "null";
	
	if ($sub_authors =~ /(\S*)\;(.*?\|\|\s*(\S*)\;){0,1}(.*?\|\|\s*(\S*)\;){0,1}/) {
		if ($1 eq "") {
			print "no author last name found.\n";
		}
		else {
			$author_one = $1;
		}
		
		if (defined $3) {
			$author_two = $3;
			}
		if (defined $5) {
			$author_three = $5;
			}
	}
	return ($author_one, $author_two, $author_three);
}

# Subroutine to extract the first two capital letters of the first venue name into $venue_one_short and the first two capital letters followed by a lowercase letter for $venue_one_long
sub Extract_Venue{
	my ($sub_venue) = @_;
	my $venue_one_short = "null";
	my $venue_one_long = "null";
#	my $sub_venue_two_short = "null";
#	my $sub_venue_two_long = "null";
	if ($sub_venue =~ /^\s*(([A-Z])[a-z]{0,1}).*?(([A-Z])[a-z]{0,1}).*/) {
		$venue_one_short = "$2.*?$4";
		$venue_one_long = "$1.*?$3";
	}
	# This portion can extend the extraction to the first three capital letters, each optionally also followed by a lowercase letter
#	if ($sub_venue =~ /\|\|\s*(([A-Z])[a-z]{0,1}).*?(([A-Z])[a-z]{0,1}).*?(([A-Z])[a-z]{0,1}){0,1}.*/) {
#		$sub_venue_two_short = "$2.*?$4";
#		$sub_venue_two_long = "$1.*?$3";
#	}

	return ($venue_one_short, $venue_one_long);
}

# Subroutine to create a regular expression containing '(year-1|year|year+1)' for $year_lax and return the original year for $year_strict
sub Extend_Year {
	my ($year) = @_;
	my $year_lax = "";
	my $year_strict = "";
	if ($year =~ /^\d+$/) {
		my $year_minus = $year-1;
		my $year_plus = $year+1;
		$year_lax = "($year_minus|$year|$year_plus)";
		$year_strict = "$year";
	} 
	else {
		$year_lax = "null";
		$year_strict = "null";
	}
	return ($year_lax, $year_strict);
}

# Subroutine to define how regular expression keys are composed
sub Define_Cluster_Keys{
	my ($author_one, $author_two, $author_three, $venue_one_short, $venue_one_long, $year_lax, $year_strict) = @_;
	my $key_simple_one = "";
	my $key_simple_two = "";
	my $key_lax = "";
	my $key_moderate = "";
	my $key_strict = "";
	
	($key_simple_one) = Combine_Into_Key($author_one, $year_lax);	
		
	if ($author_two ne "null") {
		($key_simple_two) = Combine_Into_Key($author_two, $year_lax);
		($key_lax) =  Combine_Into_Key($author_two, $venue_one_short, $year_lax);
		($key_moderate) = Combine_Into_Key($author_two, $author_three, $venue_one_short, $year_lax);
		($key_strict) = Combine_Into_Key($author_two, $author_three, $venue_one_short, $year_strict);
	} else {
		($key_simple_two) = Combine_Into_Key($author_one, $year_strict);
		($key_lax) =  Combine_Into_Key($author_one, $venue_one_short, $year_lax);
		($key_moderate) = Combine_Into_Key($author_one, $venue_one_short, $year_strict);
		($key_strict) = Combine_Into_Key($author_one, $venue_one_long, $year_strict);
	}
	return ($key_simple_one, $key_simple_two, $key_lax, $key_moderate, $key_strict);
}

# Subroutine to join variables in an array that are not "null" into a string separated by '.*?' to form a regular expression key
sub Combine_Into_Key {
	my (@array) = @_;
	my @non_null = ();
	my $key = "";
	foreach my $index (0 .. $#array) {
		unless ($array[$index] eq "null") {
			push(@non_null, $array[$index]);
		}
		else {
			next;
		}
	}
	$key = join ('.*?', @non_null);
	return $key;
}





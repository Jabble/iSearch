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
my $cited_doc_regex_file = "Documents/Meta/cited-doc-regex-values.csv";


# Open input and output files
open (INPUT, '<', $work_space.$meta_data.$cited_doc_data_file) or die "Unable to open $work_space$meta_data$cited_doc_data_file\n";
open (OUTPUT, '>>', $work_space.$meta_data.$cited_doc_regex_file) or warn "Unable to open $work_space$meta_data$cited_doc_regex_file\n"; 
print OUTPUT "cited_isearch_id;cited_arxiv_id;arxiv_regex;key_one;key_two;key_three;key_four;key_five\n";


while (<INPUT>) {
	my $line = $_;
	#omits header
	if ($line =~ /cited_isearch_id/) {
		next;
	}
	
	my ($cited_isearch_id,$cited_arxiv_id,$cited_title,$cited_authors,$cited_venue,$cited_year,$raw_xml_file) = Extract_Csv_Field_Values($line);
	print "Checking: $cited_isearch_id\n";
	my ($arxiv_regex) = Create_Arxiv_Id_Regex($cited_arxiv_id);
	my ($key_one, $key_two, $key_three, $key_four, $key_five) = Return_Cluster_Keys($cited_authors,$cited_venue,$cited_year);
	print OUTPUT "$cited_isearch_id;$cited_arxiv_id;$arxiv_regex;$key_one;$key_two;$key_three;$key_four;$key_five\n";
}


close INPUT;
close OUTPUT;

###SUBROUTINES###
# Given a line, extracts values for 7 comma delimited fields.
sub Extract_Csv_Field_Values{
	my ($sub_line) = @_;
	my ($isearch_id, $arxiv_id, $title, $authors, $venue, $year, $xml_file) = "";
	if ($sub_line =~ /(.*)\,(.*)\,(.*)\,(.*)\,(.*)\,(.*)\,(.*)$/) {
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

# Creates a regular expression from an arxiv id.
sub Create_Arxiv_Id_Regex{
	my ($arxiv_id) = @_;
	my $regex_id = "null";
	# ([a-z]+)(\.|\-|\/)([a-z]+|[0-9]+)(\.|\-|\/)*([a-z]+|[0-9]+)*/
	if ($arxiv_id =~ /^([0-9]+)(\.|\-|\/)([0-9]+)$/) {
		$regex_id = "$1.{0,1}$3";
	} elsif ( $arxiv_id =~ /^([a-z]+)(\.|\-|\/)([a-z]+|[0-9]+)(\.|\-|\/)([0-9]+)$/) {
		$regex_id = "$1.{0,1}$3.{0,1}$5";
	} elsif ( $arxiv_id =~ /^([a-z]+)(\.|\-|\/)([0-9]+)$/) {
		$regex_id = "$1.{0,1}$3"; 
	}
	return ($regex_id);
}

# Calls other subroutines to extract information and return regular expression keys.
sub Return_Cluster_Keys{
	my ($authors,$venue,$year) = @_;
	my ($author_one, $author_two, $author_three) = Extract_Authors($authors);
	my ($venue_one_short, $venue_one_long) = Extract_Venue($venue);
	my ($year_lax, $year_strict) = Extend_Year($year);
	my (@cluster_keys) = Define_Cluster_Keys($author_one, $author_two, $author_three, $venue_one_short, $venue_one_long, $year_lax, $year_strict);
	return (@cluster_keys);
}


# Defines how regular expression keys are composed.
sub Define_Cluster_Keys{
	my ($sub_author_one, $sub_author_two, $sub_author_three, $sub_venue_one_short, $sub_venue_one_long, $sub_year_lax, $sub_year_strict) = @_;
	my $sub_key_simple_one = "";
	my $sub_key_simple_two = "";
	my $sub_key_lax = "";
	my $sub_key_moderate = "";
	my $sub_key_strict = "";
	
	($sub_key_simple_one) = Combine_Into_Key($sub_author_one, $sub_year_lax);	
		
	if ($sub_author_two ne "null") {
		($sub_key_simple_two) = Combine_Into_Key($sub_author_two, $sub_year_lax);
		($sub_key_lax) =  Combine_Into_Key($sub_author_two, $sub_venue_one_short, $sub_year_lax);
		($sub_key_moderate) = Combine_Into_Key($sub_author_two, $sub_author_three, $sub_venue_one_short, $sub_year_lax);
		($sub_key_strict) = Combine_Into_Key($sub_author_two, $sub_author_three, $sub_venue_one_short, $sub_year_strict);
	} else {
		($sub_key_simple_two) = Combine_Into_Key($sub_author_one, $sub_year_strict);
		($sub_key_lax) =  Combine_Into_Key($sub_author_one, $sub_venue_one_short, $sub_year_lax);
		($sub_key_moderate) = Combine_Into_Key($sub_author_one, $sub_venue_one_short, $sub_year_strict);
		($sub_key_strict) = Combine_Into_Key($sub_author_one, $sub_venue_one_long, $sub_year_strict);
	}
	return ($sub_key_simple_one, $sub_key_simple_two, $sub_key_lax, $sub_key_moderate, $sub_key_strict);
}

# Given an  array of variables, joins variables that are not "null" into a string separated by '.*?' to form a regular expression key.
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

# Given a variable with authors listed by lastname; first name and seperated by '||', extracts first three author last names.
sub Extract_Authors{
	my ($sub_authors) = @_;
	my $sub_author_one = "null";
	my $sub_author_two = "null";
	my $sub_author_three = "null";
	if ($sub_authors =~ /(\S*)\;(.*?\|\|\s*(\S*)\;){0,1}(.*?\|\|\s*(\S*)\;){0,1}/) {
		if ($1 eq "") {
			print "no author last name found.\n";
			}
			else {
				$sub_author_one = $1;
			}
		if (defined $3) {
			$sub_author_two = $3;
			}
		if (defined $5) {
			$sub_author_three = $5;
			}
	}
	return ($sub_author_one, $sub_author_two, $sub_author_three);
}

# Given a variable with publication venue information, extracts the first two capital letters of the venue name into $sub_venue_one_short and the first two capital letters followed by one lowercase letter for $sub_venue_one_long.
sub Extract_Venue{
	my ($sub_venue) = @_;
	my $sub_venue_one_short = "null";
	my $sub_venue_one_long = "null";
#	my $sub_venue_two_short = "null";
#	my $sub_venue_two_long = "null";
	if ($sub_venue =~ /^\s*(([A-Z])[a-z]{0,1}).*?(([A-Z])[a-z]{0,1}).*/) {
		$sub_venue_one_short = "$2.*?$4";
		$sub_venue_one_long = "$1.*?$3";
	}
	# This portion can extend the extraction to the first three capital letters, each optionally also followed by a lowercase letter.
#	if ($sub_venue =~ /\|\|\s*(([A-Z])[a-z]{0,1}).*?(([A-Z])[a-z]{0,1}).*?(([A-Z])[a-z]{0,1}){0,1}.*/) {
#		$sub_venue_two_short = "$2.*?$4";
#		$sub_venue_two_long = "$1.*?$3";
#	}
	#print "$sub_venue_one_short, $sub_venue_one_long\n";
	return ($sub_venue_one_short, $sub_venue_one_long);
}

# Given a variable, checks if it contains digits. If so creates a regular expression containing 'year-1|year|year+1' for $sub_year_lax and returns the original year for $sub_year_strict.
sub Extend_Year {
	my ($sub_year) = @_;
	my $sub_year_lax = "";
	my $sub_year_strict = "";
	if ($sub_year =~ /^\d+$/) {
		my $sub_year_minus = $sub_year-1;
		my $sub_year_plus = $sub_year+1;
		$sub_year_lax = "($sub_year_minus|$sub_year|$sub_year_plus)";
		$sub_year_strict = "$sub_year";
	} else {
		$sub_year_lax = "null";
		$sub_year_strict = "null";
	}
	return ($sub_year_lax, $sub_year_strict);
}

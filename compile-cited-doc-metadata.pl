#!/usr/bin/perl 
use strict;
use warnings;

## This script extracts unique cited iSearch ids from $direct_cits_csv_file and opens each iSearch XML document with the matching id to extract metadata. 
## It then writes to $cited_doc_data_file: cited_isearch_id,cited_arxiv_id,cited_title,cited_authors,cited_venue,cited_year,raw_xml_file

# Define global variables, such as directories and files
my $work_space = "/data/local/workspace/students/anna-E2013/";
my $meta_data = "Documents/Meta/";
my $isearch_xml_data = "Documents/PF+PN_Collection/XML/PF+PN/";
my $direct_cits_csv_file = "";
my $cited_doc_id_file = "cited-doc-ids-unique.txt";
my $cited_doc_data_file = "cited-doc-metadata.csv";

# Use a system call to take data from $direct_cits_csv_file and create a file $cited_doc_id_file with citation counts and unique cited isearch ids 
system ("cut -d ',' -f 2-  $work_space$meta_data$direct_cits_csv_file | sort | uniq -c $work_space$meta_data$cited_doc_id_file");

# Open input and output files
open (INPUT, '<', $work_space.$meta_data.$cited_doc_id_file) or die "Unable to open $work_space$meta_data$cited_doc_id_file\n";
open (OUTPUT, '>>', $work_space.$meta_data.$cited_doc_data_file ) or warn "Unable to open $work_space$cited_doc_data_file\n"; 
print OUTPUT "cited_isearch_id,cited_arxiv_id,cited_title,cited_authors,cited_venue,cited_year,raw_xml_file\n";

# Find document metadata for each cited iSearch id
while (<INPUT>) {
	my $cited_isearch_id = "";
	
	if ($_ =~ /((PN|PF)[0-9]{6})/) {
		$cited_isearch_id = $1;
	}
	else {
		next;
	}

	my $xml_file = $work_space.$isearch_xml_data.$cited_isearch_id.".xml";
	
	my ($cited_arxiv_id, $cited_title, $cited_authors, $cited_venue, $cited_year) = Compile_Cited_Doc_Metadata($xml_file);
		
	print "Writing data for: $cited_isearch_id\n";
	print OUTPUT "$cited_isearch_id,$cited_arxiv_id,$cited_title,$cited_authors,$cited_venue,$cited_year,$xml_file\n";
}

close INPUT;
close OUTPUT;


###SUBROUTINES###
sub Compile_Cited_Doc_Metadata{
	my ($file) = @_;
	my $sub_arxiv_id = Find_Xml_Id($file);
	my $sub_title = Find_Xml_Title($file);
	my $sub_authors = Find_Xml_Authors($file);
	my $sub_venue = Find_Xml_Venue($file);
	my $sub_year = Parse_Year($sub_venue);
	return ($sub_arxiv_id, $sub_title, $sub_authors, $sub_venue, $sub_year);
}

sub Find_Xml_Id{
	my ($file) = @_;
	my $arxiv_id = "";
	open (SUBIN, '<', $file) or warn "Unable to open $file\n";
		while (<SUBIN>) {
			my $line = $_;
			if ($line =~/<DOCUMENTLINK>\s(.*?)\s<\/DOCUMENTLINK>/) {
				$arxiv_id  = $1;
				last;
			}
		}
	close SUBIN;
	# extract arxiv id from URL
	if ($arxiv_id =~ /http:\/\/arxiv.org\/abs\/(.*)/) {
		$arxiv_id = $1;
	}
	return $arxiv_id;
}

sub Find_Xml_Title{
	my ($file) = @_;
	my $title = "";
	my $flag = 0;
	open (SUBIN, '<', $file) or warn "Unable to open $file\n";
		while (<SUBIN>) {
			my $line = $_;
			if ($line =~/<TITLE>\s([^<\n]*)/) {
				$title = $1;
				# remove ','s
				$title =~ s/,//g;
				unless ($line =~/<\/TITLE>/) {
					$flag = 1;
					next;
				} else { 
					last;
				}
			}
			elsif ($flag ==1) {
				if ($line =~/([^<\n]*)/) {
					$title = $title." ".$1;
					# remove ','s
					$title =~ s/,//g;
				}
				if ($line =~/<\/TITLE>/) {
					$flag = 0;
					last;
				}
			}
		}
	close SUBIN;
	return $title;
}

sub Find_Xml_Authors{
	my ($file) = @_;
	my $authors = "";
	my $flag = 0;
	open (SUBIN, '<', $file) or warn "Unable to open $file\n";
		while (<SUBIN>) {
			my $line = $_;
			if ($line =~/<AUTHOR>\s([^<\n]*)/) {
				$authors = $1;
				# change ','s to ';'s
				$authors =~ s/,/;/g;
				unless ($line =~/<\/AUTHOR>/) {
					$flag = 1;
					next;
				} else { 
					last;
				}
			}
			elsif ($flag ==1) {
				if ($line =~/([^<\n]*)/) {
					$authors = $authors."||".$1;
					# change ','s to ';'s
					$authors =~ s/,/;/g;
				}
				if ($line =~/<\/AUTHOR>/) {
					$flag = 0;
					last;
				}
			}
		}
	close SUBIN;
	return $authors;
}

sub Find_Xml_Venue{
	my ($file) = @_;
	my $venue = "";
	open (SUBIN, '<', $file) or warn "Unable to open $file\n";
		while (<SUBIN>) {
			my $line = $_;
			if ($line =~/<VENUE>\s(.*?)\s<\/VENUE>/) {
				$venue  = $1;
				# remove ','s 
				$venue =~ s/,//g;
				# checks twice if $venue contains "&amp;" between anything, and changes to '&'
				my $count = 0;
				while ($count < 2) {
					if ($venue =~/(.+)\&amp\;(.+)/) {
						$venue = $1."&".$2;
					}
					$count++;
				}
				# if $venue contains ';' followed by an optional space and at least one letter, change to '||'
				if ($venue =~/(.+)\;\s*(([A-Z]|[a-z]).+)/) {
					$venue = $1."||".$2;
				}
				last;
			}
		}
	close SUBIN;
	return $venue;
}

sub Parse_Year{
	my ($venue) = @_;
	my $year = "";
	# extract year between 1970 and 2019 preceded by space or open bracket, and followed by space or closed bracket
	if  ($venue =~ /(\s|\(|\[|\/)(19[7-9][0-9]|20[0-1][0-9])(\s|\)|\])/) {
		$year = $2;
	} 
	# extract year between 1970 and 2019 preceded by a space or at least 2 numbers, and followed by '.' or end of string
	elsif ($venue =~ /(\s|[0-9]{2})(19[7-9][0-9]|20[0-1][0-9])(\.|$)/) {
		$year = $2;
	}
	return ($year);
}

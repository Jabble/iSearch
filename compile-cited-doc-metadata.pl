#!/usr/bin/perl 
use strict;
use warnings;
use File::Slurp;

## This script extracts unique cited iSearch ids from $cited_docs_file and opens each iSearch XML document with the matching id to extract information. 
## It then writes to $cited_doc_data_file: cited_isearch_id,cited_arxiv_id,cited_title,cited_authors,cited_venue,cited_year,raw_xml_file

# Define global variables, such as directories and files
my $work_space = "";
my $meta_data = "";
my $isearch_xml_data = "";
my $direct_cits_csv_file = "direct-citations.csv";
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
	my @file_contents = read_file($file);
	my $arxiv_id = "";
	my $title = "";
	my $multiline_title = 0;
	my $authors = "";
	my $multiline_authors = 0;
	my $venue = "";
	
	foreach my $line (@file_contents) {
		if ($line =~ /<FULLTEXT>/) {
			last;
		}
		
		$arxiv_id = Find_Xml_Id($arxiv_id, $line);
		($multiline_title, $title) = Find_Xml_Title($multiline_title, $title, $line);
		($multiline_authors, $authors) = Find_Xml_Authors($multiline_authors, $authors, $line);
		$venue = Find_Xml_Venue($venue,$line);
	}
	my $year = Parse_Year($venue);
	return ($arxiv_id, $title, $authors, $venue, $year);
}

sub Find_Xml_Id{
	my ($arxiv_id,$line) = @_;

	if ($line =~/<DOCUMENTLINK>\s(.*?)\s<\/DOCUMENTLINK>/) {
		$arxiv_id  = $1;
		# extract arxiv id from URL
		$arxiv_id =~ s/http:\/\/arxiv.org\/abs\/(.*)/$1/;
	}
	return $arxiv_id;
}

sub Find_Xml_Title{
	my ($multiline_title,$title,$line) = @_;
	
	if ($multiline_title) {
		if ($line =~/^([^<]*)<\/TITLE>/) {
			$title = $title." ".$1;
			$title =~ s/,//g;
			$multiline_title = 0;
		}
		elsif ($line =~/^([^<]*)$/) {
			$title = $title." ".$1;
			$title =~ s/,//g;
		}
		
	}
	elsif ($line =~/<TITLE>\s([^<\n]*)/) {
		$title = $1;
		$title =~ s/,//g;
		
		unless ($line =~/<\/TITLE>/) {
			$multiline_title = 1;
		}
	}
	return ($multiline_title,$title);
}

sub Find_Xml_Authors{
	my ($multiline_authors, $authors, $line) = @_;
	
	if ($multiline_authors) {
		if ($line =~/^([^<]*)<\/AUTHOR>/) {
			$authors = $authors."||".$1;
			# change ','s to ';'s
			$authors =~ s/,/;/g;
			$multiline_authors = 0;
		}
		elsif ($line =~/^([^<]*)$/) {
			$authors = $authors."||".$1;
			# change ','s to ';'s
			$authors =~ s/,/;/g;
		}
	}
	
	elsif ($line =~/<AUTHOR>\s([^<\n]*)/) {
		$authors = $1;
		# change ','s to ';'s
		$authors =~ s/,/;/g;
		
		unless ($line =~/<\/AUTHOR>/) {
			$multiline_authors = 1;
		}
	}
	return ($multiline_authors, $authors);
}

sub Find_Xml_Venue{
	my ($venue,$line) = @_;
	
	if ($line =~/<VENUE>\s(.*?)\s<\/VENUE>/) {
		$venue  = $1;
		# remove ',' 
		$venue =~ s/,//g;
		# replace '&amp;' with '&'
		$venue =~ s/(.+)\&amp\;(.+)/$1&$2/g;
		# replace ';' with '||'
		$venue =~ s/(.+)\;\s*(([A-Z]|[a-z]).+)/$1||$2/g;
	}
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

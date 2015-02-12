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

	my $xml_filepath = $work_space.$isearch_xml_data.$cited_isearch_id.".xml";
	
	my ($cited_arxiv_id, $cited_title, $cited_authors, $cited_venue, $cited_year) = Compile_Cited_Doc_Metadata($xml_filepath);
		
	print "Writing data for: $cited_isearch_id\n";
	print OUTPUT "$cited_isearch_id,$cited_arxiv_id,$cited_title,$cited_authors,$cited_venue,$cited_year,$xml_file\n";
}

close INPUT;
close OUTPUT;


###SUBROUTINES###

# Subroutine to compile and return metadata for an iSearch XML file
sub Compile_Cited_Doc_Metadata{
	my ($filepath) = @_;
	my @file_contents = read_file($filepath); # Read in file as an array of lines
	my $arxiv_id = "";
	my $title = "";
	my $multiline_title = 0; # Set flag for title across multiple lines 0
	my $authors = "";
	my $multiline_authors = 0; # Set flag for author names across multiple lines 0
	my $venue = "";
	
	# Read throough array of file lines and look for metadata until <FULLTEXT> is encountered
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

# Subroutine to extract ArXiv.org document id from file metadata
sub Find_Xml_Id{
	my ($arxiv_id, $line) = @_;
	
	# save URL and get id
	if ($line =~/<DOCUMENTLINK>\s(.*?)\s<\/DOCUMENTLINK>/) {
		$arxiv_id  = $1;
		# extract arxiv id from URL
		$arxiv_id =~ s/http:\/\/arxiv.org\/abs\/(.*)/$1/;
	}
	return $arxiv_id;
}

# Subroutine to extract document title from file metadata
sub Find_Xml_Title{
	my ($multiline_title, $title, $line) = @_;
	
	# check if title is multiple lines long
	if ($multiline_title) {
		# save title that ends on line and remove flag
		if ($line =~/^([^<]*)<\/TITLE>/) {
			$title = $title." ".$1;
			$title =~ s/,//g;
			$multiline_title = 0;
		}
		# otherwise save line of title
		elsif ($line =~/^([^<]*)$/) {
			$title = $title." ".$1;
			$title =~ s/,//g;
		}
		
	}
	# save line with start of title
	elsif ($line =~/<TITLE>\s([^<\n]*)/) {
		$title = $1;
		$title =~ s/,//g;
		
		# if title does not end on line, set flag
		unless ($line =~/<\/TITLE>/) {
			$multiline_title = 1;
		}
	}
	return ($multiline_title, $title);
}

# Subroutine to extract document author names from file metadata
sub Find_Xml_Authors{
	my ($multiline_authors, $authors, $line) = @_;
	
	# check if author names are multiple lines long
	if ($multiline_authors) {
		# save names that end on line and remove flag
		if ($line =~/^([^<]*)<\/AUTHOR>/) {
			$authors = $authors."||".$1;
			# change ','s to ';'s
			$authors =~ s/,/;/g;
			$multiline_authors = 0;
		}
		# otherwise save line of author names
		elsif ($line =~/^([^<]*)$/) {
			$authors = $authors."||".$1;
			# change ','s to ';'s
			$authors =~ s/,/;/g;
		}
	}
	# save line with start of author names
	elsif ($line =~/<AUTHOR>\s([^<\n]*)/) {
		$authors = $1;
		# change ','s to ';'s
		$authors =~ s/,/;/g;
		
		# if authors do not end on line, set flag
		unless ($line =~/<\/AUTHOR>/) {
			$multiline_authors = 1;
		}
	}
	return ($multiline_authors, $authors);
}

# Subroutine to extract document publication venue from file metadata
sub Find_Xml_Venue{
	my ($venue,$line) = @_;
	
	# save publication venue
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

# Subroutine to identify year in extracted document publication venue
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

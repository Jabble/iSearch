#!/usr/bin/perl 
use strict;
use warnings;

## This script removes double quotes ("") from a direct citation data file $direct_cits_txt_file, and writes $citing_id,$cited_id to $direct_cits_csv_file.


# Define global variables with directory path and files here.
my $work_space = "/"; # directory path (make sure to include '/' at then end of the path)
my $direct_cits_txt_file = ""; # direct citation TXT filename for INPUT
my $direct_cits_csv_file = "direct-citations.csv"; #direct citation CSV filename for OUTPUT

# Alternatively, take directory path and files as commandline input (make sure to include '/' at then end of the path)
#my ($work_space, $direct_cits_txt_file, $direct_cits_csv_file) = @ARGV;
#
#if (not defined $direct_cits_csv_file) {
#  die "Need directory path, direct citation .txt filename, and your .csv filename \n";
#}
# 
#if (defined $direct_cits_csv_file) {
#  print "Reading '$work_space$direct_cits_txt_file' and writing to '$direct_cits_csv_file'\n";
#}

# Open input and output files
open (INPUT, '<', $work_space.$direct_cits_txt_file) or die "Unable to open $work_space$direct_cits_txt_file\n";
open (OUTPUT, '>>', $work_space.$direct_cits_csv_file) or die "Unable to open $work_space$direct_cits_csv_file\n";
print OUTPUT "citing_isearch_id,cited_isearch_id\n";

# Read each line of $direct_cits_txt_file and write '$citing_id,$cited_id' to $direct_cits_csv_file
while (<INPUT>) {
	unless ($_ =~ /P.*?/) {
		next;
	}
	
	if ($_ =~ /\"(.+?)\",\"(.+?)\"/) {
		my $citing_id = $1;
		my $cited_id = $2;
		print OUTPUT "$citing_id,$cited_id\n";
	}
}
close INPUT;
close OUTPUT;
exit

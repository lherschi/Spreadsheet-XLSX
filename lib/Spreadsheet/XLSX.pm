package Spreadsheet::XLSX;

use 5.008008;
use strict;
use warnings;

our @ISA = qw();

our $VERSION = '0.01';

use Archive::Zip;

use Data::Dumper;

################################################################################

sub new {

	my ($class, $filename, $converter) = @_;
	
	my $self = {};
	
	$self -> {zip} = Archive::Zip -> new ($filename) or die ("Cant't open $filename as a zip file\n");	
	
	my $member_shared_strings = $self -> {zip} -> memberNamed ('xl/sharedStrings.xml');
	
	my @shared_strings = ();

	if ($member_shared_strings) {
	
		foreach my $t ($member_shared_strings -> contents =~ /t\>([^\<]*)\<\/t/gsm) {
			
			$t = $converter -> convert ($t) if $converter;
			
			push @shared_strings, $t;
		
		}
	
	}
		
	my $member_workbook = $self -> {zip} -> memberNamed ('xl/workbook.xml') or die ("xl/workbook.xml not found in this zip\n");
			
	my @Worksheet = ();
	
	foreach ($member_workbook -> contents =~ /\<(.*?)\/?\>/g) {
	
		/^(\w+)\s+/;
		
		my ($tag, $other) = ($1, $');

		my @pairs = split /\" /, $other;

		$tag eq 'sheet' or next;
		
		my $sheet = {
			MaxRow => 0,
			MaxCol => 0,
			MinRow => 1000000,
			MinCol => 1000000,
		};
		
		foreach ($other =~ /(\w+\=\".*?\")/gsm) {

			my ($k, $v) = split /\=?\"/;
	
			if ($k eq 'name') {
				$sheet -> {Name} = $v;
				$sheet -> {Name} = $converter -> convert ($sheet -> {Name}) if $converter;
			}
			elsif ($k eq 'sheetId') {
				$sheet -> {Id} = $v
			};
					
		}
		
		push @Worksheet, $sheet;
				
	}

	$self -> {Worksheet} = \@Worksheet;
	
	foreach my $sheet (@Worksheet) {
	
		my $member_name  = "xl/worksheets/sheet$sheet->{Id}.xml";
	
		my $member_sheet = $self -> {zip} -> memberNamed ($member_name) or die ("$member_name not found in this zip\n");
	
		my ($row, $col);
		
		my $flag = 0;
		my $s    = 0;
		
		foreach ($member_sheet -> contents =~ /(\<.*?\/?\>|.*?(?=\<))/g) {
		
			if (/^\<c r=\"([A-Z])([A-Z]?)(\d+)\"/) {
				
				$col = ord ($1) - 65;
				
				if ($2) {		
					$col *= 26;
					$col += (ord ($2) - 65);
				}
				
				$row = $3 - 1;
				
				$s = /t=\"s\"/ ? 1 : 0;
				
			}
			elsif (/^<v/) {
				$flag = 1;
			}
			elsif (/^<\/v/) {
				$flag = 0;
			}
			elsif ($_ && $flag) {
			
				my $v = $s ? $shared_strings [$_] : $_;
			
				$sheet -> {MaxRow} = $row if $sheet -> {MaxRow} < $row;
				$sheet -> {MaxCol} = $col if $sheet -> {MaxCol} < $col;
				$sheet -> {MinRow} = $row if $sheet -> {MinRow} > $row;
				$sheet -> {MinCol} = $col if $sheet -> {MinCol} > $col;
				
				$sheet -> {Cells} [$row] [$col] = {

					Val    => $v,
					_Value => $v,
					
				};
			
			}
					
		}
		
		$sheet -> {MinRow} = 0 if $sheet -> {MinRow} > $sheet -> {MaxRow};
		$sheet -> {MinCol} = 0 if $sheet -> {MinCol} > $sheet -> {MaxCol};

	}
	
	bless ($self, $class);

	return $self;

}

1;
__END__

=head1 NAME

Spreadsheet::XLSX - Perl extension for reading MS Excel 2007 files;

=head1 SYNOPSIS

 use Text::Iconv;
 my $converter = Text::Iconv -> new ("utf-8", "windows-1251");
 
 # Text::Iconv is not really required.
 # This can be any object with the convert method. Or nothing.

 use Spreadsheet::XLSX;
 
 my $excel = Spreadsheet::XLSX -> new ('test.xlsx', $converter);
 
 foreach my $sheet (@{$excel -> {Worksheet}}) {
 
 	printf("Sheet: %s\n", $sheet->{Name});
 	
 	$sheet -> {MaxRow} ||= $sheet -> {MinRow};
 	
         foreach my $row ($sheet -> {MinRow} .. $sheet -> {MaxRow}) {
         
 		$sheet -> {MaxCol} ||= $sheet -> {MinCol};
 		
 		foreach my $col ($sheet -> {MinCol} ..  $sheet -> {MaxCol}) {
 		
 			my $cell = $sheet -> {Cells} [$row] [$col];
 
 			if ($cell) {
 			    printf("( %s , %s ) => %s\n", $row, $col, $cell -> {Val});
 			}
 
 		}
 
 	}
 
 }

=head1 DESCRIPTION

This module is a (quick and dirty) emulation of Spreadsheet::ParseExcel for 
Excel 2007 (.xlsx) file format.

=head1 SEE ALSO

=over 2

=item Text::CSV_XS, Text::CSV_PP

http://search.cpan.org/~hmbrand/

A pure perl version is available on http://search.cpan.org/~makamaka/

=item Spreadsheet::ParseExcel

http://search.cpan.org/~kwitknr/

=item Spreadsheet::ReadSXC

http://search.cpan.org/~terhechte/

=item Spreadsheet::BasicRead

http://search.cpan.org/~gng/ for xlscat likewise functionality (Excel only)

=item Spreadsheet::ConvertAA

http://search.cpan.org/~nkh/ for an alternative set of cell2cr () /
cr2cell () pair

=item Spreadsheet::Perl

http://search.cpan.org/~nkh/ offers a Pure Perl implementation of a
spreadsheet engine. Users that want this format to be supported in
Spreadsheet::Read are hereby motivated to offer patches. It's not high
on my todo-list.

=item xls2csv

http://search.cpan.org/~ken/ offers an alternative for my C<xlscat -c>,
in the xls2csv tool, but this tool focusses on character encoding
transparency, and requires some other modules.

=item Spreadsheet::Read

http://search.cpan.org/~hmbrand/ read the data from a spreadsheet (interface 
module)

=back

=head1 AUTHOR

Dmitry Ovsyanko, E<lt>do@eludia.ru<gt>, http://eludia.ru/wiki/

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by root

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Getopt::Long;
use Data::Dumper;
use DBD::SQLite;
use IO::Handle;
use Term::ProgressBar;
use autodie qw/open/;

binmode(STDOUT, ':encoding(utf8)');

my $fh = \*STDIN;
my %opts = (
    'regex'    => '^(?<name>[^:]+):(?<password>[^:]+)',
    'file'     => '/etc/passwd',
    'report'   => '/run/shm/logparser-cmd.db',
    'table'    => 'parser'
);

GetOptions (\%opts, 'table|t=s', 'report|r=s', 'file|f=s', 'regex|r=s', 'help|h');
&help if $opts{help};
    
my $dbh = DBI->connect ("dbi:SQLite:dbname=" . $opts{report}, "", "", {RaiseError => 1});
my $table_created = 0;

#####

sub parse_line
{
    my ($line) = @_;
    if ($line =~ /$opts{regex}/)
    {
        my @keys = keys %+;
        my @values = map { $+{$_} } @keys;
        if (! $table_created)
        {
            $table_created = 1;
            $dbh->prepare ("CREATE TABLE IF NOT EXISTS " . $opts{table} . " (" . join (" text, ", @keys) . " text)")->execute ();
        }

        $dbh->prepare ("INSERT OR IGNORE INTO " . $opts{table} . "(" . join (",", @keys) .")" .
            " values (" . "?, " x (scalar @keys - 1). "?)")->execute (@values);

        return 1;
    }

    return 0;
}

###

open $fh, $opts{file} if $opts{file};
while (<$fh>)
{
    parse_line ($_);
}

sub help
{
print<<EOF
Advanced Log Parser \$VER 0.15

Example:
    $0 --regex '^(?<name>[^:]+):(?<password>[^:]+)' \\
       --file   '/etc/passwd' \\
       --report '/tmp/passwd.db' \\
       --table  'parser'

Usage:
     $0  [options]

     --file   | -f     specify file to parse
     --regex  | -r     regular expression to use (require named backreference!)

     --table  | -t     table name
     --report | -r     database location (can be a new file)

     --help   | -h     You're reading this!

EOF
;

exit (0);
}

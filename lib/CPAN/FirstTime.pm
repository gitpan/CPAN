package CPAN::Mirrored::By;

sub new { 
    my($self,@arg) = @_;
    bless [@arg], $self;
}
sub con { shift->[0] }
sub cou { shift->[1] }
sub url { shift->[2] }

package CPAN::FirstTime;

use strict;
use ExtUtils::MakeMaker qw(prompt);
require File::Path;
use vars qw($VERSION);
$VERSION = "1.00";

=head1 NAME

CPAN::FirstTime - Utility for CPAN::Config file Initialization

=head1 SYNOPSIS

CPAN::FirstTime::init()

=head1 DESCRIPTION

The init routine asks a few questions and writes a CPAN::Config
file. Nothing special.

=cut


sub init {
    my($configpm) = @_;
    use Config;
    require CPAN::Nox;
    eval {require CPAN::Config;};
    $CPAN::Config ||= {};
    
    my($ans,$default,$local,%ALL,$cont,$url,$expected_size);
    
    print qq{

The CPAN module needs a directory of its own to cache important
index files and maybe keep a temporary mirror of CPAN files. This may
be a site-wide directory or a personal directory.
};

    my $cpan_home = $CPAN::Config->{cpan_home} || MM->catdir($ENV{HOME}, ".cpan");
    if (-d $cpan_home) {
	print qq{

I see you already have a  directory
    $cpan_home
Shall we use it as the general CPAN build and cache directory?

};
    } else {
	print qq{

First of all, I\'d like to create this directory. Where?

};
    }

    $default = $cpan_home;
    $ans = prompt("CPAN build and cache directory?",$default);
    File::Path::mkpath($ans); # dies if it can't
    $CPAN::Config->{cpan_home} = $ans;
    
    print qq{

If you want, I can keep the source files after a build in the cpan
home directory. If you choose so then future builds will take the
files from there. If you don\'t want to keep them, answer 0 to the
next question.

};

    $CPAN::Config->{keep_source_where} = MM->catdir($CPAN::Config->{cpan_home},"sources");
    $CPAN::Config->{build_dir} = MM->catdir($CPAN::Config->{cpan_home},"build");

    print qq{

How big should the disk cache be for keeping the build directories
with all the intermediate files?

};

    $default = $CPAN::Config->{build_cache} || 10;
    $ans = prompt("Cache size for build directory (in MB)?", $default);
    $CPAN::Config->{build_cache} = $ans;

    # XXX This the time when we refetch the index files (in days)
    $CPAN::Config->{'index_expire'} = 1;

    print qq{

The CPAN module will need a few external programs to work
properly. Please correct me, if I guess the wrong path for a program.

};

    my(@path) = split($Config{path_sep},$ENV{PATH});
    my $prog;
    for $prog (qw/gzip tar unzip make/){
	my $path = $CPAN::Config->{$prog} || find_exe($prog,[@path]) || $prog;
	$ans = prompt("Where is your $prog program?",$path) || $path;
	$CPAN::Config->{$prog} = $ans;
    }
    my $path = $CPAN::Config->{'pager'} || 
	$ENV{PAGER} || find_exe("less",[@path]) || 
	    find_exe("more",[@path]) || "more";
    $ans = prompt("What is your favorite pager program?",$path) || $path;
    $CPAN::Config->{'pager'} = $ans;
    print qq{

Every Makefile.PL is run by perl in a seperate process. Likewise we
run \'make\' and \'make install\' in processes. If you have any parameters
\(e.g. PREFIX, INSTALLPRIVLIB, UNINST or the like\) you want to pass to
the calls, please specify them here.

};

    $default = $CPAN::Config->{makepl_arg} || "";
    $CPAN::Config->{makepl_arg} =
	prompt("Parameters for the 'perl Makefile.PL' command?",$default);
    $default = $CPAN::Config->{make_arg} || "";
    $CPAN::Config->{make_arg} = prompt("Parameters for the 'make' command?",$default);

    $default = $CPAN::Config->{make_install_arg} || $CPAN::Config->{make_arg} || "";
    $CPAN::Config->{make_install_arg} =
	prompt("Parameters for the 'make install' command?",$default);

    $local = 'MIRRORED.BY';
    if (-f $local) { # if they really have a MIRRORED.BY in the
                     # current directory, we can't help
	my($host,$dst,$country,$continent,@location);
	open FH, $local or die "Couldn't open $local: $!";
	while (<FH>) {
	    ($host) = /^([\w\.\-]+)/ unless defined $host;
	    next unless defined $host;
	    next unless /\s+dst_(dst|location)/;
	    /location\s+=\s+\"([^\"]+)/ and @location = (split /\s*,\s*/, $1) and
		($continent, $country) = @location[-1,-2];
	    $continent =~ s/\s\(.*//;
	    /dst_dst\s+=\s+\"([^\"]+)/  and $dst = $1;
	    next unless $host && $dst && $continent && $country;
	    $ALL{$continent}{$country}{$dst} = CPAN::Mirrored::By->new($continent,$country,$dst);
	    undef $host;
	    $dst=$continent=$country="";
	}
	$CPAN::Config->{urllist} ||= [];
	if ($expected_size = @{$CPAN::Config->{urllist}}) {
	    for $url (@{$CPAN::Config->{urllist}}) {
		# sanity check, scheme+colon, not "q" there:
		next unless $url =~ /^\w+:\/./;
		$ALL{"[From previous setup]"}{"found URL"}{$url}=CPAN::Mirrored::By->new('[From previous setup]','found URL',$url);
	    }
	    $CPAN::Config->{urllist} = [];
	} else {
	    $expected_size = 6;
	}

	print qq{

Now we need to know, where your favorite CPAN sites are located. Push
a few sites onto the array (just in case the first on the array won\'t
work). If you are mirroring CPAN to your local workstation, specify a
file: URL.

You can enter the number in front of the URL on the next screen, a
file:, ftp: or http: URL, or "q" to finish selecting.

};

	$ans = prompt("Press RETURN to continue");
	my $other;
	$ans = $other = "";
	my(%seen);
    
	while () {
	    my $pipe = -t *STDIN ? "| $CPAN::Config->{'pager'}" : ">/dev/null";
	    my(@valid,$previous_best);
	    open FH, $pipe;
	    {
		my($cont,$country,$url,$item);
		my(@cont) = sort keys %ALL;
		for $cont (@cont) {
		    print FH "    $cont\n";
		    for $country (sort {lc $a cmp lc $b} keys %{$ALL{$cont}}) {
			for $url (sort {lc $a cmp lc $b} keys %{$ALL{$cont}{$country}}) {
			    my $t = sprintf(
					    "      %-18s (%2d) %s\n",
					    $country,
					    ++$item,
					    $url
					   );
			    if ($cont =~ /^\[/) {
				$previous_best ||= $item;
			    }
			    push @valid, $ALL{$cont}{$country}{$url};
			    print FH $t;
			}
		    }
		}
	    }
	    close FH;
	    $previous_best ||= 1;
	    $default =
		@{$CPAN::Config->{urllist}} >= $expected_size ? "q" : $previous_best;
	    $ans = prompt(
			  "\nSelect an$other ftp or file URL or a number (q to finish)",
			  $default
			 );
	    my $sel;
	    if ($ans =~ /^\d/) {
		my $this = $valid[$ans-1];
		my($con,$cou,$url) = ($this->con,$this->cou,$this->url);
		push @{$CPAN::Config->{urllist}}, $url unless $seen{$url}++;
		delete $ALL{$con}{$cou}{$url};
#	    print "Was a number [$ans] con[$con] cou[$cou] url[$url]\n";
	    } elsif (@{$CPAN::Config->{urllist}} && $ans =~ /^q/i) {
		last;
	    } else {
		$ans =~ s|/?$|/|; # has to end with one slash
		$ans = "file:$ans" unless $ans =~ /:/; # without a scheme is a file:
		if ($ans =~ /^\w+:\/./) {
		    push @{$CPAN::Config->{urllist}}, $ans unless $seen{$ans}++;
		} else {
		    print qq{"$ans" doesn\'t look like an URL at first sight.
I\'ll ignore it for now. You can add it to lib/CPAN/Config.pm
later and report a bug in my Makefile.PL to me (andreas koenig).
Thanks.\n};
		}
	    }
	    $other ||= "other";
	} # while ()
    } else {
	$CPAN::Config->{urllist} ||= [];
	while (! @{$CPAN::Config->{urllist}}) {
	    print qq{We need to know the URL of your favorite CPAN site.
Please enter it here: };
	    chop($_ = <>);
	    s/\s//g;
	    push @{$CPAN::Config->{urllist}}, $_ if $_;
	}
    }

    # We don't ask that now, it will be noticed in time....
    $CPAN::Config->{'inhibit_startup_message'} = 0;

    print "\n\n";
    CPAN::Config->commit($configpm);
}

sub find_exe {
    my($exe,$path) = @_;
    my($dir,$MY);
    $MY = {};
    bless $MY, 'MY';
    for $dir (@$path) {
	my $abs = $MY->catfile($dir,$exe);
	if ($MY->maybe_command($abs)) {
	    return $abs;
	}
    }
}

1;

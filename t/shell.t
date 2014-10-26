use strict;
no warnings 'redefine';


BEGIN {
    chdir 't' if -d 't';
    unshift @INC, '../lib';
    require Config;
    unless ($Config::Config{osname} eq "linux" or $ENV{CPAN_RUN_SHELL_TEST}) {
	print "1..0 # Skip: test is only validated on linux\n";
  warn "\n\n\a Skipping tests! If you want to run the test
  please set environment variable \$CPAN_RUN_SHELL_TEST to 1.\n
  Pls try it on your box and inform me if it works\n";
	exit 0;
    }
    eval { require Expect };
    # I consider it good-enough to have this test only where somebody
    # has Expect installed. I do not want to promote Expect to
    # everywhere.
    if ($@) {
	print "1..0 # Skip: no Expect\n";
	exit 0;
    }
}

use File::Copy qw(cp);
cp "CPAN/TestConfig.pm", "CPAN/MyConfig.pm" or die; # because commit will overwrite it

sub read_myconfig () {
    open my $fh, "CPAN/MyConfig.pm" or die;
    local $/;
    eval <$fh>;
}

my @prgs;
{
    local $/;
    @prgs = split /########.*/, <DATA>;
    close DATA;
}

use Test::More;
plan tests => scalar @prgs + 2;

read_myconfig;
is($CPAN::Config->{histsize},100);

$Expect::Multiline_Matching = 0;
my $exp = Expect->new;
my $prompt = "empty prompt next line";
$exp->spawn(
            $^X,
            "-I.",                 # get this test's own MyConfig
            "-I../lib",
            "-MCPAN::MyConfig",
            "-MCPAN",
            # (@ARGV) ? "-d" : (), # force subtask into debug, maybe useful
            "-e",
            "\$CPAN::Suppress_readline=1;shell('$prompt\n')",
           );
my $timeout = 6;
$exp->log_stdout(0);
$exp->notransfer(1);

# shamelessly stolen from Test::Builder
sub mydiag {
    my(@msgs) = @_;
    my $msg = join '', map { defined($_) ? $_ : 'undef' } @msgs;
    # Escape each line with a #.
    $msg =~ s/^/# /gm;
    # Stick a newline on the end if it needs it.
    $msg .= "\n" unless $msg =~ /\n\Z/;
    print $msg;
}

$exp->expect(
             $timeout,
             [ eof => sub { exit } ],
             [ timeout => sub {
                   my $self = $exp;
                   print "# timed out\n";
                   my $got = $self->clear_accum;
                   if ($got =~ /lockfile/) {
		       mydiag " - due to lockfile, proceeding\n";
                       $self->send("y\n");
                   } else {
                       $got = substr($got,0,60)."..." if length($got)>63;
		       mydiag "- unknown reason, got: [$got]\n";
                       mydiag "Giving up this test\n";
                       exit;
                   }
                   Expect::exp_continue;
               }],
             '-re', $prompt
            );

for my $i (0..$#prgs){
    my $chunk = $prgs[$i];
    my($prog,$expected) = split(/~~like~~.*/, $chunk);
    unless ($expected) {
        ok(1,"empty test");
        next;
    }
    for ($prog,$expected) {
      s/^\s+//;
      s/\s+\z//;
    }
    $exp->send("$prog\n");
    $exp->expect(
                 [ eof => sub { exit } ],
                 [ timeout => sub { mydiag "timed out on $i: $prog\n"; exit } ],
                 '-re', $expected
                );
    my $got = $exp->clear_accum;
    # warn "# DEBUG: prog[$prog]expected[$expected]got[$got]";
    mydiag "$got\n";
    ok(1, $prog);
}

$exp->soft_close;

read_myconfig;
is($CPAN::Config->{histsize},101);

__END__
########
o conf build_cache
~~like~~
build_cache
########
o conf init
~~like~~
initialized
########
nothanks
~~like~~
wrote
########
o conf histsize 101
~~like~~
histsize.*101
########
o conf commit
~~like~~
wrote
########
quit
~~like~~
########

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:

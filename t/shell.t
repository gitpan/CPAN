use strict;
no warnings 'redefine';

BEGIN {
    chdir 't' if -d 't';
    unshift @INC, '../lib';
    $ENV{PERL5LIB} = '../lib';    # so children will see it too
    require Config;
    unless ($Config::Config{osname} eq "linux") {
	print "1..0 # Skip: no linux\n"; # because I fear that expect works not everywhere
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

my @prgs;
{
    local $/;
    @prgs = split /########.*/, <DATA>;
    close DATA;
}

use Test::More;
plan tests => scalar @prgs;

$Expect::Multiline_Matching = 0;
my $exp = Expect->new;
my $prompt = "empty prompt next line";
$exp->spawn(
            $^X,
            "-MCPAN::MyConfig",
            "-MCPAN",
            "-e",
            "\$CPAN::Suppress_readline=1;shell('$prompt\n')",
           );
my $timeout = 6;
# $exp->log_stdout(0);
$exp->notransfer(1);
$exp->expect(
             $timeout,
             [ eof => sub { exit } ],
             [ timeout => sub {
                   my $self = $exp;
                   print "timed out\n";
                   my $got = $self->clear_accum;
                   if ($got =~ /lockfile/) {
                       $self->send("y\n");
                   } else {
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
                 [ timeout => sub { print "timed out\n"; exit } ],
                 '-re', $expected
                );
    my $got = $exp->clear_accum;
    # warn "# DEBUG: prog[$prog]expected[$expected]got[$got]";
    print "\n";
    ok(1, $prog);
}

$exp->soft_close;

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
quit
~~like~~
########

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:

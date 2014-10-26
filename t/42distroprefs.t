use strict;

use Test::More;
use Config;
use CPAN::Distroprefs;

eval "require YAML; 1" or plan skip_all => "YAML required";
plan tests => 4;

my %ext = (
  yml => 'YAML',
);

sub find_ok {
  my ($arg, $expect, $label) = @_;
  my $finder = CPAN::Distroprefs->find(
    './distroprefs', \%ext,
  );

  isa_ok($finder, 'CPAN::Distroprefs::Iterator');

  my %arg = (
    env => \%ENV,
    perl => $^X,
    perlconfig => \%Config::Config,
    module => [],
    %$arg,
  );

  my $found;
  while (my $result = $finder->next) {
    next unless $result->is_success;
    for my $pref (@{ $result->prefs }) {
      if ($pref->matches(\%arg)) {
        $found = {
          prefs => $pref->data,
          prefs_file => $result->abs,
        };
      }
    }
  }
  is_deeply(
    $found,
    $expect,
    $label,
  );
}

find_ok(
  {
    distribution => 'HDP/Perl-Version-1',
  },
  {
    prefs => YAML::LoadFile('distroprefs/HDP.Perl-Version.yml'),
    prefs_file => 'distroprefs/HDP.Perl-Version.yml',
  },
  'match .yml',
);

%ext = (
  dd  => 'Data::Dumper',
);
find_ok(
  {
    distribution => 'INGY/YAML-0.66',
  },
  {
    prefs => do 'distroprefs/INGY.YAML.dd',
    prefs_file => 'distroprefs/INGY.YAML.dd',
  },
  'match .dd',
);

# Local Variables:
# mode: cperl
# cperl-indent-level: 2
# End:

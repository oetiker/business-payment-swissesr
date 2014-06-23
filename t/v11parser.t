use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use utf8;
use Mojo::Util qw(slurp);
use Data::Dumper;

unshift @INC, sub {
    my(undef, $filename) = @_;
    return () if $filename !~ /V11Parser/;
    if ( my $found = (grep { -e $_ } map { "$_/$filename" } grep { !ref } @INC)[0] ) {
                local $/ = undef;
                open(my $fh, '<', $found) || die("Can't read module file $found\n");
                my $module_text = <$fh>;
                close($fh);

                # define everything in a sub, so Devel::Cover will DTRT
                # NB this introduces no extra linefeeds so D::C's line numbers
                # in reports match the file on disk
                $module_text =~ s/(.*?package\s+\S+)(.*)__END__/$1sub main {$2} main();/s;
                
                # filehandle on the scalar
                open ($fh, '<', \$module_text);

                # and put it into %INC too so that it looks like we loaded the code
                # from the file directly
                $INC{$filename} = $found;
                return $fh;
     } else {
          return ();
    }
};

use Test::More tests => 5;

use_ok 'Business::Payment::SwissESR::V11Parser';

my $p = Business::Payment::SwissESR::V11Parser->new();

is (ref $p,'Business::Payment::SwissESR::V11Parser', 'Instanciation');

my $data = $p->parse(slurp $FindBin::Bin.'/test.v11');

is (ref $data, 'ARRAY', 'Parse Output type');
is (scalar @$data, 155, 'Record Count');
is ($data->[0]{transactionCost}, '1.75', 'transaction cost test');

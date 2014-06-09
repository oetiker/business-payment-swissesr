use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use utf8;

unshift @INC, sub {
    my(undef, $filename) = @_;
    return () if $filename !~ /SwissESR/;
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

use_ok 'Business::Payment::SwissESR';

my $t = Business::Payment::SwissESR->new(
        shiftDownMm => 1,
        shiftRightMm=> 2,
        senderAddressLaTeX => <<'LaTeX_End');
 Oltner 2-Stunden Lauf\newline
 Florastrasse 21\newline
 4600 Olten
LaTeX_End

is (ref $t,'Business::Payment::SwissESR', 'Instanciation');

is (`which lualatex` =~ /lualatex/, 1, 'Is LuaLaTeX available?');

$t->add(
    amount => 44.40,
    account => '01-17546-3',
    recipientAddressLaTeX => <<'LaTeX_End',
 Peter Müller\newline
 Haldenweg 12b\newline
 4600 Olten
LaTeX_End
    bodyLaTeX => 'the boddy of the bill in latex format',
    referenceNumber => 3423,
    watermark => 'secret marker',
);

my $pdf = $t->renderPdf();

is (substr($pdf,0,4),'%PDF', 'PdfRender 1');

my $pdf2 = $t->renderPdf(showPaymentSlip=>1);

is (substr($pdf2,0,4),'%PDF', 'PdfRender 2');

exit 0;

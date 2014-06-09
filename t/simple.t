use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
use utf8;

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

is (`which xelatex` =~ /xelatex/, 1, 'Is XeLaTeX available?');

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

my $emailPdf = $t->pdfEmail();

is (substr($emailPdf,0,4),'%PDF', 'EmailPDF');

my $printPdf = $t->pdfPrint();

is (substr($printPdf,0,4),'%PDF', 'PrintPDF');

exit 0;

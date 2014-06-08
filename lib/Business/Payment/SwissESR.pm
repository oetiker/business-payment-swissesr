package Business::Payment::SwissESR;

=head1 NAME

Business::Payment::SwissESR - Class for creating Esr PDFs

=head1 SYNOPSYS

 use Esr;
 my $nl = '\newline';
 my $bs = '\\';
 my $esr = Esr->new(
    shiftRightMm =>
    shiftDownMm =>
    senderAddressLaTeX => <<'LaTeX_End'
 Oltner 2-Stunden Lauf\newline
 Florastrasse 21\newline
 4600 Olten
 LaTeX_End   
 );
 $esr->add(    
    amount => 44.40,
    account => '01-17546-3',
    senderAddressLaTeX => 'Override',
    recipientAddressLaTeX => <<'LaTeX_End',
 Peter Müller\newline
 Haldenweg 12b\newline
 4600 Olten
 LaTeX_End
    bodyLaTeX => 'the boddy of the bill in latex format',
    referenceNumber => 3423,
    watermark => 'secret marker',
 );
 $esr->pdfEmail();
 $esr->pdfPrint();

=head1 DESCRIPTION

This class let's you create ESR pdfs both for email and to to print on official esr forms.
The content is modled after:

L<https://www.postfinance.ch/content/dam/pf/de/doc/consult/templ/example/44218_templ_de_fr_it.pdf>

=cut

use vars qw($VERSION);
use Mojo::Util qw(slurp);
use Mojo::Base -base;
use Cwd;

our $VERSION = '0.1.1';

has moduleBase => sub {
    my $path = $INC{'Business/Payment/SwissESR.pm'};
    $path =~ s/.pm$//;
    return $path;
};

has shiftRightMm => 0;
has shiftDownMm => 0;
has senderAddressLaTeX => 0;

has tasks => sub {
    [];
};

has tmpDir => sub {
    my $tmpDir = '/tmp/SwissESR'.$$;
    if (not -d $tmpDir){
       mkdir $tmpDir or die "Failed to create $tmpDir";
       chmod 0700, $tmpDir;
    }
    return $tmpDir;
};

sub DESTROY {
    my $self = shift;
    unlink glob $self->tmpDir.'/*';
    unlink glob $self->tmpDir.'/.??*';
    rmdir $self->tmpDir;
}

sub add {
    my $self = shift;
    push @{$self->tasks}, {@_};
}


# this file is written with latin1 encoding
        
my $runLaTeX = sub {
    my $self = shift;
    my $src = shift;
    my $tmpdir = $self->tmpDir;
    open my $out, ">:utf8", "$tmpdir/esr.tex" or die "Failed to create esr.tex";
    print $out $src;
    close $out;
    my $cwd = cwd();
    chdir $tmpdir or die "Failed to chdir to $tmpdir";
    open my $latex, '-|', 'lualatex','esr';
    chdir $cwd;
    my $latexOut = join '', <$latex>;
    close $latex;            
    if ($? != 0){
        die $latexOut;
    }
    my $pdf = slurp $tmpdir.'/esr.pdf';
    return $pdf;   
};

# this is that very cool algorithm to calculate the checksum
# used in the 
my $calcEsrChecksum = sub {
    my $self = shift;
    my $input = shift;
    my @map = ( 0, 9, 4, 6, 8, 2, 7, 1, 3, 5 );
    my $keep = 0;
    for my $number ($input =~ m/(\d)/g){
        $keep = $map[($keep+$number) % 10 ];
    }
    return ((10 - $keep) % 10);
};


my $makeEsrLaTeX = sub {
    my $self = shift;
    my $electronic = shift;
    my $root = $self->moduleBase;
    my %docSet = (
        root => $root,
        shiftDownMm => $self->shiftDownMm,
        shiftRightMm => $self->shiftRightMm
    ); 
    my $doc = <<'TEX_END';
\nonstopmode
\documentclass[10pt]{article}
\usepackage[a4paper,top=${shiftDownMm}mm,bottom=-${shiftDownMm}mm,left=${shiftRightMm}mm,right=-${shiftRightMm}mm]{geometry}
\usepackage{color}
\usepackage{fontspec}
\usepackage[raggedrightboxes]{ragged2e}
\makeatletter
\let\raggednewline=\@normalcr
\makeatother
\usepackage{parskip}
\newfontface\ocrb[Scale=1.005,Path = ${root}/ ]{ocrb10.otf}
\setmainfont{DejaVu Sans Condensed}
\usepackage{graphicx}
\usepackage{calc}
\pagestyle{empty}
\setlength{\parindent}{0pt}
\setlength{\unitlength}{1mm}
\begin{document}

TEX_END
    $doc =~ s/\${(\S+?)}/$docSet{$1}/eg;
    for my $task (@{$self->tasks}) {
        my %cfg = %$task;
        $cfg{senderAddressLaTeX} //= $self->senderAddressLaTeX;
        $cfg{root} = $root;
        $cfg{bs} = '\\';
        $cfg{template} = $electronic
            ? '\put(0,1){\includegraphics{'.$root.'/esrTemplate.pdf}}'
              .'\put(8,68){\parbox[b]{8cm}{\flushleft \textbf{\color{red}'
              .'Dieser Einzahlungsschein ist nur für elektronische Einzahlungen geeignet!}}}' 
            : '';
        my ($pc_base,$pc_nr) = $cfg{account} =~ /(\d\d)-(.+)/;
        $pc_nr =~ s/[^\d]//g;    
        my $ref  = $cfg{referenceNumber}.$self->$calcEsrChecksum($cfg{referenceNumber});
        $cfg{code} = '042>'
            . sprintf('%016d',$ref)
            . '+\hspace{0.1in}'
            . sprintf('%02d%07d',$pc_base,$pc_nr).'>';
        $cfg{referenceNumber} = '';
        while ($ref =~ s/(\d{1,5})$//){
            $cfg{referenceNumber} = $1 . '\hspace{0.1in}' . $cfg{referenceNumber};
        }
        my $page = <<'DOC_END';
\vspace*{\stretch{1}}
\begin{picture}(0,0)
DOC_END

        $page .= <<'DOC_END';
${template}
% the reference number ... positioning this properly is THE crucial element
\put(204,18){\makebox[0pt][r]{\ocrb \fontsize{10pt}{16pt}\selectfont ${code}}}
\put(8,90){\parbox[t]{5cm}{\small ${recipientAddressLaTeX}}}
\put(63,90){\parbox[t]{8cm}{\small ${recipientAddressLaTeX}}}
\put(8,41){\tiny ${referenceNumber}}
\put(8,35){\parbox[t]{5cm}{\small ${senderAddressLaTeX}}}
\put(127,54){\parbox[t]{7cm}{\small  ${senderAddressLaTeX}}}
\put(30,61){\small ${account}}
\put(92,61){\small ${account}}
\put(200,69.5){\makebox[0pt][r]{\ocrb ${referenceNumber}}}
DOC_END
        $page .= <<'DOC_END' if $cfg{watermark};
\put(200,110){\makebox[0pt][r]{\scriptsize ${watermark}}}
DOC_END

        $page .= <<'DOC_END'; 
\put(20,278){\begin{minipage}[t]{17cm}
${senderAddressLaTeX}

\vspace*{2.3cm}
\hspace*{10.7cm}\parbox[t]{6.5cm}{
  ${recipientAddressLaTeX}
}

\vspace*{-0.5cm}
${bodyLaTeX}\end{minipage}}
\end{picture}
\newpage

DOC_END
        my $resolve = sub { 
            my $v = shift; 
            if (not defined $cfg{$v}){ 
                print STDERR "No data for $v\n"; return ''
            } 
            else { 
                return $cfg{$v}
            }
        };
        $page =~ s/\${(\S+?)}/$resolve->($1)/eg;
        $page =~ s/&/\\&/g;
        $doc .= $page;
    }
    $doc .= '\end{document}'."\n";
    return $doc;
};

sub pdfEmail {
    my $self = shift;
    return $self->$runLaTeX($self->$makeEsrLaTeX(1));
}

sub pdfPrint {
    my $self = shift;
    return $self->$runLaTeX($self->$makeEsrLaTeX(0));
}
1;

__END__

=back

=head1 COPYRIGHT

Copyright (c) 2014 by OETIKER+PARTNER AG. All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 AUTHOR

S<Tobias Oetiker E<lt>tobi@oetiker.chE<gt>>

=head1 HISTORY

 2014-06-08 to 0.2 extracted from o2h
 
=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et


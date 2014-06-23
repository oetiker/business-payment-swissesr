package Business::Payment::SwissESR::V11Parser;

=head1 NAME

Business::Payment::SwissESR::V11Parser - Class for parsing v11 records

=head1 SYNOPSYS

 use Business::Payment::SwissESR::V11Parser;
 my $parser = Business::Payment::SwissESR::V11Parser->new();
 my $records = $parser->parse($data);
 for my $rec (@$records){
    warn Dumper $rec;
 }

=head1 DESCRIPTION

When issuing ESR payment slips to your customers, you can get payment data from swisspost in
the form of so called v11 files. They contain information about the paiments received. This
class transforms this information into easily accessible data.

See records L<https://www.postfinance.ch/content/dam/pf/de/doc/consult/manual/dldata/efin_recdescr_man_de.pdf>
for details (2.1 Gutschriftrecord Typ 3).

=head1 METHODS

=head2 $p->parse($string)

parses v11 encoded data and returns an array of hashes where each hash represents a payment.

      [ ...
          {
            'status' => 'reject',
            'microfilmReference' => '000010086',
            'transferDate' => '2012-09-26',
            'payDate' => '2012-09-25',
            'paymentLocation' => 'postoffice counter',
            'creditDate' => '2012-09-27',
            'submissionReference' => '5100  0100',
            'paymentType' => 'payment',
            'transactionCost' => '0.9',
            'paymentSlip' => 'ESR+',
            'amount' => '20',
            'referenceNumber' => '326015262012',
            'reseved' => '000000000',
            'accontNumber' => '01-17546-3'
          },
          {
            'status' => 'ok',
            'microfilmReference' => '004570001',
            'transferDate' => '2012-09-26',
            'payDate' => '2012-09-26',
            'paymentLocation' => 'online',
            'creditDate' => '2012-09-27',
            'submissionReference' => '0040  0400',
            'paymentType' => 'payment',
            'transactionCost' => '0',
            'paymentSlip' => 'ESR',
            'amount' => '40',
            'referenceNumber' => '326015852012',
            'reseved' => '000000000',
            'accontNumber' => '01-17546-3'
          },
       ... ]

=cut

use Mojo::Base -base;

# all the magic of this parser is in setting up the right infrastructure
# so that we can blaze through the file with just a few lines of code
# later on.

my $date = {
    w => 6,
    rx => qr/(..)(..)(..)/,
    su => sub {
        return ((2000+$_[0])."-$_[1]-$_[2]");
    }  
};

my %src = (
  '0' => 'online',
  '1' => 'postoffice counter',
  '2' => 'cash on delivery'
);

my %type = (
   '2' => 'payment',
   '5' => 'refund',
   '8' => 'correction'
);

# the v11 format is a fixed with data format. in the format structure
# we have the width (w) of each column as well as an optional regular expression 
my @format = (
    paymentSlip => {
        w => 1,
        su => sub {
            return $_[0] ? 'ESR+' : 'ESR';
        }
    },
    paymentLocation => {
        w => 1,
        su => sub {
            return $src{$_[0]} || $_[0];
        }
    },
    paymentType => {
        w => 1,
        su => sub {
            return $type{$_[0]} || $_[0];
        }
    },
    accontNumber => {
        w => 9,
        rx => qr/(..)0*(.+)(.)/,
        su => sub {
            return "$_[0]-$_[1]-$_[2]";
        }
    },
    referenceNumber => {
        w => 27,
        rx => qr/(.+)./,
        su => sub {
            my $ret = shift;
            $ret =~ s/^0+//;
            return $ret;
        }
    },
    amount => {
        w => 10,
        su => sub {
            return int($_[0]) / 100;
        }
    },
    submissionReference => 10,
    payDate => $date,
    transferDate => $date,
    creditDate => $date,
    microfilmReference => 9,
    status => {
        w => 1,
        su => sub {
            return $_[0] ? "reject" : "ok"   
        }
    },
    reseved => 9,
    transactionCost => {
        w => 4,
        su => sub {
            return int($_[0]) / 100;
        }
    }
);

my @keys;
my $parse = '^';
my %proc;

while (my $key = shift @format){
   my $val = shift @format;
   my $w = $val;
   my $rx = qr/(.*)/;
   my $su = sub { return shift };
   if (ref $val){
      $w = $val->{w};
      $su = $val->{su};
      $rx = $val->{rx} if $val->{rx};
   }
   push @keys, $key;
   $parse .= "(.{$w})";
   $proc{$key} = {
       rx => $rx,
       su => $su
   }
}
$parse .= '$';

sub parse {
    my $self = shift;
    my @data = split /[\r?\n]/, shift;
    my @all;
    for (@data){
        s/\s+$//;
        my %d;
        @d{@keys} = /$parse/;
        next unless defined $d{transactionCost};
        for my $key (keys %proc){
            $d{$key} = $proc{$key}{su}( $d{$key} =~ $proc{$key}{rx} );
        }
        push @all,\%d;
    }        
    return \@all;
}


1;

__END__

=back

=head1 COPYRIGHT

Copyright (c) 2014 by OETIKER+PARTNER AG. All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
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

 2014-06-23 to 0.6 initial version

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


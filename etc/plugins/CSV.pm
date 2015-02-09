################################################################################
#
# File      : CSV.pm
# Author    : Duco Dokter
# Created   : Mon Dec  8 15:15:37 2003
# Version   : $Id: CSV.pm,v 1.3 2010/11/25 15:08:14 wyldebeast Exp $ 
# Copyright : Wyldebeast & Wunderliebe
#
################################################################################

package CSV;

use Net::HL7::Request;
use Net::HL7::Segment;
use POSIX qw(strftime);

=pod
=head1 NAME

CSV

=head1 DESCRIPTION

Basic hl7d plugin for comma separated value files. Override this
plugin to get a specific CSV plugin. The CSV file written is the file
as defined by CSV_FILE in dir CSV_DIR, where the suffix of the file is
the control id of the incoming message (MSH 10) if you specify the
ADD_SUFFIX variable.

=cut

sub exec {

    my ($self, $client, $log, $opts) = @_;
    
    my $err = 0;
    my $msg = $client->getRequest();
    
    $log->info("CSV plugin started");
    $log->debug("CSV plugin got message:\n" . $msg->toString(1));

    my $now   = strftime "%Y%m%d", localtime;

    if (! $opts->{'CSV_DIR'} && $opts->{'CSV_FILE'}) {
	return "No file and dir configured for CSV file";
    }

    my $file = $opts->{'CSV_DIR'} . "/" . $opts->{'CSV_FILE_PREFIX'};

    if ($opts->{'UNIQUE_FILE'}) {
	$file .= "-" . $msg->getSegmentByIndex(0)->getField(10);
    }

    if ($opts->{'CSV_FILE_SUFFIX'}) {
	$file .= "." . $opts->{'CSV_FILE_SUFFIX'};
    }

    # untaint file
    $file =~ /^(.*)$/;
    $file = $1;
    
    if (! $opts->{'CSV_FIELDS'}) {
	$client->sendNack("Plugin not properly configured");
	return "Nr of fields not defined";
    }

    # Open the CSV file to be written
    open(OUT, ">>$file") || return "Could not open file";

    # How many fields do we have?
    for (my $i = 1; $i <= $opts->{'CSV_FIELDS'}; $i++) {
	
	my $value = "";

	if (defined $opts->{"CSV_" . $i}) {
	    my ($seg, $fld, $cmp, $subcmp) = split(',', $opts->{"CSV_" . $i});

	    $value = $msg->getSegmentByIndex($seg)->getField($fld);

	    # check whether we have components and/or subcomponents
	    if (ref($value)) {
		if ($cmp) {
		    if ($subcmp) {
			$value = $value->[$cmp]->[$subcmp];
		    } else {
			$value = join($Net::HL7::SUBCOMPONENT_SEPARATOR, @{$value->[$cmp]});
		    }
		} else {
		    
		    $value = $msg->getSegmentFieldAsString($seg, $fld);
		}
	    }
	}

	print OUT $opts->{'CSV_QUOTE'} . $value . $opts->{'CSV_QUOTE'};

	if ($i < $opts->{'CSV_FIELDS'}) {
	    print OUT ",";
	}
	else {
	    print OUT "\n";
	}
    }

    close(OUT);

    $client->sendAck();

    $log->info("plugin CSV done");

    return;
}

1;

=pod



=cut

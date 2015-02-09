################################################################################
#
# File      : Dumpexample.pm
# Author    : Duco Dokter
# Created   : Thu Aug 26 12:22:16 2004
# Version   : $Id: Dumpexample.pm,v 1.1 2004/08/26 13:25:53 wyldebeast Exp $ 
# Copyright :
#
################################################################################

package Dumpexample;

use Net::HL7::Request;
use Net::HL7::Segment;
use POSIX qw(strftime);

=pod
=head1 NAME

Dumpexample

=head1 DESCRIPTION

Basic hl7d plugin that simply dumps the incoming message to the
filesystem, using the message id as name of the message.

=cut

sub exec {

    my ($self, $client, $log, $opts) = @_;
    
    my $err = 0;
    my $msg = $client->getRequest();
    
    $log->info("Dump plugin started");
    $log->debug("Dump plugin got message:\n" . $msg->toString(1));

    my $now   = strftime "%Y%m%d", localtime;

    if (! $opts->{'DUMP_DIR'}) {
	return "No dump dir configured";
    }

    if (! $opts->{'FILE_SUFFIX'}) {
	$opts->{'FILE_SUFFIX'} = "dat";
    }

    if (! $opts->{'FILE_PREFIX'}) {
	$opts->{'FILE_PREFIX'} = "";
    }

    my $file = $opts->{'DUMP_DIR'} . "/" . $opts->{'FILE_PREFIX'} . $msg->getSegmentByIndex(0)->getField(10) . "." . $opts->{'FILE_SUFFIX'};

    $log->debug("Writing message to file $file");

    # untaint file
    $file =~ /^(.*)$/;
    $file = $1;
    
    # Open the CSV file to be written
    open(OUT, ">$file") || return "Could not open file";
    
    if ($opts->{'PRETTY_PRINT'}) {
	print OUT $msg->toString(1);
    }
    else {
	print OUT $msg->toString();
    }

    close(OUT);

    $client->sendAck();

    $log->info("plugin Dump done");

    return;
}

1;

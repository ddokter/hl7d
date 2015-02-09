################################################################################
#
# File      : DBexample.pm
# Author    : Duco Dokter
# Created   : Mon Dec  8 21:54:23 2003
# Version   : $Id: DBexample.pm,v 1.2 2003/12/11 19:56:20 wyldebeast Exp $ 
# Copyright : Wyldebeast & Wunderliebe
#
################################################################################

package DBexample;

use DBI;
use strict;
use POSIX qw(strftime);

=pod
=head1 NAME

DBExample

=head1 DESCRIPTION

This is an hl7d skeleton plugin doing DB things. You might use this as
a basis for your own database handling plugin.

=cut

sub exec {

    my ($self, $client, $log, $opts) = @_;

    my $msg = $client->getRequest();

    $log->debug("DBexample plugin started");
    $log->debug("Connecting to database");

    my $dbh  = DBI->connect(
			    $opts->{'DB_CONN_STR'}, 
			    $opts->{'DB_USR'}, 
			    $opts->{'DB_PWD'}
			    );
   
    $dbh || return "Couldn't open connection; $DBI::errstr";

    $log->debug("Connected");
    
    # Get some field from the message, but better do your own things here.
    #
    my $msgId = $msg->getSegmentByIndex(0)->getField(10);

    my $ins = "select 'foo'";
    
    $log->debug("Executing statement: $ins");

    my $err = "";
    my $rc = $dbh->selectall_arrayref($ins) or $err = "Can't execute $ins: $dbh->errstr";

    if ($err) {
	$client->sendNack($err);
	return $err;
    }
    else {
	$client->sendAck();
    }
    
    $dbh->disconnect();
    
    return 0;
}

1;

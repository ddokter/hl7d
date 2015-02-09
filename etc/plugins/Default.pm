################################################################################
#
# File      : Default.pm
# Author    : Duco Dokter
# Created   : Mon Dec  8 21:47:59 2003
# Version   : $Id: Default.pm,v 1.3 2003/12/08 22:14:27 wyldebeast Exp $ 
# Copyright : Wyldebeast & Wunderliebe
#
################################################################################

package Default;

# Do not remove this plugin, unless you don't want a fall through scenario.
#
sub exec {

	my ($self, $client, $log, $opts) = @_;

	$log->info("Using plugin Default");

	$client->getRequest();
	$client->sendNack("No plugin found for this message type");

	return 0;
}

1;


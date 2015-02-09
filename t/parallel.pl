#!/usr/bin/perl

# Test spawning a number of processes, sending a number of messages on
# a single connection

use Net::HL7::Connection;
use Net::HL7::Request;
use POSIX qw(strftime);
use Net::HL7::Segment;
use Net::HL7::Segments::MSH;

my ($host, $port, $spawn, $nr) = @ARGV;

if (! ($host && $port && $nr && $spawn)) {
    print "Usage: keep.pl <host> <port> <spawn> <nr>\n";
    exit -1;
}

my $req = new Net::HL7::Request();

$msh  = new Net::HL7::Segments::MSH();
$evn  = new Net::HL7::Segment("EVN");
$pid1 = new Net::HL7::Segment("PID");
$pid2 = new Net::HL7::Segment("PID");

$evn->setField(1, "A24");
$evn->setField(2, "200310011121");
$pid1->setField(3, "1234567");
$pid2->setField(3, "3456789");
$msh->setField(7, "200310011121");
$msh->setField(8, " ");
$msh->setField(14, " ");
$msh->setField(9, "Foo^Bar");
$msh->setField(3, "FooApp");
$msh->setField(12, "2.2");
$msh->setField(15, "AL");
$msh->setField(16, "NE");
$msh->setField(4, "FooFac");
$msh->setField(5, "hl7d");
$msh->setField(6, "Default");

$req->addSegment($msh);
$req->addSegment($evn);
$req->addSegment($pid1);
$req->addSegment($pid2);

print "Sending:\n";
print $req->toString(1);
print ".......\n";

for ($i = 0; $i < $spawn; $i++) {

	$pid = fork();
	if ($pid) {next;}
	my $conn = new Net::HL7::Connection($host, $port);

	for ($j = 0; $j < $nr; $j++) {
		my $res = $conn->send($req);
		print "Received:\n";
		print $res->toString(1);
	}

	$conn->close();
	exit;
}




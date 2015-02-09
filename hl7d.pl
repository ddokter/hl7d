#!/usr/bin/perl -Tw
################################################################################
#
# File      : hl7d.pl
# Author    : Duco Dokter
# Created   : Fri Dec  6 17:03:34 2002
# Version   : $Id: hl7d.pl,v 1.17 2014/09/13 17:56:44 wyldebeast Exp $
# Copyright : Wyldebeast & Wunderliebe
# License   : GPL
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. This program is distributed in
# the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more
# details. You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.
#
################################################################################

BEGIN {
    use FindBin;
    my $PATH = ($FindBin::Bin || "./");
    $PATH =~ /^(.*)$/;
    $PATH = $1;
    push(@INC, "$PATH/lib", "$PATH/etc/plugins");
}

our $VERSION = "0.36";

use IO::Socket;
use POSIX;
use strict;
use Getopt::Long;

require Net::HL7::Daemon;

$0 =~ /(([^\/]*\/)*)(.*)/;

my $PROGRAM = $2;
my $PATH    = ( $FindBin::Bin || "./");


my $USAGE= <<EOT;
Usage:
hl7d.pl [--debug] [--cfg <filename>] [--port <port>] [--nodetach] [--verify] [--help]
EOT

my $HELP= <<EOT;
$USAGE

Options:
--debug    Print some information on config items
--cfg      Config file (defaults to ./etc/hl7d.conf)
--port     Listen to this port (overrides port from config file)
--nodetach Do not detach from console. Use with debug option
--verify   Verify configuration and exit
--help     This message.

EOT


# Define a global hash array to store the options
#
my %Options = ();

# Default vars
$Options{"cfg"} = "$PATH/etc/hl7d.conf";

# Check the syntax of the command line; if correct, load options into
# the %Options array
#
die("$USAGE") unless GetOptions(\%Options,
                                ("debug", "cfg=s", "port=i", "nodetach",
                                 "verify", "help"));

if ($Options{'debug'}) {

    print "Command line options:\n";
    print "---------------------------------------------------\n";

    foreach my $opt (keys %Options) {
  print "$opt: " . $Options{$opt} . "\n";
    }
    print "---------------------------------------------------\n";
}

if ($Options{'help'}) {
        print $HELP;
        exit(0);
}

my %cfg;
my @plugins;
my %pluginCache;
my %pluginConf;

# Default cfg
$cfg{'CLIENT_TIMEOUT'} = 10;

# Read in config file
#
open(CFG, $Options{'cfg'}) || die "Couldn't open config file $Options{'cfg'}";

while(<CFG>) {

    if (/\s*([a-zA-Z0-9\_]+)\s*=\s*(.*)/) {

        $cfg{$1} = $2;
    }
}

close(CFG);

# Create the logger
#
my $logDir;

if ($cfg{'LOG_DIR'} =~ /^\./) {
    $logDir = "$PATH/" . $cfg{'LOG_DIR'};
}
else {
    $logDir = $cfg{'LOG_DIR'};
}

my $log = new Logging(
    LogDir => $logDir,
    Level  => $cfg{'LOG_LEVEL'},
    Prefix => "hl7d",
    Debug  => $Options{debug}
    );


# Read in Plugins config file
#
open(PCFG, "< $PATH/etc/plugins.conf") ||
    die "Couldn't open plugins config file";

my $cfgOk = 1;
my $line = 0;

while(<PCFG>) {

    chomp;
    $line++;

    if (! (/^\s*$/ || /^\#/)) {

        if (/\s*([^\s]+),([^\s]+),([^\s]+)\s*=\s*([^\s]+)/) {

            $plugins[@plugins] = { MSH1 => $1, MSH2 => $2, MSH3 => $3, PLG => $4 };

            # read in plugin's config file if possible
            readPluginConf($4);
        }
        else {
            print "CONFIG ERROR in line $line: $_\n";
            $Options{'verify'} || exit -1;
            $cfgOk = 0;
        }
    }
}

close(PCFG);


if ($Options{'debug'}) {

    print "\nGeneral:\n";
    print "---------------------------------------------------\n";

    printf("HL7 API version: %s\n", $Net::HL7::VERSION);
    printf("hl7d version: %s\n", $VERSION);

    print "\nConfiguration:\n";
    print "---------------------------------------------------\n";

    foreach my $opt (keys %cfg) {
        print "$opt: " . $cfg{$opt} . "\n";
    }
    print "---------------------------------------------------\n\n";

    print "Plugin configuration:\nSending app | Sending facility | type | plugin\n";
    print "---------------------------------------------------\n";

    foreach (@plugins) {
        printf("%12s| %17s| %5s| %s\n", $_->{'MSH1'}, $_->{'MSH2'},
               $_->{'MSH3'}, $_->{'PLG'});
    }

    print "---------------------------------------------------\n";
}

if ($Options{'verify'}) {
    if ($cfgOk) {
        print "\n*** Configuration looks OK ***\n";
    }
    else {
        print "\n*** Configuration ERROR ***\n";
    }

    exit;
}


# Check on the lock
if ( -e "$PATH/var/lock/pid" ) {

    my $err = "
Either the server is already running, or there\'s an old lock file
hanging about...
Please check whether the PID in the lockfile is actually a running
server and either leave this one be, or kill it. If there's no such
process, remove $PATH/var/lock/pid.
";

    die $err;
}


# establish SERVER socket, bind and listen.
#
my $server = new Net::HL7::Daemon
    (
     LocalPort => $cfg{PORT},
     Listen    => $cfg{LISTEN}
     );

$server or die "Couldn't create daemon";


# Zombie collector
#
sub REAPER {
    while ((my $waitedpid = waitpid(-1, WNOHANG)) > 0) {
        $log->info("Reaped $waitedpid" . ($? ? " with exit $?" : ''));
    }

    $SIG{CHLD} = \&REAPER;
}


# HUP handler
#
sub RESTART {

    $log->info("Restarting daemon");
    exec("$PATH/$PROGRAM", @ARGV);
}


$SIG{CHLD} = \&REAPER;
$SIG{HUP}  = \&RESTART;


# Should we daemonize?
#
if (! $Options{'nodetach'}) {

    # Make sure io is directed to oblivion.
    #
    chdir '/' or die "Can't chdir to /: $!";
    open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
    open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";

    my $ppid = fork();

    # Exit the parent process
    exit if $ppid;

    # Die if we didn't
    die "Couldn't fork: $!" unless defined($ppid);

    # Dissociate from the controlling terminal that started us and stop being
    # part of whatever process group we had been a member of.
    #
    POSIX::setsid() or die "Can't start a new session: $!";
    open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
}


{
    # Trap fatal signals, setting a flag to indicate we need to gracefully exit.

    my $time_to_die = 0;


    # Set the signal handler to our own time to die handler
    #
    local $SIG{INT} = $SIG{TERM} = sub { $time_to_die = 1; };

    # Untaint pidfile
    "$PATH/var/lock/pid" =~ /^(.*)$/;
    my $pidFile = $1;

    open(PID, ">$pidFile") || die "Couldn't write PID to $pidFile";
    print PID $$ . "\n";
    close(PID);

    $log->log("Server started with pid $$ on port " . $cfg{'PORT'});

    # Do the actual loop
    until ($time_to_die) {
        handleServer();
    }

    # Remove lock
    unlink($pidFile);
    $log->log("Server stoppped");

    $server->close();

    kill("TERM", -$$);  # terminate my process group (all kids)

    exit;
}


sub handleServer {

    while (my $client = $server->accept()) {

        $log->info("Incoming request");

        # If we receive an incoming connection, fork, and return to
        # the accept mode
        #
        $log->debug("Starting child process");

        my $pid = fork();

        # If we are the parent process...
        if ($pid) {
            $client->close();
            next;
        }

        # Here we are the forked process
        # If this doesn't work, this is rather nasty!
        #
        if (! defined $pid) {
            $log->error("Not forked: $!");
        }
        else {
            $log->debug("Child process $$ started");
        }

        # Server socket can be closed in child
        #
        $server->close();

        # Call the client handler to do the rest. This handler is
        # responsible for closing the connection when appropriate.
        #
        handleClient($client);

        if (defined $client) {
            $log->debug("Closing client");
            $client->close();
        }

        # This is it for the client
        $log->info("Exiting child process $$");
        exit;
    }
}


# The client handling is a loop untill no input is received, or a
# timeout occurs. In case the request is of type query, the connection
# may be closed as well.
#
sub handleClient {

    # restore default signal handlers inside the child process
    local $SIG{INT} = local $SIG{TERM} = 'DEFAULT';

    my $client = shift;

    # Set the timeout for incoming requests
    #
    $client->timeout($cfg{'CLIENT_TIMEOUT'});

    $log->debug("Handling client");

    while (1) {

        if (not $client->connected()) {
            $log->info("Client closed connection");
            last;
        }

        # If the connection has been closed, that's it.
        #
        my $hl7Msg = $client->getNextRequest();

        if (not defined $hl7Msg) {
            $log->info("No message received within timeout");
            last;
        }

        $log->debug("Incoming message:\n*****\n" . $hl7Msg->toString(1) . "*****\n");

        # Get info from message, and determine required plugin
        #
        my $plugin = getPlugin($hl7Msg);

        $log->debug("Plugin $plugin found");

        # untaint plugin
        $plugin =~ /^(.*)$/;
        $plugin = $1;

        if (! eval( "require $plugin;" ) ) {
            $log->error("Plugin $plugin not defined");
            $client->sendNack("No plugin found for message type");
            next;
        }

        # actually handle client
        #
        if ( my $err = $plugin->exec($client, $log, $pluginConf{$plugin}) ) {

            $log->error("Error for plugin $plugin: $err");
        }
        else {

            $log->info("Plugin handled");
        }
    }

    $log->debug("Client timed out");
}


sub getPlugin {

    my $msg = shift;

    my $msh = $msg->getSegmentByIndex(0);

    if (! $msh) {
        $log->error("No MSH segment found in request");
        return "Error";
    }

    my $type = join("^", $msh->getField(9));

    $log->info("Message sending application: " . $msh->getField(3));
    $log->info("Message facility: " . $msh->getField(4));
    $log->info("Message type: $type");

    if (exists($pluginCache{ join('_', $msh->getField(3), $msh->getField(4), $type) })) {
        $log->debug("Return plugin from cache");
        return $pluginCache{ join('_', $msh->getField(3), $msh->getField(4), $type) };
    }

    foreach (@plugins) {

        if
            (
             ($_->{MSH1} eq $msh->getField(3) || $_->{MSH1} eq "*")
             &&
             ($_->{MSH2} eq $msh->getField(4) || $_->{MSH2} eq "*")
             &&
             ($_->{MSH3} eq $type || $_->{MSH3} eq "*")
             &&
             $_->{PLG}
            )
        {
            $pluginCache{ join('_', $msh->getField(3), $msh->getField(4), $type) } = $_->{PLG};
            return $_->{PLG};
        }
    }

    return "Default";
}


sub readPluginConf {

    my $plugin = shift;

    $log->info("Trying to read config file for plugin $plugin");

    if (-r "$cfg{'PLUGIN_PATH'}/$plugin.conf") {

        open(CFG, "<$cfg{'PLUGIN_PATH'}/$plugin.conf") || return;

        while(<CFG>) {

            if (/^\s*([a-zA-Z0-9\_]+)\s*=\s*(.*)/) {

                $pluginConf{$plugin}->{$1} = $2;
            }
        }

        close(CFG);
    }
}


=head1 NAME

hl7d.pl

=head1 SYNOPSIS

hl7d.pl [--debug] [--cfg <dirname>] [--port <port>] [--nodetach] [--help]

Options:

=over 4

=item --debug

Print lots of information on processing


=item --cfg

Config dir (defaults to ./etc)


=item --port

Listen to this port (overrides port from config file)

=item --nodetach

Do not detach from the console

=item --help

This message.

=back

=head1 DESCRIPTION

This is a forking daemon to handle incoming HL7 messages. The server
accepts requests on a port, and dispatches them, according to the
plugins.conf file.  All plugins must be available on the Perl include
paths (@INC). The easy way is to put your plugins in the plugins dir
($HL7D_ROOT/etc/plugins).

The plugin must contain the exec() method, and will be passed the
L<Net::HL7::Request>, a reference to the logger for this server and a
hash of plugin options, if there's also a plugin specific
configuration file available.

The hl7d process will call the getNextRequest method of the
L<Net::HL7::Daemon::Client> object untill no data is read, to enable
multiple messages on a single client. So do not use the getNextRequest
method in your action handler, unless you'er really sure you want
this!!!

=head1 REQUIREMENTS

This server requires:

* Net::HL7, 0.66 or better

and uses an inner class Logging.

=head1 AUTHOR

D.A.Dokter <dokter@wyldebeast-wunderliebe.com>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details. You should have received a copy of the GNU General Public
License along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut


package Logging;

use strict;
use POSIX;

=head1 NAME

Logging.pm

=head1 SYNOPSIS

=begin text

require Logging;

my $log = new Logging(
    LogDir     => '/var/log',
    Prefix     => 'myapp',
    Level      => 'warn',
    DateFormat => '%Y%m%d'
);

$log->debug("This is debugging");
$log->info("This is info");
$log->warn("This is a warning");
$log->error("This is an error");
$log->fatal("This is fatal!");

$log->log("This is a message");

=end text

=head1 DESCRIPTION

This module provides VERY BASIC log4j like logging to you
application. The module currently supports six log methods:

=over 4

=item *
debug

=item *
info

=item *
warn

=item *
error

=item *
fatal

=item *
log: This will always log, whatever your level is set to

=back

=head1 PREREQUISITES

None

=cut

sub new {

    my($class, %arg) = @_;
    my $self = {};

    bless $self, $class;

    $self->init(\%arg);

    return $self;
}


sub init {
    my ($self, $arg) = @_;

    $self->{CFG} = $arg;

    # Defaults
    exists($self->{CFG}->{LogDir})
        || ($self->{CFG}->{LogDir}   = ".");
    exists($self->{CFG}->{Level})
        || ($self->{CFG}->{Level} = 0);
    exists($self->{CFG}->{DateFormat})
        || ($self->{CFG}->{DateFormat} =  "%Y%m%d%H%M%S");
    exists($self->{CFG}->{Prefix})
        || ($self->{CFG}->{Prefix} =  "$0");

    $self->{CFG}->{LogLevelMap} = {
        'debug' => 4,
        'info'  => 3,
        'warn'  => 2,
        'error' => 1,
        'fatal' => 0
    };

    $self->{CFG}->{Level} = $self->{CFG}->{LogLevelMap}->{$arg->{Level}};
}


sub debug {

    my ($self, $msg) = @_;

    if ($self->{CFG}->{Level} > 3) {

        $self->log("DEBUG $msg");
    }
}


sub info {

    my ($self, $msg) = @_;

    if ($self->{CFG}->{Level} > 2) {

        $self->log("INFO $msg");
    }
}


sub warn {

    my ($self, $msg) = @_;

    if ($self->{CFG}->{Level} > 1) {

        $self->log("WARN $msg");
    }
}


sub error {

    my ($self, $msg) = @_;

    if ($self->{CFG}->{Level} > 0) {

        $self->log("ERROR $msg");
    }
}


sub fatal {

    my ($self, $msg) = @_;

    $self->log("FATAL $msg");
}


sub log {

    my ($self, $message) = @_;

    chomp($message);

    my $now   = strftime "%Y%m%d", localtime;
    my $stamp = strftime $self->{CFG}->{DateFormat}, localtime;

    # Untaint logfile name
    my $logFile = $self->{CFG}->{LogDir} . "/" . $self->{CFG}->{Prefix} . "_" . $now . ".log";
    $logFile =~ /^(.*)$/;
    $logFile = $1;

    if (! open(LOG_FILE, ">> $logFile")) {
        $self->{ERR} = "Couldn't open logfile $logFile";
        return(0);
    }

    print LOG_FILE "$stamp\t$message\n";
    $self->{CFG}->{'Debug'} && print "$message\n";

    close(LOG_FILE);

    return(1);
}


1;


=head1 AUTHOR

D.A.Dokter <dokter@wyldebeast-wunderliebe.com>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details. You should have received a copy of the GNU General Public
License along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut


1;

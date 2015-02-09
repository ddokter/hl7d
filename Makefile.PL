use ExtUtils::MakeMaker;


WriteMakefile(
	      'NAME'           => 'hl7d',
	      'VERSION_FROM'   => 'hl7d.pl',
	      'PREFIX'         => '/usr/local/$(NAME)-$(VERSION)',
	      'AUTHOR'         => 'D.A.Dokter <dokter@wyldebeast-wunderliebe.com>',
	      'PREREQ_PM'      => { 'Net::HL7' => 0.76, 'IO::Socket::Timeout' },
	      'EXE_FILES'      => [ 'hl7d.pl' ],
	      'INSTALLDIRS'    => 'perl',
	      'INSTALLARCHLIB' => '$(PREFIX)/lib',
	      'INSTALLPRIVLIB' => '$(PREFIX)/lib',
	      'INSTALLSCRIPT'  => '$(PREFIX)',
	      'INSTALLBIN'     => '$(PREFIX)',
	      'PM'	       => {}
);


sub MY::install {
    my $self = shift;
    local *install;
    $_=$self->MM::install;
    s/(install\s::\s.*)/$1\ cfg/;
    $_;
}


sub MY::test {
    my $self = shift;
    local *test;
    $_=$self->MM::test;
    s/(test\s::\s.*)/test: mytest/;
    $_;
}


sub MY::postamble {

    "
cfg:
\t( test -d \$(PREFIX)/etc ) || mkdir \$(PREFIX)/etc
\t( test -d \$(PREFIX)/var ) || mkdir \$(PREFIX)/var
\t( test -d \$(PREFIX)/var/log ) || mkdir \$(PREFIX)/var/log
\t( test -d \$(PREFIX)/var/lock ) || mkdir \$(PREFIX)/var/lock
\t( test -d \$(PREFIX)/etc/plugins ) || mkdir \$(PREFIX)/etc/plugins
\t( test -f \$(PREFIX)/etc/hl7d.conf ) || cp etc/hl7d.conf \$(PREFIX)/etc
\t( test -f \$(PREFIX)/etc/plugins.conf ) || cp etc/plugins.conf \$(PREFIX)/etc
\tcp etc/plugins/* \$(PREFIX)/etc/plugins/

mytest:
\t\@echo \"\"
\t\@echo \"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\"
\t\@echo \"       No automated tests available\"
\t\@echo \"Please consult the README for info on testing\"
\t\@echo \"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\"
\t\@echo \"\"
";
}

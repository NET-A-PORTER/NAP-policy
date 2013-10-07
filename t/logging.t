#!perl
use strict;
use warnings;
use lib 't/lib';
use Test::Most;
use Log::Log4perl;
use 5.014;

sub check_log {
    my ($msg,$expected,$testname) = @_;

    my $appender = Log::Log4perl->appender_by_name('test');
    $appender->string('');
    Log::Log4perl->get_logger->info($msg);
    is($appender->string,$expected,
       $testname);
}

subtest 'all layouts explicit' => sub {
    my $log_conf=<<'EOCONF';
log4perl.appender.test = Log::Log4perl::Appender::String
log4perl.appender.test.layout = NAP::Logging::Layout::PatternLayout::Multiline
log4perl.appender.test.layout.ConversionPattern = UNUSED
log4perl.appender.test.layout.ConversionPattern.FirstLine = +%m%n
log4perl.appender.test.layout.ConversionPattern.ContLines = |%m%n
log4perl.appender.test.layout.ConversionPattern.LastLine = \%m%n

log4perl.rootLogger = DEBUG, test
EOCONF

    Log::Log4perl->init(\$log_conf);

    check_log('TEST!',qq{+TEST!\n},
              'single line uses FirstLine');

    check_log("TEST!\ntwo lines",qq{+TEST!\n\\two lines\n},
              'two lines use FirstLine & LastLine');

    check_log("TEST!\ntwo lines\n3",qq{+TEST!\n|two lines\n\\3\n},
              'two lines use all layouts');
};

subtest 'default only' => sub {
    my $log_conf=<<'EOCONF';
log4perl.appender.test = Log::Log4perl::Appender::String
log4perl.appender.test.layout = NAP::Logging::Layout::PatternLayout::Multiline
log4perl.appender.test.layout.ConversionPattern = <%m>%n

log4perl.rootLogger = DEBUG, test
EOCONF

    Log::Log4perl->init(\$log_conf);

    check_log('TEST!',qq{<TEST!>\n},
              'single line uses default');

    check_log("TEST!\ntwo lines",qq{<TEST!>\n<two lines>\n},
              'two lines use default');

    check_log("TEST!\ntwo lines\n3",qq{<TEST!>\n<two lines>\n<3>\n},
              'two lines use default');
};

subtest 'default + one explicit' => sub {
    my $log_conf=<<'EOCONF';
log4perl.appender.test = Log::Log4perl::Appender::String
log4perl.appender.test.layout = NAP::Logging::Layout::PatternLayout::Multiline
log4perl.appender.test.layout.ConversionPattern = [] %m%n
log4perl.appender.test.layout.ConversionPattern.ContLines = []+%m%n

log4perl.rootLogger = DEBUG, test
EOCONF

    Log::Log4perl->init(\$log_conf);

    check_log('TEST!',qq{[] TEST!\n},
              'single line uses default');

    check_log("TEST!\ntwo lines",qq{[] TEST!\n[]+two lines\n},
              'two lines use default & ContLines');

    check_log("TEST!\ntwo lines\n3",qq{[] TEST!\n[]+two lines\n[]+3\n},
              'two lines use default & ContLines twice');
};

subtest 'complex layout' => sub {
    my $log_conf=<<'EOCONF';
log4perl.appender.test = Log::Log4perl::Appender::String
log4perl.appender.test.layout = NAP::Logging::Layout::PatternLayout::Multiline
log4perl.appender.test.layout.ConversionPattern = [%d{yyyy/MM/dd HH:mm:ss,SSS}] <%M> %6p: %m%n
log4perl.appender.test.layout.ConversionPattern.ContLines = [%d{yyyy/MM/dd HH:mm:ss,SSS}]+ %m%n

log4perl.rootLogger = DEBUG, test
EOCONF

    Log::Log4perl->init(\$log_conf);

    my $appender = Log::Log4perl->appender_by_name('test');
    $appender->string('');

    Log::Log4perl->get_logger->debug('foo');
    Log::Log4perl->get_logger->debug('bar');
    Log::Log4perl->get_logger->error("fail\nfail\nmore fail\n\n");

    my $out = $appender->string;
    my $expect_re = <<'EOLOG';
\[\d+/\d+/\d+ \d+:\d+:\d+,\d+\] <main::__ANON__>  DEBUG: foo
\[\d+/\d+/\d+ \d+:\d+:\d+,\d+\] <main::__ANON__>  DEBUG: bar
\[\d+/\d+/\d+ \d+:\d+:\d+,\d+\] <main::__ANON__>  ERROR: fail
\[\d+/\d+/\d+ \d+:\d+:\d+,\d+\]\+ fail
\[\d+/\d+/\d+ \d+:\d+:\d+,\d+\]\+ more fail
EOLOG
    like($out,qr{$expect_re},'complex pattern ok');
};

done_testing();

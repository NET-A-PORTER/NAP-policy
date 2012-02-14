#!perl
use strict;
use warnings;
use lib 't/lib';
use Test::Most;
use Data::Printer;
use NAP::Exception;
use 5.014;

subtest 'simple message' => sub {
    eval { NAP::Exception->throw({message=>'foo'}) }; my $e = $@;
    like($e->as_string,
         qr{\A foo \z}smx,
         'message works');
};

subtest 'simple message with undef' => sub {
    package My::ExcUndef {
        use NAP::policy 'exception';
        has stuff => ( is => 'ro', isa => 'Int' );
        has '+message' => ( default => "count: %{stuff}i" );
    }

    eval { My::ExcUndef->throw() }; my $e = $@;
    like($e->as_string,
         qr{\A count: [ ] <undef> \z}smx,
         'message works');
};

{
    package My::Exc {
        use NAP::policy 'exception';
        has stuff => ( is => 'ro', isa => 'Int', default => 5 );
        has '+message' => ( default => "count: %{stuff}i" );
    }

    subtest 'custom accessors' => sub {
        eval {
            My::Exc->throw();
          }; my $e = $@;
        like($e->as_string,
             qr{\A count: [ ] 5 \z}smx,
             'custom format works');
    };
}

{
    package My::Exc2 {
        use NAP::policy 'exception';
        extends 'My::Exc';
        with 'NAP::Exception::Role::StackTrace';
        has '+stuff' => ( is => 'ro', isa => 'Int', default => 7 );
        has '+message' => ( default => "count: %{stuff}i\n\nStack trace: %{stack_trace}s" );
    }

    subtest 'inheritance' => sub {
        eval {
            My::Exc2->throw();
          }; my $e = $@;
        like("$e",
             qr{\A count: [ ] 7 \n\n Stack\ trace:.+}smx,
             'custom format, and overloading, works');
    };

    sub throw_something {
        My::Exc2->throw({stuff=>17});
    }

    subtest 'stack trace' => sub {
        eval { throw_something };my $e=$@;
        my $file=__FILE__;
        like($e->stack_trace->as_string,
             qr{\A\s*at \Q$file\E line \d+\n\tmain::throw_something at \Q$file\E line \d+\b},
             'stack trace start where expected');
    };
}

done_testing();

#!perl
use NAP::policy 'test';

subtest 'failures' => sub {
    eval q{package Foo;use NAP::policy 'simple_exception';};my $e=$@;
    like($e,qr{package called.*Exception},'import-time fail in wrong pkg');

    eval q{package Foo;use NAP::policy;NAP::policy::simple_exception();};$e=$@;
    like($e,qr{package called.*Exception},'call-time fail in wrong pkg');

    eval q{package MyApp::Exception;use NAP::policy;NAP::policy::simple_exception();};$e=$@;
    like($e,qr{required},'call-time fail w/o arguments');

    eval q{package MyApp::Exception;use NAP::policy;NAP::policy::simple_exception('...','message');};$e=$@;
    like($e,qr{not a module name},'call-time fail w/ bad arguments')
};

subtest 'single class creation' => sub {
    eval <<'EOC'; my $e=$@;
package MyApp::Exception;
use NAP::policy 'simple_exception';
simple_exception One => 'simple message';
EOC
    is($e,'','class creation worked')
        or note p $e;
    my $ex = eval 'MyApp::Exception::One->new';$e=$@;
    is($e,'','the class exists')
        or note p $e;
    isa_ok($ex,'MyApp::Exception::One','the exception was constructed');
    is("$ex",'simple message','message is correct');
};

subtest 'complex example' => sub {
    eval <<'EOC'; my $e=$@;
package MyApp::Exception;
use NAP::policy 'simple_exception';
simple_exception('BadExample','something bad happened');
simple_exception('BadValue','the value %{value}s is bad',{
    attrs => ['value'],
});
simple_exception('Invalid','the value %{value}s is not valid, should match %{constraint}s',{
    extends => 'BadValue',
    attrs => ['constraint'],
});
simple_exception('ShortLived','whatever',{
    stack_trace => 0,
});
EOC
    is($e,'','class creation worked')
        or note p $e;
    is(MyApp::Exception::BadExample->new->message,
       'something bad happened',
       'BadExample works');
    isa_ok(MyApp::Exception::BadExample->new->stack_trace,
           'Devel::StackTrace');
    is(MyApp::Exception::BadValue->new({value=>10})->as_string,
       'the value 10 is bad',
       'BadValue works');
    isa_ok(MyApp::Exception::BadValue->new({value=>10})->stack_trace,
           'Devel::StackTrace');
    is(MyApp::Exception::Invalid->new({value=>10,constraint=>'foo'})->as_string,
       'the value 10 is not valid, should match foo',
       'Invalid works');
    isa_ok(MyApp::Exception::Invalid->new({value=>10,constraint=>'foo'})->stack_trace,
           'Devel::StackTrace');
    is(MyApp::Exception::ShortLived->new->as_string,
       'whatever',
       'ShortLived works');
    is(MyApp::Exception::ShortLived->new->stack_trace->as_string,
       '',
       'ShortLived has no stack trace');
};

done_testing();

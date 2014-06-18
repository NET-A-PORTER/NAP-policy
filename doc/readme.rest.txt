==================================
 ``NAP::policy``: an introduction
==================================
:author: Gianni Ceccarelli
:date: 2011-10-13

What is ``NAP::policy``?
========================

It's a pragma, or a "policy" module, to help people at NAP write more
uniform code.

The module itself is equivalent to a series of ``use`` statements,
that are considered "a good idea" for our needs.

The distribution also contains a few more "good idea" modules, that
are not tied to any particular application, but can help developers.

In more detail: useful imports
------------------------------

``use NAP::policy`` gives you:

- ``strict``

  You'd never write code without this, right?

- ``warnings FATAL=>'all'``

  Yes, this means that using an uninitialised value is a fatal
  run-time error. We may relax this requirement.

- ``utf8``

  So you can have non-ASCII literals in your code. This has **nothing
  to do** with data encoding. And please don't use non-ASCII
  characters in your identifiers.

- ``true``

  You no longer have to put a ``1;`` at the end of each file!

- ``Try::Tiny``

  You get ``try`` / ``catch``, and ``match_instance_of``
  (``instance_of`` from ``Smart::Match``) to make it easy to catch
  exceptions by class

- ``Carp``

  If you are writing a module, it's better to report (for example)
  parameter errors from the perspective of the caller, not from inside
  your module. Now that you don't have to load ``Carp`` manually, you
  have no excuses.

- ``feature ':5.18'``

  You get ``given/when``, ``say``, lexical character semantic for
  string operators and regexes, and the smart-match operator. Please
  only use smart-match with the help of ``Smart::Match``, see
  below. You also get the ``__SUB__`` token and the ``fc`` (fold case)
  function.

- ``namespace::autoclean``

  Because you don't usually want to re-export stuff you imported.

You can pass a parameter to the ``use NAP::policy`` statement, to get
some additional goodies:

``'class'``
 - ``Moose``
 - an automatic call to ``__PACKAGE__->meta->make_immutable`` at the
   proper time

``'role'``
 - ``Moose::Role``

``'match'``
 - all the functions from ``Smatch::Match``, imported with the
   ``match_`` prefix

``'exception'``
 - ``Moose``
 - your package is a subclass of ``NAP::Exception``

``'simple_exception'``
 - helper function to create exception classes

``'overloads'`` and ``'dont_clean'``
 - prevent ``namespace::autoclean`` from removing overloaded operator
   and/or additional functions

``'exporter'``
 - same as ``dont_clean=>['import']``.

   You can get a similar effect for additional imported functions you
   may want to stay visible in your namespace by calling
   ``NAP::policy->mark_as_method($the_function_name)``

``'test'``
 - ``lib 't/lib'``
 - ``Test::Most`` (without the warning about ``blessed``!)
 - ``Data::Printer`` (to use instead of ``Data::Dumper`` to get human
   readable data structure printouts)

Other goodies: ``Perl::Critic``
-------------------------------

``NAP::policy::critic_profile`` returns the full path to a
``Perl::Critic`` profile that we should use for all our code. It's the
result of a merge of our various critic profiles, with some changes to
support the use of ``NAP::policy`` itself. For example,
``RequireUseStrict`` and ``RequireUseWarnings`` now know that
``NAP::policy`` provides those, and ``RequireEndWithOne`` has been
generalised to ``RequireTrue`` which knows about ``use true`` and
``NAP::policy``.

Other goodies: ``Dist::Zilla`` support
--------------------------------------

We are using ``Dist::Zilla`` for new distributions
(``NAP::Messaging``, ``NAP::policy`` itself), so it seemed a good idea
to provide some help to make it work more "the NAP way".

Inside the ``NAP::policy`` distribution you get some ``Dist::Zilla``
plugins:

- ``PkgDistNoCritic`` and ``PkgVersionNoCritic`` are slightly-modified
  versions of the plugins included in ``Dist::Zilla`` that play nice
  with ``Perl::Critic``, which would otherwise complain about the
  inserted lines of code being before ``use strict``
- ``NAPGitVersion`` is a ``VersionProvider`` that uses the same
  algorithm we use in our applications to get a usable version number.

We also provide a ``Dist::Zilla`` command: ``rpmbuild``, that will
pack your distribution using the normal ``Dist::Zilla`` process, then
make an RPM out of it using a templated spec-file.

You also get two scripts, ``nap-new-lib`` and ``nap-new-app``, that
create a distribution skeleton using a custom minting profile.

Helper modules: versions and RPM
--------------------------------

The version-detecting code is in the ``NAP::GitVersion`` module, which
is a singleton object with only one useful method:
``version_info``. It returns a 3-element list:

- the nearest Git tag
- the distance between it and the current ``HEAD``
- the abbreviated commit hash of the current ``HEAD``

These are used in both ``NAPGitVersion`` and in the RPM process to
build version numbers.

You can use the ``nap-version`` script to manage version tags.

``NAP::Rpmbuild`` implements all the RPM building logic. You pass it a
tarball, a spec-file template path, a name and a version, and it will
do everything else:

- create the ``.rpmbuild`` directory structure
- move the tarball to the ``SOURCES`` subdirectory
- create the spec-file from the template
- call ``rpmbuild`` with the appropriate parameters

Specfile templating
"""""""""""""""""""

In your ``*.spec.in`` template file, you should use:

- ``[% INCLUDE NAPDIRS deploydir='xt_central' sysdir='fulcrum' %]`` at
  the top, to set up a few RPM variables referring to directories like
  base installation dir, config files dir, log dir, PID dir.
- ``[% SETUP %]`` where you would usually write ``%setup``, to support
  having tarballs with names different from the directory they expand
  to
- ``[% INCLUDE MANIFEST user='fulcrum' group='fulcrum' %]`` to
  automatically build the RPM manifest with sensible file ownership
  and permissions
- ``[% DEPS %]`` to get the right dependencies on ``perl-nap`` instead
  of the system ``perl``
- ``[% INSTALL %]`` inside your ``%install`` section, to install your
  application to the ``deploydir`` you declared at the beginning
- ``[% INCLUDE INSTALL dirs=['lib','scripts','conf'] %]`` if you want
  to specify which directories to install

You can use the ``*.spec.in`` file created from the minting profile as
a starting point: in most cases it will just work.

Why should I use ``NAP::policy``?
=================================

The shortest answer is "so you don't have to think about which modules
to import".

"Should I use ``Try::Tiny`` or ``TryCatch`` or just ``eval``?"

"Should I use ``Moose`` or roll my own objects?"

"``Test::More``? ``Test::Most``?"

There is now a single place to answer all these questions, so you
don't have to think about them, and can just get to coding. If we find
out that the answers were wrong, we (the Architecture Team, to be
clear) will change ``NAP::policy`` and fix whatever broke.

Future ideas
------------

The RPM creation needs more love.


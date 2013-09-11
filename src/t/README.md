CoataGlue Tests
===============

The following tests can be run on their own:

000_load.y
001_init.t
008_people.t

and all the 10* tests.

The other tests require some other services (a Mint server, Fedora
repository and Damyata app) to be running, or they won't pass.

See [the Unit Tests page](https://github.com/spikelynch/CoataGlue/wiki/Unit-Tests) on the project wiki for more details.

Files with names like 'nnn_test.t.later.folks' are scripts which don't
quite work yet, so they were renamed so that 'prove' ignores them.
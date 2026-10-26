# Repository scripts

This folder contains public build, packaging, smoke-check, and regression-test tools. The LO2 loader maintenance procedure is in [Updating local LO2](../docs/UPDATING-LOCAL-LO2.md).

Local browser reproduction helpers and the generated browser loader copy live under ignored `.testdata/lo2/`; ad hoc Apex diagnostics live under `.testdata/apex/`; local SOQL queries/exports live under `.testdata/soql/`. They are not required for package creation or automated regression tests and are not distributed in the public repository. On this workspace, start the reproduction server with `.testdata/lo2/webserver.bat`.

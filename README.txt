Some usage examples can be found in demotest.d.  Unfortunately the ddoc documentation for
this library doesn't compile due to DMD bug 5704.

Build instructions:

Just compile all of the .d files into a .lib (Windows) or .a (Posix) file.
Build command for the GTK port:

dmd -ofplot2kill.lib -O -inline -release *.d

If you're using DFL, add -version=dfl to the build command:

dmd -ofplot2kill.lib -O -inline -release -version=dfl *.d

To build the demo/test module and compile an executable instead of a library, do:

dmd -O -inline -release -version=test *.d

or

dmd -O -inline -release -version=dfl -version=test *.d

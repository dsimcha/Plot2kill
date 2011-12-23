Some usage examples can be found in demotest.d.  Unfortunately the ddoc documentation for
this library doesn't compile due to DMD bug 5704.

Build instructions:

Just compile all of the .d files into a .lib (Windows) or .a (Posix) file.  If you're using 
the GTK port, add -version=gtk to the build command:

dmd -ofplot2kill.lib -O -inline -release -version=gtk *.d

If you're using DFL, add -version=dfl to the build command:

dmd -ofplot2kill.lib -O -inline -release -version=dfl *.d

To build the demo/test module and compile an executable instead of a library, do:

dmd -O -inline -release -version=gtk -version=test *.d

or

dmd -O -inline -release -version=dfl -version=test *.d
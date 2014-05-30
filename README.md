Build Documentation
==================
```
dmd -o- -Dddoc *.d
```
___
Build Library
=============

Just compile all of the .d files into a .lib (Windows) or .a (Posix) file.
Build command for the GTK port:
```
dmd -lib -ofplot2kill.lib -O -inline -release *.d
```
If you're using DFL, add -version=dfl to the build command:
```
dmd -lib -ofplot2kill.lib -O -inline -release -version=dfl *.d
```
___
Build Demo
==========

To build the demo/test module and compile an executable instead of a library, do:
```
dmd -O -inline -release -version=test *.d
```
or
```
dmd -O -inline -release -version=test -version=dfl *.d
```
___
Licensing
=========

Plot2Kill is licensed under the Boost license. You may not be able to use it
under such permissive terms if you link to a copylefted GUI library. For
example, GTK and gtkD are LGPL, which adds some (minor) requirements to
executables that link to it, but imposes no burdens on source code that simply
refers to the LGPL'd library. (The sources to this project, in isolation,
would be considered a "work that uses the library" and fall outside the scope
of the LGPL.)

beatportproToTraktor
====================

A utility for converting id3 tags from Beatport Pro into a better format for Traktor's tag importer


Installation
------------

Before you install the gem, make sure to have taglib installed with header files (and a C++ compiler of course):
•	Debian/Ubuntu: sudo apt-get install libtag1-dev
•	Fedora/RHEL: sudo yum install taglib-devel
•	Brew: brew install taglib
•	MacPorts: sudo port install taglib

Then do:
```
gem install taglib-ruby
```

Execution
---------

Details
-------
Beatport Pro (and iTunes) writes the id3v2 'Date' field "TDRC" with the Year value only.
It instead writes the fully YYYY-MM-DD value to "TDOR" and "TDRL", "Original Release" and "Release Tine" respecively. 

This script simply copies the values to the TDRC field.

TODO
----

- Plans to fix the Key / Key Text fields also
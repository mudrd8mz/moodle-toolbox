TOOLBOX
=======

This repository contains various utilities and tools that can be used
during PHP + SQL development.


Compare PostgreSQL dumps
------------------------

I use this script to compare schemas of two SQL dumps. It takes SQL dump
produced by pg_dump and converts it into a text file suitable for diffing.
Tables and fields in a table are sorted.

Example of usage:

    $ pg_dump -s moodle20a > moodle20a.sql
    $ pg_dump -s moodle20b > moodle20b.sql
    $ comparesql.php moodle20a.sql > moodle20a.txt
    $ comparesql.php moodle20b.sql > moodle20b.txt
    $ diff moodle20a.txt moodle20b.txt

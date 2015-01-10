david's moodle toolbox
======================

This repository contains various utilities and tools that I occasionally use during Moodle development and administration.

db: database
------------

Comparing PostgreSQL dumps: I use this script to compare schemas of two SQL dumps. It takes SQL dump produced by pg_dump and
converts it into a text file suitable for diffing.  Tables and fields in a table are sorted.

    $ pg_dump -s moodle20a > moodle20a.sql
    $ pg_dump -s moodle20b > moodle20b.sql
    $ comparesql.php moodle20a.sql > moodle20a.txt
    $ comparesql.php moodle20b.sql > moodle20b.txt
    $ diff moodle20a.txt moodle20b.txt

git: moodle.git helpers
-----------------------

Note: I switched to `mdk`, these are here for the reference only.

    $ cd ~/public_html/m28
    $ git checkout -b MDL-12345-something origin/master
    $ ... (edit files, commit the changes)
    $ git push github
    $ mpullinfo
    $ git checkout MOODLE_28_STABLE
    $ mprune

lang: strings checking and manipulation
---------------------------------------

Check multiple string definitions: Moodle and Mahara defines strings as associative array. I use this script to detect if there is a
single string defined multiple times in a file.

    $ cd ~/public_html/moodle20
    $ for stringfile in $( find -type f -name '*.php' | grep '/lang/en/' | sort ); do
    > php checkmultistring.php $stringfile
    > done

mbz: moodle backups
-------------------

Command-line tools for processing moodle backup files (MBZ).

Bulk restore of multiple course backups:

    $ sudo -u apache php mbz-restorecourses.php \
        --sourcedir=/path/to/folder/ \
        --categoryid=1 --userid=2

plugins:
--------

To install a downloaded plugin:

    $ cd ~/www/mdk/m28/moodle
    $ mplug.sh ~/tmp/mod_foobar_moodle28_2015010100.zip


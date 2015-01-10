#!/usr/bin/php
<?php
/*
comparesql.php - converts SQL dump into a format suitable for comparing

Copyright (C) 2011 David Mudrak <david.mudrak@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

if ($argc == 1 or $argc == 2 and ($argv[1] == '-h' or $argv[1] == '--help')) {
    echo "Usage: {$argv[0]} pgdumpfile.sql\n";
    exit(1);
}

$filename = $argv[1];

if (!is_readable($filename)) {
    echo "File not readable: $filename\n";
    exit(2);
}

$lines = file($filename, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES | FILE_TEXT);
$tables = array();
$tablename = '';

foreach ($lines as $line) {
    if (substr($line, 0, 2) == '--') {
        continue;
    }
    $matches = array();
    if (preg_match('/^CREATE TABLE (.*) \(/', $line, $matches)) {
        $tablename = $matches[1];
        continue;
    }
    if ($line == ');') {
        $tablename = '';
        continue;
    }
    if ($tablename) {
        $matches = array();
        if (preg_match('/^\s*(\w+)\s+([^,]*)(,?)$/', $line, $matches)) {
            $fieldname = $matches[1];
            $fieldspec = $matches[2];
            $tables[$tablename][$fieldname] = $fieldspec;
        }
    }
}

ksort($tables);
foreach ($tables as $tablename => $fields) {
    ksort($fields);
    echo "$tablename\n";
    foreach ($fields as $fieldname => $field) {
        echo "    $fieldname $field\n";
    }
}

#!/usr/bin/php
<?php
/*
checkmultistring.php

Copyright (C) 2011 David Mudrak <david.mudrak@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

if ($argc == 1 or $argc == 2 and ($argv[1] == '-h' or $argv[1] == '--help')) {
    echo "Usage: {$argv[0]} /path/to/lang/en/file.php\n";
    exit(1);
}

$filename = $argv[1];

if (!is_readable($filename)) {
    echo "File not readable: $filename\n";
    exit(2);
}

$counts = array();

$string = array();
include($filename);
foreach (array_keys($string) as $s) {
    $counts[$s] = 0;
}
unset($string);

$content = file_get_contents($filename);
$matches = array();
preg_match_all('/\n\$string\[\'(.+)\'\]/', $content, $matches);
foreach ($matches[1] as $s) {
    if (!isset($counts[$s])) {
        echo "$filename\tUnknown string identifier: $s\n";
        exit(-1);
    }
    $counts[$s]++;
}

$return = 0;
foreach ($counts as $stringid => $count) {
    if ($count !== 1) {
        echo "$filename\t$stringid\n";
        $return = -100;
    }
}

exit($return);

<?php
// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * Tool for mass deletion of courses in a given category.
 *
 * At the moment, this is not recursive. It does not delete courses in
 * subcategories. Also, it does not delete the category itself or anything else
 * in it (such as cohorts, questions etc).
 *
 * @package     core
 * @subpackage  cli
 * @copyright   2016 David Mudrak <david@moodle.com>
 * @license     http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

$help = "Mass deletion of courses in a given category.

Usage:
    delete-courses.php --category=<id> [--skip-recycle-bin]

Options:
    --category=<id>     ID of the course category.
    --skip-recycle-bin  Do not keep deleted courses in the recycle bin.
";

define('CLI_SCRIPT', true);

require(dirname(dirname(dirname(__FILE__))).'/config.php');
require_once($CFG->libdir.'/clilib.php');

list($options, $unrecognized) = cli_get_params(
    array(
        'category' => null,
        'skip-recycle-bin' => false,
        'help' => false
    ),
    array(
        'h' => 'help',
    )
);

if ($unrecognized) {
    $unrecognized = implode("\n  ", $unrecognized);
    cli_writeln($help);
    cli_error(get_string('cliunknowoption', 'admin', $unrecognized));
}

if ($options['help']) {
    cli_writeln($help);
    exit(0);
}

// Delete all courses from the given category.
if ($options['category']) {
    $categoryid = clean_param($options['category'], PARAM_INT);
    $courses = $DB->get_records('course', array('category' => $categoryid), 'sortorder ASC');
    $count = count($courses);

    if (empty($courses)) {
        cli_error("No course found in the category ".$categoryid);
    }

    cli_heading("Following courses will be deleted");
    $samplesize = 5;
    $sample = array_slice($courses, 0, $samplesize);
    foreach ($sample as $course) {
        cli_writeln(" [".$course->shortname."] ".$course->fullname);
    }
    if (count($sample) < $count) {
        cli_writeln(" ... and others");
    }
    cli_writeln("Total number of courses to be deleted: ".$count);

    cli_writeln("This cannot be undone, do you really want to continue?");
    $prompt = get_string('cliyesnoprompt', 'core_admin');
    $input = cli_input($prompt, '', array(get_string('clianswerno', 'core_admin'), get_string('cliansweryes', 'core_admin')));
    if ($input === get_string('clianswerno', 'core_admin')) {
        exit(1);
    }

    $done = 0;
    foreach ($courses as $course) {
        if ($options['skip-recycle-bin']) {
            // This is a hack, we pretend to be executed by the restore process
            // so that the recycle bin hook is skipped.
            $course->deletesource = 'restore';
        }
        if (!delete_course($course, false)) {
            throw new moodle_exception('cannotdeletecategorycourse', '', '', $course->shortname);
        }
        $done++;
        cli_write("\r".$done."/".$count." (".floor($done / $count * 100)."%) ");
    }
    cli_writeln("done!");

} else {
    cli_writeln($help);
}

cache_helper::purge_by_event('changesincoursecat');

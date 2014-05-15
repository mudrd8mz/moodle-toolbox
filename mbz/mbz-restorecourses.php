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
 * Bulk restore of MBZ courses from the command line
 *
 * @copyright   2014 David Mudrak <david@moodle.com>
 * @license     http://www.gnu.org/copyleft/gpl.html GNU GPL v3 or later
 */

define('CLI_SCRIPT', true);
define('EX_USAGE', 64);
define('EX_ARGS', 65);

$usage = <<<EOF
Restores all *.mbz files with course backups in the given directory.

Usage:
    $ sudo -u apache php mbz-restorecourses.php --sourcedir=/path/to/folder/ --categoryid=1 --userid=2

Options:
    --sourcedir     Full path to the directory containing MBZ files with course backups
    --categoryid    ID of the target Moodle category to restore files to
    --userid        ID of the Moodle user performing the restore
    --verbose, -v   Be verbose for debugging
    --help, -h      Print this usage and exit

EOF;

require_once(__DIR__.'/config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->dirroot . '/backup/util/includes/restore_includes.php');

list($options, $unrecognized) = cli_get_params(
    array(
        'sourcedir' => '',
        'categoryid' => null,
        'userid' => null,
        'verbose' => false,
        'help' => false,
    ),
    array(
        'v' => 'verbose',
        'h' => 'help',
    )
);

if ($options['help']
        or empty($options['sourcedir'])
        or empty($options['categoryid'])
        or empty($options['userid'])
        or !empty($unrecognized)) {
    cli_error($usage, EX_USAGE);
}

if (!is_dir($options['sourcedir'])) {
    cli_error('Invalid source directory', EX_ARGS);
}

if (!is_numeric($options['categoryid'])) {
    cli_error('Invalid categoryid', EX_ARGS);
}

if (!is_numeric($options['userid'])) {
    cli_error('Invalid userid', EX_ARGS);
}

$sourcefiles = new DirectoryIterator($options['sourcedir']);

foreach ($sourcefiles as $sourcefile) {
    if ($sourcefile->isDot()) {
        continue;
    }
    if ($sourcefile->getExtension() !== 'mbz') {
        if ($options['verbose']) {
            cli_problem('Debug: skipping file '.$sourcefile->getFilename());
        }
        continue;
    }

    cli_heading($sourcefile->getFilename());

    // Extract the file.
    $packer = get_file_packer('application/vnd.moodle.backup');
    $backupid = restore_controller::get_tempdir_name(SITEID, $options['userid']);
    $path = "$CFG->tempdir/backup/$backupid/";
    if (!$packer->extract_to_pathname($sourcefile->getPathname(), $path)) {
        cli_error('Invalid backup file '.$sourcefile->getFilename());
    }

    if ($options['verbose']) {
        cli_problem('Debug: extracted to ' . $path);
    }

    // Start delegated transaction.
    $transaction = $DB->start_delegated_transaction();

    // Create new course.
    $courseid = restore_dbops::create_new_course('clirestored', 'clirestored', $options['categoryid']);
    if ($options['verbose']) {
        cli_problem('Debug: created new course id ' . $courseid);
    }

    // Restore backup into course.
    $controller = new restore_controller($backupid, $courseid, backup::INTERACTIVE_NO,
        backup::MODE_GENERAL, $options['userid'], backup::TARGET_NEW_COURSE);
    if ($controller->execute_precheck()) {
        $controller->execute_plan();

    } else {
        cli_problem('Precheck fails for ' . $sourcefile->getFilename() . ' ... skipping');
        continue;
    }

    // Commit.
    $transaction->allow_commit();
}

<?php

/**
 *     Written by Nico Bergemann <barracuda415@yahoo.de>
 *     Copyright 2011 Nico Bergemann
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// minimum required PHP version
define('PHP_VERSION_REQUIRED', '5.1.0');
// comment out or set to false in productive environments
define('DEBUG', false);

// check for required PHP version 
if (version_compare(PHP_VERSION, PHP_VERSION_REQUIRED, '<')) {
    throw new RuntimeException(sprintf('PHP %s is not supported (required: PHP %s or higher)', PHP_VERSION, PHP_VERSION_REQUIRED));
}

// throw exceptions for non-fatal PHP errors
function exception_error_handler($errno, $errstr, $errfile, $errline) {
    throw new ErrorException($errstr, 0, $errno, $errfile, $errline);
}
set_error_handler("exception_error_handler");

// avoid tainted error messages
ini_set('html_errors', false);

// set error reporting level
if (defined('DEBUG') && DEBUG) {
    error_reporting(E_ALL);
} else {
    error_reporting(E_ERROR | E_WARNING | E_PARSE);
}
?>
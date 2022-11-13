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

try {
    require_once 'lib/main.php';
} catch (Exception $e) {
    require_once 'lib/steamprofile/ajax/XMLError.php';
    
    // print XML-formatted error
    $oError = new XMLError($e);
    $oError->build();
    exit();
}

require_once 'lib/steamprofile/ajax/SteamProfileXMLProxyApp.php';

// start application
$App = new SteamProfileXMLProxyApp();
$App->run();
?>
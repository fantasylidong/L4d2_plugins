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

require_once 'lib/util/ArrayConfig.php';

class FileConfig extends ArrayConfig {

    private static $aInstances = array();

    public static function getInstance($sConfigFile) {
        $sKey = function_exists('hash') ? hash('md5', $sConfigFile) : md5($sConfigFile);

        if (isset(self::$aInstances[$sKey])) {
            return self::$aInstances[$sKey];
        } else {
            return self::$aInstances[$sKey] = new FileConfig($sConfigFile);
        }
    }

    protected function __construct($sConfigFile) {
        parent::__construct(parse_ini_file($sConfigFile));
    }

}

?>
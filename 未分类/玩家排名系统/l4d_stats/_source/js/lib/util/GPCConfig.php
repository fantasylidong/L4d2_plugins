<?php

/*
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

class GPCConfig extends ArrayConfig {

    private static $aInstances = array();

    public static function getInstance($sGPC) {
        if (isset(self::$aInstances[$sGPC])) {
            return self::$aInstances[$sGPC];
        } else {
            return self::$aInstances[$sGPC] = new GPCConfig($sGPC);
        }
    }

    protected function __construct($sGPC) {
        $aConfig = array();

        switch ($sGPC) {
            case 'get':
                $aConfig = $_GET;
                break;

            case 'post':
                $aConfig = $_POST;
                break;

            case 'cookie':
                $aConfig = $_COOKIE;
                break;

            default:
                throw new InvalidArgumentException('Invalid config mode');
        }

        parent::__construct($aConfig);
    }

}

?>
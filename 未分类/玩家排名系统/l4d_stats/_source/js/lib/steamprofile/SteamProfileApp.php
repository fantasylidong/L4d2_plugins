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

require_once 'lib/steam/SteamID.php';
require_once 'lib/io/Cache.php';

abstract class SteamProfileApp {

    public static function getName() {
        return "SteamProfile";
    }
    
    public static function getVersion() {
        return "2.1.2";
    }
    
    public static function getUserAgent() {
        return self::getName() . '/' . self::getVersion();
    }

    private static $aValidLang = array(
        'danish',
        'czech',
        'dutch',
        'english',
        'finnish',
        'french',
        'german',
        'hungarian',
        'italian',
        'japanese',
        'norwegian',
        'polish',
        'portuguese',
        'romanian',
        'russian',
        'schinese',
        'spanish',
        'swedish',
        'tchinese',
        'thai'
    );

    public function getProfileUrl($bLang = true) {
        // load config
        $oGPCConfig = GPCConfig::getInstance('get');

        // get selected id
        $sID = $oGPCConfig->getString('id', null);

        if ($sID == null) {
            throw new Exception('No profile ID assigned');
        }

        $oSteamID = new SteamID($sID);
        $sXmlUrl = 'http://steamcommunity.com/';

        // choose if we got a numeric id or an alias
        if (!$oSteamID->isValid()) {
            // complain about invalid characters, if found
            if (!preg_match('/^[a-zA-Z0-9-_]+$/', $sID)) {
                throw new Exception("Invalid profile alias: $sID");
            }

            $sXmlUrl .= 'id/' . $sID;
        } else {
            $sXmlUrl .= 'profiles/' . $oSteamID->getSteamID64();
        }

        // add xml parameter so we get xml data (hopefully)
        $sXmlUrl .= '?xml=1';

        // get language setting
        $sLang = $oGPCConfig->getString('lang', null);

        if (!$bLang || $sLang == null) {
            // we're done here
            return $sXmlUrl;
        }

        $sLang = strtolower($sLang);

        if (in_array($sLang, self::$aValidLang)) {
            // add language parameter
            $sXmlUrl .= '&l=' . $sLang;
        }

        return $sXmlUrl;
    }

}

?>

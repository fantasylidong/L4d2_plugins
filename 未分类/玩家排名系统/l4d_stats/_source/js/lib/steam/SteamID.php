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

/**
 * Class to check and convert Steam-IDs. Uses the transformation algorithm discovered 
 * by Voogru (http://forums.alliedmods.net/showthread.php?t=60899).
 *
 * @author Nico Bergemann
 */
class SteamID {

    private $sSteamID = '';
    private $sSteamID64 = '';

    // 0x0110000100000000
    const STEAMID64_U = '76561197960265728';

    public function __construct($sID) {
        // make sure the bcmath extension is loaded
        if (!extension_loaded('bcmath')) {
            throw new RuntimeException("BCMath extension required");
        }

        if ($this->isValidID($sID)) {
            $this->sSteamID = $sID;
            $this->sSteamID64 = $this->toSteamID64($sID);
        } elseif ($this->isValidID64($sID)) {
            $this->sSteamID = $this->toSteamID($sID);
            $this->sSteamID64 = $sID;
        } else {
            $this->sSteamID = '';
            $this->sSteamID64 = '';
        }
    }

    public function getSteamID() {
        return $this->sSteamID;
    }

    public function getSteamID64() {
        return $this->sSteamID64;
    }

    public function isValid() {
        return $this->sSteamID != '';
    }

    private function isValidID($sSteamID) {
        return preg_match('/^(STEAM_)?[0-5]:[0-9]:\d+$/i', $sSteamID);
    }

    private function isValidID64($sSteamID64) {
        // anything else than a number is invalid
        // (is_numeric() doesn't work for 64 bit integers)
        if (!preg_match('/^\d+$/i', $sSteamID64)) {
            return false;
        }

        // the community id must be bigger than STEAMID64_BASE
        if (bccomp(self::STEAMID64_U, $sSteamID64) == 1) {
            return false;
        }

        return true;
    }

    private function toSteamID64($sSteamID) {
        $aID = explode(':', substr($sSteamID, 6));
        
        if (count($aID) != 3) {
            throw new InvalidArgumentException("Invalid SteamID format");
        }

        $sUniverse = $aID[0];
        $sServer = $aID[1];
        $sAuth = $aID[2];

        if (!is_numeric($sUniverse) || !is_numeric($sServer) || !is_numeric($sAuth)) {
            throw new InvalidArgumentException("Invalid SteamID format");
        }

        $sID64 = bcmul($sAuth, '2'); // multipy Auth-ID with 2
        $sID64 = bcadd($sID64, $sServer); // add Server-ID
        $sID64 = bcadd($sID64, self::STEAMID64_U); // add base ID
        // It seems that PHP appends ".0000000000" at the end sometimes.
        // I can't find a reason for this, so I'll have to take the dirty way...
        $sID64 = str_replace('.0000000000', '', $sID64);

        return $sID64;
    }

    private function toSteamID($sSteamID64) {
        if (!is_numeric($sSteamID64)) {
            throw new InvalidArgumentException("Invalid SteamID64 format");
        }
        
        $sUniverse = '0';
        $sServer = bcmod($sSteamID64, '2') == '0' ? '0' : '1';
        $sAuth = bcsub($sSteamID64, $sServer);
        $sAuth = bcsub($sAuth, self::STEAMID64_U);
        $sAuth = bcdiv($sAuth, '2');

        return "STEAM_$sUniverse:$sServer:$sAuth";
    }

}
?>
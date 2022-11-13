<?php
/**
 *	This file is part of SteamProfile.
 *
 *	Written by Nico Bergemann <barracuda415@yahoo.de>
 *	Copyright 2009 Nico Bergemann
 *
 *	SteamProfile is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	SteamProfile is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with SteamProfile.  If not, see <http://www.gnu.org/licenses/>.
 */

// thanks to voogru for the id transformation algorithm (http://forums.alliedmods.net/showthread.php?t=60899)

class SteamID {
	private $sSteamID = '';
	private $sSteamComID = '';

	const STEAMID64_BASE = '76561197960265728';

	public function __construct($sID) {
		$sPrefix = (PHP_SHLIB_SUFFIX === 'dll') ? 'php_' : '';

		if(!extension_loaded('bcmath') && !dl($sPrefix.'bcmath.'.PHP_SHLIB_SUFFIX)) {
			throw new RuntimeException("BCMath extension not avaiable");
		}

		if($this->isValidSteamID($sID)) {
			$this->sSteamID = $sID;
			$this->sSteamComID = $this->convertToSteamComID($sID);
		} elseif($this->isValidComID($sID)) {
			$this->sSteamID = $this->convertToSteamID($sID);
			$this->sSteamComID = $sID;
		} else {
			$this->sSteamID = '';
			$this->sSteamComID = '';
		}
	}

	public function getSteamID() {
		return $this->sSteamID;
	}
	
	public function getSteamComID() {
		return $this->sSteamComID;
	}
	
	public function isValid() {
		return $this->sSteamID != '';
	}

	private function isValidSteamID($sSteamID) {
		return preg_match('/^(STEAM_)?[0-5]:[0-9]:\d+$/i', $sSteamID);
	}

	private function isValidComID($sSteamComID) {
		// anything else than a number is invalid
		// (is_numeric() doesn't work for 64 bit integers)
		if(!preg_match('/^\d+$/i', $sSteamComID)) {
			return false;
		}

		// the community id must be bigger than STEAMID64_BASE
		if(bccomp(self::STEAMID64_BASE, $sSteamComID) == 1) {
			return false;
		}

		// TODO: Upper limit?

		return true;
	}

	private function convertToSteamComID($sSteamID) {
		$aTMP = explode(':', $sSteamID);

		$sServer = $aTMP[1];
		$sAuth = $aTMP[2];

		if((count($aTMP) == 3) && $sAuth != '0' && is_numeric($sServer) && is_numeric($sAuth)) {
			$sComID = bcmul($sAuth, "2"); // multipy Auth-ID with 2
			$sComID = bcadd($sComID, $sServer); // add Server-ID
			$sComID = bcadd($sComID, self::STEAMID64_BASE); // add this odd long number
			
			// It seems that PHP appends ".0000000000" at the end sometimes.
			// I can't find a reason for this, so I'll take the dirty way...
			$sComID = str_replace('.0000000000', '', $sComID);
			
			return $sComID;
		} else {
			throw new RuntimeException("Unable to convert Steam-ID");
		}
	}

	private function convertToSteamID($sSteamComID) {
		$sServer = bcmod($sSteamComID, '2') == '0' ? '0' : '1';
		$sCommID = bcsub($sSteamComID, $sServer);
		$sCommID = bcsub($sCommID, self::STEAMID64_BASE);
		$sAuth = bcdiv($sCommID, '2');

		return "STEAM_0:$sServer:$sAuth";
	}
}
?>
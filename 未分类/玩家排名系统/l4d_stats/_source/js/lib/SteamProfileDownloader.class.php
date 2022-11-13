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

class SteamProfileDownloader extends CURL {
	public function __construct($sUrl, $sVariant) {
		parent::__construct($sUrl);
		
		$aCURLVersion = curl_version();
		$this->setUserAgent('SteamProfile/2.0.2 ('.$sVariant.'; PHP '.PHP_VERSION.'; cURL '.$aCURLVersion['version'].')');
		
		// setting CURLOPT_FOLLOWLOCATION in safe_mode will raise a warning
		if(ini_get('safe_mode') == 'Off' || ini_get('safe_mode') === 0) {
			$this->setOption(CURLOPT_FOLLOWLOCATION, true);
			$this->setOption(CURLOPT_MAXREDIRS, 3);
		}
	}
	
	public function start() {
		$content = parent::start();
		
		// false means cURL failed
		if($content === false) {
			throw new Exception('cURL error ('.$this->getErrorMessage().')');
		}
		
		// anything else than status code 2xx is most likely bad
		$iHTTPCode = $this->getHTTPCode();
		if($iHTTPCode < 200 || $iHTTPCode > 299) {
			throw new Exception("Steam Community server error (HTTP $iHTTPCode)");
		}
		
		return $content;
	}
}
?>
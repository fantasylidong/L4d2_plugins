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

class Cache {
	private $CacheDir = '';
	private $iLifetime = -1;
	private $sExtension = -1;

	public function __construct($CacheDir, $iLifetime = -1, $sExtension = 'dat') {
		$this->setCacheDir($CacheDir);
		$this->setLifetime($iLifetime);
		$this->setExtension($sExtension);
	}

	public function getCacheDir() {
		return $this->CacheDir;
	}
	
	public function setCacheDir($CacheDir) {
		if(!($CacheDir instanceof File)) {
			$CacheDir = new File($CacheDir);
		}
	
		if(!$CacheDir->exists()) {
			throw new RuntimeException("Cache directory \"$CacheDir\" does not exist.");
		}

		if(!$CacheDir->canWrite()) {
			throw new RuntimeException("Cache directory \"$CacheDir\" is not writable.");
		}
		
		$this->CacheDir = $CacheDir;
	}

	public function getLifetime() {
		return $this->iLifetime;
	}
	
	public function setLifetime($iLifetime) {
		$this->iLifetime = $iLifetime;
	}

	public function getExtension() {
		return $this->sExtension;
	}
	
	public function setExtension($sExtension) {
		$this->sExtension = $sExtension;
	}

	public function getFile($sIdentifier) {
		$sHash = function_exists('hash')? hash('md5', $sIdentifier) : md5($sIdentifier);
		$sFile = $sHash.'.'.$this->sExtension;
		$sPath = $this->CacheDir->getPath().'/'.$sFile;
		return new CacheFile($sPath, $this->iLifetime);
	}
}
?>
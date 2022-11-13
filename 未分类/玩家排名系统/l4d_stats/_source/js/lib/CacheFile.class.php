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

class CacheFile extends File {
	private $iLifetime = -1;

	public function __construct($sPath, $iLifetime = -1) {
		parent::__construct($sPath);
		$this->setLifetime($iLifetime);
	}
	
	public function getLifetime() {
		return $this->iLifetime;
	}

	public function setLifetime($iLifetime = -1) {
		$this->iLifetime = (int)$iLifetime;
	}
	
	public function isCached() {
		return $this->exists() && ($this->iLifetime == -1 || time() - $this->lastModified() <= $this->iLifetime);
	}
}
?>
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

class File {
	private $sPathName;

	public function __construct($sPathName) {
		$this->sPathName = $sPathName;
	}
	
	public function getPath() {
		return $this->sPathName;
	}
	
	public function getAbsolutePath() {
		return realpath($this->sPathName);
	}
	
	public function getName() {
		return basename($this->sPathName);
	}
	
	public function getParent() {
		return dirname($this->sPathName);
	}
	
	public function getSize() {
		return filesize($this->sPathName);
	}
	
	public function lastAccess() {
		return fileatime($this->sPathName);
	}
	
	public function lastModified() {
		return filemtime($this->sPathName);
	}

	public function exists() {
		return file_exists($this->sPathName);
	}
	
	public function canRead() {
		return is_readable($this->sPathName);
	}
	
	public function canWrite() {
		return is_writable($this->sPathName);
	}
	
	public function canExecute() {
		return is_executable($this->sPathName);
	}
	
	public function isFile() {
		return is_file($this->sPathName);
	}
	
	public function isDirectory() {
		return is_dir($this->sPathName);
	}
	
	public function readStdOut() {
		return readfile($this->sPathName);
	}
	
	public function readString() {
		return file_get_contents($this->sPathName);
	}
	
	public function writeString($sContent) {
		return file_put_contents($this->sPathName, $sContent);
	}

	public function copyFrom($sPathName) {
		return copy($sPathName, $this->sPathName);
	}

	public function copyTo($sPathName) {
		return copy($this->sPathName, $sPathName);
	}
	
	public function renameTo($sNewPathName) {
		if(rename($this->sPathName, $sNewPathName)) {
			$this->sPathName = $sNewPathName;
			return true;
		} else {
			return false;
		}
	}
	
	public function delete() {
		return unlink($this->sPathName);
	}
	
	public function __toString() {
		return $this->getPath();
	}
}
?>
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

require_once 'lib/io/File.php';
require_once 'lib/io/CacheFile.php';

class Cache {

    private $oCacheDir = '';
    private $iLifetime = -1;
    private $sExtension = -1;

    public function __construct($oCacheDir, $iLifetime = -1, $sExtension = 'dat') {
        $this->setCacheDir($oCacheDir);
        $this->setLifetime($iLifetime);
        $this->setExtension($sExtension);
    }

    public function getCacheDir() {
        return $this->oCacheDir;
    }

    public function setCacheDir($oCacheDir) {
        if (!($oCacheDir instanceof File)) {
            $oCacheDir = new File($oCacheDir);
        }

        if (!$oCacheDir->exists()) {
            throw new RuntimeException("Cache directory \"$oCacheDir\" does not exist.");
        }

        if (!$oCacheDir->canWrite()) {
            throw new RuntimeException("Cache directory \"$oCacheDir\" is not writable.");
        }

        $this->oCacheDir = $oCacheDir;
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
        $sHash = function_exists('hash') ? hash('md5', $sIdentifier) : md5($sIdentifier);
        $sFileName = $sHash . '.' . $this->sExtension;
        $sSubDir = substr($sFileName, 0, 2);
        $oCacheSubDir = $this->oCacheDir->getFile($sSubDir);

        // create subdir, if not existent
        if (!$oCacheSubDir->exists()) {
            $oCacheSubDir->mkdir();
        }

        $oCacheFile = $oCacheSubDir->getFile($sFileName);

        return new CacheFile($oCacheFile, $this->iLifetime);
    }

}

?>
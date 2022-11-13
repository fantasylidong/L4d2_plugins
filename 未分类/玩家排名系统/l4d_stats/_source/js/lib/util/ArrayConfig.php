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

require_once 'lib/util/Config.php';

class ArrayConfig extends Config {

    private $aConfig;

    protected function __construct($aConfig) {
        $this->aConfig = $aConfig;
    }

    public function getArray() {
        return $this->aConfig;
    }

    public function setArray($aConfig) {
        $this->aConfig = $aConfig;
    }

    public function merge(ArrayConfig $that) {
        $this->aConfig = array_merge($this->aConfig, $that->aConfig);
    }

    public function getString($sKey, $sDefault = '') {
        return isset($this->aConfig[$sKey]) ? $this->aConfig[$sKey] : $sDefault;
    }

    public function getStringAlnum($sKey, $sDefault = '', $iMaxLen = null) {
        $sString = $this->getString($sKey, $sDefault, $iMaxLen);
        
        if (!ctype_alnum($sString)) {
            return $sDefault;
        }
        
        return $sString;
    }
    
    public function getStringFiltered($sKey, $sDefault = '', $iMaxLen = null, $sAllowedChars = 'a-z0-9-_. ') {
        $sString = $this->getString($sKey, $sDefault, $iMaxLen);
        
        if (!preg_match("#^[$sAllowedChars]+$#i", $sString)) {
            return $sDefault;
        }
        
        return $sString;
    }

    public function getInteger($sKey, $iDefault = 0) {
        return isset($this->aConfig[$sKey]) ? (int) $this->aConfig[$sKey] : $iDefault;
    }

    public function getFloat($sKey, $fDefault = 0.0) {
        return isset($this->aConfig[$sKey]) ? (float) $this->aConfig[$sKey] : $fDefault;
    }

    public function getBoolean($sKey, $bDefault = false) {
        return isset($this->aConfig[$sKey]) ? (bool) $this->aConfig[$sKey] : $bDefault;
    }

}

?>
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
class CacheFile extends File {

    private $iLifetime = -1;

    public function __construct($path, $iLifetime = -1) {
        parent::__construct($path);
        $this->setLifetime($iLifetime);
    }

    public function getLifetime() {
        return $this->iLifetime;
    }

    public function setLifetime($iLifetime = -1) {
        $this->iLifetime = (int) $iLifetime;
    }

    public function isCached() {
        return $this->exists() && ($this->iLifetime == -1 || time() - $this->lastModified() <= $this->iLifetime);
    }

}

?>
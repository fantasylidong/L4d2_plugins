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
// a little hack to support the new exception class of PHP 5.3 with the pre-defined getPrevious() method
if (version_compare(PHP_VERSION, '5.3.0', '>=')) {

    class SteamProfileImageException extends Exception {
        // PHP 5.3 supports getPrevious() out of the box
    }

} else {

    class SteamProfileImageException extends Exception {

        private $previous;

        public function __construct($message = "", $code = 0, Exception $previous = null) {
            parent::__construct($message, $code);
            $this->previous = $previous;
        }

        public function getPrevious() {
            return $this->previous;
        }

    }

}
?>
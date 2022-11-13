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

require_once 'lib/net/HTTPHeader.php';

/**
 * XML error page generator
 *
 * @author Nico Bergemann <barracuda415 at yahoo.de>
 */
class XMLError {
    private $sMessage;
    
    public function __construct($msg) {
        if ($msg instanceof Exception) {
            $this->sMessage = $msg->getMessage();
        } else {
            $this->sMessage = $msg;
        }
    }
    
    public function build() {
        $oHeader = new HTTPHeader();
        $oHeader->setResponse('Content-Type', 'application/xml');
        echo '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        echo '<response><error><![CDATA[' . $this->sMessage . ']]></error></response>';
    }
}

?>

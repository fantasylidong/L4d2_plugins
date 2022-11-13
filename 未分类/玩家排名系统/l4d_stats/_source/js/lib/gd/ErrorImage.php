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
require_once 'lib/gd/GDImage.php';

class ErrorImage extends GDImage {

    public function __construct($message, $iWidth = null, $iHeight = null) {
        $iFont = 2;

        if ($message instanceof Exception) {
            $message = $message->getMessage();
            
            if (defined('DEBUG') && DEBUG) {
                $message .= "\n" . $message->getTraceAsString();
            }
        }

        // calculate image size
        if ($iWidth == null || $iHeight != null) {
            $aMessage = explode("\n", $message);
            $iFontWidth = imagefontwidth($iFont);
            $iFontHeight = imagefontheight($iFont);

            foreach ($aMessage as $sLine) {
                $iHeight += $iFontHeight + 1;
                $iMessageWidth = $iFontWidth * (strlen($sLine) + 1);
                if ($iMessageWidth > $iWidth) {
                    $iWidth = $iMessageWidth;
                }
            }

            $iHeight += 8;
        }

        parent::__construct($iWidth, $iHeight);

        $iFontColor = $this->getColor(255, 0, 0);
        $iBorderColor = $this->getColor(255, 0, 0);
        $iBGColor = $this->getColor(255, 255, 255);
        $iPadding = 4;

        $this->fill(0, 0, $iBGColor);
        $this->drawRectangle(0, 0, $this->getWidth() - 1, $this->getHeight() - 1, $iBorderColor);
        $this->drawText($message, $iFont, $iFontColor, $iPadding, $iPadding);
    }

}

?>
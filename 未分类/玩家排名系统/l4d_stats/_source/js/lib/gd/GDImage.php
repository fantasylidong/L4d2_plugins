<?php

/*
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

/**
 * A wrapper for GD functions (mostly image[...])
 *
 * @author Nico Bergemann
 */
class GDImage {
    
    public static function getInfo() {
        return gd_info();
    }
    
    public static function isAvailable() {
        return extension_loaded('gd');
    }

    protected $rImage;
    private $bAntiAlias = true;
    private $bAlphaBlending = true;
    private $bFullAlpha = false;

    protected static function convertBoundsToDim($aBounds) {
        $iMinX = min(array($aBounds[0], $aBounds[2], $aBounds[4], $aBounds[6]));
        $iMaxX = max(array($aBounds[0], $aBounds[2], $aBounds[4], $aBounds[6]));
        $iMinY = min(array($aBounds[1], $aBounds[3], $aBounds[5], $aBounds[7]));
        $iMaxY = max(array($aBounds[1], $aBounds[3], $aBounds[5], $aBounds[7]));

        return array(
            'left' => ($iMinX >= -1) ? -abs($iMinX + 1) : abs($iMinX + 2),
            'top' => abs($iMinY),
            'width' => $iMaxX - $iMinX,
            'height' => $iMaxY - $iMinY
        );
    }

    protected static function splitColor($iColor) {
        $iColor = abs($iColor);

        $aColors = array();
        $aColors['a'] = ($iColor & 0xff000000) >> 24;
        $aColors['r'] = ($iColor & 0xff0000) >> 16;
        $aColors['g'] = ($iColor & 0xff00) >> 8;
        $aColors['b'] = $iColor & 0xff;
        return $aColors;
    }

    public function __construct($iWidth = null, $iHeight = null) {
        // make sure the GD extension is loaded
        if (!self::isAvailable()) {
            throw new RuntimeException('GD extension required');
        }

        if ($iWidth != null) {
            $this->create($iWidth, $iHeight != null ? $iHeight : $iWidth);
        }
    }
    
    public function create($iWidth, $iHeight) {
        $this->rImage = imagecreatetruecolor($iWidth, $iHeight);
    }

    public function destroy() {
        if ($this->rImage != null) {
            try {
                // avoid further attempts to close this image by setting the
                // hander to null
                $rImage = $this->rImage;
                $this->rImage = null;

                return @imagedestroy($rImage);
            } catch (Exception $ex) {
                $this->rImage = null;

                return false;
            }
        }

        return false;
    }

    protected function replace(GDImage $image) {
        try {
            @imagedestroy($this->rImage);
        } catch (Exception $e) {
            
        }

        $this->rImage = $image->rImage;
        $this->bAlphaBlending = $image->bAlphaBlending;
        $this->bFullAlpha = $image->bFullAlpha;
    }

    public function getWidth() {
        return imagesx($this->rImage);
    }

    public function getHeight() {
        return imagesy($this->rImage);
    }

    public function getHandle() {
        return $this->rImage;
    }

    public function loadFont($sFontFile) {
        return imageloadfont($sFontFile);
    }

    public function drawText($sText, $iFont, $iColor, $iX, $iY) {
        $aText = explode("\n", $sText);
        $iLineHeight = imagefontheight($iFont);

        foreach ($aText as $sLine) {
            imagestring($this->rImage, $iFont, $iX, $iY, $sLine, $iColor);
            $iY += $iLineHeight;
        }
    }

    public function drawTextFT($sText, $sFontFile, $fSize, $fAngle, $iColor, $iX, $iY, $aExtra = array()) {
        return imagefttext($this->rImage, $fSize, $fAngle, $iX, $iY, $iColor, $sFontFile, $sText, $aExtra);
    }

    public function drawTextTTF($sText, $sFontFile, $fSize, $fAngle, $iColor, $iX, $iY) {
        return imagettftext($this->rImage, $fSize, $fAngle, $iX, $iY, $iColor, $sFontFile, $sText);
    }

    public function getTTFTextBounds($sText, $sFontFile, $fSize, $fAngle) {
        return imagettfbbox($fSize, $fAngle, $sFontFile, $sText);
    }

    public function getTTFTextDim($sText, $sFontFile, $fSize, $fAngle) {
        return self::convertBoundsToDim($this->getTTFTextBounds($sText, $sFontFile, $fSize, $fAngle));
    }

    public function getFTTextBounds($sText, $sFontFile, $fSize, $fAngle) {
        return imageftbbox($fSize, $fAngle, $sFontFile, $sText);
    }

    public function getFTTextDim($sText, $sFontFile, $fSize, $fAngle) {
        return self::convertBoundsToDim($this->getFTTextBounds($sText, $sFontFile, $fSize, $fAngle));
    }

    public function draw() {
        
    }

    public function drawRectangle($iX1, $iY1, $iX2, $iY2, $iColor) {
        return imagerectangle($this->rImage, $iX1, $iY1, $iX2, $iY2, $iColor);
    }

    public function drawFilledRectangle($iX1, $iY1, $iX2, $iY2, $iColor) {
        return imagefilledrectangle($this->rImage, $iX1, $iY1, $iX2, $iY2, $iColor);
    }

    public function drawLine($iX1, $iY1, $iX2, $iY2, $iColor) {
        return imageline($this->rImage, $iX1, $iY1, $iX2, $iY2, $iColor);
    }

    public function drawEllipse($iX, $iY, $iWidth, $iHeight, $iColor) {
        return imageellipse($this->rImage, $iX, $iY, $iWidth, $iHeight, $iColor);
    }

    public function drawFilledEllipse($iX, $iY, $iWidth, $iHeight, $iColor) {
        return imagefilledellipse($this->rImage, $iX, $iY, $iWidth, $iHeight, $iColor);
    }

    public function drawPixel($iX1, $iY1, $iColor) {
        return imagesetpixel($this->rImage, $iX1, $iY1, $iColor);
    }

    public function fill($iX, $iY, $iColor) {
        return imagefill($this->rImage, $iX, $iY, $iColor);
    }

    public function copy(GDImage $Image, $iX1, $iX2, $iY1 = 0, $iY2 = 0, $iWidth = null, $iHeight = null) {
        if ($iWidth == null) {
            $iWidth = $Image->getWidth();
        }

        if ($iHeight == null) {
            $iHeight = $Image->getHeight();
        }

        return imagecopy($this->rImage, $Image->getHandle(), $iX1, $iX2, $iY1, $iY2, $iWidth, $iHeight);
    }

    public function copyResized(GDImage $Image, $iX1, $iX2, $iY1, $iY2, $iDstWidth, $iDstHeight, $iWidth, $iHeight) {
        return imagecopyresized($this->rImage, $Image->rImage, $iX1, $iX2, $iY1, $iY2, $iDstWidth, $iDstHeight, $iWidth, $iHeight);
    }

    public function copyResampled(GDImage $Image, $iX1, $iX2, $iY1, $iY2, $iDstWidth, $iDstHeight, $iWidth, $iHeight) {
        return imagecopyresampled($this->rImage, $Image->rImage, $iX1, $iX2, $iY1, $iY2, $iDstWidth, $iDstHeight, $iWidth, $iHeight);
    }

    public function scale($iWidthNew, $iHeightNew, $bResample = false) {
        $iWidth = $this->getWidth();
        $iHeight = $this->getHeight();

        if ($iWidthNew == $iWidth && $iHeightNew == $iHeight) {
            // yeah, sure
            return;
        }

        $scaledImage = new GDImage($iWidthNew, $iHeightNew);
        $scaledImage->setAntiAlias($this->isAntiAlias());
        $scaledImage->setAlphaBlending($this->isAlphaBlending());
        $scaledImage->set8BitAlpha($this->is8BitAlpha());

        if ($bResample) {
            $scaledImage->copyResampled($this, 0, 0, 0, 0, $iWidthNew, $iHeightNew, $iWidth, $iHeight);
        } else {
            $scaledImage->copyResized($this, 0, 0, 0, 0, $iWidthNew, $iHeightNew, $iWidth, $iHeight);
        }

        $this->replace($scaledImage);
    }

    public function scaleByFactor($fFactor, $bResample = false) {
        if ($fFactor == 1.0) {
            // haha, very funny
            return;
        }

        if ($fFactor <= 0) {
            // nope.avi
            throw new InvalidArgumentException("Factor must be greater than 0");
        }

        $iWidthNew = round($this->getWidth() * $fFactor);
        $iHeightNew = round($this->getHeight() * $fFactor);

        $this->scale($iWidthNew, $iHeightNew, $bResample);
    }

    public function flip($iMode) {
        $iWidth = $this->getWidth();
        $iHeight = $this->getHeight();

        $src_x = 0;
        $src_y = 0;
        $src_width = $iWidth;
        $src_height = $iHeight;

        switch ($iMode) {
            case 1: //vertical
                $src_y = $iHeight - 1;
                $src_height = -$iHeight;
                break;

            case 2: //horizontal
                $src_x = $iWidth - 1;
                $src_width = -$iWidth;
                break;

            case 3: //both
                $src_x = $iWidth - 1;
                $src_y = $iHeight - 1;
                $src_width = -$iWidth;
                $src_height = -$iHeight;
                break;

            default:
                return;
        }

        $imgdest = new GDImage($iWidth, $iHeight);
        $imgdest->setAntiAlias($this->isAntiAlias());
        $imgdest->setAlphaBlending($this->isAlphaBlending());
        $imgdest->set8BitAlpha($this->is8BitAlpha());
        $imgdest->copyResampled($this, 0, 0, $src_x, $src_y, $iWidth, $iHeight, $src_width, $src_height);

        $this->replace($imgdest);
    }

    public function setAntiAlias($bAntiAlias) {
        $this->bAntiAlias = $bAntiAlias;

        // only available if PHP is compiled with the bundled version of the
        // GD library
        if (function_exists('imageantialias')) {
            return imageantialias($this->rImage, $this->bAntiAlias);
        } else {
            return false;
        }
    }

    public function isAntiAlias() {
        return $this->bAntiAlias;
    }

    public function setAlphaBlending($bAlphaBlending) {
        imagealphablending($this->rImage, $this->bAlphaBlending = $bAlphaBlending);
    }

    public function isAlphaBlending() {
        return $this->bAlphaBlending;
    }

    public function setSaveFullAlpha($bFullAlpha) {
        imagesavealpha($this->rImage, $this->bFullAlpha = $bFullAlpha);
    }

    public function isSaveFullAlpha() {
        return $this->bFullAlpha;
    }

    public function getColor($iR, $iG, $iB, $bAntiAlias = true) {
        return imagecolorallocate($this->rImage, $iR, $iG, $iB) * ($bAntiAlias ? 1 : -1);
    }

    public function getColorAlpha($iR, $iG, $iB, $iA, $bAntiAlias = true) {
        return imagecolorallocatealpha($this->rImage, $iR, $iG, $iB, $iA) * ($bAntiAlias ? 1 : -1);
    }

    public function getColorArray($aColor, $bAntiAlias = true) {
        return imagecolorallocate($this->rImage, $aColor[0], $aColor[1], $aColor[2]) * ($bAntiAlias ? 1 : -1);
    }

    public function getColorHex($sColor, $bAntiAlias = true) {
        return $this->getColorArray(sscanf($sColor, '#%2x%2x%2x')) * ($bAntiAlias ? 1 : -1);
    }

    public function getColorTransparent() {
        return imagecolortransparent($this->rImage);
    }

    public function getColorAt($iX, $iY) {
        return imagecolorat($this->rImage, $iX, $iY);
    }

    public function setColorTransparent($iColor) {
        imagecolortransparent($this->rImage, $iColor);
    }

    public function loadGD($sFile) {
        $this->rImage = imagecreatefromgd($sFile);
    }

    public function loadGD2($sFile) {
        $this->rImage = imagecreatefromgd2($sFile);
    }

    public function loadPng($sFile) {
        $this->rImage = imagecreatefrompng($sFile);
    }

    public function loadGif($sFile) {
        $this->rImage = imagecreatefromgif($sFile);
    }

    public function loadJpeg($sFile) {
        $this->rImage = imagecreatefromjpeg($sFile);
    }

    public function loadString($sImage) {
        $this->rImage = imagecreatefromstring($sImage);
    }

    public function toPng($sOutputFile = null) {
        if ($sOutputFile == null) {
            header('Content-Type: image/png');
        }
        return imagepng($this->rImage, $sOutputFile);
    }

    public function toJpeg($sOutputFile = null, $iQuality = 80) {
        if ($sOutputFile == null) {
            header('Content-Type: image/jpeg');
        }
        return imagejpeg($this->rImage, $sOutputFile, $iQuality);
    }

    public function toGif($sOutputFile = null) {
        if ($sOutputFile == null) {
            header('Content-Type: image/gif');
        }
        return imagegif($this->rImage, $sOutputFile);
    }

    public function toImage($sFormat, $sOutputFile = null, $iQuality = 80) {
        switch (strtolower($sFormat)) {
            case 'png':
                return $this->toPng($sOutputFile);
                
            case 'jpg':
            case 'jpeg':
                return $this->toJpeg($sOutputFile, $iQuality);
                
            case 'gif':
                return $this->toGif($sOutputFile);
                
            default:
                throw new InvalidArgumentException("Unknown image format");
        }
    }
}

?>
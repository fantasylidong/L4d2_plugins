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

require_once 'lib/Application.php';
require_once 'lib/util/FileConfig.php';
require_once 'lib/util/GPCConfig.php';
require_once 'lib/net/HTTPHeader.php';
require_once 'lib/gd/GDImage.php';
require_once 'lib/gd/ErrorImage.php';
require_once 'lib/steamprofile/SteamProfileApp.php';

class SteamProfileImageApp extends SteamProfileApp implements Application {

    public function run() {
        $bDebug = defined('DEBUG') && DEBUG;

        try {
            // get profile URL
            $sXmlUrl = $this->getProfileUrl(false);

            // load config
            $oCommonConfig = FileConfig::getInstance('common.cfg');
            $oImageConfig = FileConfig::getInstance('image.cfg');
            $oGPCConfig = GPCConfig::getInstance('get');

            // load config vars
            $iCacheLifetime = $oCommonConfig->getInteger('cache.lifetime', 600);
            $sCacheDir = $oCommonConfig->getString('cache.dir', 'cache');

            $bImageFallback = $oImageConfig->getString('image.fallback', true);
            $sDefaultLayout = $oImageConfig->getString('image.layout.default', 'small');
            $sDefaultTheme = $oImageConfig->getString('image.theme.default', 'default');
            $sLayout = $oGPCConfig->getStringAlnum('layout', $sDefaultLayout);
            $sTheme = $oGPCConfig->getStringAlnum('theme', $sDefaultTheme);

            // init cache
            $oImageCache = new Cache($sCacheDir, $iCacheLifetime, 'png');
            $oImageFile = $oImageCache->getFile($_SERVER['QUERY_STRING']);

            $sImageBase = 'image/layouts';

            if (!file_exists("$sImageBase/$sLayout")) {
                if (!file_exists("$sImageBase/$sDefaultLayout")) {
                    throw new RuntimeException('Default layout folder not found');
                }

                $sLayout = $sDefaultLayout;
            }
            
            $sLayoutDir = "$sImageBase/$sLayout";

            include "$sLayoutDir/SteamProfileImage.php";

            try {
                // do we have a cached version of the profile image?
                if (!$oImageFile->isCached()) {
                    $oProfileImage = new SteamProfileImage();
                    // try to generate the profile image
                    $oProfileImage->createProfile($sXmlUrl, $sLayoutDir, $sTheme);
                    // save it to cache
                    $oProfileImage->toPng($oImageFile->getPath());
                    // clear stat cache to ensure that the rest of the
                    // script will notice the file modification
                    clearstatcache();
                }

                $this->displayImage($oImageFile);
            } catch (SteamProfileImageException $e) {
                // on debug mode, re-throw
                if ($bDebug) {
                    $ep = $e->getPrevious();
                    throw $ep == null ? $e : $ep;
                }

                // an exception was thrown in SteamProfileImage,
                // but a themed error image could have been generated
                try {
                    // try a fallback to the cached image first
                    if ($bImageFallback && $oImageFile->exists()) {
                        $this->displayImage($oImageFile);
                    } else {
                        // try to display the error image
                        $oProfileImage->toPng();
                    }
                } catch (Exception $f) {
                    // didn't work, re-throw the source exception
                    throw $e;
                }
            } catch (Exception $e) {
                // on debug mode, re-throw
                if ($bDebug) {
                    $ep = $e->getPrevious();
                    throw $ep == null ? $e : $ep;
                }

                // an exception was thrown in SteamProfileImage,
                // but we could try a fallback to the cached image
                if ($bImageFallback && $oImageFile->exists()) {
                    // redirect to cached image file
                    $this->displayImage($oImageFile);
                } else {
                    // nothing cached, re-throw exception
                    throw $e;
                }
            }
        } catch (Exception $e) {
            // quite fatal error, try to render a fail-safe error image
            if ($bDebug || !GDImage::isAvailable()) {
                $oHeader = new HTTPHeader();
                $oHeader->setResponse('Content-Type', 'text/plain');
                echo $bDebug ? "$e\n" : $e->getMessage();
            } else {
                $ErrorImage = new ErrorImage($e->getMessage());
                $ErrorImage->toPng();
            }
        }
    }

    private function displayImage(File $oImageFile) {
        $oHeader = new HTTPHeader();

        if (!$oHeader->isModifiedSince($oImageFile->lastModified())) {
            $oHeader->setResponseCode(304);
        } else {
            $oHeader->setResponse('Content-Type', 'image/png');
            $oImageFile->readStdOut();
        }
    }

}
?>
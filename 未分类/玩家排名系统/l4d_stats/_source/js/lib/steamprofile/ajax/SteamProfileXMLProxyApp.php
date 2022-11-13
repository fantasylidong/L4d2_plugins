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
require_once 'lib/steamprofile/SteamProfileApp.php';
require_once 'lib/steamprofile/net/SteamProfileLoader.php';
require_once 'lib/steamprofile/ajax/XMLError.php';

class SteamProfileXMLProxyApp extends SteamProfileApp implements Application {

    public function run() {
        try {
            // load config
            $oProxyConfig = FileConfig::getInstance('xmlproxy.cfg');
            $oCommonConfig = FileConfig::getInstance('common.cfg');

            // load config vars
            $iCacheLifetime = $oCommonConfig->getInteger('cache.lifetime', 600);
            $sCacheDir = $oCommonConfig->getString('cache.dir', 'cache');
            $iDownloaderTimeout = $oCommonConfig->getInteger('downloader.timeout', 10);
            $bXMLHttpRequestOnly = $oProxyConfig->getBoolean('proxy.check_header', true);

            $oHeader = new HTTPHeader();

            // response to XMLHttpRequest only
            if ($bXMLHttpRequestOnly && !$oHeader->isXMLHttpRequest()) {
                $oHeader->setResponseCode(204);
                return;
            }

            // get profile URL
            $sXmlUrl = $this->getProfileUrl();

            // init cache
            $oXmlCache = new Cache($sCacheDir, $iCacheLifetime, 'xml');
            $oXmlFile = $oXmlCache->getFile($sXmlUrl);

            // do we have a cached version of the xml document?
            if (!$oXmlFile->isCached()) {
                try {
                    // initialize the downloader
                    $oProfileLoader = new SteamProfileLoader($sXmlUrl, SteamProfileApp::getUserAgent(), 'Ajax');
                    $oProfileLoader->setTimeout($iDownloaderTimeout);
                    $oProfileLoader->setTrimExtra(true);
                    $oProfileLoader->setFilterCtlChars(true);

                    $sXml = '';

                    try {
                        // try to download the XML file
                        $sXml = $oProfileLoader->start();
                    } catch (Exception $e) {
                        // didn't work, close cURL handle
                        $oProfileLoader->close();
                        throw $e;
                    }

                    // close cURL handle
                    $oProfileLoader->close();
                    // save document to cache
                    $oXmlFile->writeString($sXml);
                    // clear stat cache to ensure that the rest of the
                    // script will notice the file modification
                    clearstatcache();
                } catch (Exception $e) {
                    // downloading failed, but maybe we can redirect to the old file
                    if (!$oXmlFile->exists()) {
                        // no, we can't
                        throw $e;
                    }
                }
            }

            // use client cache, if possible
            if (!$oHeader->isModifiedSince($oXmlFile->lastModified())) {
                $oHeader->setResponseCode(304);
                return;
            } else {
                $oHeader->setResponse('Content-Type', 'application/xml');
                $oXmlFile->readStdOut();
            }
        } catch (Exception $e) {
            // print XML-formatted error
            $oError = new XMLError($e);
            $oError->build();
        }
    }

}

?>

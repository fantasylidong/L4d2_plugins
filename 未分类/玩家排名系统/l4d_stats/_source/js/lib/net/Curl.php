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

/**
 * Class Curl
 *
 * cURL object wrapper for basic downloading functions
 */
class Curl {
    
    public static function isAvailable() {
        return extension_loaded('curl');
    }

    private $rHandle;
    private $rOutputFile;
    private $bManualFollow;
    private $iMaxRedirs = 3;

    public function __construct($url) {
        // make sure the cURL extension is loaded
        if (!self::isAvailable()) {
            throw new RuntimeException('cURL extension required');
        }

        if ($url instanceof Curl) {
            $this->rHandle = curl_copy_handle($url->rHandle);
        } else {
            $this->rHandle = curl_init($url);
        }
    }
    
    protected function setOption($iOpt, $value) {
        $bOk = false;
        
        try {
            $bOk = @curl_setopt($this->rHandle, $iOpt, $value);
        } catch (Exception $e) {
        }
        
        // CURLOPT_FOLLOWLOCATION can't be modified in all PHP configurations
        if ($iOpt == CURLOPT_FOLLOWLOCATION && $value === true && !$bOk) {
            // we need to parse the 301/302 responses manually :(
            $this->bManualFollow = true;
            return true;
        }
        
        // save CURLOPT_MAXREDIRS in case the above is true
        if ($iOpt == CURLOPT_MAXREDIRS) {
            $this->iMaxRedirs = $value;
        }
        
        return $bOk;
    }

    protected function getInfo($iOpt) {
        return curl_getinfo($this->rHandle, $iOpt);
    }

    public function setOutputFile($file) {
        if (is_resource($file)) {
            $this->rOutputFile = $file;
            $this->setOption(CURLOPT_FILE, $file);
        } else {
            $this->rOutputFile = fopen($file, 'w+b');
            $this->setOption(CURLOPT_FILE, $this->rOutputFile);
        }
    }

    public function setReturnTransfer($bReturn) {
        $this->setOption(CURLOPT_RETURNTRANSFER, $bReturn);
    }

    public function setUserAgent($sUA) {
        $this->setOption(CURLOPT_USERAGENT, $sUA);
    }

    public function setTimeout($iTimeout) {
        $this->setOption(CURLOPT_TIMEOUT, $iTimeout);
    }

    public function setConnectTimeout($iTimeout) {
        $this->setOption(CURLOPT_CONNECTTIMEOUT, $iTimeout);
    }
    
    public function setFollowLocation($bFollow) {
        $this->setOption(CURLOPT_FOLLOWLOCATION, $bFollow);
    }
    
    public function setMaxRedirects($iMaxRedirs) {
        $this->setOption(CURLOPT_MAXREDIRS, $iMaxRedirs);
    }

    public function getHTTPCode() {
        return $this->getInfo(CURLINFO_HTTP_CODE);
    }
    
    public function hasError() {
        return $this->getErrorCode() !== 0;
    }
    
    public function getErrorCode() {
        return curl_errno($this->rHandle);
    }

    public function getErrorMessage() {
        return curl_error($this->rHandle);
    }

    public function start() {
        // follow locations manually if PHP doesn't allow us to do so
        if ($this->bManualFollow) {
            $this->followLocation($this->iMaxRedirs);
        }
        
        return curl_exec($this->rHandle);
    }

    public function close() {
        curl_close($this->rHandle);

        if (is_resource($this->rOutputFile)) {
            fclose($this->rOutputFile);
        }
    }

    private function followLocation($iMaxRedirs) {
        if ($iMaxRedirs <= 0) {
            return;
        }
        
        $sOrigUrl = $this->getInfo(CURLINFO_EFFECTIVE_URL);
        $sNewUrl = $sOrigUrl;

        $curl = $this->copy();
        $curl->setOption(CURLOPT_HEADER, true);
        $curl->setOption(CURLOPT_NOBODY, true);
        $curl->setOption(CURLOPT_FORBID_REUSE, false);
        $curl->setOption(CURLOPT_RETURNTRANSFER, true); 
        
        $aMatches = array();
        $sError = null;
        
        while (true) {
            if ($iMaxRedirs-- < 0) {
                $sError = "Too many redirects";
                break;
            }
            
            $curl->setOption(CURLOPT_URL, $sNewUrl);
            $sHeader = $curl->start();

            if ($curl->hasError()) {
                $sError = "cURL error while following the location: " . $curl->getErrorMessage();
                break;
            }
            
            $iCode = $curl->getHTTPCode();
            if ($iCode == 301 || $iCode == 302) {
                if (!preg_match('/Location:(.*?)\n/', $sHeader, $aMatches)) {
                    // can't find the location header, maybe it isn't a redirect?
                    break;
                }
                
                $sNewUrl = trim(array_pop($aMatches));

                // if no scheme is present then the new url is a
                // relative path and thus needs some extra care
                if (!preg_match("/^https?:/i", $sNewUrl)) {
                    $sNewUrl = $sOrigUrl . $sNewUrl;
                }
            } else {
                break;
            }
        }

        $curl->close();
        
        if ($sError != null) {
            throw new Exception($sError);
        }
        
        $this->setOption(CURLOPT_URL, $sNewUrl);
    }

    public function copy() {
        return new Curl($this);
    }
}

?>

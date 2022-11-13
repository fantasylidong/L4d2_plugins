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
 * Utility class to ease HTTP header handling
 *
 * @author Nico Bergemann
 */
class HTTPHeader {

    private static $aRequestHeaders = array();
    private static $aResponseHeaders = array();
    private static $aResponseCodes = array(
        100 => 'Continue',
        101 => 'Switching Protocols',
        200 => 'OK',
        201 => 'Created',
        202 => 'Accepted',
        203 => 'Non-Authoritative Information',
        204 => 'No Content',
        205 => 'Reset Content',
        206 => 'Partial Content',
        300 => 'Multiple Choices',
        301 => 'Moved Permanently',
        302 => 'Found',
        303 => 'See Other',
        304 => 'Not Modified',
        305 => 'Use Proxy',
        307 => 'Temporary Redirect',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        402 => 'Payment Required',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        406 => 'Not Acceptable',
        407 => 'Proxy Authentication Required',
        408 => 'Request Timeout',
        409 => 'Conflict',
        410 => 'Gone',
        411 => 'Length Required',
        412 => 'Precondition Failed',
        413 => 'Request Entity Too Large',
        414 => 'Request-URI Too Long',
        415 => 'Unsupported Media Type',
        416 => 'Requested Range Not Satisfiable',
        417 => 'Expectation Failed',
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        504 => 'Gateway Timeout',
        505 => 'HTTP Version Not Supported'
    );
    private static $aSpecialCase = array(
        'te' => 'TE',
        'content-md5' => 'Content-MD5',
        'etag' => 'ETag',
        'www-authenticate' => 'WWW-Authenticate'
    );

    public static function isValidHTTPCode($iCode) {
        return isset(self::$aResponseCodes[$iCode]);
    }

    public static function getHTTPCodeString($iCode) {
        return self::isValidHTTPCode($iCode) ? $iCode . ' ' . self::$aResponseCodes[$iCode] : (string) $iCode;
    }

    public function __construct() {
        if (count(self::$aRequestHeaders) == 0) {
            $this->refreshRequestHeaders();
        }

        if (count(self::$aResponseHeaders) == 0) {
            $this->refreshResponseHeaders();
        }
    }

    public function formatKey($sKey, $sSeparator) {
        $sKey = trim($sKey);

        // Some header names like "ETag" for example would
        // become "Etag" here, which could cause trouble for
        // some browsers, so better use the format from the list.
        $sKeyLower = strtolower($sKey);
        if (isset(self::$aSpecialCase[$sKeyLower])) {
            return self::$aSpecialCase[$sKeyLower];
        }

        // split the key
        $aWords = explode($sSeparator, $sKey);
        $iWords = count($aWords);

        // change case: REFERER -> Referer
        for ($i = 0; $i < $iWords; $i++) {
            $aWords[$i] = $this->fixKeyCase($aWords[$i]);
        }

        // put the key together with '-'
        return implode('-', $aWords);
    }

    public function fixKeyCase($sKey) {
        return ucfirst(strtolower($sKey));
    }

    public function refreshRequestHeaders() {
        // clear old headers
        self::$aRequestHeaders = array();

        // use the apache function, if possible
        if (function_exists('apache_request_headers')) {
            $aRequestHeaders = apache_request_headers();

            // make sure that all keys have the same case format
            foreach ($aRequestHeaders as $sKey => $sVal) {
                $sKey = $this->formatKey($sKey, '-');
                self::$aRequestHeaders[$sKey] = $sVal;
            }
        } else {
            foreach ($_SERVER as $sKey => $sVal) {
                // we need the "HTTP_*" keys only
                if (substr($sKey, 0, 5) != 'HTTP_') {
                    continue;
                }

                $sKey = $this->formatKey(substr($sKey, 5), '_');
                self::$aRequestHeaders[$sKey] = $sVal;
            }
        }
    }

    public function refreshResponseHeaders() {
        // clear old headers
        self::$aResponseHeaders = array();

        // use the apache function, if possible
        if (function_exists('apache_response_headers')) {
            self::$aResponseHeaders = apache_response_headers();
        } else {
            $aHeaderList = headers_list();
            foreach ($aHeaderList as $sHeader) {
                $aHeader = explode(':', $sHeader);
                self::$aResponseHeaders[$aHeader[0]] = trim($aHeader[1]);
            }
        }
    }

    public function setResponseCode($iCode) {
        if (self::isValidHTTPCode($iCode)) {
            return $this->setResponse('HTTP/1.1 ' . self::getHTTPCodeString($iCode));
        } else {
            return false;
        }
    }

    public function setResponse($sName, $sValue = null, $bReplace = true) {
        if (headers_sent()) {
            return false;
        } else {
            $sName = $this->formatKey($sName, '-');

            if ($sValue == null) {
                header($sName, $bReplace);
            } else {
                header("$sName: $sValue", $bReplace);
                self::$aResponseHeaders[$sName] = $sValue;
            }

            return true;
        }
    }

    public function getResponseHeader($sName) {
        return isset(self::$aResponseHeaders[$sName]) ? self::$aResponseHeaders[$sName] : null;
    }

    public function getResponseHeaders() {
        return self::$aResponseHeaders;
    }

    public function setRedirect($sTarget, $bRelative = true) {
        $sHost = $_SERVER['HTTP_HOST'];
        $sUri = $bRelative ? dirname($_SERVER['PHP_SELF']) : '';

        // use "303 See Other" instead of PHP's default "302 Found"
        $this->setResponseCode(303);
        $this->setResponse('Location', "http://$sHost$sUri/$sTarget");
    }

    public function getRequestHeader($sName) {
        return isset(self::$aRequestHeaders[$sName]) ? self::$aRequestHeaders[$sName] : null;
    }

    public function getRequestHeaders() {
        return self::$aRequestHeaders;
    }

    public function isModifiedSince($iTime) {
        $sModifiedSet = $this->getRequestHeader('If-Modified-Since');
        $sModifiedActual = gmdate('D, d M Y H:i:s \G\M\T', $iTime);

        if ($sModifiedSet == null) {
            $this->setResponse('Last-Modified', $sModifiedActual);
            return true;
        }

        if ($sModifiedSet === $sModifiedActual) {
            return false;
        } else {
            $this->setResponse('Last-Modified', $sModifiedActual);
            return true;
        }
    }

    public function hasEntityTag($sETag) {
        $sCurrentETag = $this->getRequestHeader('If-None-Match');

        if ($sCurrentETag == null || $sCurrentETag !== $sETag) {
            $this->setResponse('ETag', $sETag);
            return false;
        } else {
            return true;
        }
    }

    public function isXMLHttpRequest() {
        return ($this->getRequestHeader('X-Requested-With') == 'XMLHttpRequest');
    }

}

?>
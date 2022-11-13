<?php
/**
 *	This file is part of SteamProfile.
 *
 *	Written by Nico Bergemann <barracuda415@yahoo.de>
 *	Copyright 2009 Nico Bergemann
 *
 *	SteamProfile is free software: you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation, either version 3 of the License, or
 *	(at your option) any later version.
 *
 *	SteamProfile is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with SteamProfile.  If not, see <http://www.gnu.org/licenses/>.
 */

class HTTPHeaders {

	private $aRequestHeaders = array();
	private $aResponseHeaders = array();
	private $aResponseCodes = array(
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
	
	private static $Instance;
	
	public static function getInstance() {
		if(self::$Instance == null) {
			self::$Instance = new HTTPHeaders();
		}
		
		return self::$Instance;
	}
	
	public function __construct() {
		if(function_exists('apache_request_headers')) {
			$aRequestHeaders = apache_request_headers();
			
			// make sure that all keys have the same case format
			foreach($aRequestHeaders as $sKey => $sVal) {
				// split the key on '-'
				$aWords = explode('-', $sKey);
				$iWords = count($aWords);
				
				// change case: referer -> Referer
				for($i = 0; $i < $iWords; $i++) {
					$aWords[$i] = $this->fixKeyCase($aWords[$i]);
				}
				
				// put the key together with '-'
				$sKey = implode('-', $aWords);
				
				$this->aRequestHeaders[$sKey] = $sVal;
			}
		} else {
			foreach($_SERVER as $sKey => $sVal) {
				// we need the "HTTP_*" keys only
				if(substr($sKey, 0, 5) != 'HTTP_') {
					continue;
				}
				
				// remove 'HTTP_'
				$sKey = substr($sKey, 5);
				
				// split the key on '_'
				$aWords = explode('_', $sKey);
				$iWords = count($aWords);
				
				// change case: REFERER -> Referer
				for($i = 0; $i < $iWords; $i++) {
					$aWords[$i] = $this->fixKeyCase($aWords[$i]);
				}
				
				// put the key together with '-'
				$sKey = implode('-', $aWords);
				
				$this->aRequestHeaders[$sKey] = $sVal;
			}
		}
		
		$this->refreshResponseHeaders();
	}
	
	public function fixKeyCase($sKey) {
		return ucfirst(strtolower($sKey));
	}
	
	public function refreshResponseHeaders() {
		if(function_exists('apache_response_headers')) {
			$this->aResponseHeaders = apache_response_headers();
		} else {
			$aHeaderList = headers_list();
			foreach($aHeaderList as $sHeader) {
				$aHeader = explode(':', $sHeader);
				$this->aResponseHeaders[$aHeader[0]] = trim($aHeader[1]);
			}
		}
	}
	
	public function setResponseCode($iCode) {
		if(isset($this->aResponseCodes[$iCode])) {
			return $this->setResponse('HTTP/1.1 '.$iCode.' '.$this->aResponseCodes[$iCode]);
		} else {
			return false;
		}
	}

	public function setResponse($sName, $sValue = null, $bReplace = true) {
		if(headers_sent()) {
			return false;
		} else {
			$sName = $this->fixKeyCase($sName);
			if($sValue == null) {
				header("$sName", $bReplace);
			} else {
				header("$sName: $sValue", $bReplace);
			}
			return true;
		}
	}
	
	public function getResponse($sName) {
		return isset($this->aResponseHeaders[$sName])? $this->aResponseHeaders[$sName] : null;
	}
	
	public function getResponseAll() {
		return $this->aResponseHeaders;
	}
	
	public function setRedirect($sTarget, $bRelative = true) {
		$sHost = $_SERVER['HTTP_HOST'];
		$sUri = $bRelative? dirname($_SERVER['PHP_SELF']) : '';
		
		// use "303 See Other" instead of PHP's default "302 Found"
		$this->setResponseCode(303);
		$this->setResponse('Location', "http://$sHost$sUri/$sTarget");
	}
	
	public function getRequest($sName) {
		return isset($this->aRequestHeaders[$sName])? $this->aRequestHeaders[$sName] : null;
	}
	
	public function getRequestAll() {
		return $this->aRequestHeaders;
	}
	
	public function isModifiedSince($iTime) {
		$sModifiedSet = $this->getRequest('If-Modified-Since');
		$sModifiedActual = gmdate("D, d M Y H:i:s \G\M\T", $iTime);
		
		if($sModifiedSet == null) {
			$this->setResponse('Last-Modified', $sModifiedActual);
			return true;
		}
		
		if($sModifiedSet === $sModifiedActual) {
			return false;
		} else {
			$this->setResponse('Last-Modified', $sModifiedActual);
			return true;
		}
	}
}
?>
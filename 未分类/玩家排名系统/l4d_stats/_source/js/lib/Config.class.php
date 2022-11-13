<?php
class Config {
	protected static $aInstances = array();
	protected $aConfig;

	public static function load($sConfigFile) {
		if(isset(self::$aInstances[$sConfigFile])) {
			return self::$aInstances[$sConfigFile];
		} else {
			return self::$aInstances[$sConfigFile] = new Config($sConfigFile);
		}
	}
	
	public function __construct($sConfigFile) {
		$this->aConfig = parse_ini_file($sConfigFile);
	}
	
	public function getConfig() {
		return $this->aConfig;
	}
	
	public function setConfig($aConfig) {
		$this->aConfig = $aConfig;
	}
	
	public function merge(Config $config) {
		$this->aConfig = array_merge($this->aConfig, $config->getConfig());
	}

	public function getString($sKey = null, $sDefault = '') {
		return isset($this->aConfig[$sKey])? $this->aConfig[$sKey] : $sDefault;
	}
	
	public function getInteger($sKey = null, $iDefault = 0) {
		return isset($this->aConfig[$sKey])? (int)$this->aConfig[$sKey] : $iDefault;
	}
	
	public function getFloat($sKey = null, $fDefault = 0.0) {
		return isset($this->aConfig[$sKey])? (float)$this->aConfig[$sKey] : $fDefault;
	}
	
	public function getBoolean($sKey = null, $bDefault = false) {
		return isset($this->aConfig[$sKey])? (bool)$this->aConfig[$sKey] : $bDefault;
	}
}
?>
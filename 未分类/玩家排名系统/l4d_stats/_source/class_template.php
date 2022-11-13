<?php

class Template {
    // Primary variable array, used to store static data and output it into the template file
    var $vars;

    // Loads a template file $file to be used by the object
    function Template($file = null) {
        $this->file = $file;
    }

    // Sets the variable $name to $value, to be recalled in the loaded template file
    function set($name, $value) {
        $this->vars[$name] = is_object($value) ? $value->fetch() : $value;
    }

    // Opens the file $file, dumps all of the vars in $var to local variables, and then parses
    // the variables into the template, dumping it into $contents to be used later.
    // Note: $file does not have to be passed if it has been loaded with Template($filename)
    function fetch($file = null) {
        if(!$file) $file = $this->file;

        extract($this->vars);          // Extract the vars to local namespace

        ob_start();                    // Start output buffering
        include($file);                // Include the file
        $contents = ob_get_contents(); // Get the contents of the buffer
        ob_end_clean();                // End buffering and discard

        return $contents;              // Return the contents
    }
}

?>

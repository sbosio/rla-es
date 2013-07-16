<?php
/**
 * This script is intended to run on the directory where the synonym files live. E.g.:
 * palabras$ php -f ../herramientas/checkThesaurus.php
 *
 * This script DOES NOT replace the original files. Instead, it creates new files with the
 * the same name than the corresponding originals, appending ".new" to them.
 *
 * This script should be enhanced to allow specifying the language code or the full filenames
 */

define ("DEFAULT_DAT_FILE", 'th_es_ES_v2.dat');
define ("DEFAULT_IDX_FILE", 'th_es_ES_v2.idx');

// TODO grab command-line parameters
$datFile = DEFAULT_DAT_FILE;
$idxFile = DEFAULT_IDX_FILE;
$newDatFile = $datFile .".new";
$newIdxFile = $idxFile .".new";

/**
 * Files Character encoding
 */
$encoding = "";


/**
 * Compares two main term lines to sort them alphabetically
 */
function cmp($a, $b) {
    $first_parts = preg_split("/\|/", $a);
    $second_parts = preg_split("/\|/", $b);
    return(strcmp($first_parts[0], $second_parts[0]));
}

/**
 * Builds an array of entries, marking the number of occurrences of each one
 */
function buildEntryList($datFile) {
    $entryList = array();
    $datFHandle = fopen($datFile, "r");
    
    if ($datFHandle === FALSE) {
        exit("Can't open input and output files");
    }
    
    $readLine = fgets($datFHandle);
    while (!feof($datFHandle)) {
        $leftSide = substr($readLine, 0, strpos($readLine, "|"));
        
        switch ($leftSide) {
            case "-":
            case "(m.)":
            case "(f.)":
            case "(adj.)":
            case "(adv.)":
            case "(tr.)":
            case "(prnl.)":
            case "(m. fig.)":
            case "(intr.)":
            case "(interj.)":
            case "(fig.)":
            case "(intr.-prnl.)":
            case "(f. fig.)":
                // This is a non-main term line, so we increment
                // the counter and save the synonym list
                $entryList[$mainTerm]['SYNONYM_COUNT']++;
                break;
            default:
                // separate left side and synonym count
                $mainTerm = substr($readLine, 0, strpos($readLine, "|"));
                // print $mainTerm ."\n";
                if (array_key_exists($mainTerm, $entryList)) {
                    $entryList[$mainTerm]['APPEARANCES']++;
                } else {
                    $entryList[$mainTerm] = array(
                        'MAIN_TERM'    => $mainTerm,
                        'APPEARANCES'  => 1,
                        'SYNONYM_COUNT' => 0,
                        'SYNONYM_LIST' => array()
                    );
                }
        } // switch ($leftSide...)
        $readLine = fgets($datFHandle);
    }
    fclose($datFHandle);
    
    foreach($entryList as $entry) {
        if ($entry['APPEARANCES'] > 1) {
            print "- Duplicate entry: " .$entry['MAIN_TERM'] ." (" .$entry['APPEARANCES'] ." occurrences)\n";
        }
    }
    
    print "\nFinished reading dat file...\n\n";
    return $entryList;
}

/**
 * Re-reads the original dat file, creating a new file with no duplicate main terms
 */
function dumpEntries($datFile, $newDatFile, $entryList) {
    // One main term (the one that is followed by synonyms)
    $mainTerm = "";
    
    // line just read from input dat file
    $readLine = "";
    
    // Left side of the read line (everything to the left of "|")
    $leftSide = "";
    
    // Right side of the read line (everything to the right of "|")
    $rightSide = "";
    
    // Array of lines of synonyms for the current main term
    $linesArray = array();

    $datFHandle = fopen($datFile, "r");
    $newDatFHandle = fopen($newDatFile, "w");
    
    if (($datFHandle === FALSE) || ($newDatFHandle === FALSE)) {
        fclose($datFHandle);
        fclose($newDatFHandle);
        exit("Can't open input and output files");
    }
    
    // The first line declares the encoding
    $encoding = fgets($datFHandle);
    fwrite($newDatFHandle, $encoding);
    
    $readLine = fgets($datFHandle);
    while (!feof($datFHandle)) {
        $leftSide = substr($readLine, 0, strpos($readLine, "|"));
        $rightSide = substr($readLine, strpos($readLine, "|") + 1);
        
        switch ($leftSide) {
            case "-":
            case "(m.)":
            case "(f.)":
            case "(adj.)":
            case "(adv.)":
            case "(tr.)":
            case "(prnl.)":
            case "(m. fig.)":
            case "(intr.)":
            case "(interj.)":
            case "(fig.)":
            case "(intr.-prnl.)":
            case "(f. fig.)":
                // This is a non-main term line, so we increment
                // the counter and save the synonym list
                $linesArray[] = $readLine;
                break;
            default:
                // This is main term line, so we must first dump
                // the previous main term data, if any
                if (strlen($mainTerm) > 0) {
                    // If the main term exists in the $entryList built in the previous file read
                    if (array_key_exists($mainTerm, $entryList)) {
                        if ($entryList[$mainTerm]['APPEARANCES'] > 1) {
                            print "- Merging entries for duplicate term " .$mainTerm ." for a total of ";
                            $entryList[$mainTerm]['SYNONYM_LIST'] = array_merge($entryList[$mainTerm]['SYNONYM_LIST'], $linesArray);
                            print count($entryList[$mainTerm]['SYNONYM_LIST']) ."\n";
                            $entryList[$mainTerm]['APPEARANCES']--;
                        } else {
                            $entryList[$mainTerm]['SYNONYM_LIST'] = array_merge($entryList[$mainTerm]['SYNONYM_LIST'], $linesArray);
                            dumpOneEntry($newDatFHandle, $mainTerm, $entryList);
                        }
                    } else {
                        die("The entry $mainTerm doesn't exist in the file");
                    }
                    $linesArray = array();
                }
                
                $mainTerm = $leftSide;
        } // switch ($leftSide...)
        $readLine = fgets($datFHandle);
    }
    
    dumpOneEntry($newDatFHandle, $mainTerm, $entryList);
    
    fclose($datFHandle);
    fflush($newDatFHandle);
    fclose($newDatFHandle);
    
    return $encoding;
}

function dumpOneEntry($newDatFHandle, $mainTerm, $entryList) {
    // Count of synonyms
    $counter = count($entryList[$mainTerm]['SYNONYM_LIST']);
    
    // Escribimos el término anterior al que acabamos de alcanzar
    fwrite($newDatFHandle, $mainTerm ."|" .$counter ."\n");
    
    // E imprimimos cada sinónimo detectado
    foreach($entryList[$mainTerm]['SYNONYM_LIST'] as $sinonimo) {
        fwrite($newDatFHandle, $sinonimo);
    } // foreach
}

/**
 * The following code is the originally used to create the index, but is
 * run on the new dat file just created
 * Some variables have been renamed and comments have been thrown here and
 * there to make easier reading it
 */
function rebuildIndex($newDatFile, $encoding) {
    global $newIdxFile;
    
    $newDatFHandle = fopen($newDatFile, "r");
    $newIdxFHandle = fopen($newIdxFile, "w");
    
    if (($newDatFHandle === FALSE) || ($newIdxFHandle === FALSE)) {
        fclose($newDatFHandle);
        fclose($newIdxFHandle);
        exit("Can't open new data and idx files");
    }
    // Open the new dat file and load its full contents into $content
    $linesArray = array();
    $content = fread($newDatFHandle, filesize($newDatFile));
    $linesArray = preg_split("/\n/is", $content);
    fclose($newDatFHandle);
       
    // Read thesaurus line by line
    // First line of every block is an entry and meaning count
    $foffset = 0 + strlen($encoding);
    $i = 1; // Index to the current line and to linesArray
    $ne = 0; // Number of entries
    $tIndex = array();
    $uniqueWords = array();
    $warnings = 0;
    $maxWarnings = 100;
    $maxWarningsMsg = 0;
    while($i < sizeof($linesArray)) {
        $rec = $linesArray[$i];
        $rl = strlen($rec) + 1;
        $parts = split("\|", $rec);
        $entry = $parts[0];
        if(!isset($parts[1])) {
            $i++;
            continue;
        }
        $nm = $parts[1];
        $p = 0;
        while($p < $nm) {
            $i++;
            $meaning = $linesArray[$i];
            $rl = $rl + strlen($meaning) + 1;
            $p++;
        }      
        array_push($tIndex, "$entry|$foffset");
        $uniqueWords[$entry] = 1;
        $ne++;
        $foffset = $foffset + $rl;
        $i++;
    }
    
    # now we have all of the information
    # so sort it and then output the encoding, count and index data
    usort($tIndex, "cmp");
    fwrite($newIdxFHandle, $encoding);
    fwrite($newIdxFHandle, "$ne\n");
    foreach($tIndex as $one) {
        fwrite($newIdxFHandle, "$one\n");
    }
    fclose($newIdxFHandle);
}

$entryList = buildEntryList($datFile);
dumpEntries($datFile, $newDatFile, $entryList);
rebuildIndex($newDatFile, $encoding);


function IsNumeric ($Value) {
    return $Value -match "^[\d\.]+$"
}

function IsBoolean ($Value) {
    return $Value -match "^(true|false|True|False|TRUE|FALSE)$"
}

function IsEmpty ($Value) {
    return $Value -match "^$"
}

function GetValue($Value) {
    if(IsNumeric($Value) -or IsBoolean($Value)) {
        return -Join($_.value, ',') 
    } if(IsEmpty($Value)) {
        return -Join('null,') 
    } else {
        return -Join('"', $_.value, '",') 
    }
}

function GetHeaderRowItem($value)
{

        if(IsNumeric($value) -or IsBoolean($value)) {
            return "{{ record[##] }}"
        } else {
            return "'{{ record[##] }}'"
        }
    
}

function Create_Macro_From_CSV
{
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [String] $fileName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $macroFileName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [String] $macroPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=3)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [bool] $isForMacroSource
    )
    Process
    {
        $macro = [Collections.Generic.List[string]]::New()
        $dataRows = [Collections.Generic.List[object]]::New()
        $headers = [Collections.Generic.List[string]]::New()
        $dataValues = [Collections.Generic.List[string]]::New()
        $headerRec = [string]
        
        #get the overall file
        $records = Import-Csv $fileName
        # Get the header properties
        $records[0].psobject.properties.name | ForEach-Object { $headers.Add($_) }
        # Import the data again but for the Data Rows
        Import-Csv $fileName | ForEach-Object { $dataRows.Add($_) }


        # Start Macro
        $macro.Add(-JOIN("{% macro ", $macroFileName.replace(".sql", '') , "() %}"))
        if($isForMacroSource) {
            $macro.Add("(")
        }
        $macro.Add("    {% set records = [")


        #Process the data
        foreach($item in $dataRows)
        {
            $insertData = '['
            $records[$dataRows.IndexOf($item)].psobject.properties | ForEach-Object { $insertData += GetValue($_.value) }
            if($dataRows.IndexOf($item) + 1 -ne $dataRows.Count) {
                $insertData = -Join($insertData.Substring(0,$insertData.Length-1), '],')
            } else {
                $insertData = -Join($insertData.Substring(0,$insertData.Length-1), ']')
            }
            $macro.Add("        " + $insertData)
        }

        # Carry on with the macro
        $macro.Add("] %}")
        $macro.Add("    {% for record in records %}")

        # Process Header Row
        $headerRow = ''
        #get column types
        $dataRows[0].psobject.properties | ForEach-Object { $dataValues.Add($_.value) }

        foreach($header in $headers) {
            $colIndex = $headers.IndexOf($header)
            $headerRec = GetHeaderRowItem $dataValues[$colIndex] $colIndex
            $headerRow = -join($headerRow,  $headerRec.Replace("##", $colIndex) ," AS ", $header, ",")
        }

        $macro.Add("        SELECT " + $headerRow.Substring(0,$headerRow.Length-1))

        $macro.Add("        {% if not loop.last %}")
        $macro.Add("            UNION ALL")
        $macro.Add("        {% endif %}")
        $macro.Add("   {% endfor %}")
        if($isForMacroSource) {
            $macro.Add("   )")
        }
        $macro.Add("{% endmacro %}")

        $outFile = -Join($macroPath, "\\", $macroFileName)

        $macro | Out-File $outFile -Encoding utf8
    }
}

function Create_DebugHelper_From_CSV
{
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [String] $fileName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $macroFileName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [String] $sourcePath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=3)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $testCaseName
    )
    Process
    {
        $macro = [Collections.Generic.List[string]]::New()
        $headers = [Collections.Generic.List[string]]::New()
        
        #get the overall file
        $records = Import-Csv $fileName
        # Get the header properties
        $records[0].psobject.properties.name | ForEach-Object { $headers.Add($_) }

        # Process Header Row
        $headerRow = ''
        foreach($header in $headers) {
            $headerRow = -join($headerRow,  $header, ",")
        }

        # Start
        $macro.Add("WITH expected AS (")
        $macro.Add(-JOIN("  SELECT * FROM unit_tests.", $macroFileName.replace(".sql", '')))
        $macro.Add("),")
        $macro.Add("actual AS (")
        $macro.Add(-JOIN("  SELECT * FROM unit_tests.", $testCaseName))
        $macro.Add("),")
        $macro.Add("expected_minus_actual AS (")
        $macro.Add(-JOIN("  SELECT ", $headerRow.Substring(0,$headerRow.Length-1), " FROM expected"))
        $macro.Add("EXCEPT")
        $macro.Add(-JOIN("  SELECT ", $headerRow.Substring(0,$headerRow.Length-1), " FROM actual"))
        $macro.Add("),")
        $macro.Add("actual_minus_expected AS (")
        $macro.Add(-JOIN("  SELECT ", $headerRow.Substring(0,$headerRow.Length-1), " FROM actual"))
        $macro.Add("EXCEPT")
        $macro.Add(-JOIN("  SELECT ", $headerRow.Substring(0,$headerRow.Length-1), " FROM expected"))
        $macro.Add("),")
        $macro.Add("outputs AS (")
        $macro.Add("    SELECT 'expected' AS which_diff, expected_minus_actual.* FROM expected_minus_actual")
        $macro.Add("    UNION ALL")
        $macro.Add("    select 'actual' AS which_diff, actual_minus_expected.* FROM actual_minus_expected")
        $macro.Add(")")
        $macro.Add("SELECT * FROM outputs")

        $outFile = -Join($sourcePath, "\\DebugHelper.sql")

        $macro | Out-File $outFile -Encoding utf8
    }
}
function Check_Folder_Exists
{
    Param
    (
        [Parameter(Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $pathToTest,
        [Parameter(Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({Test-Path $_})]
        [String] $baseFilePath,
        [Parameter(Position=2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [String] $directoryToCreate
    )
    Process
    {
        if (Test-Path -Path $pathToTest) {
            Write-Host 'folder exists: ' $pathToTest
        } else {
            Write-Host 'creating folder: ' $pathToTest
            New-Item -Path $baseFilePath -Name $directoryToCreate -ItemType "directory"
        }
    }
}


$csvPath = '..\\tests\\csv'
$macroBasePath = '.\\macros'
$macroUnitTestBasePath =  -JOIN($macroBasePath, "\\unit_tests")
$macroBasePathSource = -JOIN($macroUnitTestBasePath, "\\inputs")
$macroBaseExpecetdResultPath = -JOIN($macroUnitTestBasePath, "\\outputs")

$modelBasePath = '.\\models'
$modelsUnitTestFilePath =  -JOIN($modelBasePath, "\\unit_tests")

Check_Folder_Exists -pathToTest $macroUnitTestBasePath -BaseFilePath $macroBasePath -DirectoryToCreate "unit_tests"
Check_Folder_Exists -pathToTest $macroBasePathSource -BaseFilePath $macroUnitTestBasePath -DirectoryToCreate "inputs"
Check_Folder_Exists -pathToTest $macroBaseExpecetdResultPath -BaseFilePath $macroUnitTestBasePath -DirectoryToCreate "outputs"
Check_Folder_Exists -pathToTest $modelsUnitTestFilePath -BaseFilePath $modelBasePath -DirectoryToCreate "unit_tests"


Get-ChildItem -Path $csvPath -Recurse -Include *.csv | ForEach-Object {   
    $macroFileName = -join($_.BaseName, ".sql")
    $fileName = -join($_.BaseName, ".csv")
    $currentDirectoryName =  split-path -Leaf  $_.DirectoryName
    $testCaseName = ""
    
    $isResult = $false;
    $isForMacroSource = $true;
    $macroPathSource = $macroBasePathSource
    
    if($fileName.StartsWith("utr")) {
        $isResult= $true
        $isForMacroSource = $false
        $macroPathSource = $macroBaseExpecetdResultPath
    }

    if($currentDirectoryName.StartsWith("tc__")) {
        $testCaseName = $currentDirectoryName
        $macroFileName = -join($currentDirectoryName, "__", $macroFileName)

        #traverse back up to the top schema level
        $currentDirectoryName =  split-path -Parent $_.DirectoryName
        $currentDirectoryName =  split-path -Parent $currentDirectoryName
        $currentDirectoryName =  split-path -Leaf  $currentDirectoryName

    }
    
    $macroFullPath = -JOIN($macroPathSource, "\\", $currentDirectoryName)
    Check_Folder_Exists -pathToTest $macroFullPath -BaseFilePath $macroPathSource -DirectoryToCreate $currentDirectoryName
    Write-Host "Processing file: " $fileName
    Create_Macro_From_CSV -fileName $_.FullName  -macroFileName $macroFileName -macroPath $macroFullPath -isForMacroSource $isForMacroSource

    if ($isResult) {
        $destinationDirectory = -Join($modelsUnitTestFilePath, '\\', $currentDirectoryName)
        Write-Host "Creating Unit Test File SQL: " $macroFileName " in  " $destinationDirectory
        Check_Folder_Exists -pathToTest $destinationDirectory -BaseFilePath $modelsUnitTestFilePath -DirectoryToCreate $currentDirectoryName
        $destinationSQLFile = -Join($destinationDirectory, "\\", $macroFileName)
        -JOIN("{{ ", $macroFileName.replace(".sql", '') , "() }}") | Set-Content $destinationSQLFile -encoding ascii
        Write-Host "Creating Debug Helper for " $macroFileName 
        Create_DebugHelper_From_CSV  -fileName $_.FullName  -macroFileName $macroFileName -sourcePath $_.DirectoryName -testCaseName $testCaseName
    }

}


Write-Host "converted all files"

$source  = ".\target\manifest.json"
$compare = ".\manifest.json"
$destination = "."

dbt clean
dbt deps
dbt seed

#check if we have a file or not
if (Test-Path -Path $compare -PathType Leaf) {
    dbt run -s state:modified --defer --state $destination
} else {
    dbt run
}

#always move after the run
Move-item -Path $source  -destination  $destination  -force
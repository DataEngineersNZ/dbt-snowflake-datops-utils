$source  = ".\target\run_results.json"
$compare = ".\run_results.json"
$destination = "."

.\create_test_models_from_csv.ps1
.\run.ps1

#check if we have a file or not
if (Test-Path -Path $compare -PathType Leaf) {
    dbt test -s state:modified --defer --state $destination
} else {
    dbt test
}

#always move after the run
Move-item -Path $source  -destination $destination  -force

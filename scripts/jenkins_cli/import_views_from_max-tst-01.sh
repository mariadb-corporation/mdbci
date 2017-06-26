function help {
    echo "Usage ./scripts/jenkins_cli/import_views_from_max-tst-01.sh -s HOST(with protocol) -p PORT"
}

while getopts ":s:p:h" opt; do
  case $opt in
    s) host="$OPTARG"
    ;;
    p) port="$OPTARG"
    ;;
    h) help
       exit
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        exit 1
    ;;
  esac
done

if [ -z "$host" ] || [ -z "$port" ]; then
    echo 'All arguments must be specified!'
    help
    exit 1
fi

path_to_views="scripts/jenkins_cli/max-tst-01_views"
max_tst_01_url="http://max-tst-01.mariadb.com"
max_tst_01_port=8089
views="axilary build env push_tests regular_test snapshot test upgrade_test"

if [ ! -d "$path_to_views" ]; then
   ./scripts/jenkins_cli/export_views.sh -s "$max_tst_01_url" -p "$max_tst_01_port" -d "$path_to_views" -v "$views"
fi
./scripts/jenkins_cli/import_views.sh -s "$host" -p "$port" -d "$path_to_views"


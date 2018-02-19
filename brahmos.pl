# Add the local library path
BEGIN {
	unshift(@INC, "lib");
}

use strict;
use warnings;
use Getopt::Long;
use FindBin;
use lib "$FindBin::Bin/lib";
 
# Local in-house modules
#
use Downloader;
use Importer;
use Script;

# Run the main method
#
sub main {
    my ($downloader, $recent, $import, $script, $script_all);
	GetOptions ( "download"  => \$downloader,
				 "recent"    => \$recent,
			     "import"    => \$import,
				 "script=s"  => \$script,
				 "script-all" => \$script_all);
	if(!$downloader && !$import && !$recent && !$script && !$script_all) {
		usage();
	}
	if($downloader) {
		Downloader::download_metadata();
		Downloader::download_all_equities();
	}
	if($import) {
		Importer::import_metadata_files();
        Importer::data_import();
	}
	if($recent) {
		Downloader::download_metadata();
		Importer::import_metadata_files();		
		Downloader::download_recent();
	}
	if($script) {
		Script::run_script($script);
	}
	if($script_all) {
		Script::run_all();
	}
    return;
}

sub usage() {
    print <<HELP;

    Usage: perl brahmos.pl
    Description: General utility tool to work on data from NSE

	--download : To download all EOD data (Bhavcopy) from NSE and unzip to csv
	--import   : Import the downloaded csv file to mysql database
	--recent   : Download the current year's recent file and upload to mysql database directly
	--script   : To run external scripts
	--script-all : To run all external scripts
	
	Examples:
	perl brahmos.pl --download
	perl brahmos.pl --import
	perl brahmos.pl --recent
	perl brahmos.pl --script --all
	perl brahmos.pl --script load_eod
	
HELP
exit;
}

main();
exit;
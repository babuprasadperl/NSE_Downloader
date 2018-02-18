package Downloader;

use File::Fetch;
use POSIX qw(strftime);
use LWP::UserAgent ();
use IO::Uncompress::Unzip qw(unzip $UnzipError) ;
use File::Path qw(make_path);
use Utils;

my $config = Utils::get_config();

my  $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;
$ua->default_header( 'Accept' => '*/*' );
$ua->default_header( 'Accept-Language' => 'en-US,en;q=0.5' );
$ua->default_header( 'Host' => 'nseindia.com' );
$ua->default_header( 'Referer' => "https://www.nseindia.com/live_market/dynaContent/live_watch/get_quote/GetQuote.jsp?symbol=INFY&illiquid=0&smeFlag=0&itpFlag=0" );
$ua->default_header( 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0' );
$ua->default_header( 'X-Requested-With' => 'XMLHttpRequest' );

sub download_metadata {
    #
    # Download equity list
    my $ret1 = download_url($config->{EQUITIES_URL}.$config->{EQUITIES_FILE}, $config->{DOWNLOADED_METADATA});
    print "EQUITIES downloaded successfully \n" if $ret1;
    #
    # Download futures list
    my $ret2 = download_url($config->{DERIVATIVES_URL}.$config->{DERIVATIVES_FILE}, $config->{DOWNLOADED_METADATA});
    print "FUTURES downloaded successfully \n" if $ret2;
    return;
}

sub download_all_equities {

    # Example URL to download the bhavcopy zip files
    # https://www.nseindia.com/content/historical/EQUITIES/2014/JAN/cm09JAN2014bhav.csv.zip
    #
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime(time);
    my $url = $config->{BHAVCOPY_BASE_URL};
    for (my $eq_year = $config->{START_YEAR}; $eq_year <= Utils::get_year($year); $eq_year++ ) {
        for (my $eq_month = 0; $eq_month <= 11; $eq_month++) {
            for (my $eq_date = 1; $eq_date <= 31; $eq_date++) {
                download_data($eq_year, $eq_month, $eq_date, $url);
            }
        }
    }
    print "Downloading completed successfully\n\n\n";
    return 1;
}

sub download_recent {
    # Example URL to download the bhavcopy zip files
    # https://www.nseindia.com/content/historical/EQUITIES/2014/JAN/cm09JAN2014bhav.csv.zip
    #
    Importer::remove_workdir();
    Importer::create_workdir();
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime(time);
    my $url = $config->{BHAVCOPY_BASE_URL};
    for (my $eq_month = 0; $eq_month <= $mon; $eq_month++) {
        for (my $eq_date = 1; $eq_date <= $mday; $eq_date++) {
            my $downloaded_file = download_data(Utils::get_year($year), $eq_month, $eq_date, $url);
            Importer::import_recent_file($downloaded_file) if $downloaded_file;
        }
    }
    Importer::remove_workdir();
    print "Downloading & Import completed successfully\n\n\n";
    return 1;
}

sub download_data {
    my ($eq_year, $eq_month, $eq_date, $url) = @_;
    my $eq_url = $url;
    $eq_url .= $eq_year.'/';                
    $eq_url .= Utils::get_month($eq_month).'/';
    $eq_url .= get_bhav_filename($eq_date, $eq_month, $eq_year);

    my $new_folder =  $config->{DOWNLOADED_FOLDER}.'/'.$eq_year.'/'.Utils::get_month($eq_month);
    my $new_file   =  $eq_date.Utils::get_month($eq_month).$eq_year;
    #
    # Create the path if it doesnt exists as unzip fails if the folder is absent
    make_path($new_folder) unless (-d $new_folder);
    print "YEAR = $eq_year - MONTH = ".Utils::get_month($eq_month)." - DAY = $eq_date\n";
    # Check if the file exists, as there is no point in donwloading the file again.
    if(-f $new_folder.'/'.$new_file.'.csv') {
        print "File exists - skipping download!\n";
        return;
    }
    #
    # Temporary location to save the downloaded zip file
    my $tmp_file = $new_file.'.zip';
    my $response = $ua->get($eq_url,  ':content_file'   => $tmp_file );
    #
    # If the response is success and the temp file exists
    if ($response->is_success && -f $tmp_file) {
        print "$eq_url\n";
        my $status = unzip $tmp_file => $new_folder.'/'.$new_file.'.csv'
            or die "unzip failed: $UnzipError\n";
        # remove the temp file as it is not required any more
        unlink $tmp_file or die "Could not remove file : $tmp_file : $!\n";
    }
    else {
        #die $response->status_line;
        print "HOLIDAY in market\n";
        return;
    }
    return $new_folder.'/'.$new_file.'.csv';
}

sub get_bhav_filename {
    my ($mday, $mon, $year ) = @_;
    my $name = 'cm';
    $name .= Utils::get_day($mday);
    $name .= Utils::get_month($mon);
    $name .= $year;
    $name .= 'bhav.csv.zip';
    return $name;
}

sub download_url {
    my ($url, $folder) = @_;
    my $ff = File::Fetch->new(uri => $url);
    my $where = $ff->fetch( to => $folder ) or print "no data found\n";
    return 1;
}
1;
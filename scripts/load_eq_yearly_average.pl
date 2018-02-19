	use FindBin;
    use lib "$FindBin::Bin/../lib";
	use File::Basename;
    # Script name
    my $script_name = basename($0);
	
    use Utils;
	use Downloader;
	use Importer;
	use MySQL;
	use DBI;

	my $config = Utils::get_config();
	my $dsn = "DBI:mysql:$config->{MYSQL_DATABASE}";
    my $dbh = DBI->connect($dsn, $config->{MYSQL_USERNAME}, $config->{MYSQL_PASSWORD});
	
    my $query = "SELECT symbol FROM nse.equities_name";
    my $arry_ref = $dbh->selectall_arrayref($query);
    my @equities = @{$arry_ref};

    my $type = $script_name =~ /load_(.*)\.pl/i ? 'INSERT' : 'REPORT';
    my $table_name;

    my $db_obj = MySQL->new();
    if ($type eq 'INSERT') {
        $table_name = uc($1);
        $db_obj->init($table_name.'.json');
    }
    else {
        $db_obj->init();
    }
    $db_obj->drop_table();
	print 'Dropping table completed'."\n";
	print 'Initiating DBImport.... (this may take a while)'."\n";
	$db_obj->create_DB_table();

    #
    # Pre-built
    # $dbh = database handler
    # @equities = Names of all symbols for Equities
    #
    my $start_year = $config->{START_YEAR};
    my $end_year   = Utils::get_curr_year();
    my $base_query = "SELECT avg(close) FROM nse.equities_eod_data where TIMESTAMP between ";
    my $count = 0;

    foreach my $symbol (@equities) {
        $count++;
        print "[$count] Symbol = $symbol->[0] \n";
        my $previous_avg_increase_percent = 0;
        my $previous_avg_calc_count = 0;
        for(my $yr = $start_year; $yr <= $end_year; $yr++){
            my $year = $yr;
            my $from_date = Utils::get_DB_date($year,'01');
            my $to_date   = Utils::get_DB_date(++$year,'01');
            my $query2 = $base_query."\'$from_date\' and \'$to_date\' and symbol = \'$symbol->[0]\'";
            my @row_ary = $dbh->selectrow_array($query2);
            my $data = $row_ary[0] ? $row_ary[0] : 0;
            $data = sprintf("%.2f", $data); 
            my $inc_percent;
            if( $previous_avg_calc_count != 0 && $previous_avg_increase_percent !=0 ) {
                $inc_percent = (($data - $previous_avg_increase_percent) * 100 / $previous_avg_increase_percent) ;
                $inc_percent = sprintf("%.2f", $inc_percent); 
            }
            else {
                # First time the value will be Zero, because there is no previous month data
                $inc_percent = 0;
            }
            #
            # Insert data into database
            #
            $sth = $dbh->prepare("INSERT INTO $table_name (SYMBOL, YEAR, AVERAGE, INCREASE_PERCENT, 
                            INCREASE_10_PERCENT, INCREASE_30_PERCENT, INCREASE_50_PERCENT, INCREASE_70_PERCENT,
                            INCREASE_100_PERCENT, INCREASE_150_PERCENT, INCREASE_200_PERCENT, DECREASE_10_PERCENT,
                            DECREASE_30_PERCENT, DECREASE_50_PERCENT, DECREASE_70_PERCENT, DECREASE_100_PERCENT,
                            DECREASE_150_PERCENT, DECREASE_200_PERCENT) 
                            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

            $sth->execute($symbol->[0], $yr, $data, $inc_percent, 
                            $inc_percent > 10  ? 1 : 0,
                            $inc_percent > 30  ? 1 : 0,
                            $inc_percent > 50  ? 1 : 0,
                            $inc_percent > 70  ? 1 : 0,
                            $inc_percent > 100  ? 1 : 0,
                            $inc_percent > 150  ? 1 : 0,
                            $inc_percent > 200  ? 1 : 0,
                            $inc_percent < -10  ? 1 : 0,
                            $inc_percent < -30  ? 1 : 0,
                            $inc_percent < -50  ? 1 : 0,
                            $inc_percent < -70  ? 1 : 0,
                            $inc_percent < -100  ? 1 : 0,
                            $inc_percent < -150  ? 1 : 0,
                            $inc_percent < -200  ? 1 : 0);
            $previous_avg_calc_count++;
            # This is required for next run
            $previous_avg_increase_percent = $data;
        }
    }
#
# Post script
#
$dbh->disconnect;
    
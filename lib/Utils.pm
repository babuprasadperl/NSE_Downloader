package Utils;

use File::Slurp;

sub get_config {
	my $config_file = (-f 'config.txt') ? 'config.txt' : '../config.txt';
    my @data = read_file($config_file);
    my %config;
    foreach my $row (@data) {
		chomp $row;
        next unless $row;
        next if $row =~ /^$/;   # we dont need empty lines
		next if $row =~ /^#/;   # we dont need commented lines either
		my ($key, $value) = split '=', $row;
		$config{trim($key)} = trim($value);
	}
    return \%config;
}
#
# Remove leading and trailing spaces around strings
#
sub trim {
	my $str = shift;
	$str =~ s/^\s+//;
	$str =~ s/\s+$//;
	return $str;
}


sub get_day {
    my $mday = shift;
    if ($mday < 10) {
        return '0'.$mday;
    }
    return $mday;
}

sub get_month {
    my $mon = shift;
    my @abbr = qw(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC);
    return $abbr[$mon];
}

sub get_year {
    my $year = shift;
    $year += 1900;
    return $year;
}

sub get_curr_year {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                               localtime(time);
	return get_year($year);
}

sub get_curr_month {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                               localtime(time);
	return get_2_digit_mon($mon);
}

sub get_2_digit_mon {
	my $date = shift;
	if ($date >= 10 ) {
		return $date;
	}
	else {
		return '0'.$date;
	}
}

sub get_DB_date {
	my ($year, $mon) = @_;
	my $new_year;
	my $new_mon = get_2_digit_mon($mon);
	if( $new_mon > 12) {
		$new_year = ++$year;
		$new_mon = '01';
	}
	else {
		$new_year = $year;
	}
	return ($new_year.'-'.$new_mon.'-01');
}

1;
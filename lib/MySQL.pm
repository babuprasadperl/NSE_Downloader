package MySQL;

use JSON;
use Data::Dumper;
use File::Slurp;
use File::Copy;

use Utils;
my $config = Utils::get_config();

sub new {
	my $class = shift;
	my $self  = {
        exe_path     	=> $config->{'MYSQL_EXE'},
    	import_path  	=> $config->{'MYSQL_IMPORT'},
		username  		=> $config->{'MYSQL_USERNAME'},
		password  		=> $config->{'MYSQL_PASSWORD'},
		database  		=> $config->{'MYSQL_DATABASE'},
		workdir   		=> $config->{'WORKDIR'}
	};
	bless($self, $class);
	return $self;
}

sub init {
	my ($self, $modelfile) = @_;

	#
	#  /usr/local/mysql/bin/mysql NSE --user='root' --password='kudremukh' -e "select count(*) from NEMDMS_SUBSCRIBER;"
	#
		my $base_command = $self->{exe_path}.' ';
		$base_command   .= ' -D '.$self->{database};
		$base_command   .= ' --user='.$self->{username};
		$base_command   .= ' --password='.$self->{password};
		$base_command   .= ' -e ';
		$self->{base_command} = $base_command;

	if ($modelfile) {
		$self->{modelfile} = $modelfile;
		my $json = JSON->new->allow_nonref;
		print 'Loading DBModel coinfig = '.$self->{modelfile}."\n" if $self->{debug};
		my $json_text = read_file( $config->{MODELDIR}.'/'.$self->{modelfile} ) ;
    	$self->{dbmodel} = $json->decode( $json_text );
		print Data::Dumper::Dumper $self->{dbmodel} if $self->{debug};


    	my $DB_attr = $self->{dbmodel}->{Database}->{Attributes};
		my @columns = ();
		print 'Sorted list of table columns/attributes : '."\n" if $self->{debug};
		foreach my $sorted_num (sort { $a <=> $b } keys %{$DB_attr}) {
			my $column_hash = $DB_attr->{$sorted_num};
			foreach (keys %{$column_hash}) {
		    	print $sorted_num."-".$_."\n" if $self->{debug};
				push(@columns, $_ );
			}
		}
	}
    $self->{columns} = \@columns;
	return;
}


sub sql_import_dump {
	my $self = shift;
	print "Directory path = ".$self->{dbfile}."\n";
    return $self->locate_file($self->{dbfile});
}

sub sql_import_file {
	my $self = shift;
	return $self->DB_import($self->{dbfile});
}

sub get_alter_details {
    my $self = shift;
	my $alter_table_arr = $self->{dbmodel}->{Database}->{Alter_Table};
	my @alter_table = @{$alter_table_arr};
    my $create_cmd;
    #(@date,INSTRUCTIONS)
    #SET date = STR_TO_DATE(@date,'%Y/%m/%d);
    my @column_array = @{$self->{columns}};
    
    foreach my $alter (@alter_table) {
        $column_array[$alter->{Attribute_position}-1] = '@'.$alter->{DB_column};
        $create_cmd    .= ' ( '. join(',',@column_array) .' )';
        $create_cmd    .= ' SET '. $alter->{DB_column};
        $create_cmd    .= ' = '. $alter->{Function} . ' ( ';
        $create_cmd    .= '@'. $alter->{DB_column} . ' , ';
        $create_cmd    .= '\''. $alter->{Format} .'\' ) ';
    }
    return $create_cmd;
}

sub locate_file {
    my ($self, $path) = @_;

    # Open the directory.
    opendir (DIR, $path)
        or die "Unable to open $path: $!";

    my @files = grep { !/^\.{1,2}$/ } readdir (DIR);
    
    foreach (@files) {
		my $file = $path.'/'.$_;
        # If the file is a directory
        if (-d $file) {
            # Here is where we recurse.
            # This makes a new call to process_files()
            # using a new directory we just found.
            $self->locate_file ($file);
        } else { 
			print "file = $file\n";
            $self->DB_import($file);
        }
    }
    # Close the directory.
    closedir(DIR);
}

sub DB_import {
    my ($self, $file) = @_;
	#
	# /usr/local/mysql/bin/mysqlimport --user='root' --password='kudremukh' --ignore-lines=1 --fields-terminated-by=, --verbose --local NSE /temp/EQUITIES_EOD_DATA.csv
	#
    my $import_file = $self->modify_filename($file);
    # print Data::Dumper::Dumper $self->{columns};

	my $create_cmd  = $self->{base_command}.'"LOAD DATA LOCAL INFILE ';
    $create_cmd	   .= ' \''.$import_file.'\' ';
    $create_cmd    .= ' INTO TABLE '.$self->{dbmodel}->{Database}->{Table_Name};
    $create_cmd    .= ' CHARACTER SET latin1 ';
    $create_cmd    .= ' FIELDS TERMINATED BY \',\'';
    $create_cmd    .= ' LINES TERMINATED BY \'\n\'';
    $create_cmd    .= ' IGNORE 1 LINES ';
    $create_cmd    .= $self->get_alter_details() if ($self->{dbmodel}->{Database}->{Alter_Table}->[0]);
	$create_cmd	   .= '";';
	# print 'LOAD DAT FILE (COMMAND) = '.$create_cmd."\n";
	my $out = qx{$create_cmd};
	$self->check_errors($out);

	# my $import_cmd  = $self->{import_path}.'  ';
	# $import_cmd   .= ' --user='.$self->{username};
	# $import_cmd   .= ' --password='.$self->{password};
	# $import_cmd   .= ' --ignore-lines=1';
	# $import_cmd   .= ' --fields-terminated-by=,';
	# $import_cmd   .= ' --columns='.join(',', @{$self->{columns}});
    # $import_cmd   .= ' --local ';
	# $import_cmd   .= ' '.$self->{database}.' ';
	# $import_cmd	  .= ' '.$import_file.' ';
	# print 'Import dump to table (COMMAND) = '.$import_cmd."\n";
	# my $out = qx{$import_cmd};
	# print $out."\n";    
}

sub create_DB_table {
	my $self = shift;
	my $DB_attr = $self->{dbmodel}->{Database}->{Attributes};
    #
    # Load all attributes
	my @attr = ();
	foreach my $sorted_num (sort { $a <=> $b } keys %{$DB_attr}) {
		my $column_hash = $DB_attr->{$sorted_num};
		foreach (keys %{$column_hash}) {
			push(@attr, $_ . ' '.$column_hash->{$_});
		}
	}
	#
	# Load indexes if available
	my $index_arr = $self->{dbmodel}->{Database}->{Index};
	my @indexes = @{$index_arr};
	#
    # Load Primary key
	my $pkey_arr = $self->{dbmodel}->{Database}->{Primary_key};
	my @pkey = @{$index_pkey_arrarr};

	my $create_cmd  = $self->{base_command}.'"create table IF NOT EXISTS ';
	$create_cmd	   .= $self->{dbmodel}->{Database}->{Table_Name}.' ( ';	
	$create_cmd    .= join(',', @attr);
    $create_cmd	   .= ', PRIMARY KEY ('. join(',', @pkey).')' if $pkey[0];    
	$create_cmd	   .= ', INDEX('. join(',', @indexes).')' if $indexes[0];
	$create_cmd	   .= ' ) ';
	$create_cmd	   .= '";';
	print 'Create Table (COMMAND) = '.$create_cmd."\n";
	my $out = qx{$create_cmd};
	$self->check_errors($out);
	return;
}

sub drop_table {
	my $self = shift;
	my $drop_cmd  = $self->{base_command}.'"drop table if exists '.$self->{dbmodel}->{Database}->{Table_Name}.'";';
	print 'Drop table (COMMAND) = '.$drop_cmd."\n";
	my $out = qx{$drop_cmd};
	$self->check_errors($out);
	return;
}

sub check_errors {
	my ($self, $out) = @_;
	if($out) {
		print "\n\n".'ERROR : '.$out."\n\n";
		exit;
	}
	return;
}

sub modify_filename {
	my ($self, $old_file) = @_;
    $new_file = $self->{workdir}.$self->{dbmodel}->{Database}->{Table_Name}.'.csv';
	print "Old-file $old_file\n";
	print "New-file $new_file\n";
    unlink $new_file if (-f $new_file);
    copy($old_file, $new_file) or die "Copy failed: $!";
	return $new_file;
}

1;
package Importer;

use Utils;
use MySQL;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
my $config = Utils::get_config();

sub data_import {
    my $folder = $config->{DOWNLOADED_FOLDER};

    remove_workdir();
    create_workdir();
	my $db_obj = get_mysql_obj($config->{MYSQL_EQUITIES_EOD_MODEL}, 
	                           $folder);
	$db_obj->drop_table();
	print 'Dropping table completed'."\n";
	print 'Initiating DBImport.... (this may take a while)'."\n";
	$db_obj->create_DB_table();
	$db_obj->sql_import_dump();
	print 'DBImport completed successfully'."\n";
    remove_workdir();
    return;
}

sub import_metadata_files {
	#
	# EQUITIES META DATA
    remove_workdir();
    create_workdir();

	my $db_obj1 = get_mysql_obj($config->{MYSQL_EQUITIES_METADATA_MODEL}, 
	                           $config->{DOWNLOADED_METADATA}.'/'.$config->{EQUITIES_FILE});
	$db_obj1->drop_table();
	print 'Dropping EQUITIES meta data table completed'."\n";
	print 'Importing meta data file'."\n";
	$db_obj1->create_DB_table();
	$db_obj1->sql_import_file();
	print 'DBImport of EQUITIES meta data completed successfully'."\n";

    my $db_obj2 = get_mysql_obj($config->{MYSQL_DERIVATIVES_METADATA_MODEL}, 
	                           $config->{DOWNLOADED_METADATA}.'/'.$config->{DERIVATIVES_FILE});
	$db_obj2->drop_table();
	print 'Dropping DERIVATIES meta data table completed'."\n";
	print 'Importing meta data file'."\n";
	$db_obj2->create_DB_table();
	$db_obj2->sql_import_file();
	print 'DBImport of DERIVATIVES meta data completed successfully'."\n";

    remove_workdir();
    return;
}

sub get_mysql_obj {
	my ($model, $dbfile) = @_;
	my $db_obj = MySQL->new();
	$db_obj->{dbfile} = $dbfile;
	$db_obj->init($model);
	return $db_obj;
}

sub import_recent_file {
	my $dbfile = shift;
	#
	# EQUITIES EOD file
	my $db_obj = get_mysql_obj($config->{MYSQL_EQUITIES_EOD_MODEL},
	                           $dbfile);
	print 'Importing EOD data file'."\n";
	$db_obj->sql_import_file();
	print 'DBImport of EQUITIES meta data completed successfully'."\n";
    return;
}

sub create_workdir {
    my $dir = $config->{'WORKDIR'};
    make_path($dir) unless (-d $dir);
}

sub remove_workdir {
    remove_tree($config->{'WORKDIR'}) if -d $config->{'WORKDIR'};
}

1;
package Script;

use Utils;
use File::Slurp;
my $config = Utils::get_config();

sub run_all {
    my $folder = $config->{SCRIPTSDIR};
    # Open the directory.
    opendir (DIR, $folder)
      or die "Unable to open $folder: $!";
    my @files = grep { !/^\.{1,2}$/ } readdir (DIR);
    foreach (@files) {
       execute_script($_);
   }
   closedir(DIR);   
}

sub run_script {
    my $name = shift;
	execute_script ($name);
	return;
}

sub execute_script {
	my $script = shift;
	print "Executing script = $script\n";
	my $file = read_file($script);
	my $command = <<COM;

COM
	my $out = qx{perl $script};
	print "Output : $output\n-----------------------------------------\n\n";
}
1;
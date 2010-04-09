package Padre::Plugin::SQL::SetupConnectionsDialog;

use warnings;
use strict;

# package exports and version
our $VERSION = '0.01';

# module imports
use Padre::Wx ();
use Padre::Current ();
use Padre::Util   ('_T');

use YAML::Tiny;
use Data::Dumper;


# is a subclass of Wx::Dialog
use base 'Wx::Dialog';

# accessors
use Class::XSAccessor accessors => {
	_sizer             => '_sizer',              # window sizer
	_search_text       => '_search_text',	     # search text control
	_matches_list      => '_matches_list',	     # matches list
	_ignore_dir_check  => '_ignore_dir_check',   # ignore .svn/.git dir checkbox
	_status_text       => '_status_text',        # status label
	_directory         => '_directory',	         # searched directory
	_matched_files     => '_matched_files',		 # matched files list
};


#my @dbTypes = ( 'Postgres', 'MySQL', 'SQLite', 'ODBC' );

my %dbTypes = (
		'Postgres' 	=> { port => 5432 },
		'MySQL'		=> { port => 3301 },
	);

my $config_file = 'db_connections.yml';

# -- constructor
sub new {
	my ($class, $plugin, %opt) = @_;

	#Check if we have an open file so we can use its directory
	my $filename = Padre::Current->filename;
	my $directory;
	if($filename) {
		# current document's project or base directory
		$directory = Padre::Util::get_project_dir($filename) 
			|| File::Basename::dirname($filename);
	} else {
		# current working directory
		$directory = Cwd::getcwd();
	}
	

	
	# we need the share directory
	
	my $share_dir = $plugin->plugin_directory_share;
	
	# this doesn't seem to work when running dev.pl -a
	if( ! defined( $share_dir) || $share_dir eq '' ) {
		
		$share_dir = '/tmp';
		
	}
	
	my $db_connections;
	my $path = File::Spec->catfile($share_dir, $config_file);	
	if( ! -e $path ) {
		#print "No config file exists\n";
	}
	else {
		#print "Loading config file $path\n";
		$db_connections = YAML::Tiny->read($path);
		if( ! defined $db_connections ) {
			# create error dialog here.
			print "failed to read config " . YAML::Tiny->errstr . "\n";
		}
	}
	
	# create object
	my $self = $class->SUPER::new(
		Padre::Current->main,
		-1,
		_T('Setup Database connection'),
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxDEFAULT_FRAME_STYLE|Wx::wxTAB_TRAVERSAL,
	);

	$self->SetIcon( Wx::GetWxPerlIcon() );

	$self->_directory($directory);
	
	$self->{db_connections} = $db_connections;
	$self->{config_path}  = $path;
	
	$self->{connection_details} = undef;
	
	
	# create dialog
	$self->_create;

	return $self;
}




# -- event handler

#
# handler called when the ok button has been clicked.
# 
sub _on_ok_button_clicked {
	my ($self) = @_;

	# my $main = Padre->ide->wx->main;
# 
	# #Open the selected resources here if the user pressed OK
	# my @selections = $self->_matches_list->GetSelections();
	# foreach my $selection (@selections) {
		# my $filename = $self->_matches_list->GetClientData($selection);
		# # try to open the file now
		# $main->setup_editor($filename);
	# }
# 
	my %connection_details;
	#$connection_details{'user'} = txt
	#$self->create_connection_details;
	$self->Hide;
}

sub _on_cancel_button_clicked {
	my $self = shift;
	$self->Hide;
	#$self->Destroy;
	return undef;
}

# -- private methods

#
# create the dialog itself.
#
sub _create {
	my ($self) = @_;

	# create sizer that will host all controls
	my $sizer = Wx::BoxSizer->new( Wx::wxVERTICAL );
	$self->_sizer($sizer);

	# create the controls
	$self->_existing_db_connections;
	$self->_db_connection_list;
	$self->_setup_db_conn;
	
	#$self->_create_controls;
	$self->_create_buttons;

	# wrap everything in a vbox to add some padding
	$self->SetSizerAndFit($sizer);
	$sizer->SetSizeHints($self);

	# center the dialog
	$self->Centre;

	# focus on the search text box
	#$self->_search_text->SetFocus();
}

#
# create the buttons pane.
#
sub _create_buttons {
	my ($self) = @_;
	my $sizer  = $self->_sizer;

	#my $butsizer = $self->CreateStdDialogButtonSizer(Wx::wxOK|Wx::wxCANCEL);
	#$sizer->Add($butsizer, 0, Wx::wxALL|Wx::wxEXPAND|Wx::wxALIGN_CENTER, 5 );
	#Wx::Event::EVT_BUTTON( $self, Wx::wxID_OK, \&_on_ok_button_clicked );
	
	my $butsizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $btnCancel = Wx::Button->new($self, -1, 'Cancel');
	
	#my $okID = Wx::NewId();
	my $btnOK = Wx::Button->new($self, -1, 'OK');
	
	#my $saveID = Wx::NewId();
	my $btnSave = Wx::Button->new($self, -1,  'Save Connection');
	
	#my $delID = Wx::NewId();
	my $btnDelete = Wx::Button->new($self, -1, 'Delete Connection');
	
	
	$butsizer->Add($btnSave, 0, Wx::wxALL|Wx::wxEXPAND|Wx::wxALIGN_CENTER, 5);
	$butsizer->Add($btnDelete, 0, Wx::wxALL|Wx::wxEXPAND|Wx::wxALIGN_CENTER, 5);
	$butsizer->Add($btnOK, 0, Wx::wxALL|Wx::wxEXPAND|Wx::wxALIGN_CENTER, 5);
	$butsizer->Add($btnCancel, 0, Wx::wxALL|Wx::wxEXPAND|Wx::wxALIGN_CENTER, 5);
	
	$sizer->Add($butsizer, 0, Wx::wxALL|Wx::wxEXPAND|Wx::wxALIGN_RIGHT, 5 );
	
	Wx::Event::EVT_BUTTON(
		$self,
		$btnOK,
		sub { $_[0]->_on_ok_button_clicked; } 
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$btnSave,
		sub { $_[0]->_save_config; }
	);
	Wx::Event::EVT_BUTTON(
		$self,
		$btnDelete,
		sub { $_[0]->_delete_config; }
	);
	
	Wx::Event::EVT_BUTTON(
		$self,
		$btnCancel,
		sub { $_[0]->_on_cancel_button_clicked; }
	);
	
	
}

sub _delete_config {
	my $self = shift;
	print "_delete_config\n";
	my $connname = $self->{dbConnList_combo}->GetValue();
	print "deleting: $connname\n";
	delete $self->{db_connections}->[0]->{$connname};
	my $ok = $self->{db_connections}->write( $self->{config_path} );
	
	if( ! $ok ) {
		# TODO DIALOG 
		#print "Error??? " . $self->{db_connections}->errstr . "\n";
	}
	
	$self->_reset_form();
	
	
}


sub _read_config {
	my $self = shift;

	my $ok = $self->{db_connections}->read( $self->{config_path} );
	if( ! $ok ) {
		
		print "Error??? " . $self->{db_connections}->errstr . "\n";
	}
	
}

=pod

=head2 _save_config

This checks and saves the current config details in the form

=cut

sub _save_config {
	my $self = shift;
	print "_save_config\n";
	#YAML::Tiny->write($self->{db_connections});
	
	my $dbconnname = $self->{dbConnList_combo}->GetValue();
	
	my $username = $self->{txtDBUserName}->GetValue();
	my $password = $self->{txtDBPassword}->GetValue();
	my $dbtype = $self->{dbType}->GetValue();
	my $dbhost = $self->{txtDBHostName}->GetValue();
	my $dbname = $self->{txtDBName}->GetValue();
	my $dbinstance = $self->{txtDBInstance}->GetValue();
	my $dbport = $self->{txtDBPort}->GetValue();
	
	if( $dbconnname eq '' ) {
		print "no db connection name\n";
		return 0;
	}

	# otherwise we can save the new/changed details:
	
	# check if this connection name hasn't already been defined
	# may think about asking if they really want to over write the 
	# config
	#if( ! $self->{db_connections}->[0]->{$dbconnname} ) {
		#$self->{db_connections}->[0]->{connection} = $dbconnname;
		#$self->{db_connections}->[0]->{connection}{$dbconnname} = {
	$self->{db_connections}->[0]->{$dbconnname} = {
		dbtype => $dbtype,
		dbhost => $dbhost,
		dbport => $dbport,
		dbname => $dbname,
		dbinstance => $dbinstance,
		username => $username,
		password => $password,  # needs to be hashsed
		};
	
	#}
	#else {
	#	print "Already an entry for this connection name - ask to over write\n";
	#	return 0;
	#}
	my $ok = $self->{db_connections}->write( $self->{config_path} );
	if( ! $ok ) {
		print "Error??? " . $self->{db_connections}->errstr . "\n";
	}
}



=pod 

=head2 _validate_form_fields

Validates the form and returns a hash of the values

=cut

sub _validate_form_fields {
	my $self = shift;
	print "Checking that form is filled out\n";
	
	my $dbconnname = $self->{dbConnList_combo}->GetValue();
	
	my $username = $self->{txtDBUserName}->GetValue();
	my $password = $self->{txtDBPassword}->GetValue();
	my $dbtype = $self->{dbType}->GetValue();
	my $dbhost = $self->{txtDBHostName}->GetValue();
	my $dbname = $self->{txtDBName}->GetValue();
	my $dbinstance = $self->{txtDBInstance}->GetValue();
	my $dbport = $self->{txtDBPort}->GetValue();
	
	
	# need a dbconn name
	if( $dbconnname eq '' ) {
		# TODO DIALOG - Missing connection name
		print "No Conn Name, can't go on\n";
		return undef;
		
	}
	
	if( $dbtype eq '' ) {
		# TODO DIALOG - Missing DBType
		print "dbtype has not been defined\n";
		return undef;
	}
	
	my $dbconn_details = {
		dbconnname => $dbconnname,
		
	};
	return $dbconn_details;
	
}

#
# create controls in the dialog
#
sub _create_controls {
	my ($self) = @_;

	# search textbox
	my $search_label = Wx::StaticText->new( $self, -1, _T('type in the DSN') );
	$self->_search_text( Wx::TextCtrl->new( $self, -1, '' ) );
	
	# ignore .svn/.git checkbox
	#$self->_ignore_dir_check( Wx::CheckBox->new( $self, -1, _T('Ignore CVS/.svn/.git folders')) );
	#$self->_ignore_dir_check->SetValue(1);
	
	# matches result list
	my $matches_label = Wx::StaticText->new( $self, -1, _T('Existing Configurations:') );
	$self->_matches_list( Wx::ListBox->new( $self, -1, [-1, -1], [400, 300], [], 
		Wx::wxLB_EXTENDED ) );

# TODO delete a configuration
# allow for more detaild configuration including username and password

	$self->_sizer->AddSpacer(10);
	$self->_sizer->Add( $search_label, 0, Wx::wxALL|Wx::wxEXPAND, 2 );
	$self->_sizer->Add( $self->_search_text, 0, Wx::wxALL|Wx::wxEXPAND, 2 );
	$self->_sizer->Add( $self->_ignore_dir_check, 0, Wx::wxALL|Wx::wxEXPAND, 5);
	$self->_sizer->Add( $matches_label, 0, Wx::wxALL|Wx::wxEXPAND, 2 );
	$self->_sizer->Add( $self->_matches_list, 0, Wx::wxALL|Wx::wxEXPAND, 2 );
	$self->_sizer->Add( $self->_status_text, 0, Wx::wxALL|Wx::wxEXPAND, 10 );

	$self->_setup_events();
	
	return;
}

#
# Adds various events
#
sub _setup_events {
	my $self = shift;
	
	
	Wx::Event::EVT_LISTBOX( $self, $self->_matches_list, sub {
		my $self  = shift;
		my @matches = $self->_matches_list->GetSelections();
		my $num_selected =  scalar @matches;
		if($num_selected > 1) {
			$self->_status_text->SetLabel(
				"" . scalar @matches . _T(" items selected"));
		} elsif($num_selected == 1) {
			$self->_status_text->SetLabel(
				$self->_matches_list->GetClientData($matches[0]));
		}
		
		return;
	});
	
	Wx::Event::EVT_LISTBOX_DCLICK( $self, $self->_matches_list, sub {
		$self->_on_ok_button_clicked();
		$self->EndModal(0);
	});
}

#
# Update matches list box from matched files list
#
sub _update_matches_list_box() {
	my $self = shift;
	
	my $search_expr = $self->_search_text->GetValue();

	#quote the search string to make it safer
	#and then tranform * and ? into .* and .
	$search_expr = quotemeta $search_expr;
	$search_expr =~ s/\\\*/.*?/g;
	$search_expr =~ s/\\\?/./g;

	#Populate the list box now
	$self->_matches_list->Clear();
	my $pos = 0;
	foreach my $file (@{$self->_matched_files}) {
		my $filename = File::Basename::fileparse($file);
		if($filename =~ /^$search_expr/i) {
			$self->_matches_list->Insert($filename, $pos, $file);
			$pos++;
		}
	}
	if($pos > 0) {
		$self->_matches_list->Select(0);
		$self->_status_text->SetLabel("" . ($pos+1) . _T(' item(s) found'));
	} else {
		$self->_status_text->SetLabel(_T('No items found'));
	}
			
	return;
}

=pod


=cut 

sub _db_connection_list {
	my $self = shift;
	
	my $sizer = $self->_sizer;
	
	my $dbList_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	
	#my $numElements =scalar(@dbTypes);
	my $combo = Wx::ComboBox->new(
			$self,
			-1,
			'',			# empty string
			[-1,-1],		#pos
			[-1,-1],		#size
			[ keys( %dbTypes ) ],
			Wx::wxCB_DROPDOWN | Wx::wxCB_SORT,
		);
	
	$self->{db_combo} = $combo;
	
	my $lblDBType = Wx::StaticText->new( $self, -1, _T('Database Type:'),[-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT  );
	$dbList_sizer->Add($lblDBType); #, 0, Wx::wxALL|Wx::wxEXPAND, 2
	$dbList_sizer->Add($combo); #, 1, Wx::wxALL|Wx::wxEXPAND, 2
	
	$self->{dbType} = $combo;
	
	Wx::Event::EVT_COMBOBOX($self, $combo, sub{ $self->on_db_select(); } );
	
	$sizer->Add($dbList_sizer);
	
}

=pod

Dropdown list of existing datbase connections.

=cut

sub _existing_db_connections {
	my $self = shift;
	
	# place holder for now
	#my @connectionList = qw/RABBIT\\DBINSTANCE/;
	
	#my @documents = Load( $self->{db_connections} );
	#print "Dumper:\n" . Dumper(@documents) . "\n";
	my @connectionList = keys( %{ $self->{db_connections}->[0] } );
	print "Dumper:\n" . Dumper($self->{db_connections} ) . "\n";
	my $sizer = $self->_sizer;
	
	my $dbConnList_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	
	my $combo = Wx::ComboBox->new(
			$self,
			-1,
			'',			# empty string
			[-1,-1],		# pos
			[-1,-1],		# size
			\@connectionList,
			Wx::wxCB_DROPDOWN | Wx::wxCB_SORT,
		);
	
	$self->{dbConnList_combo} = $combo;
	
	my $lblDBConnList = Wx::StaticText->new( $self, -1, _T('Database Connection:'),[-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT  );
	$dbConnList_sizer->Add($lblDBConnList); #, 0, Wx::wxALL|Wx::wxEXPAND, 2
	$dbConnList_sizer->Add($combo, 1); # , Wx::wxALL|Wx::wxEXPAND, 2
	
	
	Wx::Event::EVT_COMBOBOX($self, $combo, sub{ $self->_on_db_connlist_select(); } );
	
	$sizer->Add($dbConnList_sizer);	
	
	
}

sub _setup_db_conn {
	my($self) = @_;
	my $sizer = $self->_sizer;
	
	my $connName_sizer =  Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $dbHostName_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $dbInstance_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $dbName_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $dbPort_sizer	= Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $dbUserName_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $dbPassword_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	my $dbConnString_sizer = Wx::BoxSizer->new( Wx::wxHORIZONTAL );
	
	my $lblConnName = Wx::StaticText->new($self, -1, _T('Connection Name:'), [-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT );
	my $txtConnName = Wx::TextCtrl->new( $self, -1, '' );
	
	$connName_sizer->Add($lblConnName, 0, Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT|Wx::wxEXPAND, 2);
	$connName_sizer->Add($txtConnName, 1); # , 1, Wx::wxEXPAND, 2
	
	my $lblDBHostName = Wx::StaticText->new($self, -1, _T('Database Host Name:'), [-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT );
	my $txtDBHostName = Wx::TextCtrl->new( $self, -1, '' );

	$dbHostName_sizer->Add($lblDBHostName, 0); #, 0, Wx::wxALL|Wx::wxRIGHT, 2
	$dbHostName_sizer->Add($txtDBHostName, 1 ); #, 1, Wx::wxALL, 2
	
	#Wx::Event::EVT_TEXT($self, $txtDBName, sub { $_[0]->_update_conn_string('DBHostName', $txtDBName->GetValue() ); }  );
	
	my $lblDBInstance = Wx::StaticText->new($self, -1, _T('Database Instance Name:'),[-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT );
	my $txtDBInstance = Wx::TextCtrl->new( $self, -1, '' );
	
	$dbInstance_sizer->Add($lblDBInstance, 0); #, 1, Wx::wxALL|Wx::wxEXPAND, 2
	$dbInstance_sizer->Add($txtDBInstance, 1); #, 1, Wx::wxALL|Wx::wxEXPAND, 2
	
	my $lblDBName = Wx::StaticText->new($self, -1, _T('Database Name:'),[-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT );
	my $txtDBName = Wx::TextCtrl->new( $self, -1, '' );
	
	$dbName_sizer->Add($lblDBName, 0); #, 1, Wx::wxEXPAND, 5
	$dbName_sizer->Add($txtDBName, 1); #, 1, Wx::wxEXPAND, 5
	
	my $lblDBPort = Wx::StaticText->new($self, -1, _T('Port:'),[-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT );
	my $txtDBPort = Wx::TextCtrl->new( $self, -1, '' );
	
	
	
	$dbPort_sizer->Add($lblDBPort, 0); #, 1, Wx::wxALL|Wx::wxEXPAND, 2
	$dbPort_sizer->Add($txtDBPort, 1); #, 1, Wx::wxALL|Wx::wxEXPAND, 2
	
	my $lblDBUserName = Wx::StaticText->new($self, -1, _T('User Name:'),[-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT );
	my $txtDBUserName = Wx::TextCtrl->new( $self, -1, '' );
	
	
	
	$dbUserName_sizer->Add($lblDBUserName, 0); #, 0, Wx::wxALL|Wx::wxEXPAND, 2
	$dbUserName_sizer->Add($txtDBUserName, 1); #, 0, Wx::wxALL|Wx::wxEXPAND, 2
	
	my $lblDBPassword = Wx::StaticText->new($self, -1, _T('Password:'), [-1, -1], [170,-1], Wx::wxALIGN_CENTRE|Wx::wxALIGN_RIGHT );
	my $txtDBPassword = Wx::TextCtrl->new( $self, -1, '', [-1,-1], [-1,-1], Wx::wxTE_PASSWORD );
	
	$dbPassword_sizer->Add($lblDBPassword, 0); #, 0, Wx::wxALL|Wx::wxEXPAND, 2
	$dbPassword_sizer->Add($txtDBPassword, 1); #, 0, Wx::wxALL|Wx::wxEXPAND, 2
	
	#my $lblDBConnString = Wx::StaticText->new($self, -1, _T('DB Connection String:') );
	#my $txtDBConnTxt = Wx::TextCtrl->new(	$self, 
	#					-1, 
	#					_T(''),
	#					[-1,-1],
	#					[600,-1], 
	#					Wx::wxTE_READONLY
	#				);
	
	#$dbConnString_sizer->Add($lblDBConnString); # , 0, Wx::wxALL|Wx::wxEXPAND, 2
	#$dbConnString_sizer->Add($txtDBConnTxt); # , 0, Wx::wxALL|Wx::wxEXPAND, 2
	
	$sizer->Add($connName_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	
	$sizer->Add($dbHostName_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	$sizer->Add($dbName_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	$sizer->Add($dbInstance_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	$sizer->Add($dbPort_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	$sizer->Add($dbUserName_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	$sizer->Add($dbPassword_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	#$sizer->Add($dbConnString_sizer, 0, Wx::wxALL|Wx::wxEXPAND, 2);
	
	
	$self->{txtDBHostName} = $txtDBHostName;
	$self->{txtDBPort} = $txtDBPort;
	$self->{txtDBUserName} = $txtDBUserName;
	$self->{txtDBPassword} = $txtDBPassword;
	$self->{txtDBName} = $txtDBName;
	$self->{txtDBInstance} = $txtDBInstance;
	
	#$self->{txtDBConnTxt} = $txtDBConnTxt;
}

sub get_connection {
	my $self = shift;
	
	my $username = $self->{txtDBUserName}->GetValue();
	my $password = $self->{txtDBPassword}->GetValue();
	my $dbtype = $self->{dbType}->GetValue();
	my $dbhost = $self->{txtDBHostName}->GetValue();
	my $dbname = $self->{txtDBName}->GetValue();
	my $dbinstance = $self->{txtDBInstance}->GetValue();
	my $dbport = $self->{txtDBPort}->GetValue();
	my %connDetails = ( 
			'username'   => $username,
			'password'   => $password,
			'dbtype'     => $dbtype,
			'dbhost'     => $dbhost,
			'dbinstance' => $dbinstance,
			'dbport'     => $dbport,
			'dbname'     => $dbname,
			
		);
	return \%connDetails;
	
}

sub _update_conn_string {
	my($self, $field, $value) = @_;
	
	my $dbHost = "Server";
	my $instance = "";
	my $dbUserName = "User";
	my $dbPass = "Password";
	
	
	$self->{txtDBConnTxt}->ChangeValue("$field=$value");
	
}


=pod 

	Redraw the dialog to suit db type.

=cut 

sub on_db_select {
	my ($self) = @_;
	
	my $dbType = $self->{db_combo}->GetValue();
	print "DBType is: $dbType\n";
	
	$self->{txtDBPort}->SetValue($dbTypes{ $self->{db_combo}->GetValue() }->{port} );
	
	# SQLite requires a browse file dialog
	
	
	#$self->_setup_db_conn();
	#$self->Update();
	
	
}

sub _on_db_connlist_select {
	my $self = shift;
	my $dbConn = $self->{dbConnList_combo}->GetValue();
	print "Connecting to: $dbConn\n";
	
	# $self->{txtDBHostName} = $txtDBHostName;
	# $self->{txtDBPort} = $txtDBPort;
	# $self->{txtDBUserName} = $txtDBUserName;
	# $self->{txtDBPassword} = $txtDBPassword;
	# $self->{txtDBName} = $txtDBName;
	# $self->{txtDBInstance} = $txtDBInstance;
	
	$self->{db_combo}->SetValue( $self->{db_connections}->[0]->{$dbConn}->{dbtype} );
	$self->{txtDBHostName}->SetValue( $self->{db_connections}->[0]->{$dbConn}->{dbhost} );
	$self->{txtDBPort}->SetValue( $self->{db_connections}->[0]->{$dbConn}->{dbport} );
	$self->{txtDBName}->SetValue( $self->{db_connections}->[0]->{$dbConn}->{dbname} );
	$self->{txtDBInstance}->SetValue( $self->{db_connections}->[0]->{$dbConn}->{dbinstsance} );
	
	$self->{txtDBUserName}->SetValue( $self->{db_connections}->[0]->{$dbConn}->{username} );
	$self->{txtDBPassword}->SetValue( $self->{db_connections}->[0]->{$dbConn}->{password} );
	
}

sub _reset_form {
	my $self = shift;
	$self->{db_combo}->SetValue('');
	$self->{dbConnList_combo}->SetValue('');
	
	$self->{txtDBHostName}->SetValue('');
	$self->{txtDBPort}->SetValue('');
	$self->{txtDBUserName}->SetValue('');
	$self->{txtDBPassword}->SetValue('');
	$self->{txtDBName}->SetValue('');
	$self->{txtDBInstance}->SetValue('');
	
}


1;


# Copyright 2008-2010 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
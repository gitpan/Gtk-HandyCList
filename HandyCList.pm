package Gtk::HandyCList;
use Gnome;

use strict;
use vars qw($VERSION @ISA);
use Carp qw(croak confess);

@ISA = qw(Gtk::CList);

$VERSION = '0.03';

1;

=head1 NAME

Gtk::HandyCList

=head1 SYNOPSIS

B<Do not use. This module is deprecated.>

=head1 DESCRIPTION

This is a utility module for Gtk-Perl, the Perl bindings to Gtk+ 1.x. Gtk-Perl has been unmaintained for a long time. Gtk+ 1.x, the library it binds, has been superseded by the API-incompatible Gtk+ 2.x series, and has subsequently been deprecated as well.

If you are writing a new application, use Gtk2-Perl instead. The Gtk+ 2.x toolkit it binds has a cleaner, more modern design than Gtk+ 1.x, and the bindings are much more comprehensive than Gtk-Perl ever was. Gtk2-Perl comes packaged with a module providing very similar functionality as this one, called L<Gtk2::SimpleList|Gtk2::SimpleList>.

The code in this version of the module is identical to L<Gtk::HandyCList|Gtk::HandyCList> 0.02, so that legacy applications will continue to work. Only the documentation has been replaced with a deprecation warning in order to discourage new development based on this module.

=head1 AUTHOR

Simon Cozens, simon@cpan.org

=head1 SEE ALSO

=over 4

=item * Gtk2-Perl, L<http://gtk2-perl.sf.net/>

=item * L<Gtk2::SimpleList|Gtk2::SimpleList>

=back

=cut

sub new {
  my $class = shift;
  my @titles = @_;
  my $self = Gtk::CList->new_with_titles(@titles);
  $self->{handy} = {
		    titles    => \@titles,
		    sorted    => 0.1, # "Can't happen" value
		    data      => [],
            sortfuncs => []
		   };
  for (0..$#titles) {
    $self->{handy}->{sortfuncs}->[$_] = sub { $_[0] cmp $_[1] }
  }
  $self->signal_connect('click_column', \&sort_clist);
  $self->signal_connect('select_row',   
                        sub { $self->{handy}->{selection}->{$_[1]} = 1 });
  $self->signal_connect('unselect_row',
                        sub { delete $self->{handy}->{selection}->{$_[1]} });
  bless $self, $class;
}

sub data {
  my $self = shift;
  if (@_) {
    for (@_) {
      croak "One of the elements to ->data() wasn't a reference"
	unless ref $_;
      if (ref $_ eq "ARRAY") {
	# Need to get it as a hash
	    my $aref = $_;
	    $_ = { map { $self->{handy}->{titles}->[$_] => $aref->[$_] }  0..$#$aref };
      } elsif (ref $_ ne "HASH") {
	croak "Element to ->data() was neither hash nor array reference";
      }
      push @{$self->{handy}->{data}}, $_;
      # Hash slices rule OK.
    }
    $self->refresh;
    $self->{handy}->{sorted} = 0.1;
  }
  return @{$self->{handy}->{data}};
}

sub clear {
  my $self = shift;
  $self->SUPER::clear;
  $self->{handy}->{data}=[];
}

sub append {
  my $self=shift;
  $self->freeze;
  my $row_no;
  for (@_) {
      croak "One of the elements to ->append() wasn't a reference"
	unless ref $_;
      if (ref $_ eq "ARRAY") {
	# Need to get it as a hash
	my $aref = $_;
	$_ = { map { $self->{handy}->{titles}->[$_] => $aref->[$_] }  0..@$aref };
      } elsif (ref $_ ne "HASH") {
	croak "Element to ->append() was neither hash nor array reference";
      }
      push @{$self->{handy}->{data}}, $_;
      $row_no = $self->SUPER::append(@$_{@{$self->{handy}->{titles}}});
  }
  $self->thaw();
  # Data is now unsorted
  $self->{handy}->{sorted} = 0.1;
  return $row_no;
}

sub prepend {
  my $self=shift;
  $self->freeze;
  for (@_) {
      croak "One of the elements to ->prepend() wasn't a reference"
	unless ref $_;
      if (ref $_ eq "ARRAY") {
	# Need to get it as a hash
	my $aref = $_;
	$_ = { map { $self->{handy}->{titles}->[$_] => $aref->[$_] }  0..@$aref };
      } elsif (ref $_ ne "HASH") {
	croak "Element to ->prepend() was neither hash nor array reference";
      }
      unshift @{$self->{handy}->{data}}, $_;
      # Must change
      $self->SUPER::prepend(@$_{@{$self->{handy}->{titles}}});
  }
  $self->thaw();
  # Data is now unsorted
  $self->{handy}->{sorted} = 0.1;
}

sub sortfuncs {
  my $self = shift;
  my @list = @_;
  if (@list % 2 or @list < @{$self->{handy}->{titles}}) { # Odd, can't be hash
    for (@list) {
      # Sanitise input
      if ($_ eq "alpha") {
	$_ = sub {$_[0] cmp $_[1]}
      } elsif ($_ eq "number") {
	$_ = sub {$_[0] <=> $_[1]}
      } elsif (ref $_ ne "CODE") {
	croak "Argument $_ to ->sortfuncs() was neither 'alpha', 'number' nor a coderef";
      }
    }

    $self->{handy}->{sortfuncs} = \@list;
  } else {
    my %hash = @_;
    for (values %hash) {
      # Sanitise input
      if ($_ eq "alpha") {
	$_ = sub {$a cmp $b}
      } elsif ($_ eq "number") {
	$_ = sub {$a <=> $b}
      } elsif (ref $_ ne "CODE") {
	croak "Argument $_ to ->sortfuncs() was neither 'number', 'alpha' nor a coderef";
      }
    }
    # Do you know how much I love manipulation of abstract data
    # structures?
    # Not at all.
    $self->{handy}->{sortfuncs} = [ @hash{@{$self->{handy}->{titles}}} ];
  }
}

sub sort_clist {
  my ($self, $column) = @_;
  my $head = $self->{handy}->{titles}->[$column];
  my $sortsub = $self->{handy}->{sortfuncs}->[$column];
  if (abs($self->{handy}->{sorted}) == $column) {
      # Flip from sorting forwards to sorting backwards
      $self->{handy}->{data} = [reverse @{$self->{handy}->{data}}];
      $self->{handy}->{sorted} *= -1;
  } else {
      $self->{handy}->{data} = [ # It's crazy, but it just might work...
                    sort
                    { $sortsub->($a->{$head}, $b->{$head})}
                    @{$self->{handy}->{data}}
                   ] ;
      $self->{handy}->{sorted} = $column;
  }

  $self->{handy}->{selection} = {};

  $self->refresh;
}

sub refresh {
  my $self = shift;
  $self->freeze;
  $self->SUPER::clear;  
  $self->SUPER::append(@$_{@{$self->{handy}->{titles}}}) 
    for @{$self->{handy}->{data}}; # *gibber*
  $self->thaw;

}

sub sizes {
  my $self = shift;
  my @sizes = @_;
  if (!(@sizes %2) and @sizes > @{$self->{handy}->{titles}}) { # That's a hash
    my %hash = @sizes;
    @sizes = @hash{@{$self->{handy}->{titles}}};
  }
  my @percents = grep /\d+%$/, @sizes;
  croak "At least one argument to ->sizes() needs to be pixels"
    unless @percents < @sizes;
  my @constants = grep { !/\d+%/ } @sizes;
  # Right.
  my $c = 0; $c += $_ for @constants;
  chop @percents;
  my $p = 0; $p += $_ for @percents;
  croak "No, no, no" if $p > 100;
  # $c is $total * (100-$p)/100
  my $total = $c*100 / (100 - $p);
  my $x=0;
  for (@sizes) {
    $_ = $1/100 * $total if /(\d+)%/;
    $self->set_column_width($x++,$_);
  }
}

sub selection {
  my $self = shift;
  my @rows_selected = keys %{$self->{handy}->{selection}};
  my %selection = map { $_, $self->{handy}->{data}->[$_] } @rows_selected;
  return \%selection; 
}

sub hide {
    my $self = shift;
    my %cols = map { $self->{handy}->{titles}->[$_] => $_ } 0..$#{$self->{handy}->{titles}};
    for (@_) {
        croak "Unknown column $_" 
            unless exists $cols{$_};
        $self->set_column_visibility($cols{$_},0);
    }
}

sub unhide {
    my $self = shift;
    my %cols = map { $self->{handy}->{titles}->[$_] => $_ } 0..$#{$self->{handy}->{titles}};
    for (@_) {
        croak "Unknown column $_" 
            unless exists $cols{$_};
        $self->set_column_visibility($cols{$_},1);
    }
}

# I could have said "*hide = *unhide" and looked at caller, but that
# seemed silly.

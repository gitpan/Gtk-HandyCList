package Gtk::HandyCList;
use Gnome;

use strict;
use vars qw($VERSION @ISA);
use Carp qw(croak confess);

@ISA = qw(Gtk::CList);

$VERSION = '0.02';

1;

=head1 NAME

Gtk::HandyCList - A more Perl-friendly Columned List

=head1 SYNOPSIS

  use Gtk::HandyCList;
  my $vbox = new Gtk::VBox(0,5);
  my $scrolled_window = new Gtk::ScrolledWindow( undef, undef );
  $vbox->pack_start( $scrolled_window, 1, 1, 0 );
  $scrolled_window->set_policy( 'automatic', 'always' );

  my $list = Gtk::HandyCList->new( qw(Name Date Cost) );
  $list->data( [ "Foo", "29/05/78", 12.33],
               [ "Bar", "01/01/74", 104.21],
               # ...
             );
  $list->sizes( Name => 100, Date => "30%", Cost => "40%" );
  $list->sortfuncs( Name => "alpha", Date => \&date_sort, Cost => "number");

=head1 DESCRIPTION

This is a version of L<Gtk::CList|Gtk::CList> which takes care of some common
things for the programmer. For instance, it keeps track of what's stored
in the list, so you don't need to keep a separate array; when the column
titles are clicked, the list will be re-sorted according to
user-supplied functions or some default rules. It allows you to
reference columns by name, instead of by number.

=head1 METHODS

=over 3

=item new(@titles)

This is equivalent to C<< Gtk::CList->new_with_titles >>, but initialises 
all the data structures required for HandyCList.

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

=pod

=item data(@data)

A get-set method to retrieve and/or set the data in the table. The data
is specified as an array of rows, and each row may either be an array
reference or a hash reference. If a hash reference, the keys of the
hash must correspond to the columns of the table.

Example: You may either say this, using array references:

  my $list = Gtk::HandyCList->new( qw(Name Date Cost) );
  $list->data( [ "Foo", "29/05/78", 12.33],
               [ "Bar", "01/01/74", 104.21] );

or this, using hash references:

  my $list = Gtk::HandyCList->new( qw(Name Date Cost) );
  $list->data( { Name => "Foo", Date => "29/05/78", Cost => 12.33 },
               { Name => "Bar", Date => "01/01/74", Cost =>104.21 } );

The data will be returned as an array of hash references.

=cut

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

=pod

=item clear

Remove all entries from the list.

=cut

sub clear {
  my $self = shift;
  $self->SUPER::clear;
  $self->{handy}->{data}=[];
}

=pod

=item append(@items)

Append some items to the list; semantics of C<@items> are the same as for
the C<data> method above.

=item prepend(@items)

Append some items to the start of the list

=cut

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

=pod

=item sortfuncs(@functions | %functions )

HandyCList automatically takes care of sorting the columns in the list
for you when the user clicks on the column titles. To do this, though,
you need to provide indication of how the data should be sorted. You
may provide either a list or a hash (keyed to columns as before) of
subroutine references or the strings "alpha" or "number" for
alphabetic and numeric comparison respectively.

Subroutine references here are B<not> the same as you would hand to
C<sort>: they must take two arguments and compare them, instead of
comparing the implicit variables C<$a> and C<$b>.

=cut

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

=pod

=item refresh

Make sure that the data displayed in the list is the same as the data
you'd get back from C<< $list->data >>. You probably won't need to
call this, unless you're doing freaky things.

=cut

sub refresh {
  my $self = shift;
  $self->freeze;
  $self->SUPER::clear;  
  $self->SUPER::append(@$_{@{$self->{handy}->{titles}}}) 
    for @{$self->{handy}->{data}}; # *gibber*
  $self->thaw;

}

=pod

=item sizes(@columns | %columns)

Set the size of each column as a number of pixels or as a
percentage. At least one of the columns must be given as a number of
pixels. Percentages should be strings like C<"40%">, not floating
point numbers.

=cut

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

=pod

=item selection

Return data regarding what is currently selected.  The return value is a
hashref, the keys being the (0-based) row numbers selected, the values
being hashrefs themselves, from column name to column data.

=cut

sub selection {
  my $self = shift;
  my @rows_selected = keys %{$self->{handy}->{selection}};
  my %selection = map { $_, $self->{handy}->{data}->[$_] } @rows_selected;
  return \%selection; 
}

=pod

=item hide (@columns)

Prevent certain columns from being displayed. 

=item unhide (@columns)

Re-allow display of certain columns

=cut

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

=head1 AUTHOR

Simon Cozens, simon@cpan.org

=head1 SEE ALSO

L<GNOME>, L<Gtk::CList>

=cut

package FFmpeg::Audio; 

use Moose::Role;  
use MooseX::Types::Moose qw( Str HashRef ); 

use namespace::autoclean; 
use experimental qw( signatures );  

requires qw( ffprobe ); 
requires qw( select_id );  

has 'audio', ( 
    is        => 'ro', 
    isa       => HashRef, 
    traits    => [ 'Hash' ], 
    lazy      => 1, 
    init_arg  => undef, 
    default   => sub ( $self ) { $self->ffprobe->{'audio'} },  
    handles   => { 
        get_audio     => 'get', 
        get_audio_ids => 'keys'  
    }
);   

has 'audio_id', ( 
    is        => 'ro', 
    isa       => Str, 
    lazy      => 1, 
    init_arg  => undef, 
    default   => sub ( $self ) { $self->select_id( 'audio' ) }, 
); 

1

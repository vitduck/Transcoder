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
    builder   => '_build_audio', 
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
    builder   => '_build_audio_id' 
); 

sub _build_audio ( $self ) { 
    return $self->ffprobe->{ 'audio' } 
}

sub _build_audio_id ( $self ) { 
    return $self->select_id( 'audio' ) 
}

1

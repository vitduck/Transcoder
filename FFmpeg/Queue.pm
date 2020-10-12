package FFmpeg::Queue; 

use Moose; 
use MooseX::Types::Moose qw(Int Str ArrayRef HashRef); 
use FFmpeg::Transcoder; 
use Parallel::ForkManager;

use namespace::autoclean; 
use experimental 'signatures'; 

with 'MooseX::Getopt::Usage'; 
with qw( FFmpeg::Video FFmpeg::Audio FFmpeg::Log); 

has 'input' => ( 
    is        => 'rw', 
    isa       => Str, 
    predicate => '_has_input',
); 

has 'input_dir' => ( 
    is        => 'rw', 
    isa       => Str,
    predicate => '_has_input_dir', 
    trigger   => sub ($self, @) { 
        # quiet mode
        $self->log_level(0); 
        $self->stats(0); 
    } 
); 

has 'queue' => ( 
    is       => 'rw', 
    isa      => ArrayRef,  
    init_arg => undef,
    traits   => ['Array'],  
    lazy     => 1,
    builder  => '_build_queue',
    handles  => { gpu => 'get'}
); 

has cuda_devices => ( 
    is       => 'rw', 
    isa      => ArrayRef, 
    init_arg => undef,
    traits   => ['Array'],
    lazy     => 1,
    default  => sub { [split /,/, $ENV{CUDA_VISIBLE_DEVICES}] }, 
    handles  => { ngpus => 'elements' } 
); 

has ntasks => ( 
    is       => 'rw', 
    isa      => Int, 
    default  => 3,
); 

has 'scale' => ( 
    is        => 'rw', 
    isa       => Str, 
    predicate => '_has_scale', 
    trigger   => sub ($self, $scale, @) { 
        # apply scale 
        for my $index ( $self->ngpus ) {   
            for my $ffmpeg ( $self->gpu($index)->@* ) { 
                $ffmpeg->scale($scale)
            }
        } 
    } 
);  

sub getopt_usage_config {
    return (
       attr_sort => sub { $_[0]->name cmp $_[1]->name }
    );
}

sub run ($self) { 
    my $device = Parallel::ForkManager->new(int($self->ngpus));

    DEVICE:
    for my $index ( $self->ngpus ) {
        $device->start and next DEVICE;

        my $transcoder = Parallel::ForkManager->new($self->ntasks);

        NVENC: 
        for my $ffmpeg_obj ( $self->gpu($index)->@* ) { 
            $transcoder->start and next NVENC; 

            $ffmpeg_obj ? system($self->ffmpeg_cmd($ffmpeg_obj)) : next NVENC; 

            $transcoder->finish 
        }
        $transcoder->wait_all_children; 

        $device->finish; 
    }
    $device->wait_all_children; 
} 

sub ffmpeg_cmd ($self, $ffmpeg_obj) {
    my @cmds = qw(ffmpeg); 
            
    # ffmpeg options 
    push @cmds, $self->log_level if $self->_has_log_level; 
    push @cmds, $self->stats     if $self->_has_stats; 

    # in-file options 
    push @cmds, $ffmpeg_obj->hwaccel   if $ffmpeg_obj->_has_hwaccel; 
    push @cmds, $ffmpeg_obj->hwdecoder if $ffmpeg_obj->_has_hwdecoder; 
    push @cmds, $ffmpeg_obj->device    if $ffmpeg_obj->_has_device; 
    push @cmds, $ffmpeg_obj->input; 

    # out-file options 
    push @cmds, $self->$_ for qw(video video_bitrate video_profile video_preset);  
    push @cmds, $self->$_ for qw(audio audio_bitrate audio_profile); 
    push @cmds, $ffmpeg_obj->filter  if $ffmpeg_obj->_has_scale; 
    push @cmds, $ffmpeg_obj->output; 

    return join(' ', @cmds) 
} 

sub _build_queue ($self) { 
    my @queue = map [], 1..$self->ngpus;  
    
    # single file
    if ($self->_has_input) { 
        push $queue[0]->@*, Fmpeg::Transcoder->new( input => $self->input );
    }

    # multiple files
    if ( $self->_has_input_dir ) { 
        my $dir = $self->input_dir; 
        my @files = <$dir/*>; 

        while (@files) { 
            for my $index ( $self->ngpus ) { 
                push $queue[$index]->@*, FFmpeg::Transcoder->new( input => shift @files, device => $index ) 
            }
        }
    } 

    return [@queue]
} 

__PACKAGE__->meta->make_immutable;

1

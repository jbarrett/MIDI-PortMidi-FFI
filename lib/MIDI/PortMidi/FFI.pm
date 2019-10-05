use strict;
use warnings;
package MIDI::PortMidi::FFI;
use base qw/ Exporter /;

{
package PmDeviceInfo;
use FFI::Platypus::Record;

record_layout(
    int => 'structVersion',
    string_rw => 'interf',
    string_rw => 'name',
    int => 'input',
    int => 'output',
    int => 'opened',
);
}

{
package PmEvent;
use FFI::Platypus::Record;

record_layout(
    int32_t => 'message',
    int32_t => 'timestamp',
);
}

use FFI::Platypus;
use FFI::Platypus::Buffer;
use FFI::CheckLib;

my $ffi = FFI::Platypus->new;
$ffi->lib( find_lib_or_die( lib => 'portmidi' ) );

# enum PmError
use constant pmNoError => 0;
use constant pmNoData => 0;
use constant pmGotData => 1;
use constant pmHostError => -10000;
use constant pmInvalidDeviceId => -9999;
use constant pmInsufficientMemory => -9998;
use constant pmBufferTooSmall => -9997;
use constant pmBufferOverflow => -9996;
use constant pmBadPtr => -9995;
use constant pmBadData => -9994;
use constant pmInternalError => -9993;
use constant pmBufferMaxSize => -9992;
$ffi->type( int => 'PmError' );

use constant PM_FILT_ACTIVE => (1 << 0x0E);
use constant PM_FILT_SYSEX => (1 << 0x00);
use constant PM_FILT_CLOCK => (1 << 0x08);
use constant PM_FILT_PLAY => ((1 << 0x0A) | (1 << 0x0C) | (1 << 0x0B));
use constant PM_FILT_TICK => (1 << 0x09);
use constant PM_FILT_FD => (1 << 0x0D);
use constant PM_FILT_UNDEFINED => PM_FILT_FD;
use constant PM_FILT_RESET => (1 << 0x0F);
use constant PM_FILT_REALTIME => (PM_FILT_ACTIVE | PM_FILT_SYSEX | PM_FILT_CLOCK | PM_FILT_PLAY | PM_FILT_UNDEFINED | PM_FILT_RESET | PM_FILT_TICK);
use constant PM_FILT_NOTE => ((1 << 0x19) | (1 << 0x18));
use constant PM_FILT_CHANNEL_AFTERTOUCH => (1 << 0x1D);
use constant PM_FILT_POLY_AFTERTOUCH => (1 << 0x1A);
use constant PM_FILT_AFTERTOUCH => (PM_FILT_CHANNEL_AFTERTOUCH | PM_FILT_POLY_AFTERTOUCH);
use constant PM_FILT_PROGRAM => (1 << 0x1C);
use constant PM_FILT_CONTROL => (1 << 0x1B);
use constant PM_FILT_PITCHBEND => (1 << 0x1E);
use constant PM_FILT_MTC => (1 << 0x01);
use constant PM_FILT_SONG_POSITION => (1 << 0x02);
use constant PM_FILT_SONG_SELECT => (1 << 0x03);
use constant PM_FILT_TUNE => (1 << 0x06);
use constant PM_FILT_SYSTEMCOMMON => (PM_FILT_MTC | PM_FILT_SONG_POSITION | PM_FILT_SONG_SELECT | PM_FILT_TUNE);

use constant HDRLENGTH => 50;
use constant PM_HOST_ERROR_MSG_LEN => 256;

$ffi->type( opaque => 'PmStream' );
$ffi->type( opaque => 'PortMidiStream' );
$ffi->type( opaque => 'PmTimeProcPtr' ); # ???
$ffi->type( 'opaque*' => 'PortMidiStream_p' );
$ffi->type( int => 'PmDeviceID' );
$ffi->type( int32_t => 'PmTimestamp' );
$ffi->type( int32_t => 'PmMessage' );
$ffi->type("record(PmDeviceInfo)" => 'PmDeviceInfo');
$ffi->type("record(PmEvent)" => 'PmEvent');

# Functions
$ffi->attach( Pm_Initialize => ['void'] => 'PmError' );
$ffi->attach( Pm_Terminate => ['void'] => 'PmError' );
$ffi->attach( Pm_HasHostError => ['PortMidiStream'] => 'int' );
$ffi->attach( Pm_GetErrorText => ['PmError'] => 'string' );
$ffi->attach( [ Pm_GetHostErrorText => '_Pm_GetHostErrorText' ] => ['string','unsigned int'] => 'void' ); # need to wrap this with scalar_to_buffer?
$ffi->attach( Pm_CountDevices => ['void'] => 'int' );
$ffi->attach( Pm_GetDefaultInputDeviceID => ['void'] => 'PmDeviceID' );
$ffi->attach( Pm_GetDefaultOutputDeviceID => ['void'] => 'PmDeviceID' );
$ffi->attach( Pm_GetDeviceInfo => ['PmDeviceID'] => 'PmDeviceInfo' );
$ffi->attach( Pm_OpenInput => ['PortMidiStream_p','PmDeviceID','opaque','int32_t','PmTimeProcPtr','opaque'] => 'PmError' ); # ???
$ffi->attach( Pm_OpenOutput => ['PortMidiStream_p','PmDeviceID','opaque','int32_t','PmTimeProcPtr','opaque'] => 'PmError' ); # ???
$ffi->attach( Pm_SetFilter => ['PortMidiStream','int32_t'] => 'PmError' );
$ffi->attach( Pm_SetChannelMask => ['PortMidiStream','int'] => 'PmError' );
$ffi->attach( Pm_Abort => ['PortMidiStream'] => 'PmError' );
$ffi->attach( Pm_Close => ['PortMidiStream'] => 'PmError' );
$ffi->attach( Pm_Synchronize => ['PortMidiStream'] => 'PmError' );
$ffi->attach( Pm_Read => ['PortMidiStream','PmEvent','int32_t'] => 'int' );
$ffi->attach( Pm_Poll => ['PortMidiStream'] => 'PmError' );
$ffi->attach( Pm_Write => ['PortMidiStream','PmEvent','int32_t'] => 'PmError' );
$ffi->attach( Pm_WriteShort => ['PortMidiStream','PmTimestamp','int32_t'] => 'PmError' );
$ffi->attach( Pm_WriteSysEx => ['PortMidiStream','PmTimestamp','string'] => 'PmError' );

sub PmBefore { $_[0] - $_[1] < 0 }
sub Pm_Channel { 1<<$_[0] }
sub Pm_MessageStatus { $_[0] & 0xFF }
sub Pm_MessageData1  { ( $_[0] >> 8 ) & 0xFF }
sub Pm_MessageData2  { ( $_[0] >> 16 ) & 0xFF }
sub Pm_Message {
    my ( $status, $data1, $data2 ) = @_;
         (((($data2) << 16) & 0xFF0000) | \
          ((($data1) << 8) & 0xFF00) | \
          (($$status) & 0xFF))
}
sub Pm_GetHostErrorText {
    my ( $buf ) = @_;
    $$buf ||= ' ' x 1024;
    my ( $ptr, $size ) = scalar_to_buffer $$buf;
    _Pm_GetHostErrorText( $ptr, $size );
}

our @EXPORT_OK = qw/
    pmNoError
    pmNoData
    pmGotData
    pmHostError
    pmInvalidDeviceId
    pmInsufficientMemory
    pmBufferTooSmall
    pmBufferOverflow
    pmBadPtr
    pmBadData
    pmInternalError
    pmBufferMaxSize
    PM_FILT_ACTIVE
    PM_FILT_SYSEX
    PM_FILT_CLOCK
    PM_FILT_PLAY
    PM_FILT_TICK
    PM_FILT_FD
    PM_FILT_UNDEFINED
    PM_FILT_RESET
    PM_FILT_REALTIME
    PM_FILT_NOTE
    PM_FILT_CHANNEL_AFTERTOUCH
    PM_FILT_POLY_AFTERTOUCH
    PM_FILT_AFTERTOUCH
    PM_FILT_PROGRAM
    PM_FILT_CONTROL
    PM_FILT_PITCHBEND
    PM_FILT_MTC
    PM_FILT_SONG_POSITION
    PM_FILT_SONG_SELECT
    PM_FILT_TUNE
    PM_FILT_SYSTEMCOMMON
    HDRLENGTH
    PM_HOST_ERROR_MSG_LEN
    Pm_Initialize
    Pm_Terminate
    Pm_HasHostError
    Pm_GetErrorText
    Pm_CountDevices
    Pm_GetDefaultInputDeviceID
    Pm_GetDefaultOutputDeviceID
    Pm_GetDeviceInfo
    Pm_OpenInput
    Pm_OpenOutput
    Pm_SetFilter
    Pm_SetChannelMask
    Pm_Abort
    Pm_Close
    Pm_Synchronize
    Pm_Read
    Pm_Poll
    Pm_Write
    Pm_WriteShort
    Pm_WriteSysEx
/;

our %EXPORT_TAGS = (
    functions => [ grep { /^Pm/ } @EXPORT_OK ],
    enums     => [ grep { /^pm/ } @EXPORT_OK ],
    defines   => [ grep { $_ !~ /[a-z]/ } @EXPORT_OK ],
);
push @{$EXPORT_TAGS{all}}, qw/ functions defines enums /;

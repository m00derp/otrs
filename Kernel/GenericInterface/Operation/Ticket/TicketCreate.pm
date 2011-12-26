# --
# Kernel/GenericInterface/Operation/Ticket/TicketCreate.pm - GenericInterface Ticket TicketCreate operation backend
# Copyright (C) 2001-2011 OTRS AG, http://otrs.org/
# --
# $Id: TicketCreate.pm,v 1.5 2011-12-26 20:01:11 cr Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::GenericInterface::Operation::Ticket::TicketCreate;

use strict;
use warnings;

use Kernel::GenericInterface::Operation::Ticket::Common;
use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.5 $) [1];

=head1 NAME

Kernel::GenericInterface::Operation::Ticket::TicketCreate - GenericInterface Ticket TicketCreate Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::GenericInterface::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (
        qw(
        DebuggerObject ConfigObject MainObject LogObject TimeObject DBObject EncodeObject
        WebserviceID
        )
        )
    {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{TicketCommonObject}
        = Kernel::GenericInterface::Operation::Ticket::Common->new( %{$Self} );

    return $Self;
}

=item Run()

perform TicketCreate Operation. This will return the created ticket number.

    my $Result = $OperationObject->Run(
        Data => {
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        ErrorMessage    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            TicketID    => 123,                     # Ticket  ID number in OTRS (help desk system)
            ArticleID   => 43,                      # Article ID number in OTRS (help desk system)
            Errors => {                         # should not return errors
                item => {
                    ErrorCode1   => 1
                    ErrorCode2   => 32
                    ErrorCode3   => undef
                    ErrorMessage => 'Error Description'
                },
            },
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(UserLogin)) {
        if ( !$Param{Data}->{$Needed} ) {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: $Needed parameter is missing!",
            );
        }
    }

    # check needed hashes
    for my $Needed (qw(Ticket Article)) {
        if ( !IsHashRefWithData( $Param{Data}->{$Needed} ) ) {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: $Needed parameter is missing or not valid!",
            );
        }
    }

    # check optional array/hashes
    for my $Optional (qw(DynamicField Attachment)) {
        if (
            defined $Param{Data}->{$Optional}
            && !IsHashRefWithData( $Param{Data}->{$Optional} )
            && !IsArrayRefWithData( $Param{Data}->{$Optional} )
            )
        {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: $Optional parameter is missing or not valid!",
            );
        }
    }

    # isolate tiket parameter
    my $Ticket = $Param{Data}->{Ticket};

    # check ticket internally
    for my $Needed (qw(Title CustomerUser)) {
        if ( !$Ticket->{$Needed} ) {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode    => 'TicketCreate.MissingParameter',
                ErrorMessage => "TicketCreate: Ticket->$Needed parameter is missing!",
            );
        }
    }

    # check Ticket->CustomerUser
    if ( !$Self->{TicketCommonObject}->ValidateCustomer( %{$Ticket} ) ) {
        return $Self->{TicketCommonObject}->ReturnError(
            ErrorCode => 'TicketCreate.InvalidParameter',
            ErrorMessage =>
                "TicketCreate: Ticket->CustomerUser parameter is invalid!",
        );
    }

    # check Ticket->Queue
    if ( !$Ticket->{QueueID} && !$Ticket->{Queue} ) {
        return $Self->{TicketCommonObject}->ReturnError(
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->QueueID or Ticket->Queue parameter is required!",
        );
    }
    if ( !$Self->{TicketCommonObject}->ValidateQueue( %{$Ticket} ) ) {
        return $Self->{TicketCommonObject}->ReturnError(
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Ticket->QueueID or Ticket->Queue parameter is invalid!",
        );
    }

    # check Ticket->Lock
    if ( !$Ticket->{LockID} && !$Ticket->{Lock} ) {
        return $Self->{TicketCommonObject}->ReturnError(
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->LockID or Ticket->Lock parameter is required!",
        );
    }
    if ( !$Self->{TicketCommonObject}->ValidateLock( %{$Ticket} ) ) {
        return $Self->{TicketCommonObject}->ReturnError(
            ErrorCode    => 'TicketCreate.InvalidParameter',
            ErrorMessage => "TicketCreate: Ticket->LockID or Ticket->Lock parameter is invalid!",
        );
    }

    # check Ticket->Type
    # Ticket type could be required or not depending on sysconfig option
    if (
        !$Ticket->{TypeID}
        && !$Ticket->{Type}
        && $Self->{ConfigObject}->Get('Ticket::Type')
        )
    {
        return $Self->{TicketCommonObject}->ReturnError(
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->TypeID or Ticket->Type parameter is required"
                . " by sysconfig option!",
        );
    }
    if ( $Ticket->{TypeID} || $Ticket->{Type} ) {
        if ( !$Self->{TicketCommonObject}->ValidateType( %{$Ticket} ) ) {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode => 'TicketCreate.InvalidParameter',
                ErrorMessage =>
                    "TicketCreate: Ticket->TypeID or Ticket->Type parameter is invalid!",
            );
        }
    }

    # check Ticket->Service
    # Ticket service could be required or not depending on sysconfig option
    if (
        !$Ticket->{ServiceID}
        && !$Ticket->{Service}
        && $Self->{ConfigObject}->Get('Ticket::Service')
        )
    {
        return $Self->{TicketCommonObject}->ReturnError(
            ErrorCode    => 'TicketCreate.MissingParameter',
            ErrorMessage => "TicketCreate: Ticket->ServiceID or Ticket->Service parameter is"
                . "  required by sysconfig option!",
        );
    }
    if ( $Ticket->{ServiceID} || $Ticket->{Service} ) {
        if ( !$Self->{TicketCommonObject}->ValidateService( %{$Ticket} ) ) {
            return $Self->{TicketCommonObject}->ReturnError(
                ErrorCode => 'TicketCreate.InvalidParameter',
                ErrorMessage =>
                    "TicketCreate: Ticket->ServiceID or Ticket->Service parameter is invalid!",
            );
        }
    }

    return {
        Success => 1,
        Data    => {
            Test => 'Test OK',
        },
    };
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

=head1 VERSION

$Revision: 1.5 $ $Date: 2011-12-26 20:01:11 $

=cut

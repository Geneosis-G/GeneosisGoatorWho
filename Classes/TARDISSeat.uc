class TARDISSeat extends GGVehiclePassengerSeat;

function GetInVechile( Pawn userPawn )
{
	local GGGoat goatUser;

	goatUser = GGGoat( userPawn );
	if( goatUser != none )
	{
		// This stops the goat's head from colliding with the bike, which after call to SetBase causes exploding collisions.
		// Normally SetCollision and SetHardAttach should take care of this, but the goat's head is special case.
		goatUser.SetHeadFixed( true );

		if( userPawn.mesh != none )
		{
			mRBChannelDriverBeforeDriving = userPawn.mesh.RBChannel;
			userPawn.mesh.SetRBChannel( RBCC_Untitled2 );
		}
	}
}

function GetOutOfVehicle( Pawn userPawn )
{
	if( userPawn.mesh != none )
	{
		userPawn.mesh.SetRBChannel( mRBChannelDriverBeforeDriving );
	}
}

event bool DriverLeave( bool bForceLeave )
{
	local bool didLeave;
	local GGGoat oldDriver;

	if(TARDISVehicle(mVehicleOwner).IsTARDISLocked())
		return false;

	oldDriver=GGGoat(Driver);
	didLeave=super.DriverLeave(bForceLeave);
	if(didLeave && oldDriver != none)
	{
		TARDISVehicle(mVehicleOwner).myMut.PassengerLeaveTARDIS(oldDriver.mCachedSlotNr);
	}

	return didLeave;
}

DefaultProperties
{
	mCameraLookAtOffset=(X=0.0f,Y=0.0f,Z=0.0f)

	mDriverPosOffsetX=0.0f
	mDriverPosOffsetZ=0.0f

	bDriverIsVisible=false

	// Vehicle
	ExitPositions(0)=(X=0.0f,Y=200.0f,Z=0.0f)
	ExitPositions(1)=(X=0.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(2)=(X=200.0f,Y=0.0f,Z=0.0f)
	ExitPositions(3)=(X=-200.0f,Y=0.0f,Z=0.0f)
	ExitPositions(4)=(X=200.0f,Y=200.0f,Z=0.0f)
	ExitPositions(5)=(X=-200.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(6)=(X=200.0f,Y=-200.0f,Z=0.0f)
	ExitPositions(7)=(X=-200.0f,Y=200.0f,Z=0.0f)
}
